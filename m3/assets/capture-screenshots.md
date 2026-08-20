# Module 3 — screenshot capture guide

Five captures, keyed to the slide numbers in `slide-plan.md` and to the
`SCREENSHOT S<n>` placeholders in `slides.pptx`. Grep the deck for
`SCREENSHOT S` to find any still unfilled.

Two of the module's demonstration slides, S41 and S42, are typeset rather than
captured, because their output was executed and is stable. The five below all
require a live workspace and cannot be produced anywhere else.

## Before you start

```bash
bash prep-ubuntu-m3.sh          # must end with "Every check passed"
export PATH="$HOME/.local/bin:$PATH"
cd ~/m3-demo                     # a scratch directory, not your course repo
```

Versions the commands below were checked against:

| Tool | Version |
|---|---|
| Databricks CLI | v1.12.1 |
| uv | 0.8.17 |
| jq | 1.7 |

Use the same terminal profile, font and window size as the Module 1 and
Module 2 captures, roughly 100×30, and run `clear` before each capture so the
command sits at the top of the frame.

The workspace paths in every capture contain your user name. That is expected
and matches the deck, which uses `santitham.pro@kmutt.ac.th` throughout.

---

## S34 — initialisation without credentials

The slide claims that `bundle init` is not an offline operation. The capture is
the evidence.

```bash
env -u DATABRICKS_HOST -u DATABRICKS_TOKEN -u DATABRICKS_CONFIG_PROFILE \
  databricks bundle init default-python
```

The frame must show the command and this error, and nothing else:

```
Error: default auth: cannot configure default credentials, please check
https://docs.databricks.com/en/dev-tools/auth.html#databricks-client-unified-authentication
to configure credentials for your preferred authentication method
```

If you can reach a workspace with a token that has no Unity Catalog access, a
second frame of that failure is worth having as a spare, because it is the more
common one in a classroom:

```
Error: template: :1:9: executing "" at <default_catalog>: error calling
default_catalog: Get ".../api/2.1/unity-catalog/current-metastore-assignment": Forbidden
```

Verified in the sandbox against a mock workspace. Both messages should appear
verbatim; a difference indicates a CLI version other than 1.12.x.

---

## S35 — what `default-python` generates

Two frames, or one tall frame if the terminal is 40 rows.

```bash
databricks bundle init default-python      # answer: m3demo, then the catalog
tree -a -I '.git|.databricks|dist|build' m3demo
```

`tree` is not installed by default: `sudo apt-get install -y tree`.

The frame must show the prompts and their answers, and then the tree. Compare
it against `assets/expected-bundle-tree.txt` before capturing; if they differ,
the difference is more interesting than the capture and should be reported
before the module runs.

The tree is the reference participants check their own project against in
Challenge 2, so it must be legible at the size the slide renders it. If the
full tree will not fit, capture `tree -a -L 2 m3demo` and keep the deeper
listing for the printed handout.

---

## S46 — where the deployment lives

Deploy first, then capture the two listings.

```bash
cd m3demo
databricks bundle deploy -t dev
databricks workspace list "/Workspace/Users/${USER_EMAIL}/.bundle/m3demo/dev"
databricks workspace list "/Workspace/Users/${USER_EMAIL}/.bundle/m3demo/dev/files"
```

Set `USER_EMAIL` from `databricks current-user me -o json | jq -r .userName`.

The frame must show four entries at the root path — `artifacts`, `files`,
`resources`, `state` — and, under `files`, the project's own directories. The
point of the slide is that the source tree exists twice, so the second listing
matters more than the first.

A workspace browser screenshot of the same path is a good second frame if the
CLI listing is visually thin, but the CLI form is preferred for consistency
with the rest of the deck.

---

## S49 — `bundle run`

```bash
databricks bundle run sample_job -t dev
```

The frame must show the run URL printed at the top, at least two state
transitions, and the terminal result. If the job fails, capture it anyway and
keep it: a failed run with its URL is a usable slide, and the recovery is the
subject of Module 4.

Note the elapsed time on the first run. The deck asserts that a first
deployment in a shared workspace is slow, and the number belongs in the
instructor notes rather than on the slide.

---

## S52 — `bundle destroy`

```bash
databricks bundle destroy -t dev
```

Answer `y` to both prompts. The frame must show both prompts, because the slide
makes the point that resources and files are deleted in two separate steps:

```
The following resources will be deleted:
  delete job sample_job
...
The following bundle files will be deleted:
  delete /Workspace/Users/<you>/.bundle/m3demo/dev/files
```

Capture before answering the second prompt if the whole exchange will not fit
in one frame; the first prompt is the one that carries the teaching point.

---

## After capturing

Paste each image over the corresponding placeholder rectangle in
`slides.pptx`, keeping the note strip at the bottom of the slide. The
placeholder is a plain rectangle at 2.35 in from the left, 2.64 in from the
top, 10.40 by 3.42 in; matching that box keeps the five slides consistent.

Then record in `project_module03_decisions.md` that the pending items from
`slide-plan.md` have been executed, and correct the deck if any output differs
from what the slides assert. Two slides were already corrected this way after
the `uv` failure, and that is the expected outcome of a capture session rather
than a sign that something went wrong.
