#!/usr/bin/env bash
set -euo pipefail

# Run the workflow's actual Bash steps. GitHub artifact transport and the
# container action are not run; transfer only the staged file's bytes.
workflow="$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")/../.github/workflows/workflow.yaml")"
tmp="$(mktemp -d -- "${TMPDIR:-/tmp}/autodoc-test.XXXXXXXX")"
trap 'rm -rf -- "$tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
cd -- "$tmp"

export GIT_ALLOW_PROTOCOL=file GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_LITERAL_PATHSPECS=1 GIT_TERMINAL_PROMPT=0
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
unset GH_TOKEN GITHUB_TOKEN GIT_CONFIG_COUNT GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
export RUNNER_TEMP="$tmp" GITHUB_OUTPUT="$tmp/output"
export GITHUB_SERVER_URL="$tmp" GITHUB_REPOSITORY=origin GIT_EDITOR=:

extract() {
  JOB="$1" STEP="$2" yq \
    '.jobs[strenv(JOB)].steps[] | select(.name == strenv(STEP)) | .run' \
    "$workflow" > "$tmp/$3.sh"
  test -s "$tmp/$3.sh"
}

run_step() {
  bash --noprofile --norc -eo pipefail "$tmp/$1.sh"
}

expect_failure() {
  if run_step "$1" > "$tmp/failure" 2>&1; then
    printf 'Expected failure in %s\n' "$1" >&2
    exit 1
  fi
  grep -F -- "$2" "$tmp/failure" >/dev/null
}

extract push 'Validate documentation path' validate
extract autodoc 'Stage documentation' stage
extract push 'Prepare download directory' prepare
extract push 'Commit documentation' commit
extract push 'Push documentation update' publish

# The two calls start from a common base and edit different parts of the same
# hidden document, whose name also contains characters used as glob syntax.
git init -q --template= --initial-branch=main origin.git --bare
git clone -q --template= origin.git generate 2>/dev/null
cd generate
doc='.docs/Guide [A].md'
export DOC_FILE="./.docs//./Guide [A].md"
mkdir .docs
printf 'first original\n1\n2\n3\n4\n5\n6\n7\n8\nlast original\n' > "$doc"
printf 'name: Example\n' > action.yaml
git add -- "$doc" action.yaml
git commit -qm base
git push -q origin HEAD:refs/heads/main
export HEAD_REF=main HEAD_SHA
HEAD_SHA="$(git rev-parse HEAD)"
cd ..
git clone -q --template= origin.git first
git clone -q --template= origin.git second

cd generate
run_step validate
ln -s -- "$doc" symlink.md
DOC_FILE=symlink.md expect_failure validate 'without symlinked components'
ln -s -- .docs alias
DOC_FILE='alias/Guide [A].md' expect_failure validate 'without symlinked components'
DOC_FILE='.docs/../action.yaml' expect_failure validate "without '..' components"
DOC_FILE="$PWD/$doc" expect_failure validate 'must be a relative path'
DOC_FILE='./.git/config' expect_failure validate 'path inside .git'
printf 'PASS: explicit relative path and benign path rejection cases\n'

stage_document() {
  : > "$GITHUB_OUTPUT"
  run_step validate
  run_step stage
  staged="$(sed -n 's/^path=//p' "$GITHUB_OUTPUT")"
  test "${staged##*/}" = documentation.md
  cmp -- "$DOC_FILE" "$staged"
}

prepare_download() {
  : > "$GITHUB_OUTPUT"
  run_step prepare
  ARTIFACT_DIR="$(sed -n 's/^path=//p' "$GITHUB_OUTPUT")"
  export ARTIFACT_DIR
  cp -- "$staged" "$ARTIFACT_DIR/documentation.md"
  : > "$GITHUB_OUTPUT"
}

stage_document
cd ../first
prepare_download
run_step validate
run_step commit
test ! -s "$GITHUB_OUTPUT"
test "$(git rev-parse HEAD)" = "$HEAD_SHA"

cd ../generate
sed -i '1s/original/generated/' "$DOC_FILE"
stage_document
cd ../first
prepare_download
run_step validate
touch "$ARTIFACT_DIR/.extra"
expect_failure commit 'must contain only the regular file'
rm -- "$ARTIFACT_DIR/.extra"
mv -- "$ARTIFACT_DIR/documentation.md" "$tmp/payload.md"
ln -s -- "$tmp/payload.md" "$ARTIFACT_DIR/documentation.md"
expect_failure commit 'must contain only the regular file'
rm -- "$ARTIFACT_DIR/documentation.md"
truncate -s 10485761 "$ARTIFACT_DIR/documentation.md"
expect_failure commit 'larger than 10 MiB'
test "$(git rev-parse HEAD)" = "$HEAD_SHA"
test -z "$(git status --porcelain)"
prepare_download
run_step commit
grep -Fx changed=true "$GITHUB_OUTPUT" >/dev/null
test "$(git diff-tree --no-commit-id --name-only -r HEAD)" = "$doc"
printf 'PASS: staged bytes, no-change handling, and artifact rejection before commit\n'

# Candidate updates in separate checkouts, built before either one is pushed.
cd ../generate
git restore -- "$doc"
sed -i '$s/original/generated/' "$DOC_FILE"
stage_document
cd ../second
prepare_download
run_step validate
run_step commit
cd ../first
GITHUB_TOKEN='' run_step publish > "$tmp/first-push" 2>&1
cd ../second
GITHUB_TOKEN='' run_step publish > "$tmp/second-push" 2>&1
grep -F 'rebasing onto the new branch tip (attempt 1 of 3)' "$tmp/second-push" >/dev/null
git --git-dir="$tmp/origin.git" show "main:$doc" > "$tmp/pushed.md"
test "$(head -n 1 "$tmp/pushed.md")" = 'first generated'
test "$(tail -n 1 "$tmp/pushed.md")" = 'last generated'
test "$(git --git-dir="$tmp/origin.git" rev-list --count "$HEAD_SHA..main")" = 2
printf 'PASS: rejected concurrent update rebases once and preserves both sections\n'

# An intervening source edit must not let the older docs update through.
cd ../first
printf 'name: New example\n' > action.yaml
git add -- action.yaml
git commit -qm 'change source'
git push -q origin HEAD:refs/heads/source-change
cd ../second
export HEAD_REF=source-change
GITHUB_TOKEN='' expect_failure publish 'other than doc_file'
test "$(git --git-dir="$tmp/origin.git" show source-change:action.yaml)" = 'name: New example'
test "$(git --git-dir="$tmp/origin.git" show "source-change:$doc" | tail -n 1)" = 'last original'
printf 'PASS: stale documentation update refuses an intervening source edit\n'
