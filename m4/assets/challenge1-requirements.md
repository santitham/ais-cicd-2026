# Challenge 1 — Author a job on a job cluster

**8 minutes. Write the file yourself. Do not open any existing resource file.**

Your bundle currently has no resources. Create one.

## Requirements

1. A new file, `resources/ingest.job.yml`.
2. One job, keyed `ingest`, named `sales_ingest`.
3. One job cluster, keyed `main`, specifying:
   - the long-term support runtime this course uses,
   - the Azure instance type this course uses,
   - the automatic access mode,
   - autoscaling between one and three workers.
4. One task, keyed `land`, claiming that cluster, running a notebook you create at
   `src/land.py`.
5. The task passes the bundle's `catalog` and `schema` variables to the notebook as
   base parameters.
6. The job allows one concurrent run and has no timeout.

The values for requirement 3 are on the slide titled *The fields of `new_cluster`*.
Look them up rather than guessing; a wrong runtime string is not caught until deploy.

## The notebook

`src/land.py` needs one line of content and one line that makes it a notebook rather
than a file. If you forget the second, `bundle validate` will tell you exactly which
one you forgot.

## Before you validate

Write down, on paper, the workspace path you expect `notebook_path` to resolve to for
target `dev`. You need the bundle name, the target, and the rule from the slide titled
*A local path becomes a workspace path*.

## Then

```bash
databricks bundle validate
databricks bundle validate -o json | jq -r '.resources.jobs.ingest.tasks[0].notebook_task.notebook_path'
```

## Success

`Validation OK!`, and a resolved path matching what you wrote down. If the resolved
path still ends in `.py`, re-read the slide: you have written the wrong payload key.

The solution is in `challenge1-solution/`. Read it only after your own version
validates.
