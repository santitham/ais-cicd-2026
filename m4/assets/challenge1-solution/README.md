# Challenge 1 — reference solution

`ingest.job.yml` goes in `resources/`. `land.py` goes in `src/`.

Resolved `notebook_path` for target `dev`, with bundle name `m4demo_<initials>`:

```
/Workspace/Users/<you>/.bundle/m4demo_<initials>/dev/files/src/land
```

Three things participants get wrong, in order of frequency:

1. The notebook marker line is missing, so `validate` reports
   `expected a notebook ... but got a file`.
2. `notebook_path` is written as `src/land.py` rather than `../src/land.py`. The path is
   relative to `resources/ingest.job.yml`, not to the bundle root.
3. `job_clusters` is written under the task rather than under the job. The schema
   rejects it as an unknown field on a task, so the warning names the task, not the job.
