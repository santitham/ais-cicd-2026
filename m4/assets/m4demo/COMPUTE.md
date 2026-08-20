# Compute in this bundle, and why

## What ships live

Every task in `resources/ingest.job.yml` claims **one existing all-purpose cluster** by
id:

```yaml
- task_key: land
  existing_cluster_id: ${var.cluster_id}
```

`cluster_id` is **pinned in `databricks.yml`** to the training workspace's cluster, so
the bundle runs with no setup step at all:

```yaml
  cluster_id:
    description: Id of the existing all-purpose cluster every task runs on
    default: 0318-031919-b3fa4xtr
```

Two consequences, and both are worth saying out loud when this file is on screen.

**The id is workspace-specific, so this bundle cannot be promoted as it stands.** That is
the same objection Part C raises against the `existing_cluster_id` that
`bundle generate job` leaves behind (S17, S29). It is accepted here because a permission
outranks a preference: the credential may not create clusters, so there is no other way
to run. Saying that plainly is better teaching than hiding it — students will meet the
same trade-off.

**A pinned id goes stale.** If `Training_Cluster` is deleted and recreated its id
changes, and the failure would otherwise appear only after a successful deploy.
`capture-run.sh` therefore resolves `cluster_id` and confirms the cluster exists before it
deploys anything, and prints the available clusters if it does not.

### Overriding without editing the file

Two of the five sources on S48 outrank a declaration's default, and the bundle
demonstrates both. Verified:

| Supplied by | Resolved `cluster_id` |
|---|---|
| the `default:` above | `0318-031919-b3fa4xtr` |
| `BUNDLE_VAR_cluster_id=OVERRIDE-1` | `OVERRIDE-1` |
| `BUNDLE_VAR_...=OVERRIDE-1` **and** `--var cluster_id=OVERRIDE-2` | `OVERRIDE-2` |

```bash
source ./cluster-env.sh Another_Cluster     # looks a name up, exports the id
databricks bundle deploy -t dev --var cluster_id=0815-...
databricks bundle validate -o json | jq -r .variables.cluster_id.value   # what is in effect
```

`cluster-env.sh` is optional now — an override helper and a way to re-read the id after
the cluster has been recreated, not a prerequisite. It must be **sourced**, not run.

## Why, and not job clusters

The slides teach `job_clusters`, and Part B gives a reason to prefer them:
`existing_cluster_id` pins a task to one cluster in one workspace, so a bundle carrying
it cannot be promoted. That objection is correct. It is also overridden by the
permission model of this workspace, which is a fact about production Databricks worth
teaching rather than hiding.

On the training workspace, the credential may not create clusters. The job-cluster form
deploys perfectly and then fails at the first run:

```
2026-08-16 15:02:47 "[dev santitham_pro] sales_ingest" INTERNAL_ERROR FAILED
Task land failed with message: Unexpected user error while preparing the cluster for
the job. Cause: PERMISSION_DENIED: You are not authorized to create clusters.
Please contact your administrator.
```

Three things about that output are worth pointing at in the lecture.

`deploy` **succeeded**. The job exists and has an id. Nothing in the declaration is at
fault, which is why question 1 of the recipe on S58 matters: the command that failed was
`run`, so the cause is not a configuration defect.

The run terminated **`INTERNAL_ERROR`**, not `TERMINATED`. That word plus the phrase
*preparing the cluster* is the signature of an infrastructure failure rather than a code
failure.

`notify` reported **`FAILED`**, despite declaring `run_if: ALL_DONE`. `ALL_DONE` governs
what happens when a dependency *finishes* in a bad state; this run never started a
cluster, so it never got that far. The Challenge 5 prediction table describes a failure
in your code, where `notify` does report `SUCCESS`.

## What is preserved on a shared cluster

The five tasks, the fan-out, the fan-in, `run_if: ALL_DONE`, the retry on `features`, and
the parameters. **`features` and `quality` still run concurrently**, because several
tasks can share one all-purpose cluster — so the parallelism Part D teaches remains
observable in the run history. Runs are also much faster, because nothing has to start.

## What changes, and what it costs the lecture

`job_clusters` is gone, so the target overrides act on a **task** instead. Same
merge-by-key rule as S44 and S45, on the key that still exists:

```yaml
targets:
  staging:
    resources:
      jobs:
        ingest:
          tasks:
            - task_key: publish
              max_retries: 1
```

Verified: `publish` alone carries the retry, and keeps its two `depends_on` entries, its
cluster and its notebook, none of which are repeated in the override.

```bash
databricks bundle validate -t staging -o json \
  | jq -r '.resources.jobs.ingest.tasks[] | "\(.task_key) retries=\(.max_retries // 0)"'
```

| | dev | staging | prod |
|---|---|---|---|
| job name | `[dev <short>] sales_ingest` | `sales_ingest` | `sales_ingest` |
| `job_clusters` declared | 0 | 0 | 0 |
| tasks | 5 | 5 | 5 |
| `publish` retries | 0 | 1 | 3 |
| trigger | none | none | daily, `UNPAUSED` |

**The silent-append trap of S46 and S47 survives, and is worse here.** Mistyping
`task_key: publish` as `publsh` gives `Validation OK!` and **six** tasks — the five real
ones plus a phantom with no cluster and no payload key at all:

```
tasks now: 6
  features  cluster=0815-...  payload=notebook
  land      cluster=0815-...  payload=notebook
  notify    cluster=0815-...  payload=notebook
  publish   cluster=0815-...  payload=notebook
  publsh    cluster=NONE      payload=NONE
  quality   cluster=0815-...  payload=notebook
```

Counting is still the only check. Five is correct; six means a typo.

Three slides describe `job_clusters` and cannot be demonstrated from the live files.
Teach them by reading `resources/ingest.job.yml.jobclusters`, which is the same job
declared the other way and is kept for exactly this purpose.

| Slide | Why it cannot be run |
|---|---|
| S20 the fields of `new_cluster` | there is no `new_cluster` in the live files |
| S21 `num_workers` or `autoscale` | same |
| S22 one cluster for the job, or one for each task | the job has no cluster of its own |

S17 needs one spoken sentence: it lists `existing_cluster_id` and gives the promotion
objection, and on this workspace that is the only available option. Say so; the
objection stands and the permission wins.

## Switching to job clusters, if the permission is granted

The job-cluster form is kept alongside, inert, because `include: [resources/*.yml]` does
not match a `.jobclusters` suffix. Swap **both** files together — they are a pair, and
the target overrides differ between them:

```bash
mv databricks.yml                       databricks.yml.shared
mv resources/ingest.job.yml             resources/ingest.job.yml.shared
mv databricks.yml.jobclusters           databricks.yml
mv resources/ingest.job.yml.jobclusters resources/ingest.job.yml
unset BUNDLE_VAR_cluster_id
```

That form declares three job clusters — `main`, `features`, `quality` — and overrides
their sizes per target: `main` by `targets.<t>.resources` merge (autoscale 1–3 / 2–6 /
4–12) and `features` by a `complex` variable replacement (2 / 4 / 8 workers). Both were
validated for all three targets. Expect 12 to 18 minutes per run, because three clusters
have to start.

## Fixing the cause instead

The credential needs the **Allow unrestricted cluster creation** entitlement, or
`CAN_USE` on a cluster policy. A policy is the better answer for a training workspace:
it caps node type, worker count and autotermination, so a room of participants can create
job clusters without being able to create expensive ones. With that in place the module
runs exactly as the slides describe, and `assets/prep-ubuntu-m4.sh` check 6 will say so.
