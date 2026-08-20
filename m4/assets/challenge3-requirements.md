# Challenge 3 — Build the pipeline

**12 minutes. Draw the graph before you write any YAML.**

You are extending the job you authored in Challenge 1, or the one you repaired in
Challenge 2. Either is a valid starting point; say which you used.

## The pipeline

Five tasks.

| Task | Waits for | Runs | Compute |
|---|---|---|---|
| `land` | nothing | `src/land.py` | the shared cluster |
| `features` | `land` | `src/features.py` | its own cluster |
| `quality` | `land` | `src/quality.py` | its own cluster |
| `publish` | `features` **and** `quality` | `src/publish.py` | the shared cluster |
| `notify` | `publish` | `src/notify.py` | the shared cluster |

## Requirements

1. Draw the graph on paper first. Five nodes. Count the arrows before you count the
   tasks.
2. `features` and `quality` must be able to run at the same time. Requirement 1 of the
   table gives them their own clusters for exactly this reason; two workers each is
   enough.
3. `notify` runs whether or not the pipeline succeeded. There is one value of `run_if`
   that expresses this. Use it, and do not give `notify` a cluster of its own.
4. One task gets `max_retries: 2` with a `min_retry_interval_millis` of at least 60000.
   Choose the task, and write one line saying why that task and not another. A defensible
   answer names a failure mode that a second attempt could plausibly survive.
5. Every notebook needs its marker line. Four of the five files do not exist yet.

## Then

```bash
databricks bundle validate
databricks bundle validate -o json \
  | jq -r '.resources.jobs.<your key>.tasks[] | "\(.task_key) <- \(.depends_on // [] | map(.task_key) | join(", "))"'
```

That last command prints the graph the file actually declares. Compare it, line by
line, with the graph you drew.

## Success

`Validation OK!`, three job clusters, and a printed graph identical to your drawing.

If the printed graph is not what you drew, the file is right and the drawing is wrong,
or the reverse. Find out which before you move on: Challenge 5 breaks this pipeline on
purpose and you will need to predict its behaviour.

The solution is in `challenge3-solution/`.
