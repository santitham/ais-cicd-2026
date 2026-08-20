# Challenge 3 — reference solution

`etl.job.yml` replaces `resources/ingest.job.yml`. The five notebooks go in `src/`.

The graph this file declares:

```
              land
             /    \
     features      quality        (parallel: separate clusters)
             \    /
             publish
                |
              notify              (run_if: ALL_DONE)
```

Verified with the CLI:

```
$ databricks bundle validate -o json \
    | jq -r '.resources.jobs.ingest.tasks[] | "\(.task_key) <- \(.depends_on // [] | map(.task_key) | join(", "))"'
features <- land
land <-
notify <- publish
publish <- features, quality
quality <- land
```

The tasks come out in alphabetical order, not file order. The resolved configuration
sorts a job's `tasks` sequence by `task_key`, which matters for reading diagnostics —
see `broken-bundle-solutions.md`, fault 1.

## The retry justification

`features` carries the retry in this solution. Any of the five is acceptable as long as
the written reason names a failure a second attempt could survive: a rate limit, a
transient network failure, a lock held by another writer. Two answers should be pushed
back on:

- **`publish`**, if the task is not idempotent. A retry re-runs the task, so a publish
  that appends rather than overwrites will write twice.
- **`notify`**, because there is nothing to retry: `run_if: ALL_DONE` already guarantees
  it runs, and a failed notification is not worth a second cluster start.

## Three things participants get wrong

1. `features` and `quality` are given the shared cluster, so they do not run in
   parallel. The declaration is valid and the graph is right; the parallelism is absent.
   The run history is what shows it.
2. `publish` is given two `depends_on` blocks rather than one block with two entries.
   The second silently replaces the first, so `publish` waits for one parent.
3. `notify` is given `run_if: ALL_DONE` **and** a `depends_on` on `publish` only. That
   is correct. Some participants also add `features` and `quality`, which is harmless
   but means the notification no longer waits for `publish`.
