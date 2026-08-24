#!/usr/bin/env python3
"""Optional repo-local Codex guardrails for SIT.

This script deliberately has no product/runtime imports. It consumes the
official Codex hook JSON shape on stdin and emits only bounded hook decisions.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


DESTRUCTIVE_GIT_TOKEN = "SIT_DESTRUCTIVE_GIT_APPROVED=R0_DESTRUCTIVE_GIT_GO"
EXTERNAL_MUTATION_TOKEN = "SIT_EXTERNAL_MUTATION_APPROVED=R0_EXTERNAL_MUTATION_GO"

DESTRUCTIVE_GIT = re.compile(
    r"\bgit\s+(?:-[^\s]+\s+)*(?:"
    r"reset\s+--hard\b|"
    r"clean\s+-[^\s;|&]*f[^\s;|&]*\b|"
    r"push\b[^\n;|&]*(?:--force(?:-with-lease)?\b|-f\b)|"
    r"branch\s+-D\b|"
    r"tag\s+-d\b"
    r")",
    re.IGNORECASE,
)

EXTERNAL_MUTATIONS = (
    ("pull-request merge", re.compile(r"\bgh\s+pr\s+merge\b", re.IGNORECASE)),
    ("mutating GitHub API", re.compile(
        r"\bgh\s+api\b[^\n;|&]*(?:-X|--method)\s*(?:POST|PUT|PATCH|DELETE)\b",
        re.IGNORECASE,
    )),
    ("Firebase deployment", re.compile(r"\bfirebase\s+deploy\b", re.IGNORECASE)),
    ("Google Cloud mutation", re.compile(
        r"\bgcloud\b[^\n;|&]*\b(?:deploy|create|delete|update|replace|set-traffic)\b",
        re.IGNORECASE,
    )),
    ("Kubernetes mutation", re.compile(
        r"\bkubectl\s+(?:--[^\s]+\s+)*(?:apply|create|delete|edit|patch|replace|rollout|scale|set)\b",
        re.IGNORECASE,
    )),
    ("Helm mutation", re.compile(r"\bhelm\s+(?:install|upgrade|uninstall|rollback)\b", re.IGNORECASE)),
    ("Terraform mutation", re.compile(
        r"\bterraform\s+(?:apply|destroy|import|taint|untaint)\b",
        re.IGNORECASE,
    )),
    ("Pulumi mutation", re.compile(r"\bpulumi\s+(?:up|destroy|import)\b", re.IGNORECASE)),
    ("AWS mutation", re.compile(
        r"\baws\b[^\n;|&]*\b(?:create|delete|deploy|put|update|change-resource-record-sets)\b|"
        r"\baws\s+s3\s+(?:cp|mv|rm|sync)\b",
        re.IGNORECASE,
    )),
    ("Cloudflare mutation", re.compile(
        r"\b(?:wrangler\s+(?:deploy|publish|delete)|cloudflared\s+tunnel\s+route)\b",
        re.IGNORECASE,
    )),
    ("production hosting deployment", re.compile(
        r"\b(?:vercel|netlify\s+deploy)\b[^\n;|&]*--prod\b",
        re.IGNORECASE,
    )),
    ("payment provider command", re.compile(r"\bstripe\s+", re.IGNORECASE)),
    ("Store automation", re.compile(
        r"\b(?:bundle\s+exec\s+)?fastlane\b|\bupload_to_play_store\b|"
        r"\bgradle(?:w)?\b[^\n;|&]*\bpublish(?:Bundle)?\b",
        re.IGNORECASE,
    )),
    ("remote host mutation path", re.compile(
        r"(?:^|[;&|]\s*)(?:env\s+[^;&|]+\s+)?(?:ssh|scp|sftp|rsync)\b",
        re.IGNORECASE,
    )),
    ("mutating production HTTP request", re.compile(
        r"\bcurl\b[^\n;|&]*(?:-X|--request)\s*(?:POST|PUT|PATCH|DELETE)\b"
        r"[^\n;|&]*(?:prod(?:uction)?|api\.stripe\.com|play\.google\.com|cloudflare)",
        re.IGNORECASE,
    )),
)

SECRET_PATTERNS = (
    re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----"),
    re.compile(rb"\bsk-(?!example|test|fake)[A-Za-z0-9_-]{20,}"),
    re.compile(rb"\bghp_[A-Za-z0-9]{30,}"),
    re.compile(rb"\bgithub_pat_[A-Za-z0-9_]{40,}"),
    re.compile(rb"\bglpat-[A-Za-z0-9_-]{20,}"),
    re.compile(rb"\bAKIA[A-Z0-9]{16}\b"),
    re.compile(rb"\bxox[baprs]-[A-Za-z0-9-]{20,}"),
    re.compile(rb"\bAIza[0-9A-Za-z_-]{35}\b"),
)


def read_input() -> dict:
    try:
        value = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError) as error:
        raise RuntimeError("invalid Codex hook input") from error
    if not isinstance(value, dict):
        raise RuntimeError("invalid Codex hook input")
    return value


def emit_denial(reason: str) -> None:
    json.dump({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }, sys.stdout, separators=(",", ":"))
    sys.stdout.write("\n")


def git_root(cwd: str) -> Path | None:
    result = subprocess.run(
        ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
        capture_output=True,
        check=False,
        text=True,
        timeout=5,
    )
    if result.returncode != 0:
        return None
    return Path(result.stdout.strip()).resolve()


def staged_paths(root: Path) -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(root), "diff", "--cached", "--name-only", "-z", "--diff-filter=ACMR"],
        capture_output=True,
        check=False,
        timeout=10,
    )
    if result.returncode != 0:
        raise RuntimeError("unable to inspect staged paths")
    return [entry.decode("utf-8", "surrogateescape") for entry in result.stdout.split(b"\0") if entry]


def scan_staged_secrets(root: Path) -> str | None:
    for path in staged_paths(root):
        result = subprocess.run(
            ["git", "-C", str(root), "show", f":{path}"],
            capture_output=True,
            check=False,
            timeout=10,
        )
        if result.returncode != 0:
            raise RuntimeError("unable to inspect staged content")
        content = result.stdout
        if len(content) > 2 * 1024 * 1024 or b"\0" in content:
            continue
        if any(pattern.search(content) for pattern in SECRET_PATTERNS):
            return path
    return None


def run_fast_validators(root: Path) -> str | None:
    whitespace = subprocess.run(
        ["git", "-C", str(root), "diff", "--cached", "--check"],
        capture_output=True,
        check=False,
        timeout=20,
    )
    if whitespace.returncode != 0:
        return "staged whitespace validation failed"

    validators = sorted((root / "tool").glob("validate_blue_ocean_n*.mjs"))
    optional = (
        root / "tool" / "validate_pilot_launch_tiers.mjs",
        root / "tool" / "validate_external_gate_setup.mjs",
        root / "tool" / "validate_external_gate_execution_board.mjs",
    )
    validators.extend(path for path in optional if path.is_file())
    for validator in validators:
        result = subprocess.run(
            ["node", str(validator)],
            cwd=root,
            capture_output=True,
            check=False,
            timeout=30,
        )
        if result.returncode != 0:
            return f"fast SIT validator failed: {validator.name}"
    return None


def pre_tool(payload: dict) -> int:
    if payload.get("tool_name") != "Bash":
        return 0
    tool_input = payload.get("tool_input")
    command = tool_input.get("command", "") if isinstance(tool_input, dict) else ""
    if not isinstance(command, str):
        emit_denial("SIT guardrail blocked an invalid Bash command payload.")
        return 0

    if DESTRUCTIVE_GIT.search(command) and DESTRUCTIVE_GIT_TOKEN not in command:
        emit_denial(
            "Destructive Git command blocked. A separately approved exact command must include the SIT destructive-Git token."
        )
        return 0
    if EXTERNAL_MUTATION_TOKEN not in command:
        for label, pattern in EXTERNAL_MUTATIONS:
            if pattern.search(command):
                emit_denial(
                    f"External {label} blocked. No production, payment, Store, VPS, DNS or Cloud mutation is authorized."
                )
                return 0

    if re.search(r"\bgit\s+(?:-[^\s]+\s+)*commit\b", command, re.IGNORECASE):
        root = git_root(str(payload.get("cwd", ".")))
        if root is None:
            emit_denial("SIT pre-commit guard could not resolve the repository root.")
            return 0
        try:
            secret_path = scan_staged_secrets(root)
            if secret_path is not None:
                emit_denial(f"High-confidence secret pattern detected in staged file: {secret_path}")
                return 0
            failure = run_fast_validators(root)
        except (OSError, RuntimeError, subprocess.TimeoutExpired):
            emit_denial("SIT pre-commit validation could not complete safely.")
            return 0
        if failure is not None:
            emit_denial(failure)
            return 0
    return 0


def session_start() -> int:
    json.dump({
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": (
                "SIT repo-local hooks are optional defense in depth and never replace owner gates, "
                "permissions, CI or full regression. If and only if work must stop at a real gate, "
                "end with SIT_PENDING_GATE: <UPPER_SNAKE_TOKEN>."
            ),
        }
    }, sys.stdout, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


def stop(payload: dict) -> int:
    message = payload.get("last_assistant_message")
    if isinstance(message, str):
        match = re.search(r"(?:^|\n)SIT_PENDING_GATE:\s*([A-Z][A-Z0-9_]{2,79})(?:\s|$)", message)
        if match:
            root = git_root(str(payload.get("cwd", ".")))
            if root is not None:
                path_result = subprocess.run(
                    ["git", "-C", str(root), "rev-parse", "--git-path", "codex/sit-pending-gate.json"],
                    capture_output=True,
                    check=False,
                    text=True,
                    timeout=5,
                )
                if path_result.returncode == 0:
                    target = Path(path_result.stdout.strip())
                    if not target.is_absolute():
                        target = root / target
                    target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
                    record = {
                        "schemaVersion": 1,
                        "state": "pending",
                        "gate": match.group(1),
                        "source": "codex-stop-hook",
                        "containsPersonalData": False,
                    }
                    descriptor, temporary = tempfile.mkstemp(prefix=".sit-pending-", dir=target.parent)
                    try:
                        os.fchmod(descriptor, 0o600)
                        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
                            json.dump(record, handle, separators=(",", ":"))
                            handle.write("\n")
                        os.replace(temporary, target)
                    finally:
                        if os.path.exists(temporary):
                            os.unlink(temporary)
    sys.stdout.write("{}\n")
    return 0


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in {"session-start", "pre-tool", "stop"}:
        return 2
    try:
        payload = read_input()
    except RuntimeError:
        return 2
    if sys.argv[1] == "session-start":
        return session_start()
    if sys.argv[1] == "pre-tool":
        return pre_tool(payload)
    return stop(payload)


if __name__ == "__main__":
    raise SystemExit(main())
