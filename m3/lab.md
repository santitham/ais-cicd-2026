# Module 3 — Lab guide

**Bundle anatomy and your first deployment**
Six challenges, 60 minutes of lab work in total, run between the teaching
segments rather than in one block. Work alone. Compare results with the room at
each debrief.

## How to read this guide

Each challenge states its time, what to do, and what success looks like.
Expected output is given for every command. Where output was produced by
executing the command, it is exact; where it depends on your workspace it is
marked, and where the command has not yet been executed against a live
workspace it is labelled **shape only**, meaning the fields are right but the
values and timings will differ.

| Marking | Meaning |
|---|---|
| exact | produced by running the command with CLI v1.12.1 |
| yours | correct in form; the values are specific to your workspace |
| shape only | not yet executed against a live workspace |

---

## Pre-flight — 5 minutes, before Challenge 1

Run the preparation script and read what it reports.

```bash
bash assets/prep-ubuntu-m3.sh
```

**Expected final lines (exact):**

```
=== Result ===
  Every check passed. You are ready for Lab A.
```

The script checks five things, and each corresponds to a lab step that cannot
proceed without it:

| Check | Why it blocks a step |
|---|---|
| Databricks CLI v1.3.0 or later | earlier versions write Terraform state, and `bundle plan` does not exist before v1.2 |
| `uv` on `PATH` | Challenge 4 fails at the build stage without it |
| `jq` | used to read resolved configuration in Challenges 2, 3 and 6 |
| `databricks current-user me` succeeds | `bundle init` calls the same endpoint before writing a file |
| at least one Unity Catalog catalog is listed | `bundle init` asks for one, and the pipeline resource is created in it |

If `uv` was installed by the script, export the path in the shell you will run
`databricks` from, or none of the deployment steps will work:

```bash
export PATH="$HOME/.local/bin:$PATH"
uv --version
```

**Expected (yours):** `uv 0.8.17` or later.

---

## Challenge 1 — Predict the resolved configuration

**7 minutes. Written answers only. Do not run anything.**

Take the handout, `assets/challenge1-handout.md`. It contains a complete
thirty-line bundle and four questions. Write down, for the `dev` target:

1. the resolved job name,
2. the resolved value of the `catalog` job parameter,
3. the resolved trigger pause status,
4. the resolved workspace root path,

and, for each, the stage of the assembly sequence that produced it: read,
merge, overlay, preset, or substitute.

Keep the paper. You check these answers in Challenge 2.

**Success:** four written answers, each attached to one of the five stages.

---

## Challenge 2 — Initialise and inventory

**8 minutes.**

### 2.1 Generate the project

```bash
cd ~                       # or wherever you keep course work
databricks bundle init default-python
```

Answer the prompts:

| Prompt | Answer |
|---|---|
| Project name | `m3demo_<your initials>` |
| Default catalog | one of the catalogs the pre-flight script listed |

The project name must consist of letters, digits and underscores. A hyphen is
rejected before anything is written (exact):

```
Error: failed to load config from file ...: invalid value for project_name:
"m3-jq". Name must consist of letters, numbers, and underscores.
```

**Expected final output (exact):**

```
✨ Your new project has been created in the 'm3demo_jq' directory!

To get started, refer to the project README.md file and the documentation at
https://docs.databricks.com/dev-tools/bundles/index.html.
```

### 2.2 Inventory what it wrote

```bash
cd m3demo_jq
tree -a -I '.databricks|dist|build'
```

Compare against `assets/expected-bundle-tree.txt`, which is the exact output of
the same command against CLI v1.12.1. Account for every difference. A tree
containing `notebooks/` or a job keyed `<project>_job` means an older CLI.

### 2.3 Locate the four constructs from Part B

Without looking at the annotated file, find and write down:

1. the bundle name and where the uuid came from,
2. the `include` pattern, and which files it pulls in,
3. one variable declaration, and the two places its value is assigned,
4. the notebook task, and the path it names.

Then read `assets/databricks.yml.annotated` and correct yourself.

### 2.4 Check your Challenge 1 answers

```bash
databricks bundle validate -o json | jq '{presets, variables}'
```

**Expected shape (exact, with your user name):**

```json
{
  "presets": {
    "jobs_max_concurrent_runs": 4,
    "name_prefix": "[dev santitham_pro] ",
    "pipelines_development": true,
    "tags": { "dev": "santitham_pro" },
    "trigger_pause_status": "PAUSED"
  },
  "variables": {
    "catalog": { "description": "The catalog to use", "value": "training" },
    "schema":  { "description": "The schema to use",  "value": "santitham_pro" }
  }
}
```

`presets` appears in the output and in no file. That is the object your
Challenge 1 answers 1, 3 and 5 came from.

**Success:** a tree matching the reference, and each Challenge 1 answer either
confirmed or corrected, with the reason.

---

## Challenge 3 — Author a second job

**10 minutes.**

Full requirements are in `assets/challenge3-requirements.md`. In summary: add a
job in a new file `resources/report.job.yml`, keyed `report_job`, named from a
new variable `report_job_name` that you declare and assign as `daily_report` in
the `dev` target, with one notebook task running a file you create at
`src/report_notebook.py`, and no trigger.

Write it yourself rather than copying the generated job.

```bash
databricks bundle validate
```

**Expected (yours):**

```
Name: m3demo_jq
Target: dev
Workspace:
  Host: https://adb-....azuredatabricks.net
  User: you@example.com
  Path: /Workspace/Users/you@example.com/.bundle/m3demo_jq/dev

Validation OK!
```

```bash
databricks bundle validate -o json | jq -r '.resources.jobs.report_job.name'
```

**Expected (exact, with your user name):**

```
[dev santitham_pro] daily_report
```

Two failures to expect. A name that comes back as `daily_report` with no prefix
means you validated against a target that is not in development mode. A name
that comes back as `${var.report_job_name}` means the variable is not declared
where you think it is.

The notebook path is relative to the file that declares it. Your file is in
`resources/`, so the task must name `../src/report_notebook.py`. A path that
escapes the bundle root is left unrewritten and fails validation.

**Success:** `Validation OK!`, and a resolved job name carrying the development
prefix. The solution is in `assets/challenge3-solution/`; read it only after
your own version validates.

---

## Challenge 4 — Deploy and inspect

**13 minutes.**

### 4.1 Plan before deploying

```bash
databricks bundle plan -t dev
```

**Expected (shape only):** one line per resource, each reporting a creation,
because nothing has been deployed yet. Three resources exist in this project:
`sample_job`, `report_job`, and the pipeline.

If this fails with

```
Error: build failed python_artifact, error: exit status 127,
output: /usr/bin/bash: line 1: uv: command not found
```

then `uv` is not on the `PATH` of the shell you are in. `plan` runs the build
stage locally before it reports anything, which is the point worth noticing:
a command that changes nothing remotely still builds locally.

### 4.2 Deploy

```bash
databricks bundle deploy -t dev
```

**Expected (shape only):** the build, the upload of the source tree, the
creation of the resources, and a completion line. The first deployment in a
shared workspace is slow; two minutes is normal and longer is not alarming.

### 4.3 Find it in the workspace

Open Workflows in the workspace UI. Confirm three things against your
Challenge 1 predictions:

1. the job name carries the `[dev <short name>]` prefix,
2. the schedule shows as paused,
3. the job is tagged `dev`.

### 4.4 Locate both copies of your code

```bash
USER_EMAIL=$(databricks current-user me -o json | jq -r .userName)
databricks workspace list "/Workspace/Users/$USER_EMAIL/.bundle/m3demo_jq/dev"
```

**Expected (shape only):** four entries — `artifacts`, `files`, `resources`,
`state`.

Then write down two paths: the workspace path of the notebook the job will
execute, and the path of the same notebook in your project directory. Get the
first from the resolved configuration rather than by browsing:

```bash
databricks bundle validate -o json \
  | jq -r '.resources.jobs.report_job.tasks[0].notebook_task.notebook_path'
```

**Expected (exact, with your user name and project):**

```
/Workspace/Users/santitham.pro@kmutt.ac.th/.bundle/m3demo/dev/files/src/report_notebook
```

**Success:** a deployed job whose name matches your prediction, and both paths
of the notebook written down.

---

## Challenge 5 — Run the job and read the result

**10 minutes.**

```bash
databricks bundle run report_job -t dev
```

**Expected (shape only):** the run URL first, then state transitions, then the
terminal result. Record the URL.

```bash
databricks bundle summary -t dev
```

**Expected (shape only):** every resource this bundle has deployed to `dev`,
with the workspace id of each. It reads deployment state, so it was empty
before Challenge 4.

```bash
databricks bundle open report_job -t dev
```

Open the run and confirm which notebook path the task executed. Compare it with
the two paths you wrote down in Challenge 4.

If the run fails, read the error, then continue. Diagnosing a failed run is
Module 4, and the run URL is what you will start from there.

**Success:** a terminal state obtained by command, and the executed notebook
path matching the deployed copy rather than your source file.

---

## Challenge 6 — Destroy, redeploy, override

**12 minutes.**

### 6.1 Destroy

```bash
databricks bundle destroy -t dev
```

**Expected (shape only):** two prompts. The first lists the resources to be
deleted, the second lists the files. Answer `y` to both.

Refresh Workflows and confirm the jobs are gone.

### 6.2 Redeploy with an override

```bash
databricks bundle deploy -t dev --var report_job_name=weekly_report
```

Then confirm the override in the resolved configuration and in the workspace:

```bash
databricks bundle validate -o json --var report_job_name=weekly_report \
  | jq -r '.resources.jobs.report_job.name'
```

**Expected (exact, with your user name):**

```
[dev santitham_pro] weekly_report
```

### 6.3 Answer in one sentence

The variable had a value assigned in the `dev` target and a value passed on the
command line. Name which won and why, using the precedence order from the
lecture.

**Success:** the jobs restored, the override visible in the workspace, and the
precedence rule stated correctly.

---

## Recovery

| Symptom | Cause | What to do |
|---|---|---|
| `cannot configure default credentials` | no profile and no environment variables | re-run the Module 2 profile setup; `databricks current-user me` must succeed first |
| `Forbidden` on `current-metastore-assignment` during `init` | the credential has no Unity Catalog access | ask the instructor for a catalog grant; `bundle init` cannot proceed without one |
| `invalid value for project_name` | the name contains a hyphen or a space | letters, digits and underscores only |
| `uv: command not found` during `plan` or `deploy` | `uv` absent, or present but not on this shell's `PATH` | `export PATH="$HOME/.local/bin:$PATH"`, confirm with `uv --version`, re-run |
| `Validation OK` but `deploy` fails | the schema is satisfied and the workspace refuses the operation | read the stage named in the message: build, upload, apply, or state |
| a resolved name has no `[dev ...]` prefix | the selected target is not in development mode | check which target is `default: true`, or pass `-t dev` explicitly |
| a `${var...}` reference survives into the resolved output | the variable is not declared at the top level | declare it under `variables:`, assign it inside the target |
| `same serial number in terraform and direct states` | the bundle carries both state files | `databricks bundle deployment migrate -t dev`, then `bundle plan` |
| the job runs an old version of the notebook | the deployed copy was edited in the workspace, or the source was edited without deploying | deploy again; the source is the only thing worth editing |

---

## If you finish early

- Run `databricks bundle validate -o json -t prod | jq '{presets, name: .resources.jobs.report_job.name}'` and explain every difference from the `dev` output. Production mode computes no presets at all.
- Read `resources/<project>_etl.pipeline.yml` and find the reference that connects it to the third task of `sample_job`. That reference is the one that does not resolve during validation. State why.
- Delete `.databricks/bundle/dev/` and run `bundle plan` again. Predict what it will report before you run it.
