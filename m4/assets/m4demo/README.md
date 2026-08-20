# m4demo — the Module 4 example, ready to deploy

One job, five tasks, three targets. This is the end state of Challenges 1 to 4, so it
is what the instructor demonstrates and what a participant who fell behind is given.

Every task runs on **one existing all-purpose cluster**, `Training_Cluster`, pinned by id
in `databricks.yml`, because the training workspace does not permit this credential to
create clusters. `COMPUTE.md` explains that decision, what it costs three of the slides,
and how to switch to the `job_clusters` form the slides teach if the permission is ever
granted — that form ships alongside, inert, as `*.jobclusters`.

There is no Python wheel, so `uv` is not required, and nothing is written to Unity
Catalog, so a writable catalog is not required either — the `catalog` and `schema`
variables are passed to the notebooks and reported back, which is enough to show the
difference between targets without depending on a grant.

Validated with Databricks CLI v1.12.1 for all three targets, in both compute forms.

## Run it

```bash
cd m4demo
databricks bundle validate                  # confirms the profile, the host, the paths
databricks bundle plan     -t dev           # what a deployment would do
databricks bundle deploy   -t dev
databricks bundle run ingest -t dev
databricks bundle summary  -t dev
databricks bundle destroy  -t dev
```

There is nothing to edit first. The workspace host comes from your CLI profile or from
`DATABRICKS_HOST`; this file does not name one, because interpolation is not permitted
on that field:

```
Error: Interpolation is not supported for the field workspace.host. Please set the
DATABRICKS_HOST environment variable if you wish to configure this field at runtime.
```

If you use a named profile, add `-p <profile>` to every command or export
`DATABRICKS_CONFIG_PROFILE`.

No setup step. `cluster_id` is pinned in `databricks.yml` to `Training_Cluster`
(`0318-031919-b3fa4xtr`). To point at a different cluster without editing the file,
`source ./cluster-env.sh Another_Cluster` or pass `--var cluster_id=...`; both outrank the
default, per S48. `COMPUTE.md` explains what pinning a workspace-specific id costs and
why it is accepted here.

**Timing.** The cluster already exists, so nothing has to start and a full run takes a
few minutes. The `job_clusters` form would cost 12 to 18 minutes per run.

## Capture the whole lifecycle in one go

```bash
bash capture-run.sh
```

Runs validate → plan → deploy → plan again → deploy again → summary → run, then the
Challenge 5 break-and-fix, then the Challenge 4 promotion checks, then destroys. Every
command's output lands in `capture/NN-<name>.txt` with a paste-able command line as its
first line, and `capture/SUMMARY.md` maps each file to the slide or lab section it
feeds.

Three runs happen (good, broken, fixed). Before deploying anything it confirms the pinned
`cluster_id` still names a cluster that exists, because a stale id would otherwise fail
only after a successful deploy.

```bash
bash capture-run.sh --phase lifecycle    # just deploy and run, no break-fix
bash capture-run.sh --phase break        # just Challenge 5
bash capture-run.sh --phase promote      # just the target and variable checks, no deploy
bash capture-run.sh --keep               # leave the deployment in place
bash capture-run.sh -p myprofile
```

`--phase promote` never deploys anything, so it finishes in seconds and is the one to
run first to confirm the bundle resolves against your workspace.

A non-zero result for `run-broken` is expected. That failure is the artefact.

## What to look at, and where it is taught

```bash
databricks bundle validate -o json | jq '.presets'
```

Five settings that appear in no file. They are what `mode: development` computes, and
they are why the job shows as `[dev <your short name>] sales_ingest` in the workspace
while its key stays `ingest`.

```bash
databricks bundle validate -o json \
  | jq -r '.resources.jobs.ingest.tasks[]
           | "\(.task_key) <- \(.depends_on // [] | map(.task_key) | join(", "))"'
```

The graph the file actually declares (S35). Note the tasks come out in **alphabetical
order**, not file order: the resolved configuration sorts them by `task_key`. That is
also why the index in a diagnostic such as `at ...tasks[3].job_cluster_key` will not
match the file — use the file position in the message instead (S24).

```bash
databricks bundle validate -t staging -o json \
  | jq -r '.resources.jobs.ingest.tasks[] | "\(.task_key) retries=\(.max_retries // 0)"'
```

Five tasks, and `publish` alone carrying `retries=1` in staging. Count them: five is
correct, **six** means an override whose `task_key` matched nothing and was appended
silently — the one fault in the module that nothing reports (S46, S47). The phantom task
has no cluster and no payload at all, and still validates.

```bash
databricks bundle validate -t dev     -o json | jq '.resources.jobs.ingest' > /tmp/dev.json
databricks bundle validate -t staging -o json | jq '.resources.jobs.ingest' > /tmp/stg.json
diff /tmp/dev.json /tmp/stg.json
```

Challenge 4.2. The name, the tags, and `publish`'s retry count differ. The name and the
tags were not written in the staging block — they come from `mode: development` on
`dev`.

```bash
BUNDLE_VAR_schema=fromenv databricks bundle validate -t staging -o json | jq -r .variables.schema.value
DATABRICKS_BUNDLE_VAR_schema=ignored databricks bundle validate -t staging -o json | jq -r .variables.schema.value
```

`fromenv`, then `staging`. The second prefix does nothing. This is the correction to
Module 3's S24, and Challenge 4.4 has participants run exactly these two commands.

## What each target changes

| | dev | staging | prod |
|---|---|---|---|
| job name | `[dev <short>] sales_ingest` | `sales_ingest` | `sales_ingest` |
| `publish` retries | 0 | 1 | 3 |
| trigger | none | none | daily, `UNPAUSED` |
| catalog / schema | `main` / `<short>` | `main` / `staging` | `main` / `prod` |

The retry is a `targets.<t>.resources` **merge** on `task_key: publish` (S44, S45): the
override names one task and one field, and `publish` keeps its two `depends_on` entries,
its cluster and its notebook without any of them being repeated.

The `job_clusters` form in `*.jobclusters` demonstrates the same merge on cluster sizes
and adds the `complex` variable **replacement** (S49, S50). `COMPUTE.md` has both tables.

## Breaking it on purpose (Challenge 5)

```bash
cp src/features.py src/features.py.keep
cp src/features.py.broken src/features.py
databricks bundle deploy -t dev
databricks bundle run ingest -t dev
```

`features.py.broken` is `features.py` with one closing parenthesis removed. Expected
states:

| Task | State | Produced by |
|---|---|---|
| `land` | `SUCCESS` | your code |
| `features` | `FAILED`, after two retries | your code |
| `quality` | `SUCCESS` | your code — a sibling, not a descendant |
| `publish` | `UPSTREAM_FAILED` | the platform |
| `notify` | `SUCCESS` | the platform let it run: `run_if: ALL_DONE` |

The two that catch people are `quality`, which succeeds because it does not depend on
`features`, and `notify`, which runs at all. Restore with
`cp src/features.py.keep src/features.py`.

This is a failure in your **code**. An infrastructure failure looks different: the run
terminates `INTERNAL_ERROR` rather than `TERMINATED` and `notify` reports `FAILED`,
because `run_if: ALL_DONE` governs a dependency that *finished* badly and such a run
never got that far. `COMPUTE.md` has the observed output.

Note that `features` is retried twice before it fails, because it declares
`max_retries: 2`. A syntax error is not a failure a retry can survive, which is the
argument against giving retries to a task that fails deterministically (S38).

## Files

| File | What it is |
|---|---|
| `databricks.yml` | bundle identity, the include pattern, three variables, three targets |
| `resources/ingest.job.yml` | the job: five tasks on the shared cluster, annotated with slide references |
| `cluster-env.sh` | optional: **source** it to override the pinned cluster id from a name |
| `COMPUTE.md` | why the shared cluster, what it costs S20–S22, how to switch back |
| `databricks.yml.jobclusters` | the `job_clusters` form the slides teach; inert until swapped in |
| `resources/ingest.job.yml.jobclusters` | the same job with three declared clusters; inert |
| `src/land.py` | the root task: builds a small DataFrame and reports the row count |
| `src/features.py` | fans out from `land`, on its own cluster, with two retries |
| `src/features.py.broken` | the same file with a `SyntaxError`, for Challenge 5 |
| `src/quality.py` | fans out from `land`, on its own cluster; raises if a check fails |
| `src/publish.py` | the fan-in: waits for both, writes nothing |
| `src/notify.py` | `run_if: ALL_DONE`, takes no parameters |
| `capture-run.sh` | runs the whole lifecycle and records every command's output |
| `.gitignore` | excludes `.databricks/`, which holds the local deployment state, and `capture/` |

Every notebook begins with `# Databricks notebook source`. Without that line the file
is not a notebook and `bundle validate` refuses the task (S14). Every notebook also
ends with `dbutils.notebook.exit(...)`, because `print()` output does not reach the API
for a notebook task — a notebook has to exit with a value for `bundle run` and the Jobs
API to report one.

## Rehearsing faster

Nothing to do: the cluster already exists, so a run is a few minutes. If the cluster is
`TERMINATED`, the first task starts it and that is the only wait — `cluster-env.sh`
reports the state so you know in advance.
