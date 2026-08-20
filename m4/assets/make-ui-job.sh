#!/usr/bin/env bash
# Instructor setup for Challenge 2.
#
# Challenge 2 needs a job that exists in the workspace and was NOT created by a
# bundle, so that bundle generate job has something to import. This script creates
# one per participant, using an interactive cluster so that the generated file
# carries existing_cluster_id — which is the first of the three defects the
# challenge is about.
#
# Usage:  bash make-ui-job.sh <cluster-id> [suffix]
# Prints the job id to hand to the participant.
set -euo pipefail

CLUSTER_ID="${1:?usage: make-ui-job.sh <existing-cluster-id> [suffix]}"
SUFFIX="${2:-$(date +%s)}"
USER_EMAIL=$(databricks current-user me -o json | jq -r .userName)
NB_PATH="/Workspace/Users/${USER_EMAIL}/hello_world_${SUFFIX}"

TMP=$(mktemp -d)
cat > "$TMP/hello_world.py" <<'PY'
# Databricks notebook source
print("this job was built by hand, in the interface")
PY

databricks workspace import "$NB_PATH" \
  --file "$TMP/hello_world.py" --language PYTHON --format SOURCE --overwrite

cat > "$TMP/job.json" <<JSON
{
  "name": "hello_world_ui_${SUFFIX}",
  "max_concurrent_runs": 1,
  "tasks": [
    {
      "task_key": "hello",
      "existing_cluster_id": "${CLUSTER_ID}",
      "notebook_task": { "notebook_path": "${NB_PATH}", "source": "WORKSPACE" }
    }
  ]
}
JSON

JOB_ID=$(databricks jobs create --json @"$TMP/job.json" -o json | jq -r .job_id)
rm -rf "$TMP"

echo
echo "job id:       $JOB_ID"
echo "notebook:     $NB_PATH"
echo
echo "Hand the job id to the participant. They run:"
echo "  databricks bundle generate job --existing-job-id $JOB_ID --key ported"
