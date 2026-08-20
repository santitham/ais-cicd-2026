# Module 4 — Lab guide

**Build, deploy, run, iterate**
Six challenges, 60 minutes of lab work in total, run between the teaching segments
rather than in one block. Challenges 1 to 5 are solo. Challenge 6 is in teams of three.

## How to read this guide

Each challenge states its time, what to do, and what success looks like. Expected output
is given for every command. Where the output was produced by executing the command it is
exact; where it depends on your workspace it is marked; where the command has not yet
been executed against a live workspace it is labelled **shape only**, meaning the fields
are right and the values and timings will differ.

| Marking | Meaning |
|---|---|
| exact | produced by running the command against Databricks CLI v1.12.1 |
| yours | correct in form; the values are specific to your workspace |
| shape only | not yet executed against a live workspace |

Challenges 3, 4, 5 and 6 each build on the bundle the previous one left behind. If a
challenge does not complete, say so at the debrief and take the solution directory
rather than working ahead — the next challenge needs a working bundle, not a correct
history. The instructor also has `assets/m4demo/`, a complete deployable bundle in the
state Challenge 4 ends in; ask for it rather than falling further behind.

---

## Pre-flight — 5 minutes, before Challenge 1

```bash
bash assets/prep-ubuntu-m4.sh
```

**Expected final lines (exact):**

```
=== Result ===
  Every check passed. You are ready for Challenge 1.
```

Seven checks. The first two are blocking, check 6 decides whether the module runs as
written, and the rest cost lab time.

| Check | Why it blocks a step |
|---|---|
| Databricks CLI v1.3.0 or later | `bundle plan` does not exist before v1.2, and earlier versions write Terraform state |
| cluster-create permission, or a cluster to borrow | every task in Challenges 1 to 5 runs on a job cluster; without the permission the deploy succeeds and the run fails |
| `databricks current-user me` succeeds | every command this afternoon authenticates as you |
| at least one Unity Catalog catalog | `bundle init` asks for one, and every task writes into it |
| `jq` | used to read resolved configuration in Challenges 1, 3, 4, 5 and 6 |
| runtime `16.4.x-scala2.12` offered | the value every cluster specification in the slides names |
| node type `Standard_D3_v2` available | availability is regional; substitute a listed type if it is absent |

**`uv` is not required this afternoon.** Module 3 needed it because `default-python`
declares a wheel artifact. Module 4 uses `default-minimal`, which declares none.

### Create the bundle

```bash
cd ~
databricks bundle init default-minimal
```

| Prompt | Answer |
|---|---|
| Project name | `m4demo_<your initials>` |
| Default catalog | one the pre-flight listed |

Letters, digits and underscores only; a hyphen is rejected before anything is written.

```bash
cd m4demo_<your initials>
mkdir -p resources src
databricks bundle validate
```

**Expected (yours):**

```
Name: m4demo_jq
Target: dev
Workspace:
  Host: https://adb-....azuredatabricks.net
  User: you@example.com
  Path: /Workspace/Users/you@example.com/.bundle/m4demo_jq/dev

Validation OK!
```

`Validation OK!` on a bundle with no resources is correct: `include: [resources/*.yml]`
matches nothing, and a glob matching nothing is not an error.

---

## Challenge 1 — Author a job on a job cluster

**8 minutes. Write the file yourself.**

Full requirements are in `assets/challenge1-requirements.md`. In summary: a new file
`resources/ingest.job.yml`, one job keyed `ingest` named `sales_ingest`, one job cluster
keyed `main` on the course runtime and instance type autoscaling one to three workers,
and one task keyed `land` claiming that cluster and running a notebook you create at
`src/land.py`, receiving `catalog` and `schema` as base parameters.

Do not open an existing resource file. The point of the exercise is that you can write
one.

**Before you validate**, write down the workspace path you expect `notebook_path` to
resolve to.

```bash
databricks bundle validate
```

**Expected (yours):** the header above, then `Validation OK!`.

```bash
databricks bundle validate -o json \
  | jq -r '.resources.jobs.ingest.tasks[0].notebook_task.notebook_path'
```

**Expected (exact, with your user name and project):**

```
/Workspace/Users/santitham.pro@kmutt.ac.th/.bundle/m4demo_jq/dev/files/src/land
```

Three failures to expect.

A path that still ends in `.py` means you wrote `spark_python_task` rather than
`notebook_task`; the notebook form strips the extension and the Python form does not.

```
Error: expected a notebook for "resources.jobs.ingest.tasks[0].notebook_task
.notebook_path" but got a file: file at .../src/land.py is not a notebook
```

means `src/land.py` does not begin with `# Databricks notebook source`.

```
Error: notebook src/land.py not found
```

means the file does not exist, or `notebook_path` says `src/land.py` where it must say
`../src/land.py`. The path is relative to `resources/ingest.job.yml`, not to the bundle
root.

**Success:** `Validation OK!`, and a resolved path matching what you wrote down.

---

## Challenge 2 — Port a job and repair it

**10 minutes.**

The instructor has created a job in the workspace by hand, on an interactive cluster,
and will give you its id. It is not a bundle resource, and that is the point.

### 2.1 Generate

```bash
databricks bundle generate job --existing-job-id <id> --key ported
```

**Expected (exact):**

```
File successfully saved to src/hello_world.py
Job configuration successfully saved to resources/ported.job.yml
```

The command made four API calls: it read the job, checked the notebook's status and the
bundle's file root, and exported the notebook. Nothing was deployed.

### 2.2 Read it before you change it

Open `resources/ported.job.yml` and mark the three defects from the slide before
editing. All three pass `bundle validate`, so run it first and watch it pass:

```bash
databricks bundle validate
```

**Expected (yours):** `Validation OK!`, on a file that is not fit to deploy.

### 2.3 Repair

1. Replace `existing_cluster_id` with a job cluster you declare and a
   `job_cluster_key` on the task. The interactive cluster exists in this workspace and
   in no other, so a bundle carrying its id cannot be promoted.
2. Delete `source: WORKSPACE`. The notebook is bundle source now, synchronised with the
   bundle, and the default source is correct.
3. Delete every key whose value is a default or an empty mapping. There are nine.

### 2.4 Confirm

```bash
databricks bundle validate
databricks bundle validate -o json \
  | jq -r '.resources.jobs.ported.tasks[0].notebook_task.notebook_path'
```

**Expected (yours):** a path under `.bundle/m4demo_<initials>/dev/files/src/`, not a
path under your home directory. If it is still the latter, `notebook_path` is still
absolute and the file was not made bundle-local.

**Success:** a resource file under fifteen lines, every line carrying information, that
validates.

**If you finish early:** run `databricks bundle deployment bind ported <id>` and say what
it changes about what the next deployment would do. Do not deploy yet.

---

## Challenge 3 — Build the pipeline

**12 minutes.**

Full requirements are in `assets/challenge3-requirements.md`. Five tasks: `land`, then
`features` and `quality` in parallel, then `publish` waiting on both, then `notify` with
`run_if: ALL_DONE`. Three job clusters, because two tasks that share one cannot run at
the same time. One retry with an interval on the task most likely to fail, with a
written reason.

**Draw the graph before you write any YAML.** Five nodes, and count the arrows before
you count the tasks.

```bash
databricks bundle validate
```

**Expected (yours):** `Validation OK!`.

```bash
databricks bundle validate -o json \
  | jq -r '.resources.jobs.ingest.tasks[]
           | "\(.task_key) <- \(.depends_on // [] | map(.task_key) | join(", "))"'
```

**Expected (exact, for the reference solution):**

```
features <- land
land <-
notify <- publish
publish <- features, quality
quality <- land
```

That is the graph your file actually declares. Compare it with your drawing, line by
line.

Two things to notice in that output. The tasks come out in **alphabetical order**, not
file order: the resolved configuration sorts them by `task_key`. And `land` has an empty
right-hand side, which is what makes it the root.

```bash
databricks bundle validate -o json \
  | jq -r '.resources.jobs.ingest.job_clusters[].job_cluster_key'
```

**Expected (exact, for the reference solution):**

```
main
features
quality
```

Three faults `validate` will **not** report, and you have to check for yourself.

| Fault | Consequence | How to check |
|---|---|---|
| `depends_on` naming a task that does not exist | rejected at deploy, not now | read the graph output above |
| a cycle | no task can start; rejected at deploy | read the graph output above |
| `features` and `quality` sharing one cluster | valid, and no parallelism | read the cluster output above |

**Success:** `Validation OK!`, three job clusters, and a printed graph identical to your
drawing.

---

## Challenge 4 — Promote to staging

**10 minutes.**

Add a `staging` target that differs from `dev` in the catalog, the worker count and
whether the schedule fires. **Do not edit `resources/ingest.job.yml`.** Everything goes
in `databricks.yml`. `assets/databricks.yml.multi-target` is the annotated reference;
write your own first.

### 4.1 Add the target

`mode: production`, an explicit `root_path`, a `permissions` entry naming yourself,
`catalog` and `schema` reassigned, and a `resources` block overriding only the worker
count of the `main` cluster.

### 4.2 Diff the two resolutions

```bash
databricks bundle validate -t dev     -o json | jq '.resources.jobs.ingest' > /tmp/dev.json
databricks bundle validate -t staging -o json | jq '.resources.jobs.ingest' > /tmp/staging.json
diff /tmp/dev.json /tmp/staging.json
```

**Expected (yours):** differences in the job name, the tags, the trigger pause status
and the cluster's worker count. Account for every line, **including the ones you did not
write** — the name prefix and the tag come from `mode: development` on `dev`, not from
anything in the staging block.

### 4.3 Count the clusters

```bash
databricks bundle validate -t staging -o json \
  | jq -r '.resources.jobs.ingest.job_clusters[].job_cluster_key'
```

**Expected (yours):** exactly `main`, `features`, `quality` — three entries, the same
three as `dev`.

If a fourth appears, the `job_cluster_key` in your override does not match the base and
the merge appended a new entry instead of merging into the existing one. Nothing reports
this. Counting is the check, and this is the only place in the module where counting is
the check.

### 4.4 Name the sources

For `catalog` and `schema`, in each of the two targets, name which of the five sources
supplied the value. Then demonstrate the top two:

```bash
BUNDLE_VAR_schema=fromenv databricks bundle validate -t staging -o json \
  | jq -r '.variables.schema.value'
```

**Expected (exact):** `fromenv`

```bash
BUNDLE_VAR_schema=fromenv databricks bundle validate -t staging -o json \
  --var=schema=fromflag | jq -r '.variables.schema.value'
```

**Expected (exact):** `fromflag`

```bash
DATABRICKS_BUNDLE_VAR_schema=ignored databricks bundle validate -t staging -o json \
  | jq -r '.variables.schema.value'
```

**Expected (exact):** `staging` — the target's assignment. The `DATABRICKS_` prefix has
no effect; the variable the CLI reads is `BUNDLE_VAR_schema`. If you wrote down four
sources this morning, this is the correction.

**Success:** two resolutions differing in exactly the properties you declared, no extra
cluster, and the precedence order stated correctly.

---

## Challenge 5 — Work the loop

**8 minutes.**

### 5.1 Deploy what you have

```bash
databricks bundle plan -t dev
```

**Expected (shape only):** one line per resource, each reporting a creation, because
nothing has been deployed yet. The Challenge 3 bundle has one job.

```bash
databricks bundle deploy -t dev
databricks bundle run ingest -t dev
```

**Expected (shape only):** the deployment stages, then the run URL, then per-task state
transitions, then a terminal result. Record the run URL. The first deployment in a
shared workspace is slow; two minutes is normal.

### 5.2 Break the second task, and predict

Open `src/features.py` and remove a closing parenthesis.

**Before you deploy, write down the state you expect each of the five tasks to be
reported in.** Five answers.

```bash
databricks bundle deploy -t dev
databricks bundle run ingest -t dev
```

**Expected (shape only):**

| Task | State | Produced by |
|---|---|---|
| `land` | `SUCCESS` | your code |
| `features` | `FAILED` | your code |
| `quality` | `SUCCESS` | your code — it does not depend on `features` |
| `publish` | `UPSTREAM_FAILED` | the platform |
| `notify` | `SUCCESS` | the platform let it run: `run_if: ALL_DONE` |

Check all five against your predictions. The two that catch people are `quality`, which
succeeds because it is a sibling and not a descendant, and `notify`, which runs at all.

**This table describes a failure in your code.** An *infrastructure* failure behaves
differently and it is worth knowing the difference, because the two look similar in the
run list. If a task cannot obtain compute at all, the run terminates `INTERNAL_ERROR`
rather than `TERMINATED`, and `run_if: ALL_DONE` does not save `notify` — `ALL_DONE`
governs what happens when a dependency *finishes* in a bad state, and a run that never
started a cluster never got that far. Observed form:

```
"[dev <short>] sales_ingest" INTERNAL_ERROR FAILED
Task land failed with message: Unexpected user error while preparing the cluster for
the job. Cause: PERMISSION_DENIED: You are not authorized to create clusters.
```

The tell is the word `INTERNAL_ERROR` and the phrase *preparing the cluster*: your code
was never reached, so nothing in the declaration is at fault. Question 1 of the recipe
on S58 still applies — the command that failed was `run` — but the answer is a
workspace permission rather than a defect.

Note that `features` was retried before it failed, because Challenge 3 gave it
`max_retries: 2`. A syntax error is not a failure a retry can survive, which is the
argument against giving retries to a task that fails deterministically.

### 5.3 Fix, and read the second plan

Restore the parenthesis.

```bash
databricks bundle deploy -t dev
databricks bundle plan -t dev
```

**Expected (shape only):** the second `plan` reports no action for the job, because
nothing about the resource changed — only a synchronised file did. Idempotence comes
from the deployment state under `state/`, not from the declaration.

```bash
databricks bundle run ingest -t dev
```

**Expected (shape only):** five tasks, all `SUCCESS`.

**Success:** a failed task, a downstream task reported separately rather than as a
failure, five predictions checked, and a second plan reporting no action where nothing
changed.

---

## Challenge 6 — Timed team challenge

**12 minutes. Teams of three. One driver, two reading.**

### 6.1 Get the bundle

```bash
cp -r assets/broken-bundle /tmp/lab6
cd /tmp/lab6
```

Four faults. One is reported by `validate` as a warning, one by `validate` as an error,
one only when `deploy` reaches the resource stage, and one only when the job runs.

### 6.2 Work the stages, in order

Do not read the whole file first. Apply the recipe:

1. Which command failed?
2. If `deploy`: which stage does the message name?
3. Does the message carry a configuration path and a file position? Go to the position.
4. If the message came from the workspace: read the field from
   `bundle validate -o json`, not from the file.

```bash
databricks bundle validate -t dev
```

**Expected first (exact except for the path):**

```
Error: expected a notebook for "resources.jobs.sales_etl.tasks[3].notebook_task
.notebook_path" but got a file: file at /tmp/lab6/src/transform.py is not a notebook
```

**The index in that message is not the position in the file.** `transform` is the second
task in `resources/sales_etl.job.yml`. The resolved configuration sorts tasks by
`task_key`, so the order the CLI is addressing is `extract`, `notify`, `publish`,
`transform`. Confirm it:

```bash
databricks bundle validate -o json | jq -r '.resources.jobs.sales_etl.tasks[].task_key'
```

Use the file position in the message, not the index.

Each fault is masked by the one before it, so fix and re-run. Record the order in which
you found them and which command found each.

### 6.3 Raise a hand

When `validate` is clean, `deploy` succeeds and the run reaches a terminal success
state. The instructor times you.

### 6.4 Debrief

The fixes are not the interesting part. The order is. Two questions for the room: which
fault cost the most time, and which command would have found it sooner.

**Success:** `validate` clean, `deploy` successful, `run` successful, and a written order
of discovery.

---

## Recovery

| Symptom | Cause | What to do |
|---|---|---|
| `cannot configure default credentials` | no profile and no environment variables | re-run the Module 2 profile setup; `databricks current-user me` must succeed first |
| `invalid value for project_name` | the name contains a hyphen or a space | letters, digits and underscores only |
| `expected a notebook ... but got a file` | the file's first line is not `# Databricks notebook source` | add the marker line |
| `notebook <path> not found` | the file does not exist, or the path is relative to the wrong file | paths in `resources/*.yml` are relative to that file: `../src/x.py` |
| `job_cluster_key <k> is not defined` | a task claims a cluster no `job_clusters` entry declares | fix the spelling at the file position the warning gives |
| `unknown field: <key>` | a misspelled key, or a task-level key written at job level | the warning names the level as well as the key |
| `invalid value ... for enum field` | a `run_if` outside the six | the message lists all six valid values |
| `no value assigned to required variable <v>` | declared, never assigned, no default | assign it in the target, or give the declaration a `default:` |
| `variable <v> has not been defined` | `--var` names a variable no declaration exists for | declare it under `variables:` first |
| `Validation OK!` and `deploy` fails | the graph is invalid, or two compute keys conflict on one task | read the stage the message names: build, upload, resource, or state |
| a fourth job cluster appears in one target | a mistyped `job_cluster_key` in a target override appended instead of merging | compare the key against the base; nothing will report this |
| a resolved name has no `[dev ...]` prefix | the selected target is not in development mode | pass `-t dev` explicitly, or check which target is `default: true` |
| a `${var...}` reference survives into the resolved output | the variable is not declared at the top level | declare it under `variables:`, assign it inside the target |
| a `--var` value containing a comma is rejected | `--var` is parsed as comma-separated | put the value in `.databricks/bundle/<target>/variable-overrides.json` |
| the job runs an old version of a notebook | the deployed copy was edited in the workspace, or the source was edited without deploying | deploy again; the source is the only thing worth editing |

---

## If you finish early

- Resolve the `prod` target of `assets/databricks.yml.multi-target` and explain every
  difference from `staging`. Both are `mode: production`, so every difference is
  something a person wrote.
- Rewrite the `features` cluster as a complex variable and assign it per target. Then
  say which of the two mechanisms you would choose for this bundle and why, in one
  sentence. `assets/databricks.yml.multi-target` does it both ways so that they can be
  compared side by side.
- Give `publish` a `run_if` of `NONE_FAILED` and predict what Challenge 5's broken run
  would report for it. Then break `features` again and check.
- Delete `.databricks/bundle/dev/` and run `bundle plan` before you run anything else.
  Predict what it will report first.
- Read `assets/m4demo/`, the reference bundle in the state your own should now be in.
  Its `resources/ingest.job.yml` carries a slide reference against every construct, so
  anything you wrote differently can be checked against the slide that taught it. Its
  `README.md` lists the four commands that read the resolved configuration, and
  `capture-run.sh` runs the whole lifecycle unattended if you want to watch it once more
  end to end.
