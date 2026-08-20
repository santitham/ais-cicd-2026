# Challenge 1 — answer key

Instructor copy. Every value below was produced by running
`databricks bundle validate -o json` against the handout bundle with CLI
v1.12.1, not derived from the documentation. The user in the captured run was
`santitham.pro@kmutt.ac.th`, giving `santitham_pro`; for the handout's
`jane.doe@example.com` the same rule gives `jane_doe`.

| # | Answer | Stage | Why |
|---|---|---|---|
| 1 | `[dev jane_doe] ingest_job` | preset | `mode: development` computes `name_prefix`, which is applied to every resource name. The key `ingest_job` is untouched. |
| 2 | `training` | overlay, then substitute | The declaration's default is `sandbox`. The `dev` target assigns `training`, and the target overlay outranks the default. `${var.catalog}` is then replaced by the winning value. |
| 3 | `PAUSED` | preset | `trigger_pause_status: PAUSED` is one of the five development-mode presets. The trigger is declared but will not fire. |
| 4 | `/Workspace/Users/<user>/.bundle/telemetry/dev` | substitute | Derived from `bundle.name` and the target name. Nothing in the file states it. |
| 5 | Yes, `4` | preset | `jobs_max_concurrent_runs: 4`. It appears on the job as `max_concurrent_runs`. |
| 6 | `/Workspace/Users/<user>/.bundle/telemetry/dev/files/src/ingest` | substitute | Local paths are rewritten to their deployed location during resolution, before any deployment, and the `.py` suffix is dropped because the file is imported as a notebook. |

The job also acquires `"tags": {"dev": "<short_name>"}` from the presets, which
nobody predicts on the first attempt and which is worth pointing out.

## The mistake to expect

Most participants answer 2 with `sandbox`, reading the default and stopping.
The point of the exercise is that four sources can supply a variable value and
the declaration's default is the weakest of them.

## A variation, if the room finds this easy

Ask what changes with `-t prod` on a bundle that has a production target: the
name loses its prefix, the trigger becomes `UNPAUSED`, the tags disappear, and
`max_concurrent_runs` reverts to whatever the resource declares. Production
mode computes no presets at all.

## Common failure when they check it in Challenge 2

`bundle validate` needs the workspace to be reachable, so a participant whose
profile has expired sees an authentication error rather than their answers.
That is level 3 of the four levels of verification behaving exactly as
described, and is worth naming as such rather than treating as a lab defect.
