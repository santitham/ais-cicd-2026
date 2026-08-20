# Challenge 6 — instructor solutions

**Do not distribute before the challenge ends.**

Four faults, one per detection stage. They surface in order: each is masked by the one
before it, so a team that works the stages down finds them in the sequence below, and a
team that reads the whole file first finds them in no order at all. That difference is
the debrief.

## Fault 1 — `src/transform.py` has no notebook marker

Detected by `bundle validate` as an **error**, which blocks everything else.

```
Error: expected a notebook for "resources.jobs.sales_etl.tasks[3].notebook_task
.notebook_path" but got a file: file at /tmp/lab6/src/transform.py is not a notebook
```

Fix: add `# Databricks notebook source` as the first line of `src/transform.py`.

**Note the index in that message.** It reads `tasks[3]`, and `transform` is the *second*
task in the file. The index is not wrong: the resolved configuration sorts a job's tasks
by `task_key`, so the order the CLI is addressing is `extract`, `notify`, `publish`,
`transform` — and `transform` is index 3 in that order. Confirm it in the room with

```bash
databricks bundle validate -o json | jq -r '.resources.jobs.sales_etl.tasks[].task_key'
```

A team counting down the file will open the wrong task. The **file position** in the
same message, `resources/sales_etl.job.yml:29:28`, is unambiguous and is the one to use.
This is the point slide S24 makes, and it is worth raising in the debrief whether or not
a team noticed.

## Fault 2 — `job_cluster_key: mian` on the `transform` task

Detected by `bundle validate` as a **warning**, and only after fault 1 is fixed —
validation reports the error and stops before it reports warnings.

```
Warning: job_cluster_key mian is not defined
  at resources.jobs.sales_etl.tasks[3].job_cluster_key
  in resources/sales_etl.job.yml:29:28
```

Fix: `mian` → `main` on line 29. A team that reads only the last line of the command
output sees `Found 1 warning` and moves on, which is the trap.

## Fault 3 — `depends_on: tranform` on the `publish` task

`bundle validate` reports **`Validation OK!`**. The fault is a dependency on a task
that does not exist, and validation does not evaluate the graph. It is rejected by the
Jobs API at the **resource stage of `deploy`**.

Fix: `tranform` → `transform` on line 38.

Teams that try to find this fault with `validate` will not find it. The recipe's first
question — which command failed — is what gets them to deploy.

## Fault 4 — `target_table` is undefined in `src/publish.py`

Deploy succeeds. The **run** fails, at the `publish` task, with a `NameError`. `extract`
and `transform` report `SUCCESS`; `publish` reports `FAILED`; `notify` runs anyway
because it declares `run_if: ALL_DONE`, which is the one thing in the bundle that is
deliberately correct and is worth pointing out.

Fix: define `target_table`, for example
`target_table = f"{dbutils.widgets.get('catalog')}.{dbutils.widgets.get('schema')}.sales"`,
or simplify the `print` to remove the reference. Either is accepted; the diagnosis is
the exercise, not the repair.

## What is deliberately *not* wrong

Three things in this bundle look suspicious and are correct. Expect at least one team
to "fix" one of them and lose time.

- `run_if: ALL_DONE` on `notify`. Intentional: the notification must run whether or not
  the pipeline succeeded.
- The `staging` target's cluster override names `job_cluster_key: main`, spelled
  correctly, and merges. It is there so that a team can compare it against the append
  behaviour on S46.
- `autoscale: {min_workers: 1, max_workers: 2}` in the base. Small, and deliberately so.

## Timing

Twelve minutes is enough for three of the four faults for most teams and all four for
one or two. Faults 1 and 2 take about four minutes together. Fault 3 costs the most,
because a team has to give up on `validate` and deploy. Fault 4 is fast once the run
history is open.

If a team is stuck at eight minutes, the prompt to give is a question, not a fix:
*which command have you not run yet?*
