#!/usr/bin/env bash
set -euo pipefail

tests_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
tmp="$(mktemp -d -- "${TMPDIR:-/tmp}/autodoc-check.XXXXXXXX")"
trap 'rm -rf -- "$tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

TMPDIR="$tmp" bash "$tests_dir/workflow.sh"
cp -- "$tests_dir"/{package.json,package-lock.json,expressions.mjs} "$tmp/"
cd -- "$tmp"
npm ci --ignore-scripts --no-audit --no-fund --userconfig /dev/null --cache "$tmp/cache"
node expressions.mjs "$tests_dir/../.github/workflows"
