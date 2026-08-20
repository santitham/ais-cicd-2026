# Challenge 3 — Author a second job

**10 minutes. Work in the project you generated in Challenge 2.**

You are adding a reporting job to the bundle. Write it yourself; do not copy
the generated job and edit it.

## Requirements

1. The job is declared in a new file, `resources/report.job.yml`. Do not add it
   to `databricks.yml`.
2. Its resource key is `report_job`.
3. Its name is not written literally. It comes from a new variable,
   `report_job_name`, which you declare with a description and assign the value
   `daily_report` in the `dev` target.
4. It has exactly one task, keyed `report`, which runs a notebook.
5. The notebook is a file you create at `src/report_notebook.py`. Two lines are
   enough. The first must be `# Databricks notebook source`, which is what makes
   the workspace treat a `.py` file as a notebook.
6. The job has no trigger.

## Then

```bash
databricks bundle validate
databricks bundle validate -o json | jq '.resources.jobs.report_job.name'
```

## Success

`Validation OK!`, and a resolved name of `[dev <your short name>] daily_report`.

If the name comes back as `daily_report` with no prefix, you are validating
against a target that is not in development mode. If it comes back as
`${var.report_job_name}`, the variable is not declared where you think it is.

## Two traps in this exercise

The path in requirement 5 is relative to the file that declares it, and your
file is in `resources/`, so the task must name `../src/report_notebook.py`.
A path that escapes the bundle root fails validation and is left unrewritten,
which is the other way this goes wrong.

The variable must be declared at the top level of `databricks.yml` and assigned
inside the target. Declaring it only inside the target is not sufficient, and
using it without declaring it at all is an error rather than an empty string.

## If you finish early

Override the name for one command without editing any file:

```bash
databricks bundle validate -o json --var report_job_name=weekly_report \
  | jq '.resources.jobs.report_job.name'
```

Name which of the four sources of a variable value won, and why. You will use
the same mechanism in Challenge 6.
