#!/usr/bin/env bash
# Recreates the m4demo bundle in the current directory.
#
#   bash make-m4-bundle.sh
#   cd m4demo
#   databricks bundle validate       # no setup step: cluster_id is pinned
#
# One job, five tasks, three targets. Every task runs on ONE EXISTING all-purpose
# cluster, Training_Cluster, pinned by id in databricks.yml, because the training
# workspace does not permit this credential to create clusters. If that cluster is
# recreated the id goes stale; capture-run.sh checks it before deploying. The
# job_clusters form the slides teach ships alongside, inert, as *.jobclusters —
# see m4demo/COMPUTE.md.
#
# No Python wheel, so uv is not required; nothing is written to Unity Catalog, so
# a writable catalog is not required. This is the end state of Challenges 1 to 4.
#
# Generated from the bundle validated with Databricks CLI v1.12.1 for all three
# targets, in both compute forms. Regenerate this script rather than editing it
# by hand; the bundle itself is also committed under assets/m4demo/.

set -euo pipefail

if [ -e m4demo ]; then
  echo "m4demo already exists here; move it aside first" >&2
  exit 1
fi
mkdir -p m4demo/resources m4demo/src

cat > m4demo/.gitignore <<'EOF__GITIGNORE'
.databricks/
build/
dist/
__pycache__/
*.egg-info
.venv/
capture/
EOF__GITIGNORE

cat > m4demo/COMPUTE.md <<'EOF_COMPUTE_MD'
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
EOF_COMPUTE_MD

cat > m4demo/README.md <<'EOF_README_MD'
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
EOF_README_MD

cat > m4demo/capture-run.sh <<'EOF_CAPTURE_RUN_SH'
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
EOF_CAPTURE_RUN_SH

cat > m4demo/cluster-env.sh <<'EOF_CLUSTER_ENV_SH'
#!/usr/bin/env bash
# OPTIONAL. databricks.yml already pins cluster_id to Training_Cluster, so the
# bundle runs without this script. Use it to point the bundle at a DIFFERENT
# cluster without editing the file, or to re-read the id after Training_Cluster
# has been recreated.
#
# SOURCE it, do not run it — a subshell's exports do not survive:
#
#   source ./cluster-env.sh                    # re-reads Training_Cluster
#   source ./cluster-env.sh My_Other_Cluster
#
# It exports BUNDLE_VAR_cluster_id, which is source 4 of the five on slide S48 and
# therefore outranks the default in databricks.yml. Print what is in effect with:
#   databricks bundle validate -o json | jq -r .variables.cluster_id.value

_m4_cluster_name="${1:-Training_Cluster}"

if ! command -v jq >/dev/null 2>&1; then
  echo "cluster-env.sh: jq is required" >&2
  return 1 2>/dev/null || exit 1
fi

# clusters list -o json prints a BARE ARRAY, so it is indexed with .[] and not
# .clusters[]. This catches people every time.
_m4_json=$(databricks clusters list -o json 2>/dev/null) || {
  echo "cluster-env.sh: databricks clusters list failed — check your profile" >&2
  return 1 2>/dev/null || exit 1
}

_m4_id=$(printf '%s' "$_m4_json" \
  | jq -r --arg n "$_m4_cluster_name" '.[] | select(.cluster_name==$n) | .cluster_id' \
  | head -1)

if [ -z "${_m4_id:-}" ] || [ "$_m4_id" = null ]; then
  echo "cluster-env.sh: no cluster named '$_m4_cluster_name'. Available:" >&2
  printf '%s' "$_m4_json" | jq -r '.[] | "  \(.cluster_id)  \(.cluster_name)  [\(.state // "?")]"' >&2
  unset _m4_cluster_name _m4_json _m4_id
  return 1 2>/dev/null || exit 1
fi

export BUNDLE_VAR_cluster_id="$_m4_id"
_m4_state=$(printf '%s' "$_m4_json" \
  | jq -r --arg n "$_m4_cluster_name" '.[] | select(.cluster_name==$n) | .state' | head -1)

echo "BUNDLE_VAR_cluster_id=$BUNDLE_VAR_cluster_id   ($_m4_cluster_name, $_m4_state)"
if [ "$_m4_state" != RUNNING ]; then
  echo "note: the cluster is $_m4_state. The first task will start it, which takes a few minutes."
fi
unset _m4_cluster_name _m4_json _m4_id _m4_state
EOF_CLUSTER_ENV_SH

cat > m4demo/databricks.yml <<'EOF_DATABRICKS_YML'
# m4demo — the end state of Module 4, ready to deploy.
#
# One job, five tasks, three targets. Every task runs on ONE EXISTING all-purpose
# cluster, claimed by id through the cluster_id variable, because the training
# workspace does not permit this credential to create clusters:
#
#   PERMISSION_DENIED: You are not authorized to create clusters.
#
# Set the id once per shell and no command needs a flag:
#
#   source ./cluster-env.sh          # looks up Training_Cluster by name
#
# The job_clusters form the slides teach is kept alongside, inert, as
# databricks.yml.jobclusters and resources/ingest.job.yml.jobclusters. COMPUTE.md
# explains the difference and how to switch if the permission is ever granted.
#
# There is no Python wheel, so uv is not required, and nothing is written to Unity
# Catalog, so a writable catalog is not required either.
#
# Validated with Databricks CLI v1.12.1 for all three targets.

bundle:
  name: m4demo

include:
  - resources/*.yml

variables:

  catalog:
    description: The catalog the tasks are told to write into
    default: main

  schema:
    description: The schema the tasks are told to write into
    default: default

  # Pinned to the training workspace's one all-purpose cluster, Training_Cluster,
  # so that the bundle runs with no setup step. Two things follow from that, and
  # both are worth saying out loud when this file is on screen:
  #
  #  1. This id is workspace-specific, so this bundle cannot be promoted to a
  #     second workspace as it stands. That is the same objection Part C raises
  #     against the existing_cluster_id that bundle generate job leaves behind
  #     (S17, S29). It is accepted here because the credential may not create
  #     clusters, which is a permission that outranks the preference.
  #  2. If Training_Cluster is deleted and recreated, this id goes stale and the
  #     failure appears at run time. capture-run.sh checks the id still exists
  #     before it deploys anything.
  #
  # Override it without editing the file, using either of the two sources that
  # outrank a declaration's default (S48):
  #   source ./cluster-env.sh Another_Cluster     # sets BUNDLE_VAR_cluster_id
  #   databricks bundle deploy -t dev --var cluster_id=0815-...
  cluster_id:
    description: Id of the existing all-purpose cluster every task runs on
    default: 0318-031919-b3fa4xtr

targets:

  dev:
    mode: development
    default: true
    variables:
      catalog: main
      schema: ${workspace.current_user.short_name}

  staging:
    mode: production
    workspace:
      root_path: /Workspace/Users/${workspace.current_user.userName}/.bundle/${bundle.name}/${bundle.target}
    variables:
      catalog: main
      schema: staging
    permissions:
      - user_name: ${workspace.current_user.userName}
        level: CAN_MANAGE

    # The merge-by-key demonstration, moved from job_clusters to tasks. This
    # names ONE task and ONE field; everything else about publish — its two
    # depends_on entries, its cluster, its notebook, its parameters — is
    # inherited from resources/ingest.job.yml.shared and is not repeated here.
    #
    # Check it with:
    #   databricks bundle validate -t staging -o json \
    #     | jq -r '.resources.jobs.ingest.tasks[] | "\(.task_key) retries=\(.max_retries // 0)"'
    #
    # And note the same trap as the job_clusters version: a mistyped task_key
    # is APPENDED as a new task rather than reported. Count the tasks — five is
    # correct, six means a typo.
    resources:
      jobs:
        ingest:
          tasks:
            - task_key: publish
              max_retries: 1

  prod:
    mode: production
    workspace:
      root_path: /Workspace/Users/${workspace.current_user.userName}/.bundle/${bundle.name}/${bundle.target}
    variables:
      catalog: main
      schema: prod
    permissions:
      - user_name: ${workspace.current_user.userName}
        level: CAN_MANAGE
    resources:
      jobs:
        ingest:
          tasks:
            - task_key: publish
              max_retries: 3
          trigger:
            periodic:
              interval: 1
              unit: DAYS
EOF_DATABRICKS_YML

cat > m4demo/databricks.yml.jobclusters <<'EOF_DATABRICKS_YML_JOBCLUSTERS'
# m4demo — the end state of Module 4, ready to deploy.
#
# One job, five tasks, three job clusters, three targets. Classic compute only:
# every task runs on a job cluster this bundle declares. There is no Python
# wheel, so uv is not required, and no pipeline, so a writable Unity Catalog
# catalog is not required either.
#
# The workspace host is deliberately absent. The CLI takes it from your profile
# or from DATABRICKS_HOST, and interpolation is not permitted on that field:
#
#   Error: Interpolation is not supported for the field workspace.host. Please
#   set the DATABRICKS_HOST environment variable if you wish to configure this
#   field at runtime.
#
# Validated with Databricks CLI v1.12.1 for all three targets.

bundle:
  name: m4demo

include:
  - resources/*.yml

# ---------------------------------------------------------------- variables ---
# Five sources of a value, lowest precedence first (S48):
#   1 default:  2 the target's variables: block
#   3 .databricks/bundle/<target>/variable-overrides.json
#   4 BUNDLE_VAR_<name>  5 --var name=value
# Note the environment variable prefix: BUNDLE_VAR_, not DATABRICKS_BUNDLE_VAR_.
variables:

  catalog:
    description: The catalog the tasks are told to write into
    default: main

  schema:
    description: The schema the tasks are told to write into
    default: default

  # A complex variable holds an entire mapping, and a target assignment
  # REPLACES it rather than merging into it (S49, S50). Compare with the
  # targets.<t>.resources override further down, which merges.
  features_cluster:
    description: The cluster the features task runs on
    type: complex
    default:
      spark_version: 16.4.x-scala2.12
      node_type_id: Standard_D3_v2
      data_security_mode: DATA_SECURITY_MODE_AUTO
      num_workers: 2

# ------------------------------------------------------------------ targets ---
targets:

  # -- dev ---------------------------------------------------------------------
  # mode: development computes presets rather than enforcing constraints:
  # a [dev <short name>] name prefix, a dev tag, paused triggers, and
  # max_concurrent_runs of 4. Read them with:
  #   databricks bundle validate -o json | jq '.presets'
  dev:
    mode: development
    default: true
    variables:
      catalog: main
      schema: ${workspace.current_user.short_name}
      # features_cluster is not assigned here, so the default above applies:
      # num_workers 2.

  # -- staging -----------------------------------------------------------------
  # mode: production computes no presets and enforces constraints instead,
  # which is why root_path and permissions are stated explicitly.
  staging:
    mode: production
    workspace:
      root_path: /Workspace/Users/${workspace.current_user.userName}/.bundle/${bundle.name}/${bundle.target}
    variables:
      catalog: main
      schema: staging
      # Whole-value replacement. There is no autoscale here and none is
      # inherited from the default, so the resolved cluster has num_workers only.
      features_cluster:
        spark_version: 16.4.x-scala2.12
        node_type_id: Standard_D3_v2
        data_security_mode: DATA_SECURITY_MODE_AUTO
        num_workers: 4
    permissions:
      - user_name: ${workspace.current_user.userName}
        level: CAN_MANAGE

    # A resource override MERGES field by field into the base declaration (S44).
    # Entries of job_clusters are matched on job_cluster_key and entries of
    # tasks on task_key. A key matching nothing is APPENDED, silently, so a
    # misspelling here produces a second cluster no task claims (S46, S47).
    # The check is to count them:
    #   databricks bundle validate -t staging -o json \
    #     | jq -r '.resources.jobs.ingest.job_clusters[].job_cluster_key'
    # Three entries is correct. Four means a typo above.
    resources:
      jobs:
        ingest:
          job_clusters:
            - job_cluster_key: main      # merges: runtime and node type survive
              new_cluster:
                autoscale:
                  min_workers: 2
                  max_workers: 6

  # -- prod --------------------------------------------------------------------
  # Not deployed in this course. It is here so that the shape of a promotion
  # target is visible and so that bundle validate -t prod can be read.
  prod:
    mode: production
    workspace:
      root_path: /Workspace/Users/${workspace.current_user.userName}/.bundle/${bundle.name}/${bundle.target}
    variables:
      catalog: main
      schema: prod
      features_cluster:
        spark_version: 16.4.x-scala2.12
        node_type_id: Standard_D3_v2
        data_security_mode: DATA_SECURITY_MODE_AUTO
        num_workers: 8
    permissions:
      - user_name: ${workspace.current_user.userName}
        level: CAN_MANAGE
    resources:
      jobs:
        ingest:
          job_clusters:
            - job_cluster_key: main
              new_cluster:
                autoscale:
                  min_workers: 4
                  max_workers: 12
          # A schedule belongs in the target, not the base: dev must not fire it.
          # production mode leaves it UNPAUSED; development mode would pause it.
          trigger:
            periodic:
              interval: 1
              unit: DAYS
EOF_DATABRICKS_YML_JOBCLUSTERS

cat > m4demo/resources/ingest.job.yml <<'EOF_RESOURCES_INGEST_JOB_YML'
# The job Module 4 builds up, in its final form.
#
# Five tasks, one fan-out and one fan-in. Every task claims ONE existing
# all-purpose cluster by id, because this workspace does not permit the
# credential to create clusters. Tasks sharing one all-purpose cluster still run
# concurrently, so features and quality remain genuinely parallel and the graph
# Part D teaches is observable in the run history.
#
# Slide references are given so that a construct on a slide can be found here and
# the reverse. Three slides describe job_clusters, which this file does not
# declare — S20, S21 and S22 — and are taught by reading
# resources/ingest.job.yml.jobclusters instead. See COMPUTE.md.

resources:
  jobs:
    ingest:
      name: sales_ingest
      max_concurrent_runs: 1
      timeout_seconds: 0

      # No job_clusters block at all. Declaring one and not claiming it would
      # still make the job try to create it.

      tasks:

        - task_key: land
          existing_cluster_id: ${var.cluster_id}
          notebook_task:
            notebook_path: ../src/land.py
            base_parameters:
              catalog: ${var.catalog}
              schema: ${var.schema}

        - task_key: features
          depends_on:
            - task_key: land
          existing_cluster_id: ${var.cluster_id}
          max_retries: 2
          min_retry_interval_millis: 60000
          notebook_task:
            notebook_path: ../src/features.py
            base_parameters:
              catalog: ${var.catalog}
              schema: ${var.schema}

        - task_key: quality
          depends_on:
            - task_key: land
          existing_cluster_id: ${var.cluster_id}
          notebook_task:
            notebook_path: ../src/quality.py
            base_parameters:
              catalog: ${var.catalog}
              schema: ${var.schema}

        - task_key: publish
          depends_on:
            - task_key: features
            - task_key: quality
          existing_cluster_id: ${var.cluster_id}
          notebook_task:
            notebook_path: ../src/publish.py
            base_parameters:
              catalog: ${var.catalog}
              schema: ${var.schema}

        - task_key: notify
          depends_on:
            - task_key: publish
          run_if: ALL_DONE
          existing_cluster_id: ${var.cluster_id}
          notebook_task:
            notebook_path: ../src/notify.py
EOF_RESOURCES_INGEST_JOB_YML

cat > m4demo/resources/ingest.job.yml.jobclusters <<'EOF_RESOURCES_INGEST_JOB_YML_JOBCLUSTERS'
# The job Module 4 builds up, in its final form.
#
# Five tasks, one fan-out and one fan-in, three job clusters. Slide references
# are given so that a construct on a slide can be found here and the reverse.

resources:
  jobs:
    ingest:                                     # the resource key (S7)
      name: sales_ingest                        # what the workspace displays (S7)
      max_concurrent_runs: 1                    # job-level keys (S15)
      timeout_seconds: 0

      # job_clusters is declared on the JOB, not on a task (S18). Each entry
      # requires exactly job_cluster_key and new_cluster.
      job_clusters:

        - job_cluster_key: main
          new_cluster:
            spark_version: 16.4.x-scala2.12     # the LTS runtime (S20)
            node_type_id: Standard_D3_v2
            data_security_mode: DATA_SECURITY_MODE_AUTO
            autoscale:                          # a range, not a fixed count (S21)
              min_workers: 1
              max_workers: 3

        # This one comes from a complex variable, so a target can replace the
        # whole specification in one assignment (S49).
        - job_cluster_key: features
          new_cluster: ${var.features_cluster}

        - job_cluster_key: quality
          new_cluster:
            spark_version: 16.4.x-scala2.12
            node_type_id: Standard_D3_v2
            data_security_mode: DATA_SECURITY_MODE_AUTO
            num_workers: 2                      # a fixed count (S21)

      tasks:

        # The root. No depends_on, so it starts when the run starts (S33).
        - task_key: land
          job_cluster_key: main                 # the claim on a cluster (S19)
          notebook_task:
            notebook_path: ../src/land.py       # relative to THIS file (S11)
            base_parameters:
              catalog: ${var.catalog}
              schema: ${var.schema}

        # features and quality both depend on land and on nothing else, so they
        # start together. They have separate clusters, which is what makes the
        # parallelism real rather than declared (S22, S35).
        - task_key: features
          depends_on:
            - task_key: land
          job_cluster_key: features
          # Retries re-run this task on the same cluster and do not re-run land
          # (S38). features is the task that reads from outside, so a transient
          # failure here is the one a second attempt can survive.
          max_retries: 2
          min_retry_interval_millis: 60000
          notebook_task:
            notebook_path: ../src/features.py
            base_parameters:
              catalog: ${var.catalog}
              schema: ${var.schema}

        - task_key: quality
          depends_on:
            - task_key: land
          job_cluster_key: quality
          notebook_task:
            notebook_path: ../src/quality.py
            base_parameters:
              catalog: ${var.catalog}
              schema: ${var.schema}

        # The fan-in. One depends_on block with two entries, not two blocks.
        - task_key: publish
          depends_on:
            - task_key: features
            - task_key: quality
          job_cluster_key: main
          notebook_task:
            notebook_path: ../src/publish.py
            base_parameters:
              catalog: ${var.catalog}
              schema: ${var.schema}

        # run_if: ALL_DONE is what makes this run whether or not the pipeline
        # succeeded (S36). It is the reason notify still reports SUCCESS in the
        # broken run of Challenge 5.
        - task_key: notify
          depends_on:
            - task_key: publish
          run_if: ALL_DONE
          job_cluster_key: main
          notebook_task:
            notebook_path: ../src/notify.py
EOF_RESOURCES_INGEST_JOB_YML_JOBCLUSTERS

cat > m4demo/src/features.py <<'EOF_SRC_FEATURES_PY'
# Databricks notebook source

# COMMAND ----------

dbutils.widgets.text("catalog", "")   # noqa: F821
dbutils.widgets.text("schema", "")    # noqa: F821

catalog = dbutils.widgets.get("catalog")   # noqa: F821
schema = dbutils.widgets.get("schema")     # noqa: F821

# COMMAND ----------

# This task and `quality` both depend only on `land`, so they start together.
# They run on separate job clusters, which is what turns that into real
# parallelism rather than two tasks queued on one cluster.
from pyspark.sql import functions as F

rows = [(i, f"order-{i}", (i % 7) * 1.5) for i in range(1, 501)]
df = spark.createDataFrame(rows, "id int, ref string, amount double")   # noqa: F821

features = (
    df.withColumn("amount_band", F.when(F.col("amount") > 6.0, "high").otherwise("low"))
      .groupBy("amount_band")
      .agg(F.count("*").alias("n"), F.round(F.avg("amount"), 2).alias("avg_amount"))
)
features.show()

built = features.count()
print(f"built {built} feature bands for {catalog}.{schema}")

# COMMAND ----------

dbutils.notebook.exit(f"bands={built} target={catalog}.{schema}")   # noqa: F821
EOF_SRC_FEATURES_PY

cat > m4demo/src/features.py.broken <<'EOF_SRC_FEATURES_PY_BROKEN'
# Databricks notebook source

# Challenge 5, step 5.2. This is `features.py` with one closing parenthesis
# removed, which is enough for the task to fail at import time.
#
#   cp src/features.py.broken src/features.py     # break it
#   git checkout src/features.py                  # or restore from the copy you kept
#
# Expected states for the run that follows:
#   land     SUCCESS           your code
#   features FAILED            your code, after 2 retries
#   quality  SUCCESS           your code — a sibling, not a descendant
#   publish  UPSTREAM_FAILED   the platform
#   notify   SUCCESS           the platform let it run: run_if: ALL_DONE

# COMMAND ----------

dbutils.widgets.text("catalog", "")   # noqa: F821
dbutils.widgets.text("schema", "")    # noqa: F821

catalog = dbutils.widgets.get("catalog")   # noqa: F821
schema = dbutils.widgets.get("schema")     # noqa: F821

# COMMAND ----------

from pyspark.sql import functions as F

rows = [(i, f"order-{i}", (i % 7) * 1.5) for i in range(1, 501)]
df = spark.createDataFrame(rows, "id int, ref string, amount double")   # noqa: F821

features = (
    df.withColumn("amount_band", F.when(F.col("amount") > 6.0, "high").otherwise("low")
      .groupBy("amount_band")
      .agg(F.count("*").alias("n"), F.round(F.avg("amount"), 2).alias("avg_amount"))
)
features.show()

built = features.count()
print(f"built {built} feature bands for {catalog}.{schema}")

# COMMAND ----------

dbutils.notebook.exit(f"bands={built} target={catalog}.{schema}")   # noqa: F821
EOF_SRC_FEATURES_PY_BROKEN

cat > m4demo/src/land.py <<'EOF_SRC_LAND_PY'
# Databricks notebook source

# The header line above is what makes this a notebook rather than a Python
# file. Without it, bundle validate refuses the task:
#   Error: expected a notebook for "...notebook_path" but got a file

# COMMAND ----------

dbutils.widgets.text("catalog", "")   # noqa: F821
dbutils.widgets.text("schema", "")    # noqa: F821

catalog = dbutils.widgets.get("catalog")   # noqa: F821
schema = dbutils.widgets.get("schema")     # noqa: F821

# COMMAND ----------

# Genuine Spark work, so the job cluster is actually exercised, but nothing is
# written: this bundle never touches Unity Catalog, so it cannot fail on a
# missing grant. The catalog and schema are carried through and reported so the
# difference between targets is visible in the run output.
rows = [(i, f"order-{i}", (i % 7) * 1.5) for i in range(1, 501)]
raw = spark.createDataFrame(rows, "id int, ref string, amount double")   # noqa: F821
landed = raw.count()

print(f"landed {landed} rows, destined for {catalog}.{schema}")

# COMMAND ----------

# print() output does not reach the API for a notebook task. A notebook has to
# exit with a value for `databricks bundle run` and the Jobs API to report one.
dbutils.notebook.exit(f"landed={landed} target={catalog}.{schema}")   # noqa: F821
EOF_SRC_LAND_PY

cat > m4demo/src/notify.py <<'EOF_SRC_NOTIFY_PY'
# Databricks notebook source

# COMMAND ----------

# This task declares run_if: ALL_DONE, so it runs whether or not the pipeline
# succeeded. It takes no parameters: a notification does not need to know the
# catalog, and giving it one would be a dependency it does not have.
print("pipeline finished")

# COMMAND ----------

dbutils.notebook.exit("notified")   # noqa: F821
EOF_SRC_NOTIFY_PY

cat > m4demo/src/publish.py <<'EOF_SRC_PUBLISH_PY'
# Databricks notebook source

# COMMAND ----------

dbutils.widgets.text("catalog", "")   # noqa: F821
dbutils.widgets.text("schema", "")    # noqa: F821

catalog = dbutils.widgets.get("catalog")   # noqa: F821
schema = dbutils.widgets.get("schema")     # noqa: F821

# COMMAND ----------

# The fan-in. This task declares one depends_on block with two entries, so it
# waits for both features and quality. If either fails, this task is reported
# UPSTREAM_FAILED and never runs.
#
# Nothing is written. In a real pipeline this is where the write would be, and
# it is the reason a retry on this task would need the write to be idempotent.
target = f"{catalog}.{schema}.sales_daily"
print(f"would publish to {target}")

# COMMAND ----------

dbutils.notebook.exit(f"published={target}")   # noqa: F821
EOF_SRC_PUBLISH_PY

cat > m4demo/src/quality.py <<'EOF_SRC_QUALITY_PY'
# Databricks notebook source

# COMMAND ----------

dbutils.widgets.text("catalog", "")   # noqa: F821
dbutils.widgets.text("schema", "")    # noqa: F821

catalog = dbutils.widgets.get("catalog")   # noqa: F821
schema = dbutils.widgets.get("schema")     # noqa: F821

# COMMAND ----------

# A sibling of `features`, not a descendant. When features fails, this one still
# succeeds, and that is the state pair Challenge 5 asks you to predict.
rows = [(i, f"order-{i}", (i % 7) * 1.5) for i in range(1, 501)]
df = spark.createDataFrame(rows, "id int, ref string, amount double")   # noqa: F821

nulls = df.filter("ref is null or amount is null").count()
negative = df.filter("amount < 0").count()
total = df.count()

print(f"checked {total} rows: {nulls} null, {negative} negative")

if nulls or negative:
    raise ValueError(f"quality gate failed: {nulls} null, {negative} negative")

# COMMAND ----------

dbutils.notebook.exit(f"checked={total} nulls=0 negative=0")   # noqa: F821
EOF_SRC_QUALITY_PY

chmod +x m4demo/capture-run.sh m4demo/cluster-env.sh

echo "created:"
find m4demo -type f | sort
echo
echo "next:"
echo "  cd m4demo"
echo "  databricks bundle validate"
echo "  bash capture-run.sh --phase promote   # resolves only, no deployment"
