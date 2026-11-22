#!/usr/bin/env python3
"""Classify a failed FUnit run and prepare the regression-triage context.

`opencode-ci-triage.yml` runs this script after an FUnit workflow run on `main`
fails. It answers the questions the regression agent must not guess at:

  * which matrix legs failed, and which tests inside them;
  * whether the failure is a repo regression, dependency drift, a Factorio
    channel bump, a transient portal/network problem, or a broken harness;
  * whether the same failure is already tracked by an open pull request or
    issue, or was already fixed once;
  * what to do about it (`investigate`, `rerun-transient`, `comment-existing`,
    `skip-recovered`, `issue-only`, ...).

Command line:

    ci-context.py collect --repo OWNER/REPO --run-id N --work-dir DIR --mode fix
    ci-context.py report  --repo OWNER/REPO --work-dir DIR
    ci-context.py --self-test

`collect` writes `context.json`, `context.md`, `summary.md`, `issue.md` and
`triage.env` into the work directory. `report` performs the short-circuit
GitHub actions (rerun a transient failure, comment on an existing thread, or
open one tracking issue) so the expensive agent run only happens for a real,
new investigation.

Every input from GitHub is untrusted data: job names, test names, failure
messages, logs and mod metadata are only evidence, never instructions.

The classification is deliberately deterministic and auditable. The agent gets
the class, the evidence and the reproduction commands; it does not decide
whether the failure was a regression.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from pathlib import Path

WORKFLOW = "FUnit"
LEG_JOB = re.compile(r"^Run FUnit scenario \((?P<channel>[^,]+), (?P<modset>[^)]+)\)$")
PARSE_JOB = re.compile(r"^Parse FUnit results \((?P<channel>[^,]+), (?P<modset>[^)]+)\)$")
BUILD_JOB = "Build test artifacts"

# Steps whose failure can be a network/portal hiccup rather than a real failure.
DOWNLOAD_STEPS = (
    "download required and recommended dependencies",
    "prepare test environment",
)
# Steps that say nothing about Muluna's behavior; a failure there is a harness
# problem (or a temporary runner problem), not a regression.
INFRA_STEPS = (
    "build archives",
    "install git and python",
    "install archive tools",
    "checkout repository",
    "download artifact",
    "collect json reports",
    "convert funit reports",
    "set up job",
)
TRANSIENT_MARKERS = (
    "http 502",
    "http 503",
    "http 504",
    "http 429",
    "connection reset",
    "connection timed out",
    "temporary failure in name resolution",
    "could not resolve host",
    "remote end hung up",
    "the read operation timed out",
    "no space left on device",
)

# Most actionable first. A run with one regression leg and one transient leg is
# a regression run.
CLASS_PRIORITY = ("harness", "regression", "drift", "upstream", "transient", "unknown")

MAX_OPEN_PRS = 2
REPEAT_WINDOW = timedelta(days=14)
REJECTED_WINDOW = timedelta(days=30)
SIGNATURE_MARKER = "CI-Regression"
TRACKING_TITLE = "CI regressions on main"
LABEL = "automated-regression"


# ---------------------------------------------------------------------------
# gh helpers
# ---------------------------------------------------------------------------
def gh(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    proc = subprocess.run(["gh", *args], capture_output=True, text=True)
    if check and proc.returncode != 0:
        raise SystemExit(
            f"error: gh {' '.join(args)} failed (exit {proc.returncode}):\n"
            f"{proc.stderr.strip()}"
        )
    return proc


def gh_json(*args: str):
    proc = gh(*args)
    try:
        return json.loads(proc.stdout)
    except ValueError as error:
        raise SystemExit(f"error: gh {' '.join(args)} did not return JSON: {error}") from error


def download_artifact(repo: str, run_id: int, name: str, destination: Path) -> bool:
    proc = gh(
        "run",
        "download",
        str(run_id),
        "-R",
        repo,
        "-n",
        name,
        "-D",
        str(destination),
        check=False,
    )
    if proc.returncode != 0:
        print(f"  no artifact {name} on run {run_id}: {proc.stderr.strip()}", file=sys.stderr)
        return False
    return True


# ---------------------------------------------------------------------------
# Evidence
# ---------------------------------------------------------------------------
def parse_junit(path: Path) -> list[dict]:
    """Return the failing test cases of a JUnit report."""
    try:
        root = ET.parse(path).getroot()
    except (ET.ParseError, OSError) as error:
        print(f"  cannot parse {path}: {error}", file=sys.stderr)
        return []

    tests = []
    for case in root.iter("testcase"):
        failure = case.find("failure")
        error = case.find("error")
        node = failure if failure is not None else error
        if node is None:
            continue
        classname = case.get("classname") or ""
        name = case.get("name") or ""
        identifier = f"{classname}.{name}" if classname else name
        message = node.get("message") or ""
        tests.append(
            {
                "id": identifier,
                "kind": "failure" if failure is not None else "error",
                "message": message[:400],
                "file": case.get("file") or "",
                "line": case.get("line") or "",
            }
        )
    return tests


def read_json(path: Path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return None


def read_lock(path: Path):
    document = read_json(path)
    if not isinstance(document, dict) or document.get("schema") != 1:
        return None
    return document


def read_text(path: Path, limit: int | None = None) -> str:
    try:
        text = path.read_text(errors="replace")
    except OSError:
        return ""
    return text if limit is None else text[:limit]


ERROR_LINE = re.compile(
    r"error |error:|failed to load mod|missing required dependency|"
    r"funit.*(?:fail|error)|lua error",
    re.IGNORECASE,
)


def error_excerpt(text: str, limit: int = 300) -> str:
    """Pull the last few error lines out of a Factorio/FUnit log.

    This gives the signature something specific to key on when the run failed
    before any test case was reported, and it shows the agent the actual error
    without making it read a multi-megabyte log first. Factorio prefixes log
    lines with a run-dependent timestamp, which must not leak into the
    signature; the tail is used because a data-stage error aborts the load and
    everything after it is noise.
    """
    matches: list[str] = []
    for line in text.splitlines():
        stripped = re.sub(r"^\d+(?:\.\d+)?\s+", "", line.strip())
        if not stripped or not ERROR_LINE.search(stripped):
            continue
        if stripped not in matches:
            matches.append(stripped)
    return " | ".join(matches[-3:])[:limit]


def lock_diff(before, after) -> dict:
    """Compare two dependency lock files."""
    if not before or not after:
        return {
            "available": False,
            "changed": False,
            "only_factorio": False,
            "factorio": {},
            "mods": [],
        }

    before_mods = {entry.get("name", "").lower(): entry for entry in before.get("mods") or []}
    after_mods = {entry.get("name", "").lower(): entry for entry in after.get("mods") or []}

    mods = []
    for key in sorted(set(before_mods) | set(after_mods)):
        old = before_mods.get(key)
        new = after_mods.get(key)
        old_version = (old or {}).get("version")
        new_version = (new or {}).get("version")
        if old_version == new_version:
            continue
        if old is None:
            change = "added"
        elif new is None:
            change = "removed"
        else:
            change = "changed"
        mods.append(
            {
                "name": (new or old).get("name", key),
                "before": old_version,
                "after": new_version,
                "change": change,
            }
        )

    before_factorio = (before.get("factorio") or {}).get("resolved")
    after_factorio = (after.get("factorio") or {}).get("resolved")
    factorio_changed = before_factorio != after_factorio

    return {
        "available": True,
        "changed": bool(mods) or factorio_changed,
        "only_factorio": factorio_changed and not mods,
        "factorio": {
            "before": before_factorio,
            "after": after_factorio,
            "changed": factorio_changed,
        },
        "mods": mods,
    }


def compute_signature(legs: dict) -> str:
    """Stable identifier for the set of failing tests and legs."""
    parts = []
    for leg in sorted(legs):
        entry = legs[leg]
        for test in entry.get("tests") or []:
            parts.append(f"{leg}:{test['id']}")
        if not entry.get("tests"):
            for step in entry.get("failed_steps") or []:
                parts.append(f"{leg}:step:{step}")
            if entry.get("error_excerpt"):
                parts.append(f"{leg}:error:{entry['error_excerpt']}")
    payload = "\n".join(sorted(set(parts))) or "no-failure-detail"
    return hashlib.sha256(payload.encode()).hexdigest()[:10]


def parse_timestamp(value: str) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


# ---------------------------------------------------------------------------
# Collection (uses gh)
# ---------------------------------------------------------------------------
def collect_leg_artifacts(
    repo: str, run_id: int, leg: str, entry: dict, leg_dir: Path
) -> None:
    channel = entry["channel"]
    modset = entry["modset"]
    slug = f"{channel}-{modset}"

    junit_dir = leg_dir / slug / "junit"
    if download_artifact(repo, run_id, f"parse-results-job-{slug}", junit_dir):
        tests = []
        for report in sorted(junit_dir.rglob("*.xml")):
            tests.extend(parse_junit(report))
        entry["tests"] = tests
        entry["junit_dir"] = str(junit_dir)

    unit_dir = leg_dir / slug / "unit"
    if download_artifact(repo, run_id, f"unit-test-job-{slug}", unit_dir):
        logs = sorted(unit_dir.rglob("funit.log"))
        if logs:
            entry["log_path"] = str(logs[0])
            full_log = read_text(logs[0], limit=2_000_000)
            entry["log_excerpt"] = full_log[-12000:]
            entry["error_excerpt"] = error_excerpt(full_log)
        locks = sorted(unit_dir.rglob(f"funit-lock-{slug}.json"))
        if locks:
            entry["lock_path"] = str(locks[0])
            entry["lock"] = read_lock(locks[0])


def collect_baseline(
    repo: str, leg: str, entry: dict, green_run: dict | None, work: Path
) -> None:
    if not green_run:
        return
    channel = entry["channel"]
    modset = entry["modset"]
    slug = f"{channel}-{modset}"
    destination = work / "baseline" / str(green_run["databaseId"]) / slug
    if not download_artifact(repo, green_run["databaseId"], f"unit-test-job-{slug}", destination):
        return
    locks = sorted(destination.rglob(f"funit-lock-{slug}.json"))
    if locks:
        entry["baseline_lock"] = read_lock(locks[0])
        entry["baseline_run"] = green_run


def collect(repo: str, run_id: int, work_dir: Path, mode: str) -> dict:
    work = Path(work_dir)
    work.mkdir(parents=True, exist_ok=True)

    run = gh_json("api", f"repos/{repo}/actions/runs/{run_id}")
    jobs = gh_json(
        "api",
        f"repos/{repo}/actions/runs/{run_id}/jobs?per_page=100",
        "--jq",
        ".jobs",
    )

    legs: dict[str, dict] = {}
    build_failed = False
    for job in jobs:
        name = job.get("name") or ""
        if name == BUILD_JOB and job.get("conclusion") == "failure":
            build_failed = True
        match = LEG_JOB.match(name) or PARSE_JOB.match(name)
        if not match:
            continue
        leg = f"{match['channel']}/{match['modset']}"
        entry = legs.setdefault(
            leg,
            {
                "channel": match["channel"],
                "modset": match["modset"],
                "job_results": [],
                "failed_steps": [],
                "tests": [],
                "log_excerpt": "",
                "lock": None,
                "baseline_lock": None,
            },
        )
        entry["job_results"].append({"name": name, "conclusion": job.get("conclusion")})
        for step in job.get("steps") or []:
            if step.get("conclusion") == "failure":
                step_name = step.get("name") or ""
                if step_name not in entry["failed_steps"]:
                    entry["failed_steps"].append(step_name)

    failed_legs = {
        leg: entry
        for leg, entry in legs.items()
        if any(result["conclusion"] == "failure" for result in entry["job_results"])
    }

    if run.get("conclusion") != "failure" and not failed_legs:
        failed_legs = {}

    print(f"Run {run_id}: {run.get('conclusion')} ({run.get('event')} on {run.get('head_branch')})")
    print(f"Failed legs: {', '.join(sorted(failed_legs)) or 'none'}")

    for leg, entry in sorted(failed_legs.items()):
        print(f"  collecting {leg} ...")
        collect_leg_artifacts(repo, run_id, leg, entry, work / "legs")

    # The newest successful run on main, newer than this failure, means the
    # problem is already gone (a later commit, or a dependency that was fixed
    # and re-run). Older ones are the baseline for the dependency comparison.
    green_runs = gh_json(
        "run",
        "list",
        "-R",
        repo,
        "--workflow",
        WORKFLOW,
        "--branch",
        "main",
        "--status",
        "success",
        "--limit",
        "20",
        "--json",
        "databaseId,headSha,createdAt,event,url",
    )
    failing_at = run.get("created_at") or ""
    newer_green = [
        green
        for green in green_runs
        if green.get("databaseId") != run_id and (green.get("createdAt") or "") > failing_at
    ]
    older_green = [
        green
        for green in green_runs
        if green.get("databaseId") != run_id and (green.get("createdAt") or "") < failing_at
    ]
    older_green.sort(key=lambda green: green.get("createdAt") or "", reverse=True)
    baseline_run = older_green[0] if older_green else None

    for leg, entry in failed_legs.items():
        collect_baseline(repo, leg, entry, baseline_run, work)

    signature = compute_signature(failed_legs)

    prs = gh_json(
        "pr",
        "list",
        "-R",
        repo,
        "--state",
        "all",
        "--limit",
        "100",
        "--json",
        "number,state,title,body,url,mergedAt,closedAt,headRefName,labels",
    )
    issues = gh_json(
        "issue",
        "list",
        "-R",
        repo,
        "--state",
        "all",
        "--label",
        LABEL,
        "--limit",
        "100",
        "--json",
        "number,state,title,body,url,closedAt",
    )

    marker = f"{SIGNATURE_MARKER}: {signature}"

    def is_automated(pr: dict) -> bool:
        labels = {label.get("name") for label in pr.get("labels") or []}
        body = pr.get("body") or ""
        return LABEL in labels or marker in body or signature in body

    automated_prs = [pr for pr in prs if is_automated(pr)]
    existing_pr = next(
        (pr for pr in automated_prs if marker in (pr.get("body") or "")), None
    ) or next((pr for pr in automated_prs if signature in (pr.get("body") or "")), None)
    existing_issue = next(
        (issue for issue in issues if marker in (issue.get("body") or "")),
        None,
    )
    open_prs = [pr for pr in automated_prs if pr.get("state") == "OPEN"]

    evidence = {
        "run": {
            "id": run.get("id", run_id),
            "conclusion": run.get("conclusion"),
            "event": run.get("event"),
            "attempt": run.get("run_attempt"),
            "head_branch": run.get("head_branch"),
            "head_sha": run.get("head_sha"),
            "created_at": failing_at,
            "url": run.get("html_url"),
        },
        "build_failed": build_failed,
        "legs": failed_legs,
        "signature": signature,
        "recovered": bool(newer_green),
        "recovered_run": newer_green[0] if newer_green else None,
        "baseline_run": baseline_run,
        "existing_pr": existing_pr,
        "existing_issue": existing_issue,
        "open_prs": len(open_prs),
        "other_open_prs": [pr["number"] for pr in open_prs],
    }

    (work / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")

    context = build_context(evidence, mode)
    write_context(work, context)
    return context


# ---------------------------------------------------------------------------
# Classification (pure)
# ---------------------------------------------------------------------------
def classify_leg(entry: dict) -> tuple[str, str]:
    steps = [step.lower() for step in entry.get("failed_steps") or []]
    text = (entry.get("log_excerpt") or "").lower()
    step_text = " ".join(steps)

    if any(steps) and all(any(infra in step for infra in INFRA_STEPS) for step in steps):
        return "harness", f"an infrastructure step failed: {', '.join(entry.get('failed_steps') or [])}"

    if any(download in step_text for download in DOWNLOAD_STEPS) and any(
        marker in text for marker in TRANSIENT_MARKERS
    ):
        return (
            "transient",
            "the dependency download or environment setup failed with a network or "
            "mod-portal error",
        )

    diff = lock_diff(entry.get("baseline_lock"), entry.get("lock"))
    entry["lock_diff"] = diff
    if diff["only_factorio"]:
        return (
            "upstream",
            "only the Factorio build differs from the last green run: "
            f"{diff['factorio']['before']} -> {diff['factorio']['after']}",
        )
    if diff["changed"]:
        names = ", ".join(
            f"{mod['name']} {mod['before']} -> {mod['after']}" for mod in diff["mods"][:6]
        )
        return "drift", f"dependency releases differ from the last green run: {names}"
    if not diff["available"]:
        return (
            "regression",
            "no dependency lock baseline was available, so the versions could not be "
            "compared; treat it as a regression until reproduced",
        )
    return "regression", "the dependencies and Factorio build match the last green run"


def build_context(evidence: dict, mode: str, now: datetime | None = None) -> dict:
    now = now or datetime.now(timezone.utc)
    run = evidence["run"]

    legs = {}
    classes = []
    for leg, entry in sorted(evidence["legs"].items()):
        klass, reason = classify_leg(entry)
        classes.append(klass)
        legs[leg] = {
            "channel": entry["channel"],
            "modset": entry["modset"],
            # The matrix channel is stable/experimental; factorio.com and the
            # setup script label the experimental channel "latest".
            "version_label": (
                "latest" if entry["channel"] == "experimental" else entry["channel"]
            ),
            "class": klass,
            "reason": reason,
            "failed_steps": entry.get("failed_steps") or [],
            "tests": entry.get("tests") or [],
            "error_excerpt": entry.get("error_excerpt") or "",
            "lock": entry.get("lock_path"),
            "lock_document": entry.get("lock"),
            "baseline_lock": entry.get("baseline_lock"),
            "baseline_run": entry.get("baseline_run"),
            "lock_diff": entry.get("lock_diff") or lock_diff(None, None),
            "log": entry.get("log_path"),
            "junit_dir": entry.get("junit_dir"),
        }

    if evidence["build_failed"]:
        classes.append("harness")
    overall = next((name for name in CLASS_PRIORITY if name in classes), "unknown")

    existing_pr = evidence.get("existing_pr")
    existing_issue = evidence.get("existing_issue")
    reason = ""

    if run.get("conclusion") != "failure" and not legs and not evidence["build_failed"]:
        action = "no-failure"
        reason = f"the run concluded {run.get('conclusion') or 'without a failure'}"
    elif evidence.get("recovered"):
        action = "skip-recovered"
        green = evidence.get("recovered_run") or {}
        reason = (
            "a newer successful FUnit run on main already exists"
            + (f" ({green.get('url')})" if green.get("url") else "")
            + "; the failure no longer reproduces"
        )
    elif existing_pr and existing_pr.get("state") == "OPEN":
        action = "comment-existing"
        reason = f"pull request #{existing_pr['number']} already tracks this failure"
    elif existing_issue and existing_issue.get("state") == "OPEN":
        action = "comment-existing"
        reason = f"issue #{existing_issue['number']} already tracks this failure"
    elif existing_pr and existing_pr.get("state") == "MERGED":
        merged_at = parse_timestamp(existing_pr.get("mergedAt") or "")
        if merged_at and now - merged_at <= REPEAT_WINDOW:
            action = "issue-repeat"
            reason = (
                f"pull request #{existing_pr['number']} was merged "
                f"{merged_at.date()} and the failure came back; the previous fix was "
                "not sufficient"
            )
        else:
            action = "investigate"
            reason = "a previous fix for this signature is older than the repeat window"
    elif existing_pr and existing_pr.get("state") == "CLOSED":
        closed_at = parse_timestamp(existing_pr.get("closedAt") or "")
        if closed_at and now - closed_at <= REJECTED_WINDOW:
            action = "skip-rejected"
            reason = (
                f"pull request #{existing_pr['number']} was closed without merging; a "
                "human decided not to take that fix, so it is not retried automatically"
            )
        else:
            action = "investigate"
            reason = "an earlier automated fix was closed long ago; retrying"
    elif evidence.get("open_prs", 0) >= MAX_OPEN_PRS:
        action = "budget-exceeded"
        reason = (
            f"{evidence['open_prs']} automated regression pull requests are already open "
            f"({', '.join('#' + str(number) for number in evidence.get('other_open_prs') or [])}); "
            "they need review before another is opened"
        )
    else:
        leg_classes = {leg["class"] for leg in legs.values()}
        if leg_classes and leg_classes == {"transient"} and (run.get("attempt") or 1) < 2:
            action = "rerun-transient"
            reason = "every failed leg failed on a network/portal error; retrying the failed jobs once"
        elif leg_classes and leg_classes == {"transient"}:
            action = "issue-only"
            reason = "the rerun still failed with network/portal errors; this needs a human"
        else:
            action = "investigate"
            reason = "no existing tracking thread, budget available, and a reproducible failure expected"

    if mode == "diagnose":
        # Keep the action the run would have taken so the summary is useful;
        # the workflow and `report` only apply it when mode is "fix".
        reason = f"{reason} (diagnose mode: the action will not be applied)"

    signatures = {
        "signature": evidence["signature"],
        "marker": f"{SIGNATURE_MARKER}: {evidence['signature']}",
    }

    return {
        "mode": mode,
        "action": action,
        "failure_class": overall,
        "reason": reason,
        "run": run,
        "signature": signatures["signature"],
        "marker": signatures["marker"],
        "build_failed": evidence["build_failed"],
        "legs": legs,
        "baseline_run": evidence.get("baseline_run"),
        "existing_pr": existing_pr,
        "existing_issue": existing_issue,
        "open_prs": evidence.get("open_prs", 0),
    }


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
def lock_diff_lines(diff: dict, indent: str = "") -> list[str]:
    if not diff.get("available"):
        return [f"{indent}_No dependency lock baseline was available._"]
    lines = []
    factorio = diff.get("factorio") or {}
    if factorio.get("changed"):
        lines.append(
            f"{indent}- Factorio: `{factorio.get('before')}` -> `{factorio.get('after')}`"
        )
    for mod in diff.get("mods") or []:
        lines.append(
            f"{indent}- `{mod['name']}`: `{mod['before'] or 'absent'}` -> "
            f"`{mod['after'] or 'absent'}` ({mod['change']})"
        )
    if not lines:
        lines.append(f"{indent}- No differences: same mods and Factorio build.")
    return lines


def reproduction_lines(context: dict, leg: dict) -> list[str]:
    channel = leg["channel"]
    version = leg.get("version_label") or channel
    modset = leg["modset"]
    # The workflow prepares this exact directory, and exports TRIAGE_DIR to the
    # agent step. Keeping the two in sync avoids a second full download.
    mods_dir = f"$TRIAGE_DIR/mods-{channel}-{modset}"
    if leg.get("lock"):
        pin = [f"  FUNIT_LOCK_FILE={leg['lock']} \\"]
        note = "# Dependencies exactly as the failing run resolved them:"
    else:
        pin = []
        note = "# No lock file was recorded for this run; resolving the newest releases:"
    return [
        "```sh",
        note,
        f"FUNIT_MODS_DIR={mods_dir} \\",
        f"FUNIT_MODSET={modset} \\",
        f"FACTORIO_VERSION={version} \\",
        *pin,
        "  ./.github/opencode/setup-factorio.sh",
        "",
        "# Then run the leg:",
        f'FACTORIO_BIN="${{RUNNER_TEMP:-/tmp/opencode}}/muluna-opencode/factorio-{version}/bin/x64/factorio" \\',
        f"FACTORIO_MODS={mods_dir} \\",
        f"FUNIT_MODSET={modset} \\",
        "  ./test-mods/planet-muluna-funit/run.sh",
        "```",
    ]


def render_context_markdown(context: dict) -> str:
    run = context["run"]
    lines = [
        "# FUnit failure triage",
        "",
        f"{context['marker']}",
        "",
        f"- Run: [#{run.get('id')}]({run.get('url')}) "
        f"({run.get('event')}, attempt {run.get('attempt')}, `{run.get('head_sha', '')[:12]}`)",
        f"- Conclusion: `{run.get('conclusion')}`",
        f"- Failure class: **{context['failure_class']}**",
        f"- Action: **{context['action']}**",
        f"- Reason: {context['reason']}",
        f"- Mode: `{context['mode']}`",
        "",
    ]

    if context.get("baseline_run"):
        baseline = context["baseline_run"]
        lines += [
            f"Last green main run used as the dependency baseline: "
            f"[#{baseline.get('databaseId')}]({baseline.get('url')}) "
            f"({baseline.get('createdAt')}).",
            "",
        ]

    if context["build_failed"]:
        lines += [
            "## Build job failed",
            "",
            "The `Build test artifacts` job failed, so no leg ran. This is a harness or",
            "repository problem (archiving, `info.json`, the pinned FUnit checkout), not a",
            "mod-set result.",
            "",
        ]

    for leg_name, leg in sorted(context["legs"].items()):
        lines += [
            f"## Leg `{leg_name}`",
            "",
            f"- Class: **{leg['class']}**",
            f"- Why: {leg['reason']}",
            f"- Failed steps: {', '.join(leg['failed_steps']) or 'n/a'}",
            "",
            "Failing tests:",
            "",
        ]
        if leg["tests"]:
            for test in leg["tests"]:
                message = test["message"].replace("\n", " ")
                lines.append(f"- `{test['id']}` ({test['kind']}): {message}")
        else:
            lines.append("- No test case details were available (see the log).")
        if leg.get("error_excerpt"):
            lines += ["", f"Log error: `{leg['error_excerpt']}`"]
        lines += ["", "Dependency diff against the last green run:", ""]
        lines += lock_diff_lines(leg["lock_diff"])
        lines += ["", "Reproduce:", ""]
        lines += reproduction_lines(context, leg)
        if leg.get("log"):
            lines.append(f"Full FUnit log: `{leg['log']}`")
        lines.append("")

    if context.get("existing_pr"):
        pr = context["existing_pr"]
        lines += [f"Existing pull request: #{pr['number']} ({pr['state']}) {pr['url']}", ""]
    if context.get("existing_issue"):
        issue = context["existing_issue"]
        lines += [f"Existing issue: #{issue['number']} ({issue['state']}) {issue['url']}", ""]

    return "\n".join(lines)


def render_summary(context: dict) -> str:
    run = context["run"]
    rows = []
    for leg_name, leg in sorted(context["legs"].items()):
        tests = len(leg["tests"])
        rows.append(f"| `{leg_name}` | {leg['class']} | {tests} | {', '.join(leg['failed_steps'])} |")

    lines = [
        f"## FUnit triage: **{context['failure_class']}** -> `{context['action']}`",
        "",
        f"Run [#{run.get('id')}]({run.get('url')}) ({run.get('event')}, "
        f"attempt {run.get('attempt')}). {context['reason']}",
        "",
    ]
    if rows:
        lines += [
            "| Leg | Class | Failing tests | Failed steps |",
            "| --- | --- | --- | --- |",
            *rows,
            "",
        ]
    if context["build_failed"]:
        lines += ["`Build test artifacts` failed; no matrix leg ran.", ""]
    lines += [f"Signature: `{context['signature']}`", ""]
    return "\n".join(lines)


def issue_body(context: dict) -> str:
    run = context["run"]
    lines = [
        context["marker"],
        "",
        f"The weekly or push FUnit run on `main` failed: [#{run.get('id')}]({run.get('url')}) "
        f"({run.get('event')}, attempt {run.get('attempt')}, `{run.get('head_sha', '')[:12]}`).",
        "",
        f"Classified as **{context['failure_class']}**. {context['reason']}",
        "",
        "| Leg | Class | Failing tests |",
        "| --- | --- | --- |",
    ]
    for leg_name, leg in sorted(context["legs"].items()):
        names = "<br>".join(f"`{test['id']}`" for test in leg["tests"]) or "no test details"
        lines.append(f"| `{leg_name}` | {leg['class']} | {names} |")

    for leg_name, leg in sorted(context["legs"].items()):
        lines += [
            "",
            f"### `{leg_name}` dependencies",
            "",
            *lock_diff_lines(leg["lock_diff"]),
        ]

    first_leg = next(iter(context["legs"].values()), None)
    lines += [
        "",
        "Reproduce the failing leg with:",
        "",
        "```sh",
        "./.github/opencode/setup-factorio.sh   # installs Factorio and FUnit",
    ]
    if first_leg:
        lines += first_leg.get("reproduction") or []
    else:
        lines.append("# no matrix leg ran")
    lines += [
        "```",
        "",
        "A human or the regression agent should reproduce this headlessly, add a",
        "regression test, and fix the cause. Dependency drift and Factorio channel bumps",
        "are fixed by adapting the compatibility patch or by pinning the last known good",
        "release.",
    ]
    return "\n".join(lines)


def write_context(work: Path, context: dict) -> None:
    for leg in context["legs"].values():
        leg["reproduction"] = reproduction_lines(context, leg)

    (work / "context.json").write_text(json.dumps(context, indent=2) + "\n")
    (work / "context.md").write_text(render_context_markdown(context) + "\n")
    (work / "summary.md").write_text(render_summary(context) + "\n")

    issue = {
        "title": f"CI regression: {context['failure_class']} on "
        + ", ".join(sorted(context["legs"]))[:120],
        "body": issue_body(context),
    }
    (work / "issue.md").write_text(issue["body"] + "\n")
    (work / "issue.json").write_text(json.dumps(issue, indent=2) + "\n")

    env = {
        "TRIAGE_SIGNATURE": context["signature"],
        "TRIAGE_ACTION": context["action"],
        "TRIAGE_CLASS": context["failure_class"],
        "TRIAGE_MODE": context["mode"],
        "TRIAGE_LEGS": " ".join(sorted(context["legs"])),
        "TRIAGE_RUN_ID": str(context["run"].get("id") or ""),
    }
    (work / "triage.env").write_text("".join(f"{key}={value}\n" for key, value in env.items()))
    print(f"Action: {context['action']} ({context['failure_class']}): {context['reason']}")


# ---------------------------------------------------------------------------
# Reporting (short-circuit GitHub actions)
# ---------------------------------------------------------------------------
def upsert_issue(repo: str, title: str, body: str, marker: str) -> None:
    issues = gh_json(
        "issue",
        "list",
        "-R",
        repo,
        "--state",
        "open",
        "--label",
        LABEL,
        "--limit",
        "100",
        "--json",
        "number,title,body",
    )
    for issue in issues:
        if title in (issue.get("title") or "") or marker in (issue.get("body") or ""):
            gh("issue", "comment", str(issue["number"]), "-R", repo, "--body", body)
            print(f"Commented on issue #{issue['number']}")
            return
    gh("issue", "create", "-R", repo, "--title", title, "--label", LABEL, "--body", body)
    print(f"Opened issue: {title}")


def report(repo: str, work_dir: Path) -> None:
    work = Path(work_dir)
    context = read_json(work / "context.json")
    if not context:
        raise SystemExit(f"error: no context.json in {work}")

    action = context["action"]
    mode = context["mode"]
    run = context["run"]
    marker = context["marker"]

    if mode != "fix":
        print(f"mode is {mode}; no GitHub changes for action {action}")
        return

    comment = (
        f"{marker}\n\n"
        f"The FUnit failure is still present on `main`: "
        f"[#{run.get('id')}]({run.get('url')}) "
        f"({context['failure_class']}, attempt {run.get('attempt')}). "
        f"{context['reason']}\n"
    )

    if action == "rerun-transient":
        gh("run", "rerun", str(run["id"]), "-R", repo, "--failed")
        print(f"Reran failed jobs of run {run['id']}")
    elif action == "comment-existing":
        if context.get("existing_pr"):
            gh("pr", "comment", str(context["existing_pr"]["number"]), "-R", repo, "--body", comment)
            print(f"Commented on pull request #{context['existing_pr']['number']}")
        elif context.get("existing_issue"):
            gh("issue", "comment", str(context["existing_issue"]["number"]), "-R", repo, "--body", comment)
            print(f"Commented on issue #{context['existing_issue']['number']}")
    elif action in {"issue-only", "issue-repeat"}:
        issue = read_json(work / "issue.json") or {}
        upsert_issue(repo, issue.get("title") or f"CI regression on main ({marker})", comment + "\n" + (issue.get("body") or ""), marker)
    elif action == "budget-exceeded":
        upsert_issue(
            repo,
            TRACKING_TITLE,
            comment
            + "\nAnother automated regression pull request is not opened until the open ones "
            "are reviewed.\n",
            marker,
        )
    else:
        print(f"no GitHub action for {action}")


# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------
def make_leg(
    channel: str = "stable",
    modset: str = "vanilla",
    steps: list[str] | None = None,
    tests: list[dict] | None = None,
    lock=None,
    baseline_lock=None,
    log: str = "",
) -> dict:
    return {
        "channel": channel,
        "modset": modset,
        "job_results": [{"name": "Run FUnit scenario", "conclusion": "failure"}],
        "failed_steps": steps if steps is not None else ["Run FUnit scenario"],
        "tests": tests if tests is not None else [],
        "log_excerpt": log,
        "lock": lock,
        "baseline_lock": baseline_lock,
    }


def make_evidence(legs: dict, **overrides) -> dict:
    evidence = {
        "run": {
            "id": 1,
            "conclusion": "failure",
            "event": "schedule",
            "attempt": 1,
            "head_branch": "main",
            "head_sha": "a" * 40,
            "created_at": "2026-11-20T04:17:00Z",
            "url": "https://example.invalid/run/1",
        },
        "build_failed": False,
        "legs": legs,
        "signature": compute_signature(legs),
        "recovered": False,
        "recovered_run": None,
        "baseline_run": None,
        "existing_pr": None,
        "existing_issue": None,
        "open_prs": 0,
        "other_open_prs": [],
    }
    evidence.update(overrides)
    return evidence


def lock(mods: dict, factorio: str = "2.1.24") -> dict:
    return {
        "schema": 1,
        "modset": "vanilla",
        "factorio": {"requested": "stable", "resolved": factorio},
        "mods": [
            {"name": name, "version": version, "file_name": f"{name}_{version}.zip"}
            for name, version in mods.items()
        ],
    }


NOW = datetime(2026, 11, 21, 12, 0, tzinfo=timezone.utc)


def self_test() -> int:
    failures: list[str] = []

    def expect(name: str, actual, expected) -> None:
        if actual != expected:
            failures.append(f"{name}: expected {expected!r}, got {actual!r}")

    # 1. A plain regression: same dependency set, a failing test.
    regression = make_leg(tests=[{"id": "suite.test", "kind": "failure", "message": "boom"}],
                          lock=lock({"PlanetsLib": "2.0.9"}),
                          baseline_lock=lock({"PlanetsLib": "2.0.9"}))
    context = build_context(make_evidence({"stable/vanilla": regression}), "fix", NOW)
    expect("regression class", context["failure_class"], "regression")
    expect("regression action", context["action"], "investigate")

    # 2. Dependency drift names the changed mod.
    drift = make_leg(lock=lock({"PlanetsLib": "2.0.10"}),
                     baseline_lock=lock({"PlanetsLib": "2.0.9"}))
    context = build_context(make_evidence({"stable/planets": drift}), "fix", NOW)
    expect("drift class", context["failure_class"], "drift")
    expect("drift mods", [mod["name"] for mod in context["legs"]["stable/planets"]["lock_diff"]["mods"]],
           ["PlanetsLib"])

    # 3. Only the Factorio build moved: upstream.
    upstream = make_leg(lock=lock({"PlanetsLib": "2.0.9"}, factorio="2.1.25"),
                        baseline_lock=lock({"PlanetsLib": "2.0.9"}, factorio="2.1.24"))
    context = build_context(make_evidence({"experimental/vanilla": upstream}), "fix", NOW)
    expect("upstream class", context["failure_class"], "upstream")

    # 4. A portal outage during the download is transient and rerun once.
    transient = make_leg(steps=["Download required and recommended dependencies"],
                         log="error: download failed for PlanetsLib (HTTP 503)")
    context = build_context(make_evidence({"stable/vanilla": transient}), "fix", NOW)
    expect("transient class", context["failure_class"], "transient")
    expect("transient action", context["action"], "rerun-transient")

    # 5. The rerun already happened: escalate to a human.
    evidence = make_evidence({"stable/vanilla": transient})
    evidence["run"]["attempt"] = 2
    expect("transient exhausted", build_context(evidence, "fix", NOW)["action"], "issue-only")

    # 6. A newer green run wins over everything.
    expect(
        "recovered",
        build_context(make_evidence({"stable/vanilla": regression}, recovered=True,
                                    recovered_run={"url": "https://example.invalid/run/2"}),
                      "fix", NOW)["action"],
        "skip-recovered",
    )

    # 7. An open tracking pull request is reused, not duplicated.
    evidence = make_evidence(
        {"stable/vanilla": regression},
        existing_pr={"number": 7, "state": "OPEN", "url": "https://example.invalid/pr/7",
                     "body": f"{SIGNATURE_MARKER}: {compute_signature({'stable/vanilla': regression})}"},
    )
    expect("existing pr", build_context(evidence, "fix", NOW)["action"], "comment-existing")

    # 8. A merged fix that did not hold becomes an issue, not another PR.
    evidence = make_evidence(
        {"stable/vanilla": regression},
        existing_pr={"number": 8, "state": "MERGED", "url": "https://example.invalid/pr/8",
                     "mergedAt": "2026-11-19T10:00:00Z"},
    )
    expect("repeat", build_context(evidence, "fix", NOW)["action"], "issue-repeat")

    # 9. A human-closed fix is not retried immediately.
    evidence = make_evidence(
        {"stable/vanilla": regression},
        existing_pr={"number": 9, "state": "CLOSED", "url": "https://example.invalid/pr/9",
                     "closedAt": "2026-11-10T10:00:00Z"},
    )
    expect("rejected", build_context(evidence, "fix", NOW)["action"], "skip-rejected")

    # 10. The budget stops a third concurrent automated pull request.
    evidence = make_evidence({"stable/vanilla": regression}, open_prs=2, other_open_prs=[1, 2])
    expect("budget", build_context(evidence, "fix", NOW)["action"], "budget-exceeded")

    # 11. Diagnose mode keeps the diagnosis but applies no GitHub change.
    evidence = make_evidence({"stable/vanilla": transient})
    diagnose = build_context(evidence, "diagnose", NOW)
    expect("diagnose mode", diagnose["mode"], "diagnose")
    expect("diagnose action", diagnose["action"], "rerun-transient")
    expect("diagnose reason", "diagnose mode" in diagnose["reason"], True)

    # 12. The harness build job failure is not attributed to a leg.
    evidence = make_evidence({}, build_failed=True)
    context = build_context(evidence, "fix", NOW)
    expect("harness class", context["failure_class"], "harness")
    expect("harness action", context["action"], "investigate")

    # 13. A successful run has nothing to triage.
    evidence = make_evidence({})
    evidence["run"]["conclusion"] = "success"
    expect("no failure", build_context(evidence, "fix", NOW)["action"], "no-failure")

    # 14. The signature ignores test order, and separates legs.
    one = make_leg(tests=[{"id": "a.one", "kind": "failure", "message": ""},
                          {"id": "a.two", "kind": "failure", "message": ""}])
    two = make_leg(tests=[{"id": "a.two", "kind": "failure", "message": ""},
                          {"id": "a.one", "kind": "failure", "message": ""}])
    expect("signature order", compute_signature({"stable/vanilla": one}),
           compute_signature({"stable/vanilla": two}))
    expect("signature legs", compute_signature({"stable/vanilla": one}) ==
           compute_signature({"experimental/vanilla": one}), False)

    # 15. Without a lock baseline the failure is still treated as a regression.
    no_baseline = make_leg(tests=[{"id": "a.one", "kind": "failure", "message": ""}])
    context = build_context(make_evidence({"stable/vanilla": no_baseline}), "fix", NOW)
    expect("no baseline class", context["failure_class"], "regression")
    expect("no baseline diff", context["legs"]["stable/vanilla"]["lock_diff"]["available"], False)

    # 16. A build-style failure inside a leg is classified as the harness.
    harness = make_leg(steps=["Install Git and Python"])
    expect("leg harness", build_context(make_evidence({"stable/vanilla": harness}), "fix", NOW)
           ["failure_class"], "harness")

    # 17. The context files are written and contain the marker.
    import tempfile
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        write_context(work, context)
        for name in ("context.json", "context.md", "summary.md", "issue.md", "triage.env"):
            if not (work / name).is_file():
                failures.append(f"output file {name} was not written")
        env = (work / "triage.env").read_text()
        if f"TRIAGE_SIGNATURE={context['signature']}" not in env:
            failures.append("triage.env does not contain the signature")

    # 18. With no test details, the log error keeps signatures distinct.
    crash_a = make_leg()
    crash_a["error_excerpt"] = "Failed to load mod Paracelsin: Missing required dependency A"
    crash_b = make_leg()
    crash_b["error_excerpt"] = "Failed to load mod Paracelsin: Missing required dependency B"
    expect(
        "error signature",
        compute_signature({"stable/planets": crash_a}) == compute_signature({"stable/planets": crash_b}),
        False,
    )
    excerpt = error_excerpt(
        "   0.000 Error Util.cpp:81: Failed to load mod \"Paracelsin\": \n"
        "\u2022 Missing required dependency Crystalline-Library\n"
        "\u2022 Missing required dependency Return-Inserter >= 1.0.1\n"
    )
    expect("error excerpt", "Missing required dependency Crystalline-Library" in excerpt, True)
    stable_a = make_leg()
    stable_a["error_excerpt"] = error_excerpt(
        " 0.041 Error Util.cpp:81: Failed to load mod\n"
        "\u2022 Missing required dependency A\n"
    )
    stable_b = make_leg()
    stable_b["error_excerpt"] = error_excerpt(
        " 0.038 Error Util.cpp:81: Failed to load mod\n"
        "\u2022 Missing required dependency A\n"
    )
    expect(
        "error signature stable",
        compute_signature({"stable/planets": stable_a})
        == compute_signature({"stable/planets": stable_b}),
        True,
    )

    # 19. Reproduction pins the lock only when one exists.
    without_lock = reproduction_lines({}, {"channel": "stable", "modset": "planets", "lock": None})
    expect("no lock reproduction", any("FUNIT_LOCK_FILE" in line for line in without_lock), False)
    with_lock = reproduction_lines(
        {}, {"channel": "stable", "modset": "planets", "lock": "/tmp/example-lock.json"}
    )
    expect(
        "lock reproduction",
        any("FUNIT_LOCK_FILE=/tmp/example-lock.json" in line for line in with_lock),
        True,
    )

    if failures:
        print("self-test FAILED:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1
    print("self-test passed (19 checks)")
    return 0


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--self-test", action="store_true", help="run the classifier self-test")
    subparsers = parser.add_subparsers(dest="command")

    collect_parser = subparsers.add_parser("collect", help="collect and classify a failed run")
    collect_parser.add_argument("--repo", required=True)
    collect_parser.add_argument("--run-id", required=True, type=int)
    collect_parser.add_argument("--work-dir", required=True, type=Path)
    collect_parser.add_argument("--mode", choices=("fix", "diagnose"), default="fix")

    report_parser = subparsers.add_parser("report", help="perform short-circuit GitHub actions")
    report_parser.add_argument("--repo", required=True)
    report_parser.add_argument("--work-dir", required=True, type=Path)

    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()
    if args.command == "collect":
        collect(args.repo, args.run_id, args.work_dir, args.mode)
        return 0
    if args.command == "report":
        report(args.repo, args.work_dir)
        return 0
    parser.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
