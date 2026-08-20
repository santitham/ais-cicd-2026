# Challenge 1 — Predict the resolved configuration

**7 minutes. Written answers only. Do not run anything yet.**

Below is a complete bundle. The command about to be run is:

```bash
databricks bundle validate -o json
```

with no `-t` flag, from the directory holding this file.

```yaml
bundle:
  name: telemetry

variables:
  catalog:
    description: The catalog the job writes to
    default: sandbox

targets:
  dev:
    mode: development
    default: true
    workspace:
      host: https://adb-1234567890123456.7.azuredatabricks.net
    variables:
      catalog: training

resources:
  jobs:
    ingest_job:
      name: ingest_job
      trigger:
        periodic:
          interval: 1
          unit: DAYS
      parameters:
        - name: catalog
          default: ${var.catalog}
      tasks:
        - task_key: ingest
          notebook_task:
            notebook_path: ./src/ingest.py
```

Assume the authenticated user is `jane.doe@example.com`.

## Write down

1. The resolved value of `.resources.jobs.ingest_job.name`.
2. The resolved value of the `catalog` job parameter.
3. The resolved value of `.resources.jobs.ingest_job.trigger.pause_status`.
4. The resolved workspace `root_path`.

For each answer, name the stage of the assembly sequence that produced it:
read, merge, overlay, preset, or substitute.

## Two further questions, if you finish early

5. `.resources.jobs.ingest_job.max_concurrent_runs` does not appear anywhere in
   the file above. Will it appear in the output, and with what value?
6. The task names `./src/ingest.py`. What will `notebook_path` say after
   resolution?

Keep this paper. You check every answer against the CLI in Challenge 2.
