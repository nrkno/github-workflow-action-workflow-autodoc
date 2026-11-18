# GitHub Workflow - AutoDoc

Workflow to update docs based on workflow or actions parameters.

It uses github-action [nrkno/github-action-action-workflow-autodoc](https://github.com/nrkno/github-action-action-workflow-autodoc) to generate documentation

<!-- start -->
## GitHub Workflow - AutoDoc


### Optional Inputs

|Input name|Description|Type|Default|
|---|---|---|---|
|**runs-on**|An unpadded runner label such as ubuntu-latest, or a JSON string<br>(`'"ubuntu-latest"'`), list (`'["self-hosted", "Linux"]'`) or object<br>(`'{"group": "g"}'`). Enclose JSON in single quotes `'`.<br>|string|`ubuntu-latest`|
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
  `persist-credentials: false`, validates `doc_file`, and runs the action.
  It validates the path again before uploading a copy as `documentation.md`.
  The fixed name inside the artifact lets callers use hidden paths and
  literal characters such as `[` in `doc_file`. This job has no write token.
- **`push`** has `contents: write`. It makes a fresh checkout of the same
  commit and downloads the artifact into a new directory. The download must
  contain only one regular `documentation.md` file, at most 10 MiB. The job
  checks the destination before copying the file over `doc_file`, commits with
  hooks and fsmonitor disabled and system and user Git configuration ignored, and
  pushes to an explicit URL. The push step passes its token to Git through a
  masked `http.extraheader`. This job runs neither the autodoc action nor
  scripts from the branch.

`doc_file` must be an existing regular file named by a relative path inside
the checkout, with no `..` components or symbolic links in the path. Git
metadata under `.git` is not a documentation target.

Callers must grant `contents: write`, as before. The commit sits on the head
SHA of the pull request. A caller may run this workflow more than once per pull
request (plattform-terraform documents a plan and an apply workflow into one
README), so another run may push first. A rejected push is retried at most 3
times: the job fetches the branch tip, requires that it still contains the head
SHA and that only `doc_file` changed since, and replays its own commit on the tip
with `git rebase --onto`. The artifact is not copied again, so edits made by the
other run to other parts of `doc_file` are kept. If the branch was force-pushed,
changed another file, or the replay conflicts, the job fails instead and the
next run regenerates the documentation. Call from `pull_request`, not
`pull_request_target`. A pull request from a fork or with an unknown head
repository is skipped; the workflow does not update branches in forks.

Both jobs start by deleting any `.git` left in the workspace. Persistent
self-hosted runners keep workspaces between jobs, and checkout would otherwise
reuse a planted `.git/config` (`url.<x>.pushInsteadOf`, `core.sshCommand`,
`core.fsmonitor`) for its own authenticated git commands. Git system and user
configuration is ignored in the push job.

The artifact handoff limits what the push job will copy to `doc_file`. This
assumes runner isolation between jobs. Deleting `.git` does not isolate jobs
that share the same persistent host.

The `autodoc_out` output contains text taken from the documented file, so treat
it as untrusted. Never interpolate it into a `run:` script; pass it through `env:`.

`runs-on` accepts an unpadded plain label (`ubuntu-latest`), a JSON string
(`'"ubuntu-latest"'`), a JSON list (`'["self-hosted", "Linux"]'`) or a JSON
object (`'{"group": "g"}'`). The JSON forms may have surrounding whitespace.
An empty JSON string does not specify a runner.

## Self-test

`.github/workflows/autodoc.yaml` documents this repository with the local
workflow, but only when the `AUTODOC_SELFTEST` variable is `true`. It skips draft
pull requests and runs when a pull request is marked ready for review. Leave
the variable off while action v2.2.0 remains locked: it still renders the old
README templates.

1. Wait for the hardened action from
   [action PR #57](https://github.com/nrkno/github-action-action-workflow-autodoc/pull/57)
   to be released. Verify that the release builds from its checked-in
   `Dockerfile`. Update the step to the published version tag, regenerate
   `actions.lock`, and verify that it locks the intended release commit.
2. Before enabling the repository self-test, run a canary in an approved
   disposable repository with the updated workflow and lockfile. Use a
   same-repository pull request with no secrets and a benign `action.yaml`
   defining an optional input `canary-input`. Put stale text between the
   default autodoc markers in `.docs/Guide [A].md`, with sentinel text both
   before and after the markers. Have the canary call the local reusable
   workflow with `workflow_file: action.yaml`, `doc_file: './.docs/Guide [A].md'`,
   and `contents: write`. Use the self-test's draft guard and `opened`,
   `ready_for_review`, and `reopened` events. Confirm the draft skips; once
   ready, confirm the write job commits only that file on the PR branch,
   replaces the stale text with a section containing `canary-input`, and
   leaves the sentinels unchanged. Close and reopen the canary PR at the new
   head and confirm that no further commit is made.
3. Once the canary passes, remove only the variable check. Keep the draft
   guard and `ready_for_review` trigger.

For local checks, run `bash tests/workflow.sh` (Linux, Git, and `yq` v4).
It exercises the workflow's Bash steps with isolated files and a local Git
repository. It does not run the container or the GitHub artifact service.

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
