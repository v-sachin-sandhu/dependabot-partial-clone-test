# dependabot-partial-clone-test

A fixture for testing how Dependabot's `github_actions` updater clones action repositories, in particular the change in [dependabot/dependabot-core#16780](https://github.com/dependabot/dependabot-core/pull/16780).

## What it exercises

[`.github/workflows/partial-clone-test.yml`](.github/workflows/partial-clone-test.yml) pins four actions. The workflow job is disabled (`if: ${{ false }}`), so it never runs; Dependabot only reads the `uses:` lines.

| Action | Pin | Clones Dependabot makes |
|---|---|---|
| `openclaw/openclaw/.github/actions/git-owner` | `dd4528b…`, a commit that is not a branch or tag tip and has no tag; about 10 GiB repository | pinned-ref clone (to find the branch that contains the commit) and a bare clone for the cooldown dates (its tags have no GitHub release) |
| `useblacksmith/begin-testbox` | `233448a…`, same kind of pin; small repository, no GitHub releases | the same two clones |
| `actions/checkout` | `631c942…`, same kind of pin; small repository with GitHub releases | pinned-ref clone only; the cooldown date comes from the releases API |
| `actions/setup-node` | `v4` | none (control) |

[`dependabot-cli/job.yml`](dependabot-cli/job.yml) is a Dependabot CLI job for this repository with a 7-day cooldown, which is what makes the updater look up release dates.

There is deliberately no `.github/dependabot.yml`, so GitHub's own Dependabot does not run against this repository. Add one if you want to watch the hosted service once the change is deployed.

## Running it

Requirements: Docker and the [Dependabot CLI](https://github.com/dependabot/cli).

**With the change** (mount a dependabot-core checkout that contains it):

```sh
dependabot update -f dependabot-cli/job.yml -t 35m \
  -v /path/to/dependabot-core/github_actions/lib:/home/dependabot/github_actions/lib
```

**Without the change** (the published updater image):

```sh
dependabot update -f dependabot-cli/job.yml -t 35m
```

> The run without the change clones `openclaw/openclaw` in full, about 10 GiB per clone, twice. It fills small disks and takes a long time. Run it only on a machine with plenty of free disk space.

In a Codespace, the `-v` source must be the Docker host path, not `/workspaces/...`. Find it with `docker inspect` on the dev container; it is usually `/var/lib/docker/codespacemount/workspace/dependabot-core/github_actions/lib`.

## What to look for in the log

```sh
grep -E "git clone .*(--filter|--bare|--no-recurse-submodules) https" update.log   # every action clone
grep -E "Partial clone failed" update.log                                        # fallbacks to a full clone
grep -E "No space left on device|Timed out due to inactivity" update.log
grep -E "git branch --remotes --contains|git for-each-ref|git log -1 --no-mailmap" update.log
```

## Results observed with the change

Run on 2026-11-03 with the published `dependabot-updater-github-actions` image, the change mounted (dependabot-core commit `305c55273`) and `dependabot-cli/job.yml`. The job finished in 105 seconds with exit 0, 5 partial clones, no fallback to a full clone and no disk or timeout errors.

| Action | Step | Command | Time |
|---|---|---|---|
| `openclaw/openclaw/.github/actions/git-owner` | pinned-ref clone | `git clone --no-checkout --filter=tree:0 --no-recurse-submodules …` | 17.1 s |
| | branch lookup | `git branch --remotes --contains dd4528b…` | 7.8 s |
| | cooldown clone | `git clone --bare --filter=tree:0 --no-recurse-submodules …` | 14.5 s |
| | tag date / commit date | `git for-each-ref …` / `git log -1 --no-mailmap …` | 0.01 s / 0.01 s |
| `useblacksmith/begin-testbox` | pinned-ref clone, branch lookup, cooldown clone, dates | same commands | 0.2 s, 0.01 s, 0.09 s, 0.01 s |
| `actions/checkout` | pinned-ref clone, branch lookup | same commands | 0.23 s, 0.02 s |
| | cooldown date | GitHub releases API, no clone | |
| `actions/setup-node` | none | no clone | |

Updates the job created:

| Action | From | To |
|---|---|---|
| `openclaw/openclaw/.github/actions/git-owner` | `dd4528b6393e7d00063067a080ca7241b48ce475` | `d98df6c24ac2a5b89decf4e1cf0fc1e0a9871e43` (on `main`, still contains the action) |
| `useblacksmith/begin-testbox` | `233448af4bfdc6fca509a7f0974411ac6d8a8043` | `22ff2ea5697369864347140857d218e42815b33c` |
| `actions/checkout` | `631c942040754b6e095e929c1677c07e10ed4f87` | `f548e57e544e1ff5a4c46bf1e1b8685f8e4a348a` |
| `actions/setup-node` | `v4` | `v7` |

The target versions depend on the upstream repositories and on the cooldown, so they change over time.

Without the change, update jobs that clone `openclaw/openclaw` in full fail with `fatal: write error: No space left on device` or `Timed out due to inactivity after 900 seconds`. That run was not repeated here because of the disk space it needs.
