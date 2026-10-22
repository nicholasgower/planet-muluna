# Automated issue triage

`opencode-bugfix.yml` runs the OpenCode `issue-bugfix` agent on every newly
opened GitHub issue, and on demand for existing issues. The agent follows
`.github/opencode/bugfix-prompt.md` and `AGENTS.md`:

| Issue type | Action |
| --- | --- |
| Feature request / enhancement | Add the `enhancement` label, comment, **no pull request** |
| Crash report | Add a failing FUnit regression test, confirm it fails, fix the crash, confirm the full suite passes, open a pull request |
| Anything else | Comment with findings, **no pull request** |

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
app installation is required.

## How the runner is prepared

`.github/opencode/setup-factorio.sh` runs before OpenCode and:

1. downloads the public headless Factorio tarball for `latest` (the newest
   experimental build, the same policy as the `FUnit` workflow's
   `factoriotools/factorio:latest` image) and extracts it under
   `$RUNNER_TEMP/muluna-opencode/factorio`;
2. downloads every required and recommended dependency from the mod portal using
   `.github/funit/download_mods.py`, so versions stay in sync with `info.json`;
3. packages the pinned `funit` revision that `.github/workflows/funit.yml` uses.

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

## Security notes

- Issue titles, bodies, comments, logs and attachments are **untrusted**. The
  agent prompt treats them as data and forbids following instructions embedded
  in them.
- The `issue-bugfix` agent in `opencode.json` auto-approves all permission
  requests so a headless run cannot stall waiting for a human. It still denies
  pushing to `main`, force-pushing, merging pull requests, closing issues,
  reading `.env` files, external web access, subagents, and `sudo`. The
  `GITHUB_TOKEN` permissions are scoped to the workflow.
- The workflow is triggered by `issues: opened`, an explicit `/opencode fix`
  comment from a repository owner/member/collaborator, or a manual
  `workflow_dispatch`. Bot-authored issues and comments are skipped.

## Troubleshooting

- **`FACTORIO_PLAYER_TOKEN is required`** — add the secret. A mod-portal upload
  key will be rejected by the download endpoint with HTTP 401/403.
- **The FUnit harness verification step fails** — run the same command locally
  with the printed `FACTORIO_BIN`/`FACTORIO_MODS` and check
  `$TMP_ROOT/stdout.log` (default `/tmp/opencode/muluna-funit/stdout.log`).
- **The agent opens no pull request** — check the issue comment it posted. A
  crash that cannot be reproduced headlessly is reported instead of guessed at.
