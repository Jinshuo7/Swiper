import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "ticket_controller.py"
SPEC = importlib.util.spec_from_file_location("ticket_controller", MODULE_PATH)
assert SPEC and SPEC.loader
controller = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = controller
SPEC.loader.exec_module(controller)


def command(*args: str, cwd: Path) -> str:
    return subprocess.run(
        list(args), cwd=cwd, check=True, text=True, capture_output=True
    ).stdout


class TicketControllerTests(unittest.TestCase):
    def manifest(self) -> dict:
        return {
            "ticket": {"id": "test", "acceptance_criteria": ["done"]},
            "scope": {
                "allow_edit": ["editable.txt"],
                "allow_create": [],
                "context": ["context.txt"],
            },
            "models": {
                "codex": {"role": "codex", "provider": "x", "model": "x"},
                "deepseek": {"role": "deepseek", "provider": "x", "model": "x"},
            },
            "budgets": {},
            "risk": {},
            "verification": [
                {
                    "name": "true",
                    "command": ["git", "diff", "--check"],
                    "inputs": ["editable.txt"],
                }
            ],
        }

    def bare_controller(self, manifest=None):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        command("git", "init", cwd=root)
        (root / "editable.txt").write_text("editable")
        (root / "context.txt").write_text("context")
        value = manifest or self.manifest()
        value["run_root"] = str(root / "runs")
        path = root / "manifest.json"
        path.write_text(json.dumps(value))
        return controller.TicketController(path, source_root=root)

    def test_routine_and_planned_classification(self) -> None:
        manifest = self.manifest()
        self.assertEqual(controller.classify_ticket(manifest), (False, []))
        manifest["risk"]["architectural"] = True
        self.assertEqual(controller.classify_ticket(manifest), (True, ["architectural"]))

    def test_strict_json_rejects_trailing_prose_and_two_objects(self) -> None:
        for value in ('{"disposition":"ACCEPT"} trailing', '{} {}'):
            with self.subTest(value=value):
                with self.assertRaises(controller.ControllerError):
                    controller.parse_json_response(value)

    def test_final_assistant_message_wins(self) -> None:
        messages = [
            {"role": "assistant", "content": [{"type": "text", "text": '{"disposition":"ACCEPT"}'}]},
            {"role": "assistant", "content": [{"type": "text", "text": '{"disposition":"CORRECT","corrections":["fix"]}'}]},
        ]
        parsed = controller.parse_json_response(controller.final_assistant_text(messages))
        self.assertEqual(parsed["disposition"], "CORRECT")

    def test_accept_requires_every_criterion(self) -> None:
        with self.assertRaisesRegex(controller.ControllerError, "every acceptance criterion"):
            controller.validate_acceptance(
                {
                    "disposition": "ACCEPT",
                    "blocking_findings": [],
                    "criteria": [{"index": 0, "met": True, "evidence": "proof"}],
                },
                ["one", "two"],
            )

    def test_well_formed_accept_and_correct_schemas(self) -> None:
        accepted = {
            "disposition": "ACCEPT",
            "blocking_findings": [],
            "criteria": [
                {"index": 0, "met": True, "evidence": "test A"},
                {"criterion": "two", "met": True, "evidence": "test B"},
            ],
        }
        self.assertEqual(controller.validate_acceptance(accepted, ["one", "two"]), "ACCEPT")
        self.assertEqual(
            controller.validate_acceptance(
                {"disposition": "CORRECT", "corrections": ["fix it"]}, ["one"]
            ),
            "CORRECT",
        )
        with self.assertRaisesRegex(controller.ControllerError, "corrections"):
            controller.validate_acceptance({"disposition": "CORRECT", "corrections": []}, ["one"])

    def test_model_workspace_is_outside_repository_and_run_root(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            command("git", "init", cwd=root)
            command("git", "config", "user.email", "test@example.com", cwd=root)
            command("git", "config", "user.name", "Test", cwd=root)
            (root / "editable.txt").write_text("editable\n")
            (root / "context.txt").write_text("context\n")
            command("git", "add", ".", cwd=root)
            command("git", "commit", "-m", "baseline", cwd=root)
            manifest = self.manifest()
            manifest["run_root"] = str(root / "runs")
            manifest_path = root / "manifest.json"
            manifest_path.write_text(json.dumps(manifest))
            instance = controller.TicketController(manifest_path, source_root=root)
            self.assertNotIn(root.resolve(), instance.model_root.resolve().parents)
            self.assertNotIn(instance.run_root.resolve(), instance.model_root.resolve().parents)

    def test_tool_event_without_path_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest_path = root / "manifest.json"
            manifest_path.write_text(json.dumps(self.manifest()))
            (root / "editable.txt").write_text("editable")
            (root / "context.txt").write_text("context")
            command("git", "init", cwd=root)
            instance = controller.TicketController(manifest_path, source_root=root)
            with self.assertRaisesRegex(controller.ControllerError, "identifiable string path"):
                instance._tool_event_path({"toolName": "write", "args": {"content": "x"}})

    def test_post_call_integrity_detects_source_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            command("git", "init", cwd=root)
            (root / "editable.txt").write_text("before")
            (root / "context.txt").write_text("context")
            manifest_path = root / "manifest.json"
            manifest_path.write_text(json.dumps(self.manifest()))
            instance = controller.TicketController(manifest_path, source_root=root)
            instance.baseline_hashes = {"editable.txt": controller.file_hash(root / "editable.txt")}
            expected = instance._integrity_snapshot()
            (root / "editable.txt").write_text("after")
            with self.assertRaisesRegex(controller.ControllerError, "integrity drift"):
                instance._assert_integrity(expected)

    def test_forged_patch_ready_ledger_without_attestation_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            command("git", "init", cwd=root)
            command("git", "config", "user.email", "test@example.com", cwd=root)
            command("git", "config", "user.name", "Test", cwd=root)
            (root / "editable.txt").write_text("base")
            command("git", "add", "editable.txt", cwd=root)
            command("git", "commit", "-m", "base", cwd=root)
            (root / "candidate.patch").write_text("")
            (root / "head.txt").write_text(command("git", "rev-parse", "HEAD", cwd=root))
            ledger = root / "ledger.json"
            ledger.write_text(json.dumps({
                "state": "PATCH_READY",
                "source_root": str(root),
                "candidate_patch_hash": controller.file_hash(root / "candidate.patch"),
                "changed_paths": ["editable.txt"],
                "baseline_hashes": {"editable.txt": None},
            }))
            with self.assertRaisesRegex(controller.ControllerError, "attestation"):
                controller.apply_accepted(ledger)

    def test_verifier_blocking_findings_block(self) -> None:
        manifest = self.manifest()
        manifest["models"]["verifier"] = {"role": "verifier", "provider": "x", "model": "x"}
        instance = self.bare_controller(manifest)
        instance._bounded_response = lambda *args, **kwargs: (
            {"disposition": "VERIFY", "blocking_findings": ["unsafe"]}, None
        )
        with self.assertRaisesRegex(controller.ControllerError, "blocking findings"):
            instance._run_independent_verifier("diff", [])

    def test_verifier_missing_blocking_findings_blocks(self) -> None:
        manifest = self.manifest()
        manifest["models"]["verifier"] = {"role": "verifier", "provider": "x", "model": "x"}
        instance = self.bare_controller(manifest)
        instance._bounded_response = lambda *args, **kwargs: (
            {"disposition": "VERIFY"}, None
        )
        with self.assertRaisesRegex(controller.ControllerError, "omitted"):
            instance._run_independent_verifier("diff", [])

    def test_clean_verifier_receipt_is_in_acceptance_prompt(self) -> None:
        manifest = self.manifest()
        manifest["models"]["verifier"] = {"role": "verifier", "provider": "x", "model": "x"}
        instance = self.bare_controller(manifest)
        instance._bounded_response = lambda *args, **kwargs: (
            {"disposition": "VERIFY", "blocking_findings": []}, None
        )
        instance._run_independent_verifier("diff", [])
        self.assertIn('"blocking_findings": []', instance._acceptance_prompt("diff", []))

    def test_context_request_cannot_expand_edit_scope(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "context.txt").write_text("context")
            (root / "editable.txt").write_text("editable")
            model = root / "model"
            model.mkdir()
            broker = controller.ContextBroker(
                root, model, ["context.txt"], ["editable.txt"], [], 4, 1000, [], []
            )
            broker.copy_initial()
            with self.assertRaisesRegex(controller.ControllerError, "owner approval"):
                broker.handle_request(
                    {
                        "requested": ["context.txt"],
                        "reason": "must change it",
                        "access": "edit",
                        "maximum_scope": 1,
                    }
                )

    def test_context_request_rejects_non_numeric_maximum_scope(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "context.txt").write_text("context")
            model = root / "model"
            model.mkdir()
            broker = controller.ContextBroker(
                root, model, ["context.txt"], [], [], 4, 1000, [], []
            )
            with self.assertRaisesRegex(controller.ControllerError, "positive integer"):
                broker.handle_request({
                    "requested": ["context.txt"],
                    "reason": "needed",
                    "access": "read-only",
                    "maximum_scope": "one",
                })

    def test_request_allowlisted_read_only_file_syncs_cleanly(self) -> None:
        instance = self.bare_controller()
        root = instance.source_root
        (root / "requested.txt").write_text("requested")
        instance.manifest["scope"]["allow_context_requests"] = ["requested.txt"]
        instance.baseline_hashes = {"requested.txt": controller.file_hash(root / "requested.txt")}
        instance.isolated_root.mkdir()
        (instance.isolated_root / "requested.txt").write_text("requested")
        instance.broker = controller.ContextBroker(
            instance.isolated_root,
            instance.model_root,
            [],
            ["editable.txt"],
            [],
            5,
            1000,
            [],
            ["requested.txt"],
        )
        instance.broker.grant("requested.txt", access="read-only")
        instance._sync_worker_changes()

    def test_re_request_preserves_edited_file_and_write_mode(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "editable.txt").write_text("before")
            model = root / "model"
            model.mkdir()
            broker = controller.ContextBroker(
                root, model, [], ["editable.txt"], [], 5, 1000, [], []
            )
            broker.grant("editable.txt", access="edit")
            target = model / "editable.txt"
            target.write_text("worker edit")
            broker.grant("editable.txt", access="read-only")
            self.assertEqual(target.read_text(), "worker edit")
            self.assertTrue(target.stat().st_mode & 0o200)

    def test_context_continuation_contains_all_prior_grants(self) -> None:
        instance = self.bare_controller()
        for name in ("first.txt", "second.txt"):
            (instance.source_root / name).write_text(name)
        instance.broker = controller.ContextBroker(
            instance.source_root,
            instance.model_root,
            [],
            [],
            [],
            5,
            1000,
            [],
            ["first.txt", "second.txt"],
        )
        replies = iter([
            '{"disposition":"REQUEST_CONTEXT","requested":["first.txt"],"reason":"one","access":"read-only","maximum_scope":1}',
            '{"disposition":"REQUEST_CONTEXT","requested":["second.txt"],"reason":"two","access":"read-only","maximum_scope":1}',
            '{"disposition":"PLAN"}',
        ])
        prompts = []

        def fake_run(model_name, prompt, **kwargs):
            prompts.append(prompt)
            return controller.PiResult(next(replies), controller.Usage())

        instance._run_pi = fake_run
        instance._bounded_response("codex", "base", allowed={"PLAN"})
        self.assertIn("first.txt\nfirst.txt", prompts[2])
        self.assertIn("second.txt\nsecond.txt", prompts[2])

    def test_every_run_failure_writes_blocked_receipt(self) -> None:
        failures = [
            controller.ControllerError("parse error"),
            controller.ControllerError("model timeout exceeded"),
            controller.ControllerError("token budget exceeded"),
            RuntimeError("unexpected stub failure"),
        ]
        for failure in failures:
            with self.subTest(failure=str(failure)):
                instance = self.bare_controller()

                def fail(error=failure):
                    raise error

                instance._run_impl = fail
                with self.assertRaises(type(failure)):
                    instance.run()
                ledger = json.loads(instance.ledger_path.read_text())
                receipt = json.loads((instance.run_root / "receipt.json").read_text())
                self.assertEqual(ledger["state"], "BLOCKED")
                self.assertEqual(receipt["state"], "BLOCKED")
                self.assertEqual(receipt["exception_type"], type(failure).__name__)
                self.assertEqual(receipt["exception_message"], str(failure))

    def test_required_missing_visual_blocks_before_models(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            command("git", "init", cwd=root)
            command("git", "config", "user.email", "test@example.com", cwd=root)
            command("git", "config", "user.name", "Test", cwd=root)
            (root / "editable.txt").write_text("editable\n")
            (root / "context.txt").write_text("context\n")
            command("git", "add", ".", cwd=root)
            command("git", "commit", "-m", "baseline", cwd=root)
            manifest = self.manifest()
            manifest["run_root"] = str(root / "runs")
            manifest["visual_references"] = [
                {"path": "approved/missing.png", "required": True}
            ]
            manifest_path = root / "manifest.json"
            manifest_path.write_text(json.dumps(manifest))
            instance = controller.TicketController(manifest_path, source_root=root)
            with self.assertRaisesRegex(controller.ControllerError, "no substitution"):
                instance.run()
            ledger = json.loads(instance.ledger_path.read_text())
            self.assertEqual(ledger["state"], "BLOCKED")
            self.assertEqual(ledger["model_calls"], {"codex": 0, "deepseek": 0, "verifier": 0})
            self.assertTrue((instance.run_root / "receipt.json").is_file())
            command("git", "worktree", "remove", "--force", str(instance.isolated_root), cwd=root)

    def test_verification_key_changes_with_input(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            command("git", "init", cwd=root)
            command("git", "config", "user.email", "test@example.com", cwd=root)
            command("git", "config", "user.name", "Test", cwd=root)
            (root / "editable.txt").write_text("one\n")
            (root / "context.txt").write_text("context\n")
            command("git", "add", ".", cwd=root)
            command("git", "commit", "-m", "baseline", cwd=root)
            manifest = self.manifest()
            manifest["run_root"] = str(root / "runs")
            manifest_path = root / "manifest.json"
            manifest_path.write_text(json.dumps(manifest))
            instance = controller.TicketController(manifest_path, source_root=root)
            instance.prepare()
            check = instance.manifest["verification"][0]
            first = instance._test_key(check, {})
            (instance.isolated_root / "editable.txt").write_text("two\n")
            second = instance._test_key(check, {})
            self.assertNotEqual(first, second)
            command("git", "worktree", "remove", "--force", str(instance.isolated_root), cwd=root)

    def test_verification_key_changes_with_undeclared_allowed_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            command("git", "init", cwd=root)
            command("git", "config", "user.email", "test@example.com", cwd=root)
            command("git", "config", "user.name", "Test", cwd=root)
            (root / "editable.txt").write_text("one\n")
            (root / "other.txt").write_text("before\n")
            (root / "context.txt").write_text("context\n")
            command("git", "add", ".", cwd=root)
            command("git", "commit", "-m", "baseline", cwd=root)
            manifest = self.manifest()
            manifest["scope"]["allow_edit"].append("other.txt")
            manifest["run_root"] = str(root / "runs")
            manifest_path = root / "manifest.json"
            manifest_path.write_text(json.dumps(manifest))
            instance = controller.TicketController(manifest_path, source_root=root)
            instance.prepare()
            check = instance.manifest["verification"][0]
            first = instance._test_key(check, {})
            (instance.isolated_root / "other.txt").write_text("after\n")
            second = instance._test_key(check, {})
            self.assertNotEqual(first, second)
            self.assertNotIn(root.resolve(), instance._cache_root().resolve().parents)
            command("git", "worktree", "remove", "--force", str(instance.isolated_root), cwd=root)

    def test_corrupt_or_mismatched_cache_is_not_reused(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary) / "cache.json"
            cache.write_text("not json")
            self.assertIsNone(controller.TicketController._cached_pass(cache, "key", ["true"]))
            cache.write_text(json.dumps({"key": "wrong", "command": ["true"], "returncode": 0}))
            self.assertIsNone(controller.TicketController._cached_pass(cache, "key", ["true"]))

    def test_unchanged_cache_entry_is_reused(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary) / "cache.json"
            expected = {"key": "key", "command": ["true"], "returncode": 0}
            cache.write_text(json.dumps(expected))
            self.assertEqual(
                controller.TicketController._cached_pass(cache, "key", ["true"]), expected
            )

    def test_review_diff_includes_prior_work_but_candidate_patch_does_not(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            command("git", "init", cwd=root)
            command("git", "config", "user.email", "test@example.com", cwd=root)
            command("git", "config", "user.name", "Test", cwd=root)
            (root / "editable.txt").write_text("committed\n")
            (root / "context.txt").write_text("context\n")
            command("git", "add", ".", cwd=root)
            command("git", "commit", "-m", "baseline", cwd=root)
            (root / "editable.txt").write_text("prior user work\n")
            manifest = self.manifest()
            manifest["run_root"] = str(root / "runs")
            manifest_path = root / "manifest.json"
            manifest_path.write_text(json.dumps(manifest))
            instance = controller.TicketController(manifest_path, source_root=root)
            instance.prepare()
            (instance.isolated_root / "editable.txt").write_text("worker result\n")
            review = instance._diff()
            worker = (instance.run_root / "worker.patch").read_text()
            self.assertIn("-committed", review)
            self.assertIn("+worker result", review)
            self.assertIn("-prior user work", worker)
            self.assertNotIn("-committed", worker)
            command("git", "worktree", "remove", "--force", str(instance.isolated_root), cwd=root)


if __name__ == "__main__":
    unittest.main()
