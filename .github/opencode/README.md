# Automated triage

Two OpenCode workflows act on failures without a human in the loop, and both
only ever propose a pull request that a human still reviews:

| Workflow | Trigger | Agent | Reacts to |
| --- | --- | --- | --- |
| `opencode-bugfix.yml` | New or reopened issue, `/opencode fix`, manual dispatch | `issue-bugfix` | A reported, reproducible crash or minor gameplay bug |
| `opencode-ci-triage.yml` | A failed `FUnit` run on `main` (push or weekly schedule), manual dispatch | `ci-triage` | A red test suite, including failures caused by an external mod or a new Factorio build |

## Automated issue triage

`opencode-bugfix.yml` runs the OpenCode `issue-bugfix` agent on every newly
opened or reopened GitHub issue, and on demand for existing issues. The agent
follows `.github/opencode/bugfix-prompt.md` and `AGENTS.md`:

| Issue type | Action |
| --- | --- |
| Feature request / enhancement | Add the `enhancement` label, comment, **no pull request** |
| Crash report | Add a failing FUnit regression test, confirm it fails, fix the crash, confirm the full suite passes, open a pull request |
| Minor, reproducible gameplay bug | Reproduce it with a failing FUnit test or a deterministic data probe, fix it, confirm the suite passes, open a pull request |
| Anything else | Comment with findings or a request for reproduction details, **no pull request** |

A gameplay bug is in scope only when the report contains concrete reproduction
steps and an expected result, the cause is local and minor, and the corrected
behavior can be verified in the headless harness. Balance changes, new
features, and reports that cannot be reproduced are left to a human maintainer.

The pull request format is the review-oriented PlanetsLib PR #130 format
documented under "Pull requests and AI-generated bugfixes" in `AGENTS.md`.
Automated pull requests are proposals and still need a human review.

## Manual runs

To run the bot on an existing issue, a repository owner, member, or collaborator
comments:

```text
/opencode fix
```

or `/oc fix`. A bare `/opencode` is deliberately not enough, so ordinary
comments cannot trigger an expensive run. The issue must be open, and the
commenter must be a repository owner, member, or collaborator. The agent
re-reads the issue, checks for an existing PR or an already-fixed bug, and then
follows the same workflow.

You can also run **Opencode Bugfix** from the Actions tab
(`workflow_dispatch`) and provide the issue number.

## Required secrets and variables

| Name | Kind | Purpose |
| --- | --- | --- |
| `FACTORIO_PLAYER_TOKEN` | secret | A **player token** from the Factorio client's `player-data.json`. The mod-portal upload key (`FACTORIO_TOKEN`) cannot download mods. |
| `OPENCODE_API_KEY` | secret | API key for the provider used by the model. The default model is `opencode-go/deepseek-v4.1-flash`. If you use another provider, add its key (`ANTHROPIC_API_KEY`, `OPENCODE_ZEN_API_KEY`, ...). |
| `OPENCODE_MODEL` | variable (optional) | Overrides the model, in `provider/model` form. |
| `FACTORIO_VERSION` | variable (optional) | Factorio version to download, or `latest` (default). |
| `FACTORIO_USERNAME` | variable (optional) | Mod-portal username for downloads. Defaults to `MeteorSwarm`. |

The workflow uses `GITHUB_TOKEN` (with `contents: write`, `issues: write`, and
`pull-requests: write`) instead of the OpenCode GitHub App OIDC exchange, so no
app installation is required. `opencode-ci-triage.yml` reuses the same secrets,
plus `actions: write` so it can retry a transient failure, and creates the
`automated-regression` label on first use.

The run executes the OpenCode CLI directly
(`opencode run --agent issue-bugfix --auto`) rather than the
`anomalyco/opencode/github` action. In OpenCode 1.19.x the action's `agent`
input is not applied by `opencode github run`; it falls back to the `build`
agent, whose `bash` permission is `ask` and therefore hangs a headless run.
Running the CLI directly also guarantees the bugfix agent's system prompt and
permissions are used. `--auto` approves any remaining asks; the agent's
explicit deny rules still apply.

## How the runner is prepared

`.github/opencode/setup-factorio.sh` runs before OpenCode and:

1. downloads the public headless Factorio tarball for `latest` (the newest
   experimental build, matching the experimental leg of the `FUnit` workflow's
   `factoriotools/factorio` matrix) and extracts it under
   `$RUNNER_TEMP/muluna-opencode/factorio-<release>`. Set `FACTORIO_VERSION=stable`
   to use the newest stable build instead; each release keeps its own install so
   a single job can reproduce a stable leg and an experimental leg;
2. downloads every required and recommended dependency from the mod portal using
   `.github/funit/download_mods.py`, so versions stay in sync with `info.json`.
   `FUNIT_MODSET` selects the mod set and `FUNIT_LOCK_FILE` pins the exact
   releases a recorded run used;
3. packages the pinned `funit` revision that `.github/workflows/funit.yml` uses.

`FUNIT_MODS_DIR` points the download at a dedicated directory. A regression run
uses one directory per failing leg, because two legs can pin different versions
of the same mod.

It exports `FACTORIO_BIN` and `FACTORIO_MODS`, which
`test-mods/planet-muluna-funit/run.sh` already understands. The workflow runs the
suite once before OpenCode starts to verify the harness, then the agent runs it
again while reproducing and fixing the issue.

## Running locally

Reuse an existing install and mod directory by exporting both variables:

```sh
FACTORIO_BIN=/path/to/factorio/bin/x64/factorio \
FACTORIO_MODS=/path/to/mods \
./.github/opencode/setup-factorio.sh   # no-op, prints the paths
```

Or let the script prepare everything (requires a player token):

```sh
FACTORIO_PLAYER_TOKEN=... ./.github/opencode/setup-factorio.sh
./test-mods/planet-muluna-funit/run.sh
```

Both scripts have `#!/usr/bin/env bash` shebangs and use bash-only features;
GitHub-hosted Ubuntu runners include bash. Invoke them directly rather than
through POSIX `sh`.

To exercise the agent itself, run OpenCode locally with the same agent and point
it at an issue, or re-run the GitHub Actions workflow for a past `issues` event.

## Automated regression triage

`opencode-ci-triage.yml` reacts to a failed `FUnit` run on `main`, from a push or
the weekly schedule. It is a separate workflow from the issue bot because the
evidence is different: there is no reporter, and the failure may be caused by a
dependency that published a new release rather than by a commit.

`.github/opencode/ci-context.py` does the deterministic triage before any model
runs. It downloads the failing legs' JUnit reports, logs and dependency locks,
compares the locks with the last green `main` run, and decides:

| Evidence | Class | Action |
| --- | --- | --- |
| Portal 5xx / network / download timeout on the download or setup step | `transient` | Rerun the failed jobs once |
| `Build test artifacts` or an infrastructure step failed | `harness` | Investigate the harness |
| Same mod versions and Factorio build as the last green run | `regression` | Investigate |
| Mod versions differ | `drift` | Investigate |
| Only the Factorio build differs | `upstream` | Investigate |
| A newer green `main` run exists | — | Drop silently |
| An open PR/issue carries the same `CI-Regression:` signature | — | Comment on it |
| A merged fix for the signature is newer than 14 days | — | Open/comment on an issue instead |
| A human closed the automated fix less than 30 days ago | — | Do not retry |
| Two automated regression PRs are already open | — | Comment on the tracking issue |

A real, new failure goes to the `ci-triage` agent, whose prompt is
`.github/opencode/ci-triage-prompt.md`. It reproduces the failing leg against the
lock file the run recorded, adds coverage that fails without the fix, fixes the
cause, and opens one pull request labeled `automated-regression` with a
`CI-Regression: <signature>` line at the top of the body. Every pull request is a
proposal and still needs a human review.

The triage context (classification, failing tests, dependency diff, logs,
reproduction commands) is uploaded as the `ci-triage` artifact and summarized in
the job summary. Workflow changes are denied to the agent by `opencode.json`: a
failure that needs a different matrix or workflow must be reported by a human.

### Manual runs

Run **Opencode CI Triage** from the Actions tab with `run_id` set to a past
`FUnit` run and `mode=diagnose` (the default) to classify without touching
GitHub or running the agent. Use `mode=fix` to allow a pull request. The same
`collect` and `report` subcommands work locally:

```sh
GH_TOKEN=... python3 .github/opencode/ci-context.py collect \
  --repo nicholasgower/planet-muluna --run-id <id> \
  --work-dir /tmp/opencode/ci-triage --mode diagnose
python3 .github/opencode/ci-context.py --self-test
```

### Dependency locks

Every FUnit leg uploads `funit-lock-<channel>-<modset>.json` inside its test
artifact. It records the Factorio build and every resolved mod release with its
`sha256`, which is what lets the triage tell a regression from drift and lets the
agent reproduce a failure exactly:

```sh
FUNIT_MODS_DIR=/tmp/opencode/ci-triage/mods-stable-planets \
FUNIT_MODSET=planets FACTORIO_VERSION=stable \
FUNIT_LOCK_FILE=/path/to/funit-lock-stable-planets.json \
  ./.github/opencode/setup-factorio.sh
```

The locks are not yet used to pin pull request runs; that policy decision is
open, and the recorded files are what make it cheap to adopt.

## Security notes

- Issue titles, bodies, comments, logs and attachments are **untrusted**. The
  agent prompt treats them as data and forbids following instructions embedded
  in them.
- The `issue-bugfix` agent in `opencode.json` auto-approves all permission
  requests so a headless run cannot stall waiting for a human. It still denies
  pushing to `main`, force-pushing, merging pull requests, closing issues,
  reading `.env` files, external web access, subagents, and `sudo`. The
  `GITHUB_TOKEN` permissions are scoped to the workflow.
- The workflow is triggered by `issues: opened` or `issues: reopened`, an
  explicit `/opencode fix` comment from a repository
  owner/member/collaborator, or a manual `workflow_dispatch`. Bot-authored
  issues and comments are skipped.
- `opencode-ci-triage.yml` never checks out or executes pull request code: it
  runs from the default branch and checks out `main`, so the failure's logs are
  data rather than code. The `ci-triage` agent additionally cannot edit
  `.github/workflows/**`, run `gh workflow`, merge pull requests, or close
  issues.

## Troubleshooting

- **`FACTORIO_PLAYER_TOKEN is required`** — add the secret. A mod-portal upload
  key will be rejected by the download endpoint with HTTP 401/403.
- **The FUnit harness verification step fails** — run the same command locally
  with the printed `FACTORIO_BIN`/`FACTORIO_MODS` and check
  `$TMP_ROOT/stdout.log` (default `/tmp/opencode/muluna-funit/stdout.log`).
- **The agent opens no pull request** — check the issue comment it posted. A
  bug that cannot be reproduced or verified headlessly is reported instead of
  guessed at, and feature requests are left to the maintainers.
