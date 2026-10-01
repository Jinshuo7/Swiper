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

    def test_routine_and_planned_classification(self) -> None:
        manifest = self.manifest()
        self.assertEqual(controller.classify_ticket(manifest), (False, []))
        manifest["risk"]["architectural"] = True
        self.assertEqual(controller.classify_ticket(manifest), (True, ["architectural"]))

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
