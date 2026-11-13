# GitHub Workflow - AutoDoc

Workflow to update docs based on workflow or actions parameters.

It uses github-action [nrkno/github-action-action-workflow-autodoc](https://github.com/nrkno/github-action-action-workflow-autodoc) to generate documentation

<!-- start -->
## GitHub Workflow - AutoDoc


### Optional Inputs

|Input name|Description|Type|Default|
|---|---|---|---|
|**runs-on**|Runner label, e.g. ubuntu-latest. A plain label, a JSON string<br>(`'"ubuntu-latest"'`) or a JSON list (`'["self-hosted", "Linux"]'`)<br>are all accepted. Enclose JSON in single quotes `'`.<br>|string|`ubuntu-latest`|
|**workflow_file**|Path to the workflow file to document|string|`action.yaml`|
|**doc_file**|Path to the markdown file to update with documentation|string|`README.md`|
|**start_token**|Token marking the start of the autodoc section|string|`<!-- autodoc start -->`|
|**end_token**|Token marking the end of the autodoc section|string|`<!-- autodoc end -->`|
|**table**|Format inputs as a markdown table|string|`false`|
|**debug**|Print debug messages. 0=none, 1=some, 2=more, 3=all|string|`0`|


### Outputs

|Output name|Description|
|---|---|
|autodoc_out|If enabled, the generated documentation for inputs, secrets, and outputs|
|autodoc_type|The type automaticly detected by the script of the input_file documented: workflow or action|

### Simple example usage (job-level 'uses' syntax)

```yaml
---
name: workflow-example
on:
  pull_request:

jobs:
  example-job:
    # The called workflow pushes the result, so the job must grant this.
    permissions:
      contents: write
    # Reusable workflows are called at job level. Pin to a full commit SHA.
    uses: nrkno/github-workflow-action-workflow-autodoc/.github/workflows/workflow.yaml@<full-commit-sha> # vX.Y.Z
```

### Full example usage (job-level 'uses' syntax)

```yaml
---
name: workflow-example
on:
  pull_request:

jobs:
  example-job:
    # The called workflow pushes the result, so the job must grant this.
    permissions:
      contents: write
    # Reusable workflows are called at job level. Pin to a full commit SHA.
    uses: nrkno/github-workflow-action-workflow-autodoc/.github/workflows/workflow.yaml@<full-commit-sha> # vX.Y.Z
    with:
      runs-on: 'ubuntu-latest'
      workflow_file: 'action.yaml'
      doc_file: 'README.md'
      start_token: '<!-- autodoc start -->'
      end_token: '<!-- autodoc end -->'
      table: 'false'
      debug: '0'
```


<!-- end -->

## Security model

The documentation has to be pushed back to the branch, which needs a write
token. A container action can write `GITHUB_ENV`, `GITHUB_PATH` and the
workspace (including `.git/config`), and so can run code in, or redirect, any
later step of its own job. The workflow therefore uses two jobs:

- **`autodoc`** has `contents: read`. It checks out the PR head with
  `persist-credentials: false`, runs the action and uploads `doc_file` as an
  artifact. It never sees a write token.
- **`push`** has `contents: write`. It makes a fresh checkout of the same
  commit, downloads the artifact and requires it to be exactly one regular file
  (no links, directories or extra files, at most 10 MiB). It copies that file
  over `doc_file` (which must be a regular file with no symlinked path
  component), commits it with hooks and fsmonitor disabled and system and user
  git configuration ignored, and pushes to an explicit URL. Only that last step
  receives the token, through a masked `http.extraheader`. No code from the
  branch or from the action runs in this job.

Callers must grant `contents: write`, as before. The commit sits on the head
SHA of the pull request. A caller may run this workflow more than once per pull
request (plattform-terraform documents a plan and an apply workflow into one
README), so another run may push first. A rejected push is retried at most 3
times: the job fetches the branch tip, requires that it still contains the head
SHA and that only `doc_file` changed since, and replays its own commit on the tip
with `git rebase --onto`. The artifact is not copied again, so edits made by the
other run to other parts of `doc_file` are kept. If the branch was force-pushed,
changed another file, or the replay conflicts, the job fails instead and the
next run regenerates the documentation. Pull requests from forks are skipped:
they have a read-only token and their branch does not exist in this repository.

Both jobs start by deleting any `.git` left in the workspace. Persistent
self-hosted runners keep workspaces between jobs, and checkout would otherwise
reuse a planted `.git/config` (`url.<x>.pushInsteadOf`, `core.sshCommand`,
`core.fsmonitor`) for its own authenticated git commands. Git system and user
configuration is ignored in the push job.

What a compromised action can still do is limit its damage to the content of
`doc_file`.

The `autodoc_out` output contains text taken from the documented file, so treat
it as untrusted. Never interpolate it into a `run:` script; pass it through `env:`.

`runs-on` accepts a plain label (`ubuntu-latest`), a JSON string
(`'"ubuntu-latest"'`), a JSON list (`'["self-hosted", "Linux"]'`) or a JSON
object (`'{"group": "g"}'`), with optional leading whitespace.

## Self-test

`.github/workflows/autodoc.yaml` documents this repository with the local
workflow, but only when the repository variable `AUTODOC_SELFTEST` is `true`.
Until the `TODO(bump)` on the action step in `workflow.yaml` is done, the pinned
action still renders the old README templates and would revert the regenerated
README on every pull request. Remove the `if:` with the bump.

## Lockfile upkeep

`.github/workflows/actions.lock` is generated by the
[`gh actions-lock`](https://github.com/github/gh-actions-lock) extension. Step
`uses:` references keep full version tags (`actions/checkout@v7.0.1`); the
lockfile records the commit SHA each tag resolved to, including transitive
actions, and GitHub enforces those SHAs when the workflow runs. A moved or
re-pointed tag therefore cannot change what runs. Whenever a `uses:` reference
in `.github/workflows/` is added, removed or changed, update the lockfile in the
same PR:

```sh
gh extension install github/gh-actions-lock --pin v0.4.1  # once
gh actions-lock
```

Commit `actions.lock` together with any tag rewrite the extension makes.
Renovate regenerates the lockfile in its action-bump PRs; run the command above for hand edits.

Reusable workflow calls (`jobs.<job_id>.uses`) are not covered by the lockfile.
Keep them pinned to a full commit SHA with a `# vX.Y.Z` comment.
The `Actions lockfile` workflow runs `gh actions-lock --verify-local` on PRs that
touch `.github/workflows/` and fails if an action reference has no lockfile
entry. Do not edit the lockfile by hand.
