#!/usr/bin/env bash
# Smoke-test a dispatchable GitHub Actions workflow against an unmerged commit.
#
# `.github/workflows/opencode-bugfix.yml` is normally triggered by `issues` and
# `issue_comment` events, and those events always run the workflow from the
# default branch. To exercise a modified workflow, push the commit under test to
# a temporary branch and dispatch the workflow with `--ref <temp-branch>`.
#
# Usage:
#   tools/ci/workflow-test.sh --issue 462 [options]
#
# Options:
#   --issue N              Issue number to pass to the workflow (required).
#   --repo OWNER/REPO      Repository to dispatch against.
#                          Default: derived from the `origin` remote.
#   --workflow NAME        Workflow file name (or .github/workflows/ path).
#                          Default: opencode-bugfix.yml.
#   --ref REF              Git ref to test. Default: HEAD.
#   --branch NAME          Temporary remote branch name.
#                          Default: ci/opencode-test-<UTC timestamp>.
#   --dry-run              Print the git/gh commands without running them.
#   --wait                 Wait for the dispatched run to finish.
#   --delete-branch        Delete the temporary remote branch after the run
#                          completes. Implies waiting for completion.
#   -h, --help             Show this help.
#
# Environment:
#   RUN_LOOKUP_ATTEMPTS    Attempts to find the new run ID (default: 20).
#   RUN_LOOKUP_INTERVAL    Seconds between lookup attempts (default: 3).
#   WAIT_TIMEOUT           Max seconds to wait for a run (default: 7200).
#   WAIT_INTERVAL          Seconds between status polls (default: 15).
#
# Safety:
#   * Never pushes to main/master; the temporary branch is validated with
#     `git check-ref-format`.
#   * Refuses to reuse an existing remote branch and never force-pushes.
#   * Only deletes the remote branch when --delete-branch is given.
#   * --dry-run performs no mutation and makes no network calls.
#
# Exit status:
#   0  command completed (or, with --wait, the run succeeded).
#   1  run finished with a non-success conclusion, or a step failed.
#   2  usage error.

set -euo pipefail

PROG="$(basename "$0")"

RUN_LOOKUP_ATTEMPTS="${RUN_LOOKUP_ATTEMPTS:-20}"
RUN_LOOKUP_INTERVAL="${RUN_LOOKUP_INTERVAL:-3}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-7200}"
WAIT_INTERVAL="${WAIT_INTERVAL:-15}"

usage() {
  cat <<'EOF'
Smoke-test a dispatchable GitHub Actions workflow against an unmerged commit.

Usage:
  workflow-test.sh --issue N [--repo owner/repo] [--workflow opencode-bugfix.yml]
                   [--ref REF] [--branch NAME] [--dry-run] [--wait]
                   [--delete-branch] [--help]

Options:
  --issue N          Issue number passed to the workflow as `issue_number`.
                     Required.
  --repo OWNER/REPO  Repository to dispatch against.
                     Default: derived from the git `origin` remote.
  --workflow NAME    Workflow file name (a bare file name is resolved under
                     .github/workflows/). Default: opencode-bugfix.yml.
  --ref REF          Git ref to test. Default: HEAD.
  --branch NAME      Temporary remote branch to push the commit to.
                     Default: ci/opencode-test-<UTC timestamp>.
  --dry-run          Print the exact git/gh commands that would run and exit.
  --wait             Wait for the dispatched run to finish.
  --delete-branch    Delete the temporary remote branch after the run finishes.
                     Implies waiting for completion.
  -h, --help         Show this help.

Environment:
  RUN_LOOKUP_ATTEMPTS  Attempts to find the new run ID (default 20).
  RUN_LOOKUP_INTERVAL  Seconds between lookup attempts (default 3).
  WAIT_TIMEOUT         Max seconds to wait for a run (default 7200).
  WAIT_INTERVAL        Seconds between status polls (default 15).

Notes:
  * The commit is pushed with `git push origin <sha>:refs/heads/<branch>`.
  * `--dry-run` does not touch the network or the remote.
  * With `--wait`, the helper delegates to tools/ci/run-debug.sh when that
    script exists and is executable, and otherwise polls `gh run view`.
  * A wait that ends in a non-success conclusion exits 1.

Examples:
  # Show the plan and commands only.
  workflow-test.sh --issue 462 --dry-run

  # Dispatch from the current HEAD, then wait for the result.
  workflow-test.sh --issue 462 --wait

  # Dispatch a specific commit and clean up the temporary branch afterwards.
  workflow-test.sh --issue 462 --ref 1234abc --wait --delete-branch
EOF
}

die() {
  printf '%s: error: %s\n' "$PROG" "$*" >&2
  exit 1
}

usage_error() {
  printf '%s: error: %s\n' "$PROG" "$*" >&2
  printf "Try '%s --help'.\n" "$PROG" >&2
  exit 2
}

warn() {
  printf '%s: warning: %s\n' "$PROG" "$*" >&2
}

note() {
  printf '%s: %s\n' "$PROG" "$*"
}

# Print a shell-quoted command line, for --dry-run.
show_cmd() {
  local rendered
  rendered="$(printf '%q ' "$@")"
  printf '    %s\n' "${rendered% }"
}

require_uint() {
  local name="$1" value="$2" min="${3:-1}"
  [[ "$value" =~ ^[0-9]+$ ]] || usage_error "$name must be a non-negative integer (got: $value)"
  (( value >= min )) || usage_error "$name must be at least $min (got: $value)"
}

# --- argument parsing -------------------------------------------------------

issue=""
repo=""
workflow="opencode-bugfix.yml"
ref="HEAD"
branch=""
dry_run=0
wait=0
delete_branch=0

while (( $# > 0 )); do
  case "$1" in
    --issue)
      (( $# >= 2 )) || usage_error "--issue requires a value"
      issue="$2"; shift 2 ;;
    --issue=*)
      issue="${1#*=}"; shift ;;
    --repo)
      (( $# >= 2 )) || usage_error "--repo requires a value"
      repo="$2"; shift 2 ;;
    --repo=*)
      repo="${1#*=}"; shift ;;
    --workflow)
      (( $# >= 2 )) || usage_error "--workflow requires a value"
      workflow="$2"; shift 2 ;;
    --workflow=*)
      workflow="${1#*=}"; shift ;;
    --ref)
      (( $# >= 2 )) || usage_error "--ref requires a value"
      ref="$2"; shift 2 ;;
    --ref=*)
      ref="${1#*=}"; shift ;;
    --branch)
      (( $# >= 2 )) || usage_error "--branch requires a value"
      branch="$2"; shift 2 ;;
    --branch=*)
      branch="${1#*=}"; shift ;;
    --dry-run)
      dry_run=1; shift ;;
    --wait)
      wait=1; shift ;;
    --delete-branch)
      delete_branch=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    --)
      shift
      (( $# == 0 )) || usage_error "unexpected positional argument: $1"
      ;;
    -*)
      usage_error "unknown option: $1 (try --help)" ;;
    *)
      usage_error "unexpected positional argument: $1 (try --help)" ;;
  esac
done

[[ -n "$issue" ]] || { usage >&2; usage_error "--issue is required"; }
[[ "$issue" =~ ^[1-9][0-9]*$ ]] || usage_error "--issue must be a positive integer (got: $issue)"
[[ -n "$workflow" ]] || usage_error "--workflow must not be empty"
[[ -n "$ref" ]] || usage_error "--ref must not be empty"

require_uint RUN_LOOKUP_ATTEMPTS "$RUN_LOOKUP_ATTEMPTS"
require_uint RUN_LOOKUP_INTERVAL "$RUN_LOOKUP_INTERVAL" 0
require_uint WAIT_TIMEOUT "$WAIT_TIMEOUT"
require_uint WAIT_INTERVAL "$WAIT_INTERVAL" 0

# --- repository / git state -------------------------------------------------

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || die "not inside a git work tree"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || die "could not determine the git repository root"

sha="$(git rev-parse --verify --quiet "${ref}^{commit}" 2>/dev/null || true)"
[[ -n "$sha" ]] || die "could not resolve ref '${ref}' to a commit in ${repo_root}"
commit_subject="$(git log -1 --format=%s "$sha" 2>/dev/null || echo '(unknown)')"

if [[ -z "$repo" ]]; then
  origin_url="$(git config --get remote.origin.url 2>/dev/null || true)"
  case "$origin_url" in
    https://github.com/*|http://github.com/*)
      repo="${origin_url#*github.com/}" ;;
    git@github.com:*)
      repo="${origin_url#git@github.com:}" ;;
    ssh://git@github.com/*)
      repo="${origin_url#ssh://git@github.com/}" ;;
  esac
  repo="${repo%.git}"
  repo="${repo%/}"
fi
[[ -n "$repo" ]] || die "could not determine repository; pass --repo OWNER/REPO"
[[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] \
  || usage_error "--repo must look like OWNER/REPO (got: $repo)"

if [[ -z "$branch" ]]; then
  branch="ci/opencode-test-$(date -u +%Y%m%dT%H%M%SZ)"
fi

# Safety: never target the default branches.
case "${branch#refs/heads/}" in
  main|master)
    usage_error "refusing to push to '${branch}'; choose a temporary branch" ;;
esac
git check-ref-format --branch "${branch#refs/heads/}" >/dev/null 2>&1 \
  || usage_error "invalid branch name: ${branch} (see 'git check-ref-format --branch')"
[[ "$branch" != refs/heads/* ]] || branch="${branch#refs/heads/}"

# --- workflow validation ----------------------------------------------------

workflow_file="$(basename "$workflow")"
workflow_path=".github/workflows/${workflow_file}"
[[ "$workflow_path" == *.yml || "$workflow_path" == *.yaml ]] \
  || usage_error "--workflow must name a .yml/.yaml workflow file (got: $workflow)"

workflow_blob="$(git cat-file -p "${sha}:${workflow_path}" 2>/dev/null)" \
  || die "workflow file '${workflow_path}' does not exist at ${ref} (${sha}); push the workflow change first"

# A workflow is dispatchable when `workflow_dispatch` appears as a trigger.
# Ignore full-line comments to avoid matching documentation, and avoid
# `grep -q` in a pipeline because pipefail can report a SIGPIPE race.
if ! awk '!/^[[:space:]]*#/ && /workflow_dispatch/ { found = 1 } END { exit(found ? 0 : 1) }' \
  <<<"$workflow_blob"; then
  die "workflow '${workflow_path}' at ${ref} (${sha}) is not dispatchable: no workflow_dispatch trigger"
fi

if [[ "$dry_run" -eq 0 ]]; then
  command -v gh >/dev/null 2>&1 || die "gh CLI not found in PATH"
  gh auth status >/dev/null 2>&1 || die "gh is not authenticated; run 'gh auth login'"
fi

# --- plan -------------------------------------------------------------------

origin_repo=""
origin_url="$(git config --get remote.origin.url 2>/dev/null || true)"
case "$origin_url" in
  https://github.com/*|http://github.com/*) origin_repo="${origin_url#*github.com/}" ;;
  git@github.com:*) origin_repo="${origin_url#git@github.com:}" ;;
  ssh://git@github.com/*) origin_repo="${origin_url#ssh://git@github.com/}" ;;
esac
origin_repo="${origin_repo%.git}"
origin_repo="${origin_repo%/}"

printf '\nPlan:\n'
printf '  repository:      %s\n' "$repo"
printf '  workflow:        %s (%s)\n' "$workflow" "$workflow_path"
printf '  ref:             %s\n' "$ref"
printf '  commit:          %s %s\n' "$sha" "$commit_subject"
printf '  temp branch:     %s\n' "$branch"
printf '  issue number:    %s\n' "$issue"
printf '  wait:            %s\n' "$([[ "$wait" -eq 1 ]] && echo yes || echo no)"
printf '  delete branch:   %s\n' "$([[ "$delete_branch" -eq 1 ]] && echo yes || echo no)"
printf '\n'

if [[ -n "$origin_repo" && "$origin_repo" != "$repo" ]]; then
  warn "origin remote is '${origin_repo}' but --repo is '${repo}'; the commit is pushed to origin and dispatched against '${repo}'"
fi

if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null \
  || [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null | head -n 1)" ]]; then
  warn "working tree has uncommitted changes; only the committed tree at ${sha} is tested"
fi

if [[ "$delete_branch" -eq 1 && "$wait" -eq 0 ]]; then
  note "--delete-branch implies waiting for the run to finish before deleting the branch"
fi

# --- dry run ----------------------------------------------------------------

run_lookup_args=(
  gh run list
  --repo "$repo"
  --workflow "$workflow"
  --event workflow_dispatch
  --branch "$branch"
  --limit 5
  --json databaseId,headBranch,headSha,createdAt,status,conclusion,url
)
json_fields="databaseId,headBranch,headSha,createdAt,status,conclusion,url"
jq_filter=$(printf '[.[] | select(.headSha == "%s")] | sort_by(.createdAt) | last | if . == null then empty else "\\(.databaseId) \\(.url)" end' "$sha")

if [[ "$dry_run" -eq 1 ]]; then
  printf 'Dry run: the following commands would run, in order.\n\n'
  printf '  1. Push the commit to a temporary branch (no force):\n'
  show_cmd git push origin "${sha}:refs/heads/${branch}"
  printf '\n  2. Confirm the remote branch did not already exist before pushing:\n'
  show_cmd git ls-remote --heads origin "refs/heads/${branch}"
  printf '\n  3. Dispatch the workflow against the temporary branch:\n'
  show_cmd gh workflow run "$workflow" --repo "$repo" --ref "$branch" -f "issue_number=${issue}"
  printf '\n  4. Find the new run (poll, matching %s):\n' "$sha"
  printf '    gh run list --repo %s --workflow %s --event workflow_dispatch --branch %s --limit 5 --json %s --jq %s\n' \
    "$repo" "$workflow" "$branch" "$json_fields" "'${jq_filter}'"
  printf '    (repeat up to %s times, %ss apart)\n' "$RUN_LOOKUP_ATTEMPTS" "$RUN_LOOKUP_INTERVAL"
  if [[ "$wait" -eq 1 || "$delete_branch" -eq 1 ]]; then
    printf '\n  5. Wait for completion'
    if [[ -x "${repo_root}/tools/ci/run-debug.sh" ]]; then
      printf ' (via tools/ci/run-debug.sh):\n'
      printf '    tools/ci/run-debug.sh --run %s --wait\n' '<run-id>'
    else
      printf ' (poll with gh run view):\n'
      printf '    gh run view %s --repo %s --json status,conclusion,url\n' '<run-id>' "$repo"
    fi
  fi
  if [[ "$delete_branch" -eq 1 ]]; then
    printf '\n  6. Delete the temporary remote branch:\n'
    show_cmd git push origin --delete "refs/heads/${branch}"
  fi
  printf '\nDry run: nothing was pushed, dispatched, or deleted.\n'
  exit 0
fi

# --- execute ----------------------------------------------------------------

command -v git >/dev/null 2>&1 || die "git not found in PATH"
git remote get-url origin >/dev/null 2>&1 || die "no 'origin' remote configured"

existing="$(git ls-remote --heads origin "refs/heads/${branch}")" \
  || die "could not query origin for branch '${branch}'"
[[ -z "$existing" ]] \
  || die "remote branch '${branch}' already exists; choose another name with --branch"

printf 'Pushing %s to origin as %s...\n' "$sha" "$branch"
git push origin "${sha}:refs/heads/${branch}" \
  || die "failed to push commit ${sha} to origin/${branch}"

published=1
cleanup_on_error() {
  [[ "$published" -eq 1 ]] || return 0
  if [[ "$delete_branch" -eq 1 ]]; then
    printf '%s: removing temp branch origin/%s\n' "$PROG" "$branch" >&2
    if git push origin --delete "refs/heads/${branch}" >/dev/null 2>&1; then
      published=0
      return 0
    fi
  fi
  printf '%s: temp branch left in place: origin/%s\n' "$PROG" "$branch" >&2
  printf '%s: remove it with: git push origin --delete refs/heads/%s\n' "$PROG" "$branch" >&2
}

printf 'Dispatching %s against %s...\n' "$workflow" "$branch"
if ! dispatch_output="$(gh workflow run "$workflow" --repo "$repo" --ref "$branch" -f "issue_number=${issue}" 2>&1)"; then
  cleanup_on_error
  printf '%s\n' "$dispatch_output" >&2
  die "gh workflow run failed; is '${workflow}' dispatchable and does '${branch}' exist?"
fi
if [[ -n "$dispatch_output" ]]; then
  printf '%s\n' "$dispatch_output"
fi

run_id=""
run_url=""

printf 'Looking for the new workflow_dispatch run...\n'
for (( attempt = 1; attempt <= RUN_LOOKUP_ATTEMPTS; attempt++ )); do
  line="$("${run_lookup_args[@]}" --jq "$jq_filter" 2>/dev/null || true)"
  line="${line%%$'\n'*}"
  if [[ -n "$line" && "$line" != "null" ]]; then
    read -r run_id run_url <<<"$line" || true
    break
  fi
  if (( attempt < RUN_LOOKUP_ATTEMPTS )); then
    sleep "$RUN_LOOKUP_INTERVAL"
  fi
done

if [[ -z "$run_id" || "$run_id" == "null" ]]; then
  cleanup_on_error
  die "could not find a workflow_dispatch run for '${branch}' (sha ${sha}); check ${repo}/actions manually"
fi
[[ -n "$run_url" ]] || run_url="https://github.com/${repo}/actions/runs/${run_id}"

printf 'Run id:  %s\n' "$run_id"
printf 'Run URL: %s\n' "$run_url"

# --- wait -------------------------------------------------------------------

run_conclusion=""
run_finished=0

wait_for_run() {
  local id="$1" output status conclusion deadline

  if [[ -x "${repo_root}/tools/ci/run-debug.sh" ]]; then
    printf 'Waiting for run %s via tools/ci/run-debug.sh...\n' "$id"
    if "${repo_root}/tools/ci/run-debug.sh" --run "$id" --wait; then
      run_finished=1
      return 0
    fi
    # The delegated waiter exits non-zero for failed runs too; check whether the
    # run actually reached a conclusion before falling back to polling.
    output="$(gh run view "$id" --repo "$repo" --json status,conclusion \
      --jq '"\(.status) \(.conclusion // "none")"' 2>/dev/null || true)"
    read -r status conclusion <<<"${output:-unknown none}" || true
    if [[ "${status:-unknown}" == "completed" ]]; then
      run_conclusion="${conclusion:-none}"
      run_finished=1
      return 0
    fi
    warn "tools/ci/run-debug.sh did not finish run ${id}; falling back to gh polling"
  fi

  deadline=$(( SECONDS + WAIT_TIMEOUT ))
  while :; do
    output="$(gh run view "$id" --repo "$repo" --json status,conclusion,url \
      --jq '"\(.status) \(.conclusion // "none")"' 2>/dev/null || true)"
    read -r status conclusion <<<"${output:-unknown none}" || true
    case "${status:-unknown}" in
      completed) break ;;
    esac
    if (( SECONDS >= deadline )); then
      warn "timed out after ${WAIT_TIMEOUT}s waiting for run ${id} (last status: ${status:-unknown})"
      return 1
    fi
    sleep "$WAIT_INTERVAL"
  done
  run_conclusion="${conclusion:-none}"
  run_finished=1
  return 0
}

exit_code=0
if [[ "$wait" -eq 1 || "$delete_branch" -eq 1 ]]; then
  if ! wait_for_run "$run_id"; then
    exit_code=1
  fi

  # Give delegated waiters a chance to expose the conclusion.
  if [[ -z "$run_conclusion" ]]; then
    run_conclusion="$(gh run view "$run_id" --repo "$repo" --json conclusion \
      --jq '.conclusion // "none"' 2>/dev/null || echo 'unknown')"
  fi

  printf '\nFinal status: run %s finished with conclusion: %s\n' "$run_id" "${run_conclusion:-unknown}"
  if [[ "${run_conclusion:-none}" == "success" ]]; then
    exit_code=0
  elif [[ "$exit_code" -eq 0 ]]; then
    exit_code=1
  fi
fi

# --- optional branch cleanup ------------------------------------------------

if [[ "$delete_branch" -eq 1 ]]; then
  if [[ "$run_finished" -ne 1 ]]; then
    warn "not deleting origin/${branch}: run ${run_id} did not finish"
    warn "delete it later with: git push origin --delete refs/heads/${branch}"
  else
    case "$branch" in
      main|master) die "refusing to delete '${branch}'" ;;
    esac
    printf 'Deleting temporary remote branch origin/%s...\n' "$branch"
    if git push origin --delete "refs/heads/${branch}"; then
      published=0
    else
      warn "failed to delete origin/${branch}; delete it manually with: git push origin --delete refs/heads/${branch}"
      exit_code=1
    fi
  fi
fi

exit "$exit_code"
