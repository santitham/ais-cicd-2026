#!/usr/bin/env bash
# Creates the m3demo bundle in the current directory.
#
#   bash make-m3-bundle.sh && cd m3demo && databricks bundle validate
#
# One job, one notebook task, two targets. No uv, no Unity Catalog catalog.
# Generated from the bundle validated with Databricks CLI v1.12.1.

set -euo pipefail

if [ -e m3demo ]; then echo "m3demo already exists here; move it aside first" >&2; exit 1; fi
mkdir -p m3demo/resources m3demo/src

cat > m3demo/.gitignore <<'EOF__GITIGNORE'
.databricks/
build/
dist/
__pycache__/
*.egg-info
.venv/
EOF__GITIGNORE

cat > m3demo/README.md <<'EOF_README_MD'
# m3demo — a bundle that is ready to deploy

One job, one notebook task, two targets. No Python wheel, so `uv` is not
required. No pipeline, so a writable Unity Catalog catalog is not required.
This is the smallest thing that exercises the whole Module 3 lifecycle.

Validated with Databricks CLI v1.12.1: `Validation OK!` for both targets, in
both compute variants.

## Deploy it

```bash
cd m3demo
databricks bundle validate            # confirms the profile, the host and the paths
databricks bundle deploy -t dev
databricks bundle run sample_job -t dev
databricks bundle summary -t dev
databricks bundle destroy -t dev
```

There is nothing to edit first. The workspace host comes from your CLI profile
or from `DATABRICKS_HOST`; the file does not name one, because interpolation is
not permitted on `workspace.host`:

```
Error: Interpolation is not supported for the field workspace.host. Please set
the DATABRICKS_HOST environment variable if you wish to configure this field
at runtime.
```

If you use a named profile, add `-p <profile>` to every command, or export
`DATABRICKS_CONFIG_PROFILE`.

## If your workspace has no serverless compute

The task declares no compute, which means serverless. To run it on an existing
all-purpose cluster instead:

```bash
mv resources/sample_job.job.yml         resources/sample_job.job.yml.serverless
mv resources/sample_job.job.yml.cluster resources/sample_job.job.yml

databricks clusters list -o json | jq -r '.[] | "\(.cluster_id)  \(.cluster_name)"'
databricks bundle deploy -t dev --var cluster_id=<the id you chose>
databricks bundle run sample_job -t dev --var cluster_id=<the id you chose>
```

`clusters list -o json` prints a bare array, so it is indexed with `.[]` and
not `.clusters[]`.

## What to look at once it is deployed

```bash
databricks bundle validate -o json | jq '.presets'
```

Five settings that appear in no file. They are what `mode: development`
computes, and they are why the job is named `[dev <your short name>] m3_hello`
in the workspace while its key stays `sample_job`.

```bash
databricks bundle validate -o json \
  | jq -r '.resources.jobs.sample_job.tasks[0].notebook_task.notebook_path'
```

The deployed location of `src/sample_notebook.py`, resolved before deployment
rather than discovered after it. That path, and the file on your disk, are the
two copies of the same code.

```bash
databricks bundle validate -o json -t prod | jq '{presets, name: .resources.jobs.sample_job.name}'
```

Production mode computes no presets at all, so the name loses its prefix. The
`prod` target here deploys under `/Workspace/Shared`, because production mode
refuses a user-specific root path.

## Files

| File | What it is |
|---|---|
| `databricks.yml` | bundle identity, the include pattern, two variables, two targets |
| `resources/sample_job.job.yml` | the job: one notebook task, serverless |
| `resources/sample_job.job.yml.cluster` | the same job on an existing cluster; not matched by `include`, so it is inert until renamed |
| `src/sample_notebook.py` | the notebook, with the `# Databricks notebook source` header that makes it one |
| `.gitignore` | excludes `.databricks/`, which holds the local deployment state |

## Extending it

Adding a second job is Challenge 3 of the lab: a new file under `resources/`,
a new variable for its name, and one notebook task pointing at a file you
create. The path in a resource file is relative to that file, so it begins
`../src/`.
EOF_README_MD

cat > m3demo/databricks.yml <<'EOF_DATABRICKS_YML'
# A minimal Declarative Automation Bundle, ready to deploy.
#
# It declares one job with one notebook task. There is no Python wheel, so uv
# is not required, and no pipeline, so a writable Unity Catalog catalog is not
# required either. Both are the reason the default-python template needs more
# setup than this.
#
# The workspace host is deliberately absent: the CLI takes it from your profile
# or from DATABRICKS_HOST. Interpolation is not permitted on that field, so a
# variable cannot be used for it.

bundle:
  name: m3demo

include:
  - resources/*.yml

variables:
  job_name:
    description: Display name of the job, before the development-mode prefix
    default: m3_hello

  cluster_id:
    description: >-
      Id of an existing all-purpose cluster. Only used by the fallback resource
      file resources/sample_job.job.yml.cluster; the default serverless form
      ignores it.
    default: ""

targets:

  dev:
    mode: development
    default: true

  prod:
    mode: production
    workspace:
      root_path: /Workspace/Shared/.bundle/${bundle.name}/${bundle.target}
    variables:
      job_name: m3_hello
EOF_DATABRICKS_YML

cat > m3demo/resources/sample_job.job.yml <<'EOF_SAMPLE_JOB_JOB_YML'
# One job, one task, no compute declared.
#
# A notebook task with no job_cluster_key and no existing_cluster_id runs on
# serverless compute. If serverless is not enabled in your workspace, rename
# this file out of the way and rename sample_job.job.yml.cluster in its place.

resources:
  jobs:
    sample_job:
      name: ${var.job_name}

      tasks:
        - task_key: hello
          notebook_task:
            notebook_path: ../src/sample_notebook.py
EOF_SAMPLE_JOB_JOB_YML

cat > m3demo/resources/sample_job.job.yml.cluster <<'EOF_SAMPLE_JOB_JOB_YML_CLUSTER'
# Fallback for a workspace without serverless compute.
#
#   mv resources/sample_job.job.yml         resources/sample_job.job.yml.serverless
#   mv resources/sample_job.job.yml.cluster resources/sample_job.job.yml
#   databricks bundle deploy -t dev --var cluster_id=<your cluster id>
#
# Find a cluster id with:  databricks clusters list -o json | jq -r '.[] | "\(.cluster_id)  \(.cluster_name)"'
# Note the bare array: index it with .[], not .clusters[].

resources:
  jobs:
    sample_job:
      name: ${var.job_name}

      tasks:
        - task_key: hello
          existing_cluster_id: ${var.cluster_id}
          notebook_task:
            notebook_path: ../src/sample_notebook.py
EOF_SAMPLE_JOB_JOB_YML_CLUSTER

cat > m3demo/src/sample_notebook.py <<'EOF_SAMPLE_NOTEBOOK_PY'
# Databricks notebook source

# This file is a notebook because of the header line above. Without it the
# workspace imports it as a plain Python file and the task fails to start.

# COMMAND ----------

print("hello from the deployed copy")

# COMMAND ----------

# print() output does not reach the API for a notebook task. A notebook must
# exit with a value for `databricks bundle run` and the jobs API to report one.
dbutils.notebook.exit("ok")  # noqa: F821
EOF_SAMPLE_NOTEBOOK_PY

echo "created:"
find m3demo -type f | sort
echo
echo "next:  cd m3demo && databricks bundle validate"
