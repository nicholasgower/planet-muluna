#!/usr/bin/env bash
#
# run-debug.sh - inspect GitHub Actions runs for the planet-muluna repo.
#
# GitHub only serves `gh run view --log` for runs that have finished, so this
# helper exists to (a) show what is happening in a live run via the jobs API,
# (b) optionally wait for completion, and (c) pull and filter the logs once the
# run is done. The only mutating operation is --cancel, and it must be asked for
# explicitly.
#
# All output is plain text so it is safe to paste into CI logs. Temp files are
# created with mode 0600 and removed on exit.

set -euo pipefail

PROG="${0##*/}"

# Plain, non-interactive output: safe to redirect into a CI log, never paged,
# never colorized.
export NO_COLOR=1
export GH_PAGER=cat

# Evidence worth surfacing by default when triaging the bugfix workflow.
DEFAULT_GREP='agent:|permission:|action: "ask"|error|failed|Created PR|issuecomment|workflow_dispatch'

POLL_INTERVAL=15        # seconds between status checks while --wait is active
MAX_POLL_FAILURES=5     # consecutive API failures tolerated before giving up
MAX_LINE_LEN=600        # filtered log lines longer than this are truncated

REPO=""
WORKFLOW=""
RUN_ID=""
LIMIT=10
WAIT=0
TIMEOUT=900
GREP="$DEFAULT_GREP"
GREP_SET=0
FULL=0
EXIT_CODE=0
MODE=""

TMP_LOG=""
TMP_ERR=""

usage() {
  cat <<EOF
Usage:
  $PROG [--repo owner/repo] --workflow <name-or-file> [--latest] [--limit N]
  $PROG [--repo owner/repo] --run <run-id> [--wait] [--timeout SECONDS] [--grep REGEX] [--full] [--exit-code]
  $PROG [--repo owner/repo] --cancel <run-id>
  $PROG --help

Modes:
  --workflow NAME|FILE  Workflow name (e.g. "Opencode Bugfix") or file
                        (e.g. opencode-bugfix.yml). Requires --latest or is
                        implied: lists the most recent runs.
  --latest              List recent runs: id, status, conclusion, event, short
                        head SHA, display title, URL.
  --run ID              Show a compact job/step summary for one run and filter
                        its logs once the run has completed.
  --cancel ID           Cancel a run. This is the only mutating operation and
                        is never implied by another flag.

Options:
  --repo OWNER/REPO     Target repository. Defaults to
                        \`gh repo view --json nameWithOwner\`, then the origin
                        remote.
  --limit N             Number of runs to list with --latest (default: 10).
  --wait                With --run: poll every ${POLL_INTERVAL}s until the run completes.
  --timeout SECONDS     With --wait: give up after this long (default: ${TIMEOUT}).
  --grep REGEX          With --run: case-insensitive extended regex used to
                        filter logs. Replaces the default filter:
                          $DEFAULT_GREP
                        Filtered lines longer than ${MAX_LINE_LEN} characters are truncated;
                        combine with --full to see complete lines.
  --full                With --run: print the entire log, no filtering.
  --exit-code           With --run: exit 3 when the run did not conclude
                        "success". Reporting still happens first.
  -h, --help            Show this help and exit.

Exit status:
  0  success (the run itself may have failed; see the printed conclusion)
  1  runtime error (gh missing, not authenticated, log unavailable, timeout)
  2  usage error
  3  --exit-code was given and the run concluded anything but success

Examples:
  $PROG --workflow opencode-bugfix.yml --latest --limit 3
  $PROG --run 123456789 --wait --timeout 1200
  $PROG --run 123456789 --grep 'permission:|action: "ask"'
  $PROG --run 123456789 --full
  $PROG --cancel 123456789
EOF
}

say()  { printf '%s\n' "$*"; }
warn() { printf '%s: warning: %s\n' "$PROG" "$*" >&2; }
die()  { printf '%s: error: %s\n' "$PROG" "$*" >&2; exit 1; }
usage_error() { printf '%s: error: %s\n' "$PROG" "$*" >&2; printf "Try '%s --help'.\n" "$PROG" >&2; exit 2; }

cleanup() {
  if [ -n "$TMP_LOG" ]; then rm -f -- "$TMP_LOG"; fi
  if [ -n "$TMP_ERR" ]; then rm -f -- "$TMP_ERR"; fi
  return 0
}
trap cleanup EXIT INT TERM

need_value() {
  # need_value <flag> <remaining-args-count>
  if [ "$2" -lt 2 ]; then
    usage_error "$1 requires a value"
  fi
}

is_positive_int() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    0) return 1 ;;
  esac
  return 0
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------- arg parsing

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --repo)
      need_value "$1" "$#"
      REPO="$2"; shift 2
      ;;
    --repo=*)
      REPO="${1#*=}"; shift
      ;;
    --workflow)
      need_value "$1" "$#"
      WORKFLOW="$2"; shift 2
      ;;
    --workflow=*)
      WORKFLOW="${1#*=}"; shift
      ;;
    --latest)
      [ -z "$MODE" ] || [ "$MODE" = "latest" ] || usage_error "--latest cannot be combined with --$MODE"
      MODE="latest"; shift
      ;;
    --run)
      need_value "$1" "$#"
      [ -z "$MODE" ] || [ "$MODE" = "run" ] || usage_error "--run cannot be combined with --$MODE"
      MODE="run"; RUN_ID="$2"; shift 2
      ;;
    --run=*)
      [ -z "$MODE" ] || [ "$MODE" = "run" ] || usage_error "--run cannot be combined with --$MODE"
      MODE="run"; RUN_ID="${1#*=}"; shift
      ;;
    --cancel)
      need_value "$1" "$#"
      [ -z "$MODE" ] || [ "$MODE" = "cancel" ] || usage_error "--cancel cannot be combined with --$MODE"
      MODE="cancel"; RUN_ID="$2"; shift 2
      ;;
    --cancel=*)
      [ -z "$MODE" ] || [ "$MODE" = "cancel" ] || usage_error "--cancel cannot be combined with --$MODE"
      MODE="cancel"; RUN_ID="${1#*=}"; shift
      ;;
    --limit)
      need_value "$1" "$#"
      LIMIT="$2"; shift 2
      ;;
    --limit=*)
      LIMIT="${1#*=}"; shift
      ;;
    --wait)
      WAIT=1; shift
      ;;
    --timeout)
      need_value "$1" "$#"
      TIMEOUT="$2"; shift 2
      ;;
    --timeout=*)
      TIMEOUT="${1#*=}"; shift
      ;;
    --grep)
      need_value "$1" "$#"
      GREP="$2"; GREP_SET=1; shift 2
      ;;
    --grep=*)
      GREP="${1#*=}"; GREP_SET=1; shift
      ;;
    --full)
      FULL=1; shift
      ;;
    --exit-code)
      EXIT_CODE=1; shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      usage_error "unknown option: $1"
      ;;
    *)
      usage_error "unexpected argument: $1"
      ;;
  esac
done

# --full and --grep together is contradictory; --full wins but say so.
if [ "$FULL" -eq 1 ] && [ "$GREP_SET" -eq 1 ]; then
  warn "--grep is ignored because --full was given"
fi

# A workflow without an explicit mode means "list its latest runs".
if [ -z "$MODE" ] && [ -n "$WORKFLOW" ]; then
  MODE="latest"
fi

if [ -z "$MODE" ]; then
  usage_error "one of --workflow, --run, or --cancel is required"
fi

case "$MODE" in
  latest)
    [ -n "$WORKFLOW" ] || usage_error "--latest requires --workflow <name-or-file>"
    [ -z "$RUN_ID" ] || usage_error "--latest does not take a run id"
    [ "$FULL" -eq 0 ] || usage_error "--full only applies to --run"
    [ "$WAIT" -eq 0 ] || usage_error "--wait only applies to --run"
    [ "$EXIT_CODE" -eq 0 ] || usage_error "--exit-code only applies to --run"
    [ "$GREP_SET" -eq 0 ] || usage_error "--grep only applies to --run"
    is_positive_int "$LIMIT" || usage_error "--limit must be a positive integer (got: $LIMIT)"
    ;;
  run)
    [ -n "$RUN_ID" ] || usage_error "--run requires a run id"
    [ -z "$WORKFLOW" ] || usage_error "--workflow cannot be combined with --run"
    is_positive_int "$RUN_ID" || usage_error "--run expects a numeric run id (got: $RUN_ID)"
    is_positive_int "$TIMEOUT" || usage_error "--timeout must be a positive integer number of seconds (got: $TIMEOUT)"
    if [ "$FULL" -eq 0 ] && [ -n "$GREP" ]; then
      # Reject a regex that grep cannot parse, before spending time on a download.
      set +e
      printf '' | grep -Eq -- "$GREP" 2>/dev/null
      grep_rc=$?
      set -e
      if [ "$grep_rc" -gt 1 ]; then
        usage_error "invalid --grep regular expression: $GREP"
      fi
    fi
    ;;
  cancel)
    [ -n "$RUN_ID" ] || usage_error "--cancel requires a run id"
    [ -z "$WORKFLOW" ] || usage_error "--workflow cannot be combined with --cancel"
    is_positive_int "$RUN_ID" || usage_error "--cancel expects a numeric run id (got: $RUN_ID)"
    [ "$WAIT" -eq 0 ] || usage_error "--wait does not apply to --cancel"
    [ "$FULL" -eq 0 ] || usage_error "--full does not apply to --cancel"
    [ "$GREP_SET" -eq 0 ] || usage_error "--grep does not apply to --cancel"
    [ "$EXIT_CODE" -eq 0 ] || usage_error "--exit-code does not apply to --cancel"
    ;;
  *)
    usage_error "unknown mode: $MODE"
    ;;
esac

# ------------------------------------------------------------ environment prep

if ! require_cmd gh; then
  die "the GitHub CLI (gh) is not installed or not on PATH. Install it from https://cli.github.com/ and run 'gh auth login'."
fi

if ! gh auth status -h github.com >/dev/null 2>&1; then
  die "gh is not authenticated for github.com. Run 'gh auth login -h github.com' or export GH_TOKEN with 'repo' and 'workflow' scopes."
fi

# gh auth status reports stored accounts, so an invalid env token can slip past
# it; verify the token that will actually be used.
if [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; then
  if ! gh api user -q .login >/dev/null 2>&1; then
    die "the GH_TOKEN/GITHUB_TOKEN in this environment is not accepted by github.com. Unset it or replace it with a valid token that has 'repo' and 'workflow' scopes."
  fi
fi

resolve_repo() {
  local name url

  name="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  if [ -n "$name" ]; then
    printf '%s\n' "$name"
    return 0
  fi

  url="$(git config --get remote.origin.url 2>/dev/null || true)"
  if [ -n "$url" ]; then
    # https://github.com/owner/repo.git  |  git@github.com:owner/repo.git
    case "$url" in
      *github.com[:/]*/*)
        name="$(printf '%s' "${url%.git}" | sed -E 's#^.*github\.com[:/]##')"
        printf '%s\n' "$name"
        return 0
        ;;
    esac
  fi

  return 1
}

if [ -z "$REPO" ]; then
  REPO="$(resolve_repo || true)"
  [ -n "$REPO" ] || die "could not determine the repository. Pass --repo owner/repo (or run this inside a clone with an origin remote)."
fi

case "$REPO" in
  */*) ;;
  *) usage_error "--repo must be in owner/repo form (got: $REPO)" ;;
esac
case "$REPO" in
  */*/*) usage_error "--repo must be in owner/repo form (got: $REPO)" ;;
esac
case "$REPO" in
  /*|*/) usage_error "--repo must be in owner/repo form (got: $REPO)" ;;
esac

# gh api needs the repo to exist and to be readable with the current token.
if ! gh api "repos/$REPO" -q .full_name >/dev/null 2>&1; then
  die "cannot access repos/$REPO with the current gh token. Check the spelling, that your account can read the repository, and that the token has the 'repo' scope (run 'gh auth status')."
fi

# ------------------------------------------------------------------- helpers

api_get() {
  # api_get <path> <jq-filter>
  gh api "$1" -q "$2"
}

run_field() {
  # run_field <run-id> <jq-filter>
  api_get "repos/$REPO/actions/runs/$1" "$2"
}

run_status() {
  run_field "$1" '.status'
}

run_conclusion() {
  run_field "$1" '(.conclusion // "-")'
}

# ---------------------------------------------------------------- --latest

list_runs() {
  local out

  say "Repository: $REPO"
  say "Workflow:   $WORKFLOW"
  say ""

  out="$(
    gh run list \
      --repo "$REPO" \
      --workflow "$WORKFLOW" \
      --limit "$LIMIT" \
      --json databaseId,status,conclusion,event,headSha,displayTitle,url,createdAt \
      -q '.[] | [
            (.databaseId|tostring),
            .status,
            (.conclusion // "-"),
            .event,
            ((.headSha // "")[0:7]),
            ((.displayTitle // "") | gsub("[\t\n\r]"; " ")),
            .url
          ] | @tsv' 2>/dev/null
  )" || die "could not list runs for workflow '$WORKFLOW'. Check the workflow name or file (gh accepts either, e.g. 'Opencode Bugfix' or 'opencode-bugfix.yml')."

  if [ -z "$out" ]; then
    say "No runs found for workflow '$WORKFLOW'."
    say "Hint: workflow names and file names are both accepted; confirm with 'gh workflow list --repo $REPO'."
    return 0
  fi

  # Fixed-width columns keep the table readable without depending on `column`.
  { printf 'ID\tSTATUS\tCONCLUSION\tEVENT\tSHA\tTITLE\tURL\n'; printf '%s\n' "$out"; } | awk -F'\t' '
    NR == 1 {
      printf "%-12s %-10s %-11s %-19s %-8s %-50s %s\n", $1, $2, $3, $4, $5, $6, $7
      next
    }
    {
      title = $6
      if (length(title) > 50) title = substr(title, 1, 47) "..."
      printf "%-12s %-10s %-11s %-19s %-8s %-50s %s\n", $1, $2, $3, $4, $5, title, $7
    }
  '

  say ""
  say "Logs are only available once a run has completed. Use:"
  say "  $PROG --repo $REPO --run <ID> [--wait] [--grep REGEX|--full]"
  return 0
}

# ------------------------------------------------------------ --run summary

print_run_summary() {
  local id="$1" meta

  meta="$(run_field "$id" '[
      (.name // "(unnamed workflow)"),
      (.display_title // ""),
      (.event // "-"),
      (.head_branch // "-"),
      ((.head_sha // "")[0:7]),
      .status,
      (.conclusion // "-"),
      (.html_url // ""),
      (.run_attempt // 1 | tostring),
      (.created_at // "-")
    ] | @tsv')" || die "could not read run $id in $REPO. Check the id (gh run list shows them)."

  IFS=$'\t' read -r wf_name wf_title wf_event wf_branch wf_sha wf_status wf_conclusion wf_url wf_attempt wf_created <<<"$meta"

  say "Run $id - $wf_name"
  if [ -n "$wf_title" ]; then say "  title:      $wf_title"; fi
  say "  event:      $wf_event"
  say "  branch:     $wf_branch  sha: $wf_sha"
  say "  status:     $wf_status  conclusion: $wf_conclusion"
  say "  attempt:    $wf_attempt"
  say "  created:    $wf_created"
  say "  url:        $wf_url"

  say ""
  say "Jobs:"
  # --paginate applies the filter per page and concatenates, which needs no
  # external jq and works on gh versions without --slurp. Steps arrive inline.
  local jobs_out
  jobs_out="$(
    gh api --paginate "repos/$REPO/actions/runs/$id/jobs?per_page=100" -q '
      .jobs[] |
        (["JOB", .name, .status, (.conclusion // "-"), (.id|tostring),
          ((.started_at // "-") + " -> " + (.completed_at // "-"))] | @tsv),
        (.steps[]? | ["STEP", .name, .status, (.conclusion // "-"), "", ""] | @tsv)
    ' 2>/dev/null
  )" || die "could not read jobs for run $id. Check that the id belongs to a workflow run in $REPO."

  if [ -z "$jobs_out" ]; then
    say "  (no jobs reported yet; the run may still be queued)"
  else
    local kind name state conclusion jid times
    while IFS=$'\t' read -r kind name state conclusion jid times; do
      case "$kind" in
        JOB)
          say "  $name [$state/$conclusion] id=$jid"
          say "      $times"
          ;;
        STEP)
          say "      STEP [$conclusion] $name"
          ;;
      esac
    done <<<"$jobs_out"
  fi

  say ""
  say "Result: $wf_status/$wf_conclusion"
}

# ------------------------------------------------------------- --run waiting

wait_for_run() {
  local id="$1" deadline now status rc failures=0

  deadline=$(( $(date +%s) + TIMEOUT ))
  say "Waiting for run $id to complete (timeout ${TIMEOUT}s, polling every ${POLL_INTERVAL}s)..."

  while :; do
    set +e
    status="$(run_status "$id" 2>/dev/null)"
    rc=$?
    set -e

    if [ "$rc" -ne 0 ] || [ -z "$status" ]; then
      failures=$((failures + 1))
      if [ "$failures" -ge "$MAX_POLL_FAILURES" ]; then
        die "could not read the status of run $id after $failures attempts. Check network access and gh auth."
      fi
      warn "status check failed ($failures/$MAX_POLL_FAILURES); retrying"
    else
      failures=0
      if [ "$status" = "completed" ]; then
        say "Run $id completed."
        return 0
      fi
      say "  $(date -u '+%H:%M:%SZ') status: $status"
    fi

    now=$(date +%s)
    if [ "$now" -ge "$deadline" ]; then
      return 1
    fi
    # Do not oversleep past the deadline.
    if [ $((deadline - now)) -lt "$POLL_INTERVAL" ]; then
      sleep $((deadline - now))
    else
      sleep "$POLL_INTERVAL"
    fi
  done
}

# ---------------------------------------------------------------- --run logs

fetch_and_filter_logs() {
  local id="$1" total matched

  TMP_LOG="$(mktemp "${TMPDIR:-/tmp}/run-debug-log.XXXXXX")"
  TMP_ERR="$(mktemp "${TMPDIR:-/tmp}/run-debug-err.XXXXXX")"
  chmod 600 "$TMP_LOG" "$TMP_ERR" 2>/dev/null || true

  say ""
  say "Downloading logs for run $id ..."
  if ! gh run view "$id" --repo "$REPO" --log >"$TMP_LOG" 2>"$TMP_ERR"; then
    local reason
    reason="$(tr '\n' ' ' <"$TMP_ERR" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
    if [ -n "$reason" ]; then warn "$reason"; fi
    die "could not download logs for run $id. GitHub only serves logs for completed runs; wait for it with --wait. Logs can also be expired or purged (90 days by default)."
  fi

  total=$(wc -l <"$TMP_LOG" | tr -d '[:space:]')
  if [ "$total" -eq 0 ]; then
    say "The log for run $id is empty (no output was produced)."
    return 0
  fi

  if [ "$FULL" -eq 1 ]; then
    say "=== full log, $total lines ==="
    cat "$TMP_LOG"
    return 0
  fi

  matched="$(grep -Eic -- "$GREP" "$TMP_LOG" 2>/dev/null || true)"
  if [ -z "$matched" ]; then matched=0; fi

  say "=== filtered log (regex: $GREP) ==="
  if [ "${matched:-0}" -eq 0 ]; then
    say "No matching lines in $total lines of log."
    say "Try a broader pattern with --grep REGEX, or print everything with --full."
    return 0
  fi

  say "--- $matched matching line(s) out of $total ---"
  # grep -n keeps it obvious that lines are filtered, and preserves job/step
  # prefixes that gh writes to the first columns. Very long lines (issue JSON
  # payloads, minified output) are truncated so CI logs stay readable; --full
  # prints them intact.
  set +e
  grep -Ein -- "$GREP" "$TMP_LOG" | awk -v max="$MAX_LINE_LEN" '
    {
      if (length($0) > max) {
        printf "%s ... [truncated, %d chars total]\n", substr($0, 1, max), length($0)
      } else {
        print
      }
    }
  '
  set -e

  # Also surface the failing step names, which are easy to miss in raw logs.
  local failed_steps
  failed_steps="$(grep -Ei -- 'Process completed with exit code|Error:|##\[error\]' "$TMP_LOG" | head -n 20 || true)"
  if [ -n "$failed_steps" ]; then
    say ""
    say "--- first error-ish lines ---"
    printf '%s\n' "$failed_steps"
  fi

  return 0
}

# ----------------------------------------------------------------- --cancel

cancel_run() {
  local id="$1" status conclusion

  status="$(run_status "$id")" || die "could not read run $id in $REPO."
  conclusion="$(run_conclusion "$id" 2>/dev/null || true)"

  if [ "$status" = "completed" ]; then
    say "Run $id is already completed (conclusion: ${conclusion:-unknown}); refusing to cancel."
    say "Nothing was changed."
    return 0
  fi

  say "Cancelling run $id in $REPO (status was: $status) ..."
  if ! gh run cancel "$id" --repo "$REPO"; then
    die "gh run cancel failed for run $id. You may lack permission to cancel it."
  fi

  local i
  for i in 1 2 3 4 5 6 7 8; do
    sleep 5
    status="$(run_status "$id" 2>/dev/null || true)"
    say "  status: $status"
    if [ "$status" = "completed" ]; then
      say "Run $id cancelled (conclusion: $(run_conclusion "$id" 2>/dev/null || printf '-'))."
      return 0
    fi
  done

  say "Cancel requested for run $id; it has not reported completion yet."
  say "Check with: $PROG --repo $REPO --run $id"
  return 0
}

# -------------------------------------------------------------------- dispatch

case "$MODE" in
  latest)
    list_runs
    ;;
  run)
    initial_status="$(run_status "$RUN_ID")" || die "could not read run $RUN_ID in $REPO. Check the id (gh run list shows them)."
    print_run_summary "$RUN_ID"

    if [ "$WAIT" -eq 1 ]; then
      if [ "$initial_status" = "completed" ]; then
        say "Run $RUN_ID is already completed; nothing to wait for."
      else
        if ! wait_for_run "$RUN_ID"; then
          say ""
          die "timed out after ${TIMEOUT}s waiting for run $RUN_ID (status still $(run_status "$RUN_ID" 2>/dev/null || printf 'unknown')). Re-run with a larger --timeout, or inspect it live at $(run_field "$RUN_ID" '.html_url' 2>/dev/null || printf 'the Actions tab')."
        fi
        # Refresh the summary so the conclusion shown matches the log below.
        say ""
        print_run_summary "$RUN_ID"
      fi
    elif [ "$initial_status" != "completed" ]; then
      say ""
      die "run $RUN_ID is still in progress; GitHub does not serve logs for live runs. Re-run with --wait (optionally --timeout SECONDS)."
    fi

    fetch_and_filter_logs "$RUN_ID"

    if [ "$EXIT_CODE" -eq 1 ]; then
      conclusion="$(run_conclusion "$RUN_ID" 2>/dev/null || true)"
      if [ "${conclusion:-}" != "success" ]; then
        say ""
        say "Run $RUN_ID concluded '${conclusion:-unknown}', not 'success'."
        exit 3
      fi
    fi
    ;;
  cancel)
    cancel_run "$RUN_ID"
    ;;
esac
