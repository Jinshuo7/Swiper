#!/usr/bin/env python3
"""Deterministic, budgeted controller for one agent ticket at a time.

The controller owns orchestration. Models receive bounded packets and return
structured dispositions; they never decide scheduling, retries, or file scope.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import selectors
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
from typing import Any, Iterable


class ControllerError(RuntimeError):
    pass


class State(str, Enum):
    CREATED = "CREATED"
    BASELINED = "BASELINED"
    ISOLATED = "ISOLATED"
    CLASSIFIED = "CLASSIFIED"
    READY = "READY"
    PLANNED = "PLANNED"
    IMPLEMENTED = "IMPLEMENTED"
    VERIFIED = "VERIFIED"
    REVIEWED = "REVIEWED"
    CORRECTING = "CORRECTING"
    ACCEPTED = "ACCEPTED"
    PATCH_READY = "PATCH_READY"
    APPLIED = "APPLIED"
    DRY_RUN = "DRY_RUN"
    BLOCKED = "BLOCKED"


ALLOWED_TRANSITIONS = {
    State.CREATED: {State.BASELINED, State.BLOCKED},
    State.BASELINED: {State.ISOLATED, State.BLOCKED},
    State.ISOLATED: {State.CLASSIFIED, State.BLOCKED},
    State.CLASSIFIED: {State.READY, State.PLANNED, State.IMPLEMENTED, State.BLOCKED},
    State.READY: {State.PLANNED, State.IMPLEMENTED, State.DRY_RUN, State.BLOCKED},
    State.PLANNED: {State.IMPLEMENTED, State.BLOCKED},
    State.IMPLEMENTED: {State.VERIFIED, State.BLOCKED},
    State.VERIFIED: {State.REVIEWED, State.BLOCKED},
    State.REVIEWED: {State.ACCEPTED, State.CORRECTING, State.BLOCKED},
    State.CORRECTING: {State.IMPLEMENTED, State.BLOCKED},
    State.ACCEPTED: {State.PATCH_READY, State.BLOCKED},
    State.PATCH_READY: {State.APPLIED, State.BLOCKED},
    State.APPLIED: set(),
    State.DRY_RUN: set(),
    State.BLOCKED: set(),
}


PLANNING_FLAGS = (
    "ambiguous",
    "architectural",
    "cross_cutting",
    "dependency_heavy",
    "safety_sensitive",
    "hard_to_decompose",
)

INDEPENDENT_REVIEW_FLAGS = (
    "deletion_or_data_loss",
    "persistence_or_migration",
    "privacy_or_security",
    "release_candidate",
    "large_or_cross_cutting_diff",
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_hash(path: Path) -> str | None:
    if path.is_file():
        return sha256_bytes(path.read_bytes())
    if path.is_dir():
        digest = hashlib.sha256()
        for child in sorted(candidate for candidate in path.rglob("*") if candidate.is_file()):
            if ".git" in child.parts:
                continue
            digest.update(child.relative_to(path).as_posix().encode())
            digest.update(b"\0")
            digest.update(child.read_bytes())
            digest.update(b"\0")
        return digest.hexdigest()
    return None


def json_dump(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    temporary.replace(path)


def run_command(
    args: list[str],
    *,
    cwd: Path,
    env: dict[str, str] | None = None,
    timeout: int = 60,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        args,
        cwd=cwd,
        env={**os.environ, **(env or {})},
        text=True,
        capture_output=True,
        timeout=timeout,
    )
    if check and completed.returncode:
        raise ControllerError(
            f"command failed ({completed.returncode}): {' '.join(args)}\n"
            f"{completed.stderr[-4000:]}"
        )
    return completed


def git(root: Path, *args: str, timeout: int = 60, check: bool = True) -> str:
    return run_command(["git", *args], cwd=root, timeout=timeout, check=check).stdout


def normalize_repo_path(value: str) -> str:
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or value in ("", "."):
        raise ControllerError(f"unsafe repository path: {value!r}")
    return path.as_posix()


def ensure_paths(values: Iterable[str]) -> list[str]:
    return sorted(set(normalize_repo_path(value) for value in values))


def paths_from_nul(data: str) -> list[str]:
    return [entry for entry in data.split("\0") if entry]


def classify_ticket(manifest: dict[str, Any]) -> tuple[bool, list[str]]:
    ticket = manifest.get("ticket", {})
    scope = manifest.get("scope", {})
    verification = manifest.get("verification", [])
    missing = []
    if not ticket.get("acceptance_criteria"):
        missing.append("acceptance criteria")
    if not scope.get("allow_edit"):
        missing.append("edit allowlist")
    if not scope.get("context"):
        missing.append("known implementation context")
    if not verification:
        missing.append("verification commands")
    if missing:
        raise ControllerError("ticket is not executable: missing " + ", ".join(missing))
    reasons = [flag for flag in PLANNING_FLAGS if manifest.get("risk", {}).get(flag, False)]
    return bool(reasons), reasons


def should_independently_verify(manifest: dict[str, Any]) -> tuple[bool, list[str]]:
    reasons = [
        flag
        for flag in INDEPENDENT_REVIEW_FLAGS
        if manifest.get("risk", {}).get(flag, False)
    ]
    return bool(reasons), reasons


def parse_json_response(text: str) -> dict[str, Any]:
    text = text.strip()
    fenced = re.fullmatch(r"```json\s*\n?(.*?)\n?```", text, flags=re.DOTALL)
    candidate = fenced.group(1).strip() if fenced else text
    try:
        value = json.loads(candidate)
    except json.JSONDecodeError as error:
        raise ControllerError("final assistant message is not exactly one JSON object") from error
    if not isinstance(value, dict):
        raise ControllerError("final assistant message is not a JSON object")
    return value


def final_assistant_text(messages: list[dict[str, Any]]) -> str:
    for message in reversed(messages):
        if message.get("role") == "assistant":
            return "".join(
                str(content.get("text", ""))
                for content in message.get("content", [])
                if content.get("type") == "text"
            )
    return ""


def validate_disposition(value: dict[str, Any], allowed: set[str]) -> str:
    disposition = value.get("disposition")
    if disposition not in allowed:
        raise ControllerError(f"invalid disposition {disposition!r}; expected {sorted(allowed)}")
    return disposition


def validate_acceptance(value: dict[str, Any], criteria: list[str]) -> str:
    disposition = validate_disposition(value, {"ACCEPT", "CORRECT", "BLOCK"})
    if disposition == "CORRECT":
        corrections = value.get("corrections")
        if not isinstance(corrections, list) or not corrections:
            raise ControllerError("CORRECT requires a non-empty corrections list")
    if disposition != "ACCEPT":
        return disposition
    if value.get("blocking_findings") != []:
        raise ControllerError("ACCEPT requires blocking_findings: []")
    results = value.get("criteria")
    if not isinstance(results, list) or len(results) != len(criteria):
        raise ControllerError("ACCEPT must account for every acceptance criterion exactly once")
    matched: set[int] = set()
    for result in results:
        if not isinstance(result, dict) or result.get("met") is not True:
            raise ControllerError("ACCEPT criterion must have met: true")
        evidence = result.get("evidence")
        if not isinstance(evidence, str) or not evidence.strip():
            raise ControllerError("ACCEPT criterion requires non-empty evidence")
        index = result.get("index")
        text = result.get("criterion")
        if isinstance(index, int) and not isinstance(index, bool) and 0 <= index < len(criteria):
            matched.add(index)
        elif isinstance(text, str) and text in criteria:
            matched.add(criteria.index(text))
        else:
            raise ControllerError("ACCEPT criterion does not match ticket criteria")
    if matched != set(range(len(criteria))):
        raise ControllerError("ACCEPT criteria contain duplicates or omissions")
    return disposition


@dataclass
class Usage:
    calls: int = 0
    input: int = 0
    output: int = 0
    cache_read: int = 0
    cache_write: int = 0
    reasoning: int = 0
    estimated_cost: float = 0.0

    def add(self, raw: dict[str, Any]) -> None:
        if not raw:
            return
        self.calls += 1
        self.input += int(raw.get("input", 0) or 0)
        self.output += int(raw.get("output", 0) or 0)
        self.cache_read += int(raw.get("cacheRead", 0) or 0)
        self.cache_write += int(raw.get("cacheWrite", 0) or 0)
        self.reasoning += int(raw.get("reasoning", 0) or 0)
        self.estimated_cost += float((raw.get("cost") or {}).get("total", 0) or 0)

    def as_dict(self) -> dict[str, Any]:
        return self.__dict__.copy()

    def merge(self, other: "Usage") -> None:
        self.calls += other.calls
        self.input += other.input
        self.output += other.output
        self.cache_read += other.cache_read
        self.cache_write += other.cache_write
        self.reasoning += other.reasoning
        self.estimated_cost += other.estimated_cost


@dataclass
class PiResult:
    text: str
    usage: Usage
    files_read: set[str] = field(default_factory=set)
    files_written: set[str] = field(default_factory=set)
    meaningful_events: int = 0


class ContextBroker:
    """Builds bounded packets and grants exact, auditable context requests."""

    def __init__(
        self,
        source_root: Path,
        model_root: Path,
        context_paths: list[str],
        edit_paths: list[str],
        create_paths: list[str],
        max_context_files: int,
        max_context_bytes: int,
        allow_binary_context: list[str],
        request_allowlist: list[str],
    ) -> None:
        self.source_root = source_root
        self.model_root = model_root
        self.context_paths = set(ensure_paths(context_paths))
        self.edit_paths = set(ensure_paths(edit_paths))
        self.create_paths = set(ensure_paths(create_paths))
        self.max_context_files = max_context_files
        self.max_context_bytes = max_context_bytes
        self.allow_binary_context = set(ensure_paths(allow_binary_context))
        self.request_allowlist = set(ensure_paths(request_allowlist))
        self.granted: set[str] = set()
        self.context_bytes = 0
        self.binary_bytes = 0

    def repository_map(self) -> list[str]:
        return sorted(
            line
            for line in git(self.source_root, "ls-files").splitlines()
            if line and not line.startswith((".derivedData", ".tmp/"))
        )

    def copy_initial(self) -> None:
        for path in sorted(self.context_paths | self.edit_paths | self.create_paths):
            self.grant(
                path,
                access="edit" if path in self.edit_paths | self.create_paths else "read-only",
            )

    def grant(self, path: str, *, access: str) -> None:
        path = normalize_repo_path(path)
        if len(self.granted | {path}) > self.max_context_files:
            raise ControllerError("context-file budget exceeded")
        if access == "edit" and path not in self.edit_paths | self.create_paths:
            raise ControllerError(f"edit scope expansion requires owner approval: {path}")
        source = self.source_root / path
        if not source.is_file() and path not in self.create_paths:
            raise ControllerError(f"requested context does not exist: {path}")
        target = self.model_root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.is_file():
            suffix = source.suffix.lower()
            binary = suffix in {".png", ".jpg", ".jpeg", ".gif", ".pdf", ".mov", ".mp4"}
            if binary and path not in self.allow_binary_context:
                raise ControllerError(f"binary context was not explicitly approved: {path}")
            size = source.stat().st_size
            if self.context_bytes + size > self.max_context_bytes:
                raise ControllerError("context-byte budget exceeded; split, excerpt, or BLOCK")
            shutil.copy2(source, target)
            self.context_bytes += size
            if binary:
                self.binary_bytes += size
        else:
            target.touch()
        target.chmod(0o644 if access == "edit" else 0o444)
        self.granted.add(path)

    def handle_request(self, response: dict[str, Any]) -> list[str]:
        requested = response.get("requested")
        reason = str(response.get("reason", "")).strip()
        access = str(response.get("access", "")).lower()
        if not reason or access not in {"read-only", "edit"}:
            raise ControllerError("REQUEST_CONTEXT requires reason and read-only/edit access")
        if isinstance(requested, str):
            requested = [requested]
        if not isinstance(requested, list) or not requested:
            raise ControllerError("REQUEST_CONTEXT requires exact requested paths")
        paths = ensure_paths(str(path) for path in requested)
        maximum = response.get("maximum_scope", len(paths))
        if isinstance(maximum, bool) or not isinstance(maximum, int) or maximum < 1:
            raise ControllerError("REQUEST_CONTEXT maximum_scope must be a positive integer")
        if len(paths) > maximum:
            raise ControllerError("context request exceeds its declared maximum scope")
        permitted = self.context_paths | self.edit_paths | self.create_paths | self.request_allowlist
        refused = set(paths) - permitted
        if refused:
            raise ControllerError(
                "context request is outside the manifest's retrieval boundary: "
                + ", ".join(sorted(refused))
            )
        for path in paths:
            self.grant(path, access=access)
        return paths

    def packet_index(self) -> dict[str, Any]:
        imports: dict[str, list[str]] = {}
        tests: dict[str, list[str]] = {}
        for path in sorted(self.granted):
            source = self.model_root / path
            if source.suffix == ".swift":
                imports[path] = [
                    line.split(maxsplit=1)[1]
                    for line in source.read_text(errors="replace").splitlines()
                    if line.startswith("import ") and len(line.split(maxsplit=1)) == 2
                ]
            stem = source.stem.removesuffix("Tests").removesuffix("Test")
            tests[path] = [
                candidate
                for candidate in self.repository_map()
                if "Test" in candidate and stem and stem in Path(candidate).stem
            ][:10]
        return {
            "files": sorted(self.granted),
            "editable": sorted(self.edit_paths),
            "creatable": sorted(self.create_paths),
            "bytes": self.context_bytes,
            "binary_bytes": self.binary_bytes,
            "estimated_tokens": (self.context_bytes - self.binary_bytes + 3) // 4,
            "imports": imports,
            "source_to_test_candidates": tests,
        }

    def text_payload(self, paths: list[str]) -> str:
        sections = []
        for path in paths:
            source = self.model_root / normalize_repo_path(path)
            if path in self.allow_binary_context:
                sections.append(f"--- {path}\n[binary reference supplied in packet workspace]")
                continue
            try:
                content = source.read_text()
            except UnicodeDecodeError as error:
                raise ControllerError(f"requested context is binary and not renderable: {path}") from error
            sections.append(f"--- {path}\n{content}")
        return "\n\n".join(sections)


class TicketController:
    def __init__(
        self,
        manifest_path: Path,
        *,
        execute_models: bool = False,
        source_root: Path | None = None,
    ) -> None:
        self.manifest_path = manifest_path.resolve()
        self.manifest = json.loads(self.manifest_path.read_text())
        self.execute_models = execute_models
        self.source_root = (
            source_root
            or Path(self.manifest.get("source_root", self.manifest_path.parents[3]))
        ).resolve()
        self._validate_manifest()
        ticket_id = str(self.manifest["ticket"]["id"])
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        requested_run_root = self.manifest.get("run_root")
        base = (
            Path(requested_run_root).expanduser().resolve()
            if requested_run_root
            else self.source_root / ".tmp" / "agent-runs"
        )
        self.run_root = base / f"{ticket_id}-{stamp}"
        self.run_root.mkdir(parents=True, exist_ok=False)
        worktree_parent = Path(tempfile.gettempdir()) / "swipr-agent-worktrees"
        worktree_parent.mkdir(parents=True, exist_ok=True)
        self.isolated_root = worktree_parent / self.run_root.name
        self.model_root = Path(tempfile.mkdtemp(prefix="swipr-agent-model-"))
        self.attestation_root = Path(tempfile.mkdtemp(prefix="swipr-agent-attestation-"))
        self.ledger_path = self.run_root / "ledger.json"
        self.state = State.CREATED
        self.history: list[dict[str, Any]] = []
        self.codex_usage = Usage()
        self.deepseek_usage = Usage()
        self.attempts = 0
        self.context_requests = 0
        self.started_at = time.monotonic()
        self.files_read: set[str] = set()
        self.files_written: set[str] = set()
        self.changed_paths: list[str] = []
        self.review_paths: list[str] = []
        self.candidate_patch_hash: str | None = None
        self.review_patch_hash: str | None = None
        self.attestation_path: str | None = None
        self.worker_receipt: dict[str, Any] = {}
        self.independent_receipt: dict[str, Any] | None = None
        self.call_limits = {"codex": 0, "deepseek": 2, "verifier": 1}
        self.model_calls = {"codex": 0, "deepseek": 0, "verifier": 0}
        self.usage_baseline: dict[str, Any] = {"status": "not_configured"}
        self.git_state: dict[str, Any] = {}
        self.baseline_hashes: dict[str, str | None] = {}
        self.baseline_tree = ""
        self.result_tree = ""
        self.broker: ContextBroker | None = None
        self._record("controller created")

    def _validate_manifest(self) -> None:
        required = ("ticket", "scope", "models", "budgets", "verification")
        missing = [name for name in required if name not in self.manifest]
        if missing:
            raise ControllerError("manifest missing: " + ", ".join(missing))
        self.manifest["scope"]["allow_edit"] = ensure_paths(
            self.manifest["scope"].get("allow_edit", [])
        )
        self.manifest["scope"]["context"] = ensure_paths(
            self.manifest["scope"].get("context", [])
        )
        self.manifest["scope"]["allow_create"] = ensure_paths(
            self.manifest["scope"].get("allow_create", [])
        )
        overlap = set(self.manifest["scope"]["allow_create"]) & set(
            self.manifest["scope"]["context"] + self.manifest["scope"]["allow_edit"]
        )
        if overlap:
            raise ControllerError("create paths cannot also be read-only context: " + ", ".join(overlap))
        if int(self.manifest["budgets"].get("max_attempts", 2)) > 2:
            raise ControllerError("maximum implementation attempts cannot exceed two")
        for check in self.manifest["verification"]:
            if not isinstance(check.get("command"), list) or not check["command"]:
                raise ControllerError("verification commands must be non-empty argument arrays")
            check["inputs"] = ensure_paths(check.get("inputs", []))

    def _record(self, note: str, **extra: Any) -> None:
        self.history.append(
            {"at": datetime.now(timezone.utc).isoformat(), "state": self.state, "note": note, **extra}
        )
        self._write_ledger()

    def _transition(self, next_state: State, note: str) -> None:
        if next_state not in ALLOWED_TRANSITIONS[self.state]:
            raise ControllerError(f"invalid transition {self.state} -> {next_state}")
        self.state = next_state
        self._record(note)

    def _write_ledger(self) -> None:
        json_dump(
            self.ledger_path,
            {
                "manifest": str(self.manifest_path),
                "source_root": str(self.source_root),
                "run_root": str(self.run_root),
                "isolated_root": str(self.isolated_root),
                "state": self.state,
                "history": self.history,
                "codex": self.codex_usage.as_dict(),
                "deepseek": self.deepseek_usage.as_dict(),
                "deepseek_sessions": (1 if self.model_calls["deepseek"] else 0)
                + self.model_calls["verifier"],
                "implementation_attempts": self.attempts,
                "context_requests": self.context_requests,
                "elapsed_seconds": round(time.monotonic() - self.started_at, 3),
                "files_read": sorted(self.files_read),
                "files_written": sorted(self.files_written),
                "changed_paths": self.changed_paths,
                "review_paths": self.review_paths,
                "candidate_patch_hash": self.candidate_patch_hash,
                "review_patch_hash": self.review_patch_hash,
                "attestation_path": self.attestation_path,
                "worker_receipt": self.worker_receipt,
                "independent_receipt": self.independent_receipt,
                "usage_baseline": self.usage_baseline,
                "model_calls": self.model_calls,
                "call_limits": self.call_limits,
                "git_state": self.git_state,
                "quality_followup": {
                    "escaped_defects": None,
                    "regressions": None,
                    "owner_intervention": self.state == State.BLOCKED,
                    "post_acceptance_corrections": None,
                },
                "baseline_hashes": self.baseline_hashes,
                "baseline_tree": self.baseline_tree,
                "result_tree": self.result_tree,
            },
        )

    def block(self, reason: str) -> None:
        if self.state != State.BLOCKED:
            if State.BLOCKED in ALLOWED_TRANSITIONS[self.state]:
                self._transition(State.BLOCKED, reason)
            else:
                self.state = State.BLOCKED
                self._record(reason)
        self._write_receipt(reason)
        raise ControllerError(reason)

    def _write_receipt(self, summary: str, error: BaseException | None = None) -> None:
        json_dump(
            self.run_root / "receipt.json",
            {
                "ticket": self.manifest["ticket"]["id"],
                "state": self.state,
                "summary": summary,
                "exception_type": type(error).__name__ if error else None,
                "exception_message": str(error) if error else None,
                "patch": str(self.run_root / "candidate.patch")
                if self.changed_paths and (self.run_root / "candidate.patch").exists()
                else None,
                "review_patch": str(self.run_root / "review.patch")
                if (self.run_root / "review.patch").exists()
                else None,
                "ledger": str(self.ledger_path),
                "codex": self.codex_usage.as_dict(),
                "deepseek": self.deepseek_usage.as_dict(),
                "deepseek_sessions": (1 if self.model_calls["deepseek"] else 0)
                + self.model_calls["verifier"],
                "attempts": self.attempts,
                "changed_paths": self.changed_paths,
                "review_paths": self.review_paths,
                "candidate_patch_hash": self.candidate_patch_hash,
                "review_patch_hash": self.review_patch_hash,
                "verification": str(self.run_root / "verification.json")
                if (self.run_root / "verification.json").exists()
                else None,
            },
        )

    def baseline(self) -> None:
        head = git(self.source_root, "rev-parse", "HEAD").strip()
        (self.run_root / "head.txt").write_text(head + "\n")
        (self.run_root / "staged.patch").write_text(
            git(self.source_root, "diff", "--binary", "--cached")
        )
        (self.run_root / "unstaged.patch").write_text(
            git(self.source_root, "diff", "--binary")
        )
        (self.run_root / "working.patch").write_text(
            git(self.source_root, "diff", "--binary", "HEAD")
        )
        untracked = paths_from_nul(
            git(self.source_root, "ls-files", "--others", "--exclude-standard", "-z")
        )
        untracked_manifest = {
            path: file_hash(self.source_root / path)
            for path in untracked
            if (self.source_root / path).is_file()
        }
        json_dump(self.run_root / "untracked.json", untracked_manifest)
        self.git_state = {
            "head": head,
            "staged_paths": paths_from_nul(
                git(self.source_root, "diff", "--name-only", "--cached", "-z")
            ),
            "unstaged_paths": paths_from_nul(
                git(self.source_root, "diff", "--name-only", "-z")
            ),
            "untracked_paths": sorted(untracked_manifest),
        }
        relevant = set(self.manifest["scope"]["allow_edit"])
        relevant.update(self.manifest["scope"]["allow_create"])
        relevant.update(self.manifest["scope"]["context"])
        for check in self.manifest["verification"]:
            relevant.update(check["inputs"])
        relevant.update(
            normalize_repo_path(reference["path"])
            for reference in self.manifest.get("visual_references", [])
        )
        self.baseline_hashes = {
            path: file_hash(self.source_root / path) for path in sorted(relevant)
        }
        json_dump(self.run_root / "baseline-hashes.json", self.baseline_hashes)
        snapshot_command = self.manifest.get("usage_snapshot_command")
        if snapshot_command:
            result = run_command(snapshot_command, cwd=self.source_root, check=False, timeout=30)
            self.usage_baseline = {
                "status": "captured" if result.returncode == 0 else "failed",
                "returncode": result.returncode,
                "stdout": result.stdout[-4000:],
                "stderr": result.stderr[-4000:],
            }
        self._transition(State.BASELINED, "captured HEAD, diffs, untracked files, and hashes")

    def isolate(self) -> None:
        head = (self.run_root / "head.txt").read_text().strip()
        if self.isolated_root.exists():
            self.block(f"isolated path already exists: {self.isolated_root}")
        run_command(
            ["git", "worktree", "add", "--detach", str(self.isolated_root), head],
            cwd=self.source_root,
            timeout=180,
        )
        working_patch = self.run_root / "working.patch"
        if working_patch.stat().st_size:
            run_command(
                ["git", "apply", "--binary", str(working_patch)],
                cwd=self.isolated_root,
                timeout=120,
            )
        needed_untracked = set(self.manifest["scope"].get("seed_untracked", []))
        needed_untracked.update(
            path
            for path, digest in self.baseline_hashes.items()
            if digest is not None and not (self.isolated_root / path).exists()
        )
        for path in ensure_paths(needed_untracked):
            source = self.source_root / path
            if source.is_file():
                target = self.isolated_root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
        self.baseline_tree = self._write_tree(self.isolated_root, "baseline.index")
        self._transition(State.ISOLATED, "created detached worktree with captured baseline")

    def _write_tree(self, root: Path, index_name: str) -> str:
        index = self.run_root / index_name
        env = {"GIT_INDEX_FILE": str(index)}
        run_command(["git", "read-tree", "HEAD"], cwd=root, env=env)
        run_command(["git", "add", "-A"], cwd=root, env=env, timeout=120)
        return run_command(["git", "write-tree"], cwd=root, env=env).stdout.strip()

    def prepare(self) -> tuple[bool, list[str]]:
        self.baseline()
        self.isolate()
        needs_plan, reasons = classify_ticket(self.manifest)
        independent, independent_reasons = should_independently_verify(self.manifest)
        self.call_limits["codex"] = 2 + int(needs_plan)
        if "max_codex_calls" in self.manifest["budgets"]:
            requested = int(self.manifest["budgets"]["max_codex_calls"])
            if requested > self.call_limits["codex"]:
                raise ControllerError("manifest may not exceed the policy Codex-call limit")
            self.call_limits["codex"] = requested
        context_allowance = int(self.manifest["budgets"].get("max_context_requests", 3))
        self.call_limits["deepseek"] = int(
            self.manifest["budgets"].get("max_worker_calls", 2 + context_allowance)
        )
        self.call_limits["verifier"] = 1 + context_allowance if independent else 0
        self._transition(State.CLASSIFIED, "classified ticket deterministically")
        missing_references = []
        for reference in self.manifest.get("visual_references", []):
            path = normalize_repo_path(reference["path"])
            if reference.get("required", True) and not (self.isolated_root / path).is_file():
                missing_references.append(path)
        if missing_references:
            self.block(
                "required approved visual references unavailable; no substitution allowed: "
                + ", ".join(missing_references)
            )
        visual_paths = [
            normalize_repo_path(reference["path"])
            for reference in self.manifest.get("visual_references", [])
        ]
        self.broker = ContextBroker(
            self.isolated_root,
            self.model_root,
            self.manifest["scope"]["context"] + visual_paths,
            self.manifest["scope"]["allow_edit"],
            self.manifest["scope"]["allow_create"],
            int(self.manifest["budgets"].get("max_context_files", 40)),
            int(self.manifest["budgets"].get("max_context_bytes", 100_000)),
            self.manifest["scope"].get("allow_binary_context", []),
            self.manifest["scope"].get("allow_context_requests", []),
        )
        self.broker.copy_initial()
        packet = {
            "ticket": self.manifest["ticket"],
            "product_decisions": self.manifest.get("product_decisions", []),
            "constraints": self.manifest.get("constraints", []),
            "scope": self.manifest["scope"],
            "verification": self.manifest["verification"],
            "visual_references": [
                {
                    **reference,
                    "sha256": file_hash(
                        self.isolated_root / normalize_repo_path(reference["path"])
                    ),
                }
                for reference in self.manifest.get("visual_references", [])
            ],
            "context_index": self.broker.packet_index(),
            "repository_file_map": self.broker.repository_map(),
            "git_state": self.git_state,
            "planning_required": needs_plan,
            "planning_reasons": reasons,
            "independent_verification_required": independent,
            "independent_verification_reasons": independent_reasons,
        }
        json_dump(self.run_root / "packet.json", packet)
        target = int(self.manifest["budgets"].get("soft_context_tokens", 25_000))
        estimated = packet["context_index"]["estimated_tokens"]
        if estimated > target:
            self._record(
                "soft context target exceeded; no blind truncation performed",
                estimated_tokens=estimated,
                target_tokens=target,
            )
        self._transition(State.READY, "bounded packet and model workspace ready")
        return needs_plan, reasons

    def _model_command(
        self,
        model: dict[str, Any],
        prompt_path: Path,
        *,
        session_path: Path | None,
        tools: bool,
    ) -> list[str]:
        command = [
            str(model.get("pi", "/opt/homebrew/bin/pi")),
            "--provider",
            model["provider"],
            "--model",
            model["model"],
            "--thinking",
            model.get("thinking", "medium"),
            "--offline",
            "--no-extensions",
            "--no-skills",
            "--no-prompt-templates",
            "--no-themes",
            "--no-context-files",
            "--approve",
            "--mode",
            "json",
        ]
        if tools:
            command += ["--tools", "read,write,edit"]
        else:
            command += ["--no-tools"]
        command += ["--session", str(session_path)] if session_path else ["--no-session"]
        command += ["--print", f"@{prompt_path}"]
        if not self.manifest.get("sandbox_models", True):
            return command
        sandbox = shutil.which("sandbox-exec")
        if not sandbox:
            raise ControllerError("sandbox_models is enabled but sandbox-exec is unavailable")
        write_paths = [
            self.model_root,
            Path.home() / ".pi",
            Path.home() / ".config",
            Path.home() / "Library" / "Caches",
        ] + [Path(path).expanduser().resolve() for path in self.manifest.get("sandbox_write_paths", [])]
        quote = lambda path: str(path).replace("\\", "\\\\").replace('"', '\\"')
        rules = " ".join(f'(subpath "{quote(path)}")' for path in write_paths)
        profile = self.model_root / ".sandbox.sb"
        profile.write_text(
            f"(version 1) (allow default) (deny file-write*) (allow file-write* {rules})\n"
        )
        return [sandbox, "-f", str(profile), *command]

    def _safe_tool_path(self, raw: str) -> str:
        path = Path(raw)
        resolved = path.resolve() if path.is_absolute() else (self.model_root / path).resolve()
        try:
            return resolved.relative_to(self.model_root.resolve()).as_posix()
        except ValueError as error:
            raise ControllerError(f"model attempted access outside packet workspace: {raw}") from error

    def _tool_event_path(self, event: dict[str, Any]) -> str:
        tool = event.get("toolName")
        args = event.get("args")
        raw_path = args.get("path") if isinstance(args, dict) else None
        if not isinstance(raw_path, str) or not raw_path:
            raise ControllerError(f"{tool} tool event has no identifiable string path")
        return self._safe_tool_path(raw_path)

    def _integrity_snapshot(self) -> dict[str, str | None]:
        protected = {
            f"source:{path}": file_hash(self.source_root / path)
            for path in self.baseline_hashes
        }
        for path in [
            self.ledger_path,
            self.run_root / "head.txt",
            self.run_root / "baseline-hashes.json",
            *sorted(self.run_root.glob("*.patch")),
        ]:
            if path.exists():
                protected[f"run:{path.name}"] = file_hash(path)
        return protected

    def _assert_integrity(self, expected: dict[str, str | None]) -> None:
        drifted = []
        for label, digest in expected.items():
            kind, value = label.split(":", 1)
            path = self.source_root / value if kind == "source" else self.run_root / value
            if file_hash(path) != digest:
                drifted.append(label)
        if drifted:
            raise ControllerError("post-model integrity drift: " + ", ".join(sorted(drifted)))

    def _run_pi(
        self,
        model_name: str,
        prompt: str,
        *,
        session_path: Path | None = None,
        tools: bool = False,
    ) -> PiResult:
        models = self.manifest["models"]
        model = models[model_name]
        role = str(model.get("role", "codex" if model_name == "codex" else model_name))
        if role not in self.call_limits:
            raise ControllerError(f"unknown model role: {role}")
        if self.model_calls[role] >= self.call_limits[role]:
            self.block(f"{role} call budget exhausted")
        prompt_bytes = len(prompt.encode())
        soft_tokens = int(self.manifest["budgets"].get("soft_context_tokens", 25_000))
        estimated_prompt_tokens = (prompt_bytes + 3) // 4
        if role == "codex" and estimated_prompt_tokens > soft_tokens:
            self._record(
                "Codex prompt exceeds soft token target; sent intact for correctness",
                model=model_name,
                estimated_prompt_tokens=estimated_prompt_tokens,
                soft_target=soft_tokens,
            )
        hard_prompt_bytes = int(
            self.manifest["budgets"].get("max_model_prompt_bytes", 1_000_000)
        )
        if prompt_bytes > hard_prompt_bytes:
            self.block("model prompt byte budget exceeded; split ticket or request bounded excerpts")
        self.model_calls[role] += 1
        self._write_ledger()
        budgets = self.manifest["budgets"]
        prompt_path = self.model_root / f".controller-{model_name}.md"
        prompt_path.write_text(prompt)
        log_path = self.run_root / f"{model_name}-{int(time.time())}.jsonl"
        stderr_path = self.run_root / f"{model_name}-{int(time.time())}.stderr"
        protected = self._integrity_snapshot()
        process = subprocess.Popen(
            self._model_command(model, prompt_path, session_path=session_path, tools=tools),
            cwd=self.model_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
        assert process.stdout and process.stderr
        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ, "stdout")
        selector.register(process.stderr, selectors.EVENT_READ, "stderr")
        started = last_progress = time.monotonic()
        maximum_seconds = int(budgets.get("model_timeout_seconds", 600))
        progress_seconds = int(budgets.get("progress_timeout_seconds", 180))
        maximum_bytes = int(budgets.get("max_event_log_bytes", 5_000_000))
        total_bytes = 0
        assistant_messages: list[dict[str, Any]] = []
        usage = Usage()
        files_read: set[str] = set()
        files_written: set[str] = set()
        meaningful = 0
        active_write: str | None = None
        observed_hashes = {
            path: file_hash(self.model_root / path)
            for path in self.manifest["scope"]["allow_edit"]
            + self.manifest["scope"].get("allow_create", [])
        }
        stderr_chunks: list[str] = []
        with log_path.open("w") as log:
            try:
                while selector.get_map():
                    now = time.monotonic()
                    if now - started > maximum_seconds:
                        raise ControllerError("model timeout exceeded")
                    if now - last_progress > progress_seconds:
                        raise ControllerError("no deterministic meaningful progress")
                    events = selector.select(timeout=1)
                    if not events and process.poll() is not None:
                        break
                    for key, _ in events:
                        line = key.fileobj.readline()
                        if not line:
                            selector.unregister(key.fileobj)
                            continue
                        total_bytes += len(line.encode())
                        if total_bytes > maximum_bytes:
                            raise ControllerError("model event-log budget exceeded")
                        if key.data == "stderr":
                            stderr_chunks.append(line)
                            continue
                        log.write(line)
                        log.flush()
                        try:
                            event = json.loads(line)
                        except json.JSONDecodeError:
                            continue
                        if event.get("type") == "message_end":
                            message = event.get("message", {})
                            if message.get("role") == "assistant":
                                assistant_messages.append(message)
                                delta = Usage()
                                delta.add(message.get("usage", {}))
                                usage.merge(delta)
                                aggregate = (
                                    self.codex_usage if role == "codex" else self.deepseek_usage
                                )
                                aggregate.merge(delta)
                                token_limit_name = (
                                    "max_codex_tokens"
                                    if role == "codex"
                                    else "max_deepseek_tokens"
                                )
                                token_limit = int(budgets.get(token_limit_name, 0))
                                projected_tokens = sum(
                                    (aggregate.input, aggregate.output, aggregate.reasoning)
                                )
                                if token_limit and projected_tokens > token_limit:
                                    raise ControllerError(f"{role} token budget exceeded")
                                if role != "codex":
                                    turn_limit = int(budgets.get("max_deepseek_model_turns", 0))
                                    if turn_limit and aggregate.calls > turn_limit:
                                        raise ControllerError("DeepSeek model-turn budget exceeded")
                                    cost_limit = float(budgets.get("max_deepseek_cost", 0))
                                    if (
                                        cost_limit
                                        and aggregate.estimated_cost > cost_limit
                                    ):
                                        raise ControllerError("DeepSeek estimated-cost budget exceeded")
                                for content in message.get("content", []):
                                    if content.get("type") == "text":
                                        text = content.get("text", "")
                                        if "REQUEST_CONTEXT" in text or "CHECKPOINT" in text:
                                            meaningful += 1
                                            last_progress = now
                        if event.get("type") == "tool_execution_start":
                            tool = event.get("toolName")
                            if tool in {"read", "write", "edit"}:
                                relative = self._tool_event_path(event)
                                if tool == "read":
                                    files_read.add(relative)
                                else:
                                    if relative not in (
                                        self.manifest["scope"]["allow_edit"]
                                        + self.manifest["scope"].get("allow_create", [])
                                    ):
                                        raise ControllerError(
                                            f"model attempted write outside allowlist: {relative}"
                                        )
                                    files_written.add(relative)
                                    active_write = relative
                        if event.get("type") == "tool_execution_end" and event.get(
                            "toolName"
                        ) in {"write", "edit"}:
                            if active_write:
                                current = file_hash(self.model_root / active_write)
                                if current != observed_hashes.get(active_write):
                                    observed_hashes[active_write] = current
                                    meaningful += 1
                                    last_progress = now
                                active_write = None
            except BaseException:
                process.send_signal(signal.SIGINT)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                raise
            finally:
                self._assert_integrity(protected)
        returncode = process.wait(timeout=10)
        stderr_path.write_text("".join(stderr_chunks))
        if returncode:
            raise ControllerError(f"model process failed with exit {returncode}")
        self.files_read.update(files_read)
        self.files_written.update(files_written)
        self._write_ledger()
        return PiResult(
            final_assistant_text(assistant_messages),
            usage,
            files_read,
            files_written,
            meaningful,
        )

    def _bounded_response(
        self,
        model_name: str,
        prompt: str,
        *,
        allowed: set[str],
        session_path: Path | None = None,
        tools: bool = False,
    ) -> tuple[dict[str, Any], PiResult]:
        base_prompt = prompt
        while True:
            result = self._run_pi(
                model_name, prompt, session_path=session_path, tools=tools
            )
            response = parse_json_response(result.text)
            disposition = validate_disposition(response, allowed | {"REQUEST_CONTEXT"})
            if disposition != "REQUEST_CONTEXT":
                self._write_ledger()
                return response, result
            self.context_requests += 1
            if self.context_requests > int(self.manifest["budgets"].get("max_context_requests", 3)):
                self.block("context-request budget exceeded")
            assert self.broker
            granted = self.broker.handle_request(response)
            prompt = (
                base_prompt
                + "\n\nYour prior structured response was:\n"
                + json.dumps(response, indent=2)
                + "\n\nThe controller granted only these requested files: "
                + ", ".join(granted)
                + ". Continue and return one allowed JSON disposition.\n"
                + self.broker.text_payload(granted)
            )

    def _planning_prompt(self) -> str:
        packet = (self.run_root / "packet.json").read_text()
        return (
            "You are the bounded planner. Do not implement or use tools. Read the packet JSON below. "
            "Return JSON only. Use disposition PLAN with a concise implementation_instructions list, "
            "or REQUEST_CONTEXT with exact requested paths, reason, access, and maximum_scope, or BLOCK.\n"
            + packet
        )

    def _worker_prompt(self, plan: dict[str, Any] | None, correction: str | None = None) -> str:
        packet = (self.run_root / "packet.json").read_text()
        return (
            "You are the sole implementation worker. Files outside the packet workspace are unavailable. "
            "Edit only the allowlist, write/update tests where allowlisted, inspect your changes, and self-review. "
            "Do not run tests; the deterministic controller does that. Return JSON only: disposition IMPLEMENTED "
            "with summary and risks, REQUEST_CONTEXT, or BLOCK.\n"
            f"Packet:\n{packet}\nPlan:\n{json.dumps(plan or {}, indent=2)}\n"
            f"Correction:\n{correction or 'none'}"
        )

    def _verifier_prompt(self, diff: str, evidence: list[dict[str, Any]]) -> str:
        return (
            "You are an independent risk verifier. You did not implement this change. No tools. "
            "Review only the ticket, final diff, deterministic evidence, and stated risks. Return JSON only: "
            "VERIFY with findings, REQUEST_CONTEXT with exact paths/reason/read-only access/maximum_scope, "
            "or BLOCK. Do not infer missing evidence.\n"
            f"Ticket:\n{json.dumps(self.manifest['ticket'], indent=2)}\n"
            f"Risks:\n{json.dumps(self.manifest.get('risk', {}), indent=2)}\n"
            f"Diff:\n{diff}\nEvidence:\n{json.dumps(evidence, indent=2)}"
        )

    def _run_independent_verifier(
        self, diff: str, evidence: list[dict[str, Any]]
    ) -> None:
        if "verifier" not in self.manifest["models"]:
            self.block("high-risk ticket requires a configured independent verifier")
        receipt, _ = self._bounded_response(
            "verifier",
            self._verifier_prompt(diff, evidence),
            allowed={"VERIFY", "BLOCK"},
        )
        if receipt["disposition"] == "BLOCK":
            self.block(str(receipt.get("reason", "independent verification blocked")))
        findings = receipt.get("blocking_findings")
        if not isinstance(findings, list):
            self.block("independent verifier omitted blocking_findings list")
        if findings:
            self.block("independent verifier reported blocking findings")
        self.independent_receipt = receipt

    def _sync_worker_changes(self) -> None:
        assert self.broker
        unexpected = []
        for path in sorted(self.broker.granted):
            model = self.model_root / path
            isolated = self.isolated_root / path
            before = self.baseline_hashes.get(path)
            after = file_hash(model)
            if path not in self.manifest["scope"]["allow_edit"] and after != before:
                unexpected.append(path)
            if path in (
                self.manifest["scope"]["allow_edit"]
                + self.manifest["scope"].get("allow_create", [])
            ):
                isolated.parent.mkdir(parents=True, exist_ok=True)
                if model.exists():
                    shutil.copy2(model, isolated)
                elif isolated.exists():
                    isolated.unlink()
        if unexpected:
            self.block("unexpected changed files: " + ", ".join(unexpected))

    def _tool_versions(self) -> dict[str, str]:
        versions = {}
        for command in self.manifest.get("tool_version_commands", []):
            result = run_command(command, cwd=self.isolated_root, check=False, timeout=30)
            versions[" ".join(command)] = (result.stdout + result.stderr).strip()[:2000]
        return versions

    def _test_key(self, check: dict[str, Any], versions: dict[str, str]) -> str:
        inputs = {
            path: file_hash(self.isolated_root / path) for path in check.get("inputs", [])
        }
        material = {
            "command": check["command"],
            "environment": check.get("environment", {}),
            "inputs": inputs,
            "candidate_tree": self._write_tree(self.isolated_root, "verification.index"),
            "versions": versions,
        }
        return sha256_bytes(json.dumps(material, sort_keys=True).encode())

    def _cache_root(self) -> Path:
        return Path(tempfile.gettempdir()) / "swipr-agent-test-cache"

    @staticmethod
    def _cached_pass(cache: Path, key: str, command: list[str]) -> dict[str, Any] | None:
        try:
            value = json.loads(cache.read_text())
        except (OSError, json.JSONDecodeError, TypeError):
            return None
        if (
            not isinstance(value, dict)
            or value.get("returncode") != 0
            or value.get("key") != key
            or value.get("command") != command
        ):
            return None
        return value

    def verify(self) -> list[dict[str, Any]]:
        status_before = set(
            paths_from_nul(git(self.isolated_root, "status", "--porcelain=v1", "-z"))
        )
        versions = self._tool_versions()
        cache_root = self._cache_root()
        cache_root.mkdir(parents=True, exist_ok=True)
        evidence = []
        for check in self.manifest["verification"]:
            key = self._test_key(check, versions)
            cache = cache_root / f"{key}.json"
            if check.get("reuse", True) and cache.exists():
                result = self._cached_pass(cache, key, check["command"])
                if result:
                    result = {**result, "reused": True}
                    evidence.append(result)
                    continue
            started = time.monotonic()
            completed = run_command(
                check["command"],
                cwd=self.isolated_root,
                env=check.get("environment", {}),
                timeout=int(check.get("timeout_seconds", 900)),
                check=False,
            )
            result = {
                "name": check["name"],
                "key": key,
                "command": check["command"],
                "returncode": completed.returncode,
                "elapsed_seconds": round(time.monotonic() - started, 3),
                "stdout_tail": completed.stdout[-4000:],
                "stderr_tail": completed.stderr[-4000:],
                "reused": False,
            }
            json_dump(cache, result)
            evidence.append(result)
            if completed.returncode:
                json_dump(self.run_root / "verification.json", evidence)
                self.block(f"verification failed: {check['name']}")
        status_after = set(
            paths_from_nul(git(self.isolated_root, "status", "--porcelain=v1", "-z"))
        )
        if status_after != status_before:
            self.block("verification changed repository files outside its evidence outputs")
        json_dump(self.run_root / "verification.json", evidence)
        return evidence

    def _diff(self) -> str:
        self.result_tree = self._write_tree(self.isolated_root, "result.index")
        scope_paths = sorted(
            set(self.manifest["scope"]["allow_edit"])
            | set(self.manifest["scope"].get("allow_create", []))
        )
        self.changed_paths = paths_from_nul(
            git(
                self.isolated_root,
                "diff",
                "--name-only",
                "-z",
                self.baseline_tree,
                self.result_tree,
                "--",
                *scope_paths,
            )
        )
        unexpected = set(
            paths_from_nul(
                git(
                    self.isolated_root,
                    "diff",
                    "--name-only",
                    "-z",
                    self.baseline_tree,
                    self.result_tree,
                )
            )
        ) - set(scope_paths)
        if unexpected:
            self.block("unexpected changed files: " + ", ".join(sorted(unexpected)))
        candidate_diff = git(
            self.isolated_root,
            "diff",
            "--binary",
            self.baseline_tree,
            self.result_tree,
            "--",
            *scope_paths,
            timeout=120,
        )
        (self.run_root / "worker.patch").write_text(candidate_diff)
        self.review_paths = paths_from_nul(
            git(
                self.isolated_root,
                "diff",
                "--name-only",
                "-z",
                "HEAD",
                self.result_tree,
                "--",
                *scope_paths,
            )
        )
        review_diff = git(
            self.isolated_root,
            "diff",
            "--binary",
            "HEAD",
            self.result_tree,
            "--",
            *scope_paths,
            timeout=120,
        )
        (self.run_root / "review.patch").write_text(review_diff)
        self.review_patch_hash = sha256_bytes(review_diff.encode())
        return review_diff

    def _acceptance_prompt(self, diff: str, evidence: list[dict[str, Any]]) -> str:
        return (
            "You are the production acceptance reviewer. Review diff-first and risk-aware. No tools. "
            "Return JSON only with one disposition: ACCEPT, CORRECT, BLOCK, or REQUEST_CONTEXT. "
            "CORRECT must contain exact bounded corrections. REQUEST_CONTEXT must name exact paths, reason, "
            "access, and maximum_scope.\n"
            f"Ticket:\n{json.dumps(self.manifest['ticket'], indent=2)}\n"
            f"Risks:\n{json.dumps(self.manifest.get('risk', {}), indent=2)}\n"
            f"Worker receipt:\n{json.dumps(self.worker_receipt, indent=2)}\n"
            f"Independent receipt:\n{json.dumps(self.independent_receipt, indent=2)}\n"
            f"Diff:\n{diff}\nEvidence:\n{json.dumps(evidence, indent=2)}"
        )

    def _write_attestation(self) -> None:
        payload = {
            "run_root": str(self.run_root.resolve()),
            "head": (self.run_root / "head.txt").read_text().strip(),
            "candidate_patch_hash": self.candidate_patch_hash,
            "review_patch_hash": self.review_patch_hash,
            "baseline_hashes": self.baseline_hashes,
            "changed_paths": self.changed_paths,
        }
        payload["digest"] = sha256_bytes(json.dumps(payload, sort_keys=True).encode())
        path = self.attestation_root / "accepted.json"
        json_dump(path, payload)
        self.attestation_path = str(path)

    def run(self) -> None:
        try:
            self._run_impl()
        except BaseException as error:
            if self.state != State.BLOCKED:
                self.state = State.BLOCKED
                self.history.append(
                    {
                        "at": datetime.now(timezone.utc).isoformat(),
                        "state": self.state,
                        "note": f"{type(error).__name__}: {error}",
                    }
                )
                self._write_ledger()
            self._write_receipt(str(error), error)
            raise
        if self.state not in {State.ACCEPTED, State.PATCH_READY, State.DRY_RUN, State.BLOCKED}:
            error = ControllerError(f"controller exited in non-terminal state {self.state}")
            self.state = State.BLOCKED
            self._record(str(error))
            self._write_receipt(str(error), error)
            raise error

    def _run_impl(self) -> None:
        needs_plan, _ = self.prepare()
        if not self.execute_models:
            self._transition(State.DRY_RUN, "dry run complete; no model invoked")
            self._write_receipt("dry run complete; no model invoked")
            return
        plan = None
        if needs_plan:
            self._transition(State.PLANNED, "starting conditional Codex planning")
            plan, _ = self._bounded_response(
                "codex",
                self._planning_prompt(),
                allowed={"PLAN", "BLOCK"},
            )
            if plan["disposition"] == "BLOCK":
                self.block(str(plan.get("reason", "planner blocked")))
        self.attempts = 1
        worker_session = self.run_root / "deepseek-session.jsonl"
        response, _ = self._bounded_response(
            "deepseek",
            self._worker_prompt(plan),
            allowed={"IMPLEMENTED", "BLOCK"},
            session_path=worker_session,
            tools=True,
        )
        if response["disposition"] == "BLOCK":
            self.block(str(response.get("reason", "worker blocked")))
        self.worker_receipt = response
        self._sync_worker_changes()
        self._transition(State.IMPLEMENTED, "worker returned a bounded implementation")
        evidence = self.verify()
        self._transition(State.VERIFIED, "deterministic verification passed")
        diff = self._diff()
        independent, _ = should_independently_verify(self.manifest)
        if independent:
            self._run_independent_verifier(diff, evidence)
        review, _ = self._bounded_response(
            "codex",
            self._acceptance_prompt(diff, evidence),
            allowed={"ACCEPT", "CORRECT", "BLOCK"},
        )
        validate_acceptance(review, self.manifest["ticket"]["acceptance_criteria"])
        self._transition(State.REVIEWED, f"Codex returned {review['disposition']}")
        if review["disposition"] == "BLOCK":
            self.block(str(review.get("reason", "acceptance blocked")))
        if review["disposition"] == "CORRECT":
            if self.attempts >= int(self.manifest["budgets"].get("max_attempts", 2)):
                self.block("implementation-attempt budget exhausted")
            self._transition(State.CORRECTING, "one bounded correction requested")
            self.attempts += 1
            correction = json.dumps(review.get("corrections", review), indent=2)
            corrected, _ = self._bounded_response(
                "deepseek",
                self._worker_prompt(plan, correction),
                allowed={"IMPLEMENTED", "BLOCK"},
                session_path=worker_session,
                tools=True,
            )
            if corrected["disposition"] == "BLOCK":
                self.block(str(corrected.get("reason", "correction blocked")))
            self.worker_receipt = corrected
            self._sync_worker_changes()
            self._transition(State.IMPLEMENTED, "bounded correction completed")
            evidence = self.verify()
            self._transition(State.VERIFIED, "post-correction verification passed")
            diff = self._diff()
            if independent:
                self._run_independent_verifier(diff, evidence)
            review, _ = self._bounded_response(
                "codex",
                self._acceptance_prompt(diff, evidence),
                allowed={"ACCEPT", "BLOCK"},
            )
            validate_acceptance(review, self.manifest["ticket"]["acceptance_criteria"])
            self._transition(State.REVIEWED, f"final Codex review returned {review['disposition']}")
            if review["disposition"] != "ACCEPT":
                self.block(str(review.get("reason", "final acceptance blocked")))
        self._transition(State.ACCEPTED, "ticket accepted; no automatic progression")
        self._diff()
        if self.changed_paths:
            shutil.copy2(self.run_root / "worker.patch", self.run_root / "candidate.patch")
            self.candidate_patch_hash = file_hash(self.run_root / "candidate.patch")
            self._write_attestation()
            self._transition(State.PATCH_READY, "accepted patch ready for explicit apply")
            self._write_receipt("accepted patch ready; stopped before explicit apply")
        else:
            self._write_receipt("accepted captured baseline; no new patch to apply")


def apply_accepted(ledger_path: Path) -> None:
    ledger = json.loads(ledger_path.read_text())
    if ledger.get("state") != State.PATCH_READY:
        raise ControllerError("only PATCH_READY runs may be applied")
    source_root = Path(ledger["source_root"])
    expected_head = (ledger_path.parent / "head.txt").read_text().strip()
    if git(source_root, "rev-parse", "HEAD").strip() != expected_head:
        raise ControllerError("live HEAD changed since the run")
    patch = ledger_path.parent / "candidate.patch"
    if not patch.is_file():
        raise ControllerError("candidate patch is missing")
    if file_hash(patch) != ledger.get("candidate_patch_hash"):
        raise ControllerError("candidate patch hash does not match the accepted ledger")
    attestation_value = ledger.get("attestation_path")
    if not isinstance(attestation_value, str):
        raise ControllerError("external acceptance attestation is missing")
    attestation_path = Path(attestation_value).resolve()
    if not attestation_path.is_file() or ledger_path.parent.resolve() in attestation_path.parents:
        raise ControllerError("external acceptance attestation is invalid")
    attestation = json.loads(attestation_path.read_text())
    digest = attestation.pop("digest", None)
    if digest != sha256_bytes(json.dumps(attestation, sort_keys=True).encode()):
        raise ControllerError("external acceptance attestation digest mismatch")
    expected_attestation = {
        "run_root": str(ledger_path.parent.resolve()),
        "head": expected_head,
        "candidate_patch_hash": file_hash(patch),
        "review_patch_hash": file_hash(ledger_path.parent / "review.patch"),
        "baseline_hashes": ledger.get("baseline_hashes"),
        "changed_paths": ledger.get("changed_paths"),
    }
    if attestation != expected_attestation:
        raise ControllerError("accepted evidence does not match external attestation")
    changed = ledger.get("changed_paths", [])
    if not changed:
        raise ControllerError("accepted run has no audited changed paths")
    for path in changed:
        expected = ledger.get("baseline_hashes", {}).get(path)
        if file_hash(source_root / path) != expected:
            raise ControllerError(f"live file changed since baseline: {path}")
    run_command(["git", "apply", "--check", "--binary", str(patch)], cwd=source_root)
    run_command(["git", "apply", "--binary", str(patch)], cwd=source_root)
    ledger["state"] = State.APPLIED
    ledger.setdefault("history", []).append(
        {
            "at": datetime.now(timezone.utc).isoformat(),
            "state": State.APPLIED,
            "note": "accepted patch explicitly applied after live-state revalidation",
        }
    )
    json_dump(ledger_path, ledger)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    run_parser = subparsers.add_parser("run", help="prepare or execute one ticket")
    run_parser.add_argument("manifest", type=Path)
    run_parser.add_argument(
        "--source-root",
        type=Path,
        help="repository to snapshot; defaults to the manifest's repository",
    )
    run_parser.add_argument(
        "--execute-models",
        action="store_true",
        help="invoke configured models; default is a safe dry run",
    )
    apply_parser = subparsers.add_parser("apply", help="apply an accepted patch explicitly")
    apply_parser.add_argument("ledger", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    controller: TicketController | None = None
    try:
        if args.command == "run":
            controller = TicketController(
                args.manifest,
                execute_models=args.execute_models,
                source_root=args.source_root,
            )
            controller.run()
            print(controller.ledger_path)
        else:
            apply_accepted(args.ledger.resolve())
    except BaseException as error:
        print(f"BLOCK: {error}", file=sys.stderr)
        if controller is not None:
            print(controller.ledger_path)
        return 130 if isinstance(error, KeyboardInterrupt) else 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
