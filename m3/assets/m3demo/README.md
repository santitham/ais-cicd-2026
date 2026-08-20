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
