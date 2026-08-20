# Module 4 — verified technical facts

All CLI results below were produced with **Databricks CLI v1.12.1** against a mock
workspace API that serves the SCIM, Unity Catalog, workspace and jobs endpoints the
CLI calls. That is sufficient for every claim up to the point a resource is created.
Anything that requires a real deployment is marked **[pending]** and must be executed
against the training workspace before delivery.

## 1. Template used to start Module 4

`databricks bundle init default-minimal` produces a bundle with **no resources**:

```
.gitignore  .vscode/{__builtins__.pyi,extensions.json,settings.json}
AGENTS.md  CLAUDE.md  README.md  databricks.yml
fixtures/.gitkeep  pyproject.toml  tests/conftest.py
```

`databricks.yml` declares `bundle` (name, uuid), `include: [resources/*.yml]`, two
variables (`catalog`, `schema`), and the `dev` (mode development, default) and `prod`
(mode production, explicit `root_path`, `permissions`) targets. There is no
`resources/` directory, no `artifacts` block and therefore **no `uv` dependency** —
unlike `default-python`, which Module 3 used. `include` matching nothing is not an
error: `Validation OK!`.

## 2. Job, task and cluster keys — confirmed against the CLI bundle JSON schema

`job_clusters` is a **sequence**; each item requires `job_cluster_key` and
`new_cluster`. A task selects one with `job_cluster_key` at task level.

Canonical `new_cluster` as emitted by the shipping Databricks template:

```yaml
job_clusters:
  - job_cluster_key: main
    new_cluster:
      spark_version: 16.4.x-scala2.12
      node_type_id: Standard_D3_v2
      data_security_mode: DATA_SECURITY_MODE_AUTO
      autoscale:
        min_workers: 1
        max_workers: 4
```

- `16.4.x-scala2.12` is the value Databricks' own template pins ("the latest LTS DBR
  version"). 16.4 LTS is supported to 9 May 2028. 13.3 LTS reaches end of support on
  **22 Aug 2026**, which is why the examples in the Azure bundle documentation must not
  be copied.
- `Standard_D3_v2` is what the CLI's `smallest_node_type` helper returns for Azure.
  `Standard_DS3_v2` is still valid but has no compatible fallback instance type, so a
  room of participants launching at once can hit capacity errors.
- `data_security_mode` is optional; `DATA_SECURITY_MODE_AUTO` is what the template
  emits. `kind: CLASSIC_PREVIEW` is optional and must not be taught as required.
- `num_workers` and `autoscale` are alternatives. Declaring **both** passes validation
  (see §4).

`run_if` — the enum has exactly six values. The CLI prints them itself:

```
Warning: invalid value "ALL_DONE_OR_SKIPPED" for enum field. Valid values are
[ALL_DONE ALL_FAILED ALL_SUCCESS AT_LEAST_ONE_FAILED AT_LEAST_ONE_SUCCESS NONE_FAILED]
  at resources.jobs.etl.tasks[2].run_if
  in resources/etl.job.yml:26:19
```

## 3. Path rewriting differs by task type — [verified]

| Source | Resolved |
|---|---|
| `notebook_task.notebook_path: ../src/clean.py` | `/Workspace/Users/<user>/.bundle/<name>/dev/files/src/clean` |
| `spark_python_task.python_file: ../src/plain.py` | `/Workspace/Users/<user>/.bundle/<name>/dev/files/src/plain.py` |

The notebook path loses its extension; the Python file keeps it. A `notebook_task`
pointing at a file that lacks the `# Databricks notebook source` first line fails:

```
Error: expected a notebook for "resources.jobs.hello_world.tasks[0].notebook_task.notebook_path"
but got a file: file at /path/src/hello_world.py is not a notebook
```

## 4. What `bundle validate` does and does not catch — [verified]

Each row was produced by introducing exactly one fault into a working three-task job.

| Fault | `bundle validate` result |
|---|---|
| task names an undefined `job_cluster_key` | **Warning**: `job_cluster_key mian is not defined`, with `at resources.jobs.ingest.tasks[1].job_cluster_key` and `in resources/ingest.job.yml:42:28` |
| unknown field (`notebook_taskk`) | **Warning**: `unknown field: notebook_taskk`, with path and line |
| `run_if` outside the enum | **Warning**, listing the six valid values |
| `notebook_path` naming a file that does not exist | **Error**: `notebook src/reprot.py not found` |
| a declared variable with no value and no default | **Error**: `no value assigned to required variable warehouse_id. Variables are usually assigned in databricks.yml, and they can be overridden using "--var", the BUNDLE_VAR_warehouse_id environment variable, or .databricks/bundle/<target>/variable-overrides.json` |
| `--var` naming an undeclared variable | **Error**: `variable nosuchvar has not been defined` |
| `depends_on` naming a task that does not exist | **`Validation OK!`** — not caught |
| a dependency cycle (clean → report → features → clean) | **`Validation OK!`** — not caught |
| two tasks with the same `task_key` | **`Validation OK!`** — not caught |
| `num_workers` and `autoscale` both declared | **`Validation OK!`** — not caught |
| `existing_cluster_id` and `job_cluster_key` on the same task | **`Validation OK!`** — not caught |
| a task with no compute declared at all | **`Validation OK!`** — not caught |

The dividing line: validate checks the schema, resolves references it owns
(variables, `job_cluster_key`, local file existence) and reaches the workspace. It
does not evaluate the task graph and does not reject mutually exclusive compute keys.
Those are rejected by the Jobs API at the resource stage of `deploy`, or produce a
job that deploys and then misbehaves.

## 4b. Task order in the resolved configuration — [verified]

The resolved configuration sorts a job's `tasks` sequence **by `task_key`**, not by
file order. Measured on `assets/m4demo/`, whose file order is `land`, `features`,
`quality`, `publish`, `notify`:

```
$ databricks bundle validate -o json | jq -r '.resources.jobs.ingest.tasks[].task_key'
features
land
notify
publish
quality
```

So `land`, the **first** task in the file, is `tasks[1]` in every diagnostic. Confirmed
twice against `m4demo`, once for each fault that names it:

```
Warning: job_cluster_key mian is not defined
  at resources.jobs.ingest.tasks[1].job_cluster_key
  in resources/ingest.job.yml:42:28
```

```
Error: expected a notebook for "resources.jobs.ingest.tasks[1].notebook_task
.notebook_path" but got a file: file at .../src/land.py is not a notebook
```

Line 42 is where `job_cluster_key` sits on the `land` task, so the **file position is
correct** while the index counts down the sorted list. Teach the position, not the
index. This is what slides S23 and S24 carry, and the same example runs in Challenge 6.

## 5. Target overrides — [verified]

A `targets.<t>.resources` block **merges into** the base declaration; it does not
replace it. Sequences under `job_clusters` and `tasks` are merged **by key**.

Measured on `assets/m4demo/`. The base `main` cluster is `autoscale {1,3}`. With

```yaml
targets:
  staging:
    resources:
      jobs:
        etl:
          job_clusters:
        ingest:
          job_clusters:
            - job_cluster_key: main
              new_cluster:
                autoscale: { min_workers: 2, max_workers: 6 }
```

the resolved staging cluster keeps `spark_version`, `node_type_id` and
`data_security_mode` from the base and takes the new `autoscale`. Nothing else in the
job changes. The CLI emits the keys of a resolved mapping in alphabetical order, which
is why S45 shows `autoscale` first.

Overriding a **task** works the same way. A staging block naming only

```yaml
tasks:
  - task_key: report
    max_retries: 3
trigger:
  periodic: { interval: 1, unit: DAYS }
```

resolves to three tasks in which `report` alone carries `max_retries: 3` and still
carries its original `depends_on` and `job_cluster_key`, plus a trigger with
`pause_status: UNPAUSED` because staging declares `mode: production`.

**A mistyped key does not error — it appends.** Writing `job_cluster_key: mian` in the
override produces a **fourth** entry in `m4demo`'s `job_clusters`, appended after the
three the base declares:

```
{"job_cluster_key":"main",    "new_cluster":{"autoscale":{"max_workers":3,"min_workers":1}, ...}}
{"job_cluster_key":"features","new_cluster":{"num_workers":4, ...}}
{"job_cluster_key":"quality", "new_cluster":{"num_workers":2, ...}}
{"job_cluster_key":"mian",    "new_cluster":{"autoscale":{"max_workers":6,"min_workers":2}}}
```

`main` is untouched and still claimed by every task, and `mian` carries only the
overridden fields — no `spark_version`, no `node_type_id`. `Validation OK!`, no
warning. This is the failure that costs the most time in practice, and it is what S46
shows.

## 6. Variable precedence — [verified], and a correction to Module 3

Measured by overriding `schema` through every channel at once. Lowest to highest:

1. `default:` in the variable declaration
2. the assignment in the selected target's `variables:` block
3. `.databricks/bundle/<target>/variable-overrides.json`
4. the `BUNDLE_VAR_<name>` environment variable
5. `--var name=value` on the command line

**`DATABRICKS_BUNDLE_VAR_<name>` has no effect.** Setting
`DATABRICKS_BUNDLE_VAR_schema=fromenv2` leaves the value at the target's assignment;
`BUNDLE_VAR_schema=fromenv1` changes it. Module 3's slide S24 names the
`DATABRICKS_` prefix and omits `variable-overrides.json`; both need correcting.

`--var` accepts repeated flags (`--var=a=1 --var=b=2`) or one comma-separated flag
(`--var=a=1,b=2`). It is parsed as CSV, so a **complex value containing commas cannot
be passed on the command line**:

```
Error: invalid argument "cluster={\"spark_version\":...}" for "--var" flag:
parse error on line 1, column 10: bare " in non-quoted-field
```

Complex values must come from `variable-overrides.json`, which works and replaces the
whole value rather than merging into it.

## 7. Complex variables — [verified]

A variable declared `type: complex` may hold an entire `new_cluster` mapping, and a
target assigns a different one. Assignment **replaces** the whole value: a staging
assignment carrying `num_workers: 8` and no `autoscale` resolves to a cluster with
`num_workers` and no `autoscale`, unlike the `targets.resources` merge in §5.

## 8. `bundle generate job` — [verified]

```
databricks bundle generate job --existing-job-id 842914290173 --key hello_world
```

```
File successfully saved to src/hello_world.py
Job configuration successfully saved to resources/hello_world.job.yml
```

Four API calls: `GET /api/2.2/jobs/get`, `GET /api/2.0/workspace/get-status` on the
notebook and on the bundle file root, and `GET /api/2.0/workspace/export`.

Flags: `--existing-job-id` (required), `--key` (a persistent flag on `bundle
generate`), `-d/--config-dir` (default `resources`), `-s/--source-dir` (default
`src`), `-f/--force`, `--download-spark-python-files`. Only jobs whose tasks are
notebook tasks are supported.

Generated file, verbatim:

```yaml
resources:
  jobs:
    hello_world:
      name: hello_world_ui
      tasks:
        - task_key: hello
          existing_cluster_id: 0815-123456-abcdefgh
          email_notifications: {}
          notebook_task:
            notebook_path: ../src/hello_world.py
            source: WORKSPACE
          run_if: ALL_SUCCESS
          timeout_seconds: 0
          webhook_notifications: {}
      email_notifications: {}
      max_concurrent_runs: 1
      queue:
        enabled: true
      timeout_seconds: 0
      webhook_notifications: {}
```

Three things are wrong with it as bundle source, and all three validate cleanly:
`existing_cluster_id` pins an interactive cluster that will not exist in another
workspace; `source: WORKSPACE` is redundant once the file is bundle-local; and six
empty or default-valued keys carry no information.

## 9. Not reachable without a live workspace — [pending]

`bundle plan`, `deploy`, `run`, `summary` and `destroy` all read deployment state from
the workspace and fail identically against a mock:

```
Error: reading resources.json: opening: not a file:
/Workspace/Users/<user>/.bundle/m4demo_jq/dev/state/resources.json
```

Still to capture on the training workspace: `plan` output for a create and for a
change, `deploy` stage lines, `run` output including the run URL and per-task states,
a task failure with a downstream skip, and `summary`.
