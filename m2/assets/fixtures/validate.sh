#!/usr/bin/env bash
# validate.sh — run levels 1 to 3 against one YAML file, stopping at the first
# failure so the output names the level that rejected it.
set -u
f="${1:?usage: ./validate.sh <file.yml>}"

printf '\n[1] parse            : '
if yq . "$f" >/dev/null 2>&1; then echo "ok"
else echo "FAILED"; yq . "$f"; exit 1; fi

printf '[2] style and truthy : '
if yamllint -s -c .yamllint.yml "$f" >/dev/null 2>&1; then echo "ok"
else echo "FAILED"; yamllint -c .yamllint.yml "$f"; exit 1; fi

printf '[3] workflow schema  : '
if actionlint "$f" >/dev/null 2>&1; then echo "ok"
else echo "FAILED"; actionlint "$f"; exit 1; fi

echo "all three levels passed: $f"
