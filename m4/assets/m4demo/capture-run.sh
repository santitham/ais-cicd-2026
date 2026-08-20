#!/usr/bin/env bash
# Runs the Module 4 lifecycle against a live workspace and records every
# command's output, so that the "shape only" markings in lab.md can be replaced
# with real output and the three deck screenshots can be captured from a known
# state.
#
#   bash capture-run.sh                 # everything: lifecycle, break-fix, promote, destroy
#   bash capture-run.sh --phase lifecycle
#   bash capture-run.sh --phase break
#   bash capture-run.sh --phase promote
#   bash capture-run.sh --keep          # skip the final destroy
#   bash capture-run.sh -p myprofile    # pass a CLI profile to every command
#
# Output goes to capture/NN-<name>.txt, one file per command, plus
# capture/SUMMARY.md mapping each file to the slide or lab section it feeds.
#
# No setup needed: databricks.yml pins cluster_id to Training_Cluster. The script
# verifies that cluster still exists before it deploys anything. To point at a
# different one:  source ./cluster-env.sh Another_Cluster
#
# Timing. Because the cluster already exists, nothing has to be started and a run
# takes a few minutes rather than the 12-18 a three-job-cluster run would. The
# full script performs three runs (good, broken, fixed). Run it once and read the
# capture directory afterwards.

set -u -o pipefail

PHASE=all
KEEP=0
TARGET=dev
JOB_KEY=ingest

while [ $# -gt 0 ]; do
  case "$1" in
    --phase) PHASE="${2:?--phase needs a value}"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    -p|--profile) export DATABRICKS_CONFIG_PROFILE="${2:?-p needs a value}"; shift 2 ;;
    -t|--target) TARGET="${2:?-t needs a value}"; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

case "$PHASE" in all|lifecycle|break|promote) ;; *)
  echo "--phase must be one of: all lifecycle break promote" >&2; exit 2 ;;
esac

[ -f databricks.yml ] || { echo "run this from inside the m4demo directory" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

# Every task claims an existing cluster by id. databricks.yml pins one, but a
# pinned id goes stale if the cluster is deleted and recreated, and that failure
# would otherwise appear only after a successful deploy. Check it here: one API
# call now beats a wasted run.
if grep -q 'existing_cluster_id' resources/ingest.job.yml 2>/dev/null; then
  _cid=$(databricks bundle validate -t "$TARGET" -o json 2>/dev/null \
         | jq -r '.variables.cluster_id.value // empty')
  if [ -z "${_cid:-}" ]; then
    echo "cluster_id resolves to nothing. Either databricks.yml lost its default, or" >&2
    echo "the bundle does not validate. Run: databricks bundle validate" >&2
    exit 2
  fi
  if ! databricks clusters get "$_cid" -o json >/dev/null 2>&1; then
    echo "cluster_id is $_cid, and no such cluster exists in this workspace." >&2
    echo "Training_Cluster was probably recreated. Fix it with either:" >&2
    echo "  source ./cluster-env.sh          # override for this shell" >&2
    echo "  \$EDITOR databricks.yml           # update the pinned default" >&2
    echo "Available clusters:" >&2
    databricks clusters list -o json 2>/dev/null \
      | jq -r '.[] | "  \(.cluster_id)  \(.cluster_name)  [\(.state // "?")]"' >&2
    exit 2
  fi
  echo "cluster_id: $_cid  (verified present)"
  unset _cid
fi

mkdir -p capture
N=0
declare -a INDEX=()

# run <name> <description> -- <command...>
# Records stdout and stderr together, prints a one-line result, and never aborts
# the script: some commands in this sequence are expected to fail.
run() {
  local name="$1" desc="$2"; shift 3
  N=$((N+1))
  local file
  file=$(printf 'capture/%02d-%s.txt' "$N" "$name")
  {
    if [ "$1" = bash ] && [ "$2" = -c ]; then
      echo "\$ $3"          # paste-able: the wrapper is an implementation detail
    else
      local shown="$*"
      shown="databricks ${shown#db }"       # db is a wrapper; show the real command
      echo "\$ $shown"
    fi
    echo
  } > "$file"
  local start rc elapsed
  start=$(date +%s)
  "$@" >> "$file" 2>&1
  rc=$?
  elapsed=$(( $(date +%s) - start ))
  printf '  %-28s rc=%-3s %4ss  %s\n' "$name" "$rc" "$elapsed" "$file"
  INDEX+=("$(printf '%02d-%s.txt|%s|rc=%s, %ss' "$N" "$name" "$desc" "$rc" "$elapsed")")
  return 0
}

# Every databricks call below reads DATABRICKS_CONFIG_PROFILE from the
# environment, so the profile never has to be interpolated into a command string.
db() { databricks "$@"; }

echo "=== Module 4 capture run ==="
echo "phase: $PHASE   target: $TARGET   profile: ${DATABRICKS_CONFIG_PROFILE:-<default>}"
echo "started: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo

# ---------------------------------------------------------------- environment --
run version      "CLI version, for the verified-facts record"                -- db --version
run whoami       "the authenticated identity every command below uses"       -- db current-user me -o json

# ------------------------------------------------------------------ lifecycle --
if [ "$PHASE" = all ] || [ "$PHASE" = lifecycle ]; then
  echo "-- lifecycle"
  run validate         "lab.md pre-flight and Challenge 1 expected output"       -- db bundle validate -t "$TARGET"
  run presets          "S27 of Module 3, and Challenge 4.2 in this module"       -- bash -c "databricks bundle validate -t $TARGET -o json | jq '{presets, variables}'"
  run graph            "Challenge 3 expected graph output"                       -- bash -c "databricks bundle validate -t $TARGET -o json | jq -r '.resources.jobs.$JOB_KEY.tasks[] | \"\\(.task_key) <- \\(.depends_on // [] | map(.task_key) | join(\", \"))\"'"
  run task-compute     "Challenge 1: every task's compute, as resolved"            -- bash -c "databricks bundle validate -t $TARGET -o json | jq -r '.resources.jobs.$JOB_KEY.tasks[] | \"\\(.task_key)  \\(.existing_cluster_id // .job_cluster_key // \"NONE\")\"'"
  run plan-create      "SCREENSHOT S54, first half: every resource a create"     -- db bundle plan -t "$TARGET"
  run deploy-first     "SCREENSHOT S55, first half: the deployment stages"       -- db bundle deploy -t "$TARGET"
  run plan-nochange    "SCREENSHOT S54, second half: no action"                  -- db bundle plan -t "$TARGET"
  run deploy-second    "SCREENSHOT S55, second half: idempotent redeploy"        -- db bundle deploy -t "$TARGET"
  run summary          "lab.md Challenge 5.1, currently marked shape only"       -- db bundle summary -t "$TARGET"
  run root-path        "the four entries under the deployment root"              -- bash -c "databricks workspace list \"\$(databricks bundle validate -t $TARGET -o json | jq -r .workspace.root_path)\""
  run run-good         "SCREENSHOT S56: run URL, per-task states, result"        -- db bundle run "$JOB_KEY" -t "$TARGET"
  run run-only         "S56 second image: rerun one task without redeploying"    -- db bundle run "$JOB_KEY" -t "$TARGET" --only features
fi

# ----------------------------------------------------------------- break-fix ---
if [ "$PHASE" = all ] || [ "$PHASE" = break ]; then
  echo "-- break-fix (Challenge 5)"
  cp src/features.py capture/features.py.original
  cp src/features.py.broken src/features.py
  run deploy-broken    "Challenge 5.2: deploy succeeds, the code is broken"      -- db bundle deploy -t "$TARGET"
  run run-broken       "Challenge 5.2 expected states, and the run-history shot" -- db bundle run "$JOB_KEY" -t "$TARGET"
  cp capture/features.py.original src/features.py
  run deploy-fixed     "Challenge 5.3: redeploy after the fix"                   -- db bundle deploy -t "$TARGET"
  run plan-after-fix   "Challenge 5.3: no action for what did not change"        -- db bundle plan -t "$TARGET"
  run run-fixed        "Challenge 5.3: all five tasks SUCCESS"                   -- db bundle run "$JOB_KEY" -t "$TARGET"
  echo "  src/features.py restored from capture/features.py.original"
fi

# ------------------------------------------------------------------- promote ---
if [ "$PHASE" = all ] || [ "$PHASE" = promote ]; then
  echo "-- promote (Challenge 4)"
  run validate-staging "Challenge 4.2: staging resolves"                         -- db bundle validate -t staging
  run job-dev          "Challenge 4.2: the dev resolution, for the diff"         -- bash -c "databricks bundle validate -t $TARGET -o json | jq '.resources.jobs.$JOB_KEY'"
  run job-staging      "Challenge 4.2: the staging resolution, for the diff"     -- bash -c "databricks bundle validate -t staging -o json | jq '.resources.jobs.$JOB_KEY'"
  run tasks-staging    "Challenge 4.3: five tasks, not six, and one retry moved"  -- bash -c "databricks bundle validate -t staging -o json | jq -r '.resources.jobs.$JOB_KEY.tasks[] | \"\\(.task_key) retries=\\(.max_retries // 0)\"'"
  run task-count       "Challenge 4.3: the count IS the check for a silent append" -- bash -c "for T in $TARGET staging prod; do printf '%-8s %s tasks\\n' \"\$T\" \"\$(databricks bundle validate -t \$T -o json | jq '.resources.jobs.$JOB_KEY.tasks | length')\"; done"
  run var-env          "Challenge 4.4: BUNDLE_VAR_ wins over the target"         -- bash -c "BUNDLE_VAR_schema=fromenv databricks bundle validate -t staging -o json | jq -r .variables.schema.value"
  run var-flag         "Challenge 4.4: --var wins over BUNDLE_VAR_"              -- bash -c "BUNDLE_VAR_schema=fromenv databricks bundle validate -t staging -o json --var=schema=fromflag | jq -r .variables.schema.value"
  run var-wrong-prefix "Challenge 4.4: DATABRICKS_BUNDLE_VAR_ does nothing"      -- bash -c "DATABRICKS_BUNDLE_VAR_schema=ignored databricks bundle validate -t staging -o json | jq -r .variables.schema.value"
  run validate-prod    "the prod resolution, never deployed"                     -- db bundle validate -t prod
  DEVF=$(ls capture/*-job-dev.txt 2>/dev/null | head -1)
  STGF=$(ls capture/*-job-staging.txt 2>/dev/null | head -1)
  if [ -s "${DEVF:-}" ] && [ -s "${STGF:-}" ]; then
    diff <(tail -n +3 "$DEVF") <(tail -n +3 "$STGF") \
      > capture/diff-dev-staging.txt 2>&1 || true
    printf '  %-28s %s\n' "diff-dev-staging" "capture/diff-dev-staging.txt"
    INDEX+=("diff-dev-staging.txt|Challenge 4.2: every line that differs between the two targets|-")
  fi
fi

# ------------------------------------------------------------------- destroy ---
if [ "$KEEP" -eq 0 ] && { [ "$PHASE" = all ] || [ "$PHASE" = lifecycle ]; }; then
  echo "-- destroy"
  run destroy "leaves the workspace clean for the next cohort" -- db bundle destroy -t "$TARGET" --auto-approve
else
  echo "-- destroy skipped; run: databricks bundle destroy -t $TARGET --auto-approve"
fi

# ------------------------------------------------------------------- summary ---
{
  echo "# Module 4 capture run"
  echo
  echo "Phase \`$PHASE\`, target \`$TARGET\`, run $(date -u '+%Y-%m-%d %H:%M UTC')."
  echo "Databricks CLI: $(grep -m1 -hoE 'v[0-9]+\.[0-9]+\.[0-9]+' capture/01-version.txt 2>/dev/null || echo unknown)"
  echo
  echo "A non-zero \`rc\` is not necessarily a fault. \`run-broken\` is expected to fail;"
  echo "that failure is the artefact."
  echo
  echo "| File | Feeds | Result |"
  echo "|---|---|---|"
  for row in "${INDEX[@]+"${INDEX[@]}"}"; do
    IFS='|' read -r f d r <<< "$row"
    echo "| \`$f\` | $d | $r |"
  done
  echo
  echo "## Next"
  echo
  echo "1. Replace every **shape only** marking in \`../lab.md\` with the matching output above."
  echo "2. Capture the three deck screenshots. The file numbers depend on the phase, so"
  echo "   the files are named here without them:"
  echo "     - S54 from \`*-plan-create.txt\` and \`*-plan-nochange.txt\`"
  echo "     - S55 from \`*-deploy-first.txt\` and \`*-deploy-second.txt\`"
  echo "     - S56 from \`*-run-good.txt\`"
  echo "   Re-run those commands in a 100x30 terminal for the images; the text captured here"
  echo "   is the record, not the screenshot."
  echo "3. Open the run URL in \`*-run-broken.txt\` and capture the run history with all five"
  echo "   task states legible. That image answers the exit ticket's second question, and it"
  echo "   is the third extra capture listed in ../capture-screenshots.md."
} > capture/SUMMARY.md

echo
echo "=== done: $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="
echo "wrote $N command logs to capture/ — start with capture/SUMMARY.md"
