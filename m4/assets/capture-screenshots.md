# Module 4 — screenshots to capture

Three slides carry a placeholder. Each shows output that only exists after a real
deployment, which is why none of them could be typeset from the sandbox runs. Capture
all three on the Ubuntu server against the training workspace, in one session, from the
same bundle, so the job names and paths agree across the three images.

## The fast way

`assets/m4demo/capture-run.sh` runs every command below against the live workspace and
records its output under `capture/`, so the text is captured before you start taking
images:

```bash
cd assets/m4demo
bash capture-run.sh --phase promote      # resolves only, seconds, no deployment
bash capture-run.sh                      # the full lifecycle, 40-60 min
cat capture/SUMMARY.md
```

Then re-run only the three commands below in a sized terminal for the images. The
captured text is the record; the screenshot is the artefact for the slide.

## Set up the terminal

Set up once:

```bash
cd assets/m4demo                        # or ~/m4demo_$USER, the bundle from Challenge 3
export PS1='$ '                         # a short prompt keeps the images readable
printf '\e[8;30;100t'                   # 100 columns x 30 rows
databricks bundle destroy -t dev --auto-approve   # start from nothing
```

The job key in `m4demo` is `ingest`. Substitute your own key if you are capturing from a
participant-shaped bundle.

Crop each image to the terminal window only. Paste into the placeholder rectangle on
the slide; the rectangle is 10.40 x 3.42 inches, so a 100-column terminal at a 3:1
aspect fills it without scaling artefacts.

---

## S54 — `plan` before `deploy`

Two captures in one image if they fit, otherwise capture the first and note the second
in the speaker notes.

```bash
databricks bundle plan -t dev
```

Wanted: one line per resource, each reporting a **create**, because nothing has been
deployed. There are three job clusters and one job in the Challenge 3 bundle.

Then, after the deployment in S55 exists, run it again with no edits so that the
**no change** form is visible. If both fit in 30 rows, capture them together — the
contrast is the point of the slide.

## S55 — Deploying a second time

```bash
databricks bundle deploy -t dev
databricks bundle deploy -t dev          # again, nothing edited
```

Wanted: the stage lines of the first deployment, then the second deployment reporting
no action. If the second is too terse to be legible on its own, include the first for
contrast even if the image has to be two panes.

Note for the slide's speaker notes: record the wall-clock time of each, because the
first deployment in a shared workspace is slow and participants will ask.

## S56 — `bundle run`, and what it reports

```bash
databricks bundle run ingest -t dev
```

Wanted, in this order: the run URL, the per-task state transitions, and the terminal
result. The five-task pipeline from Challenge 3 is the right subject because
`features` and `quality` appear as concurrent, which nothing else in the deck shows.

Then capture the `--only` form as a second image if there is room on the slide:

```bash
databricks bundle run ingest -t dev --only features
```

---

## Also worth capturing, for the lab guide rather than the deck

These fill the **shape only** markings in `lab.md`. They are not on any slide, so a
rough capture is enough.

1. `databricks bundle summary -t dev` after the Challenge 3 deployment — the resource
   list with workspace ids. `capture-run.sh` records this as `*-summary.txt`.
2. The run history page for a run in which `features` failed and `notify` still ran, from
   Challenge 5. `capture-run.sh --phase break` produces exactly this run; take the run
   URL from `*-run-broken.txt`. The states of all five tasks must be legible; this is the image that
   answers the exit ticket's second question.
3. The Workflows list showing the `[dev <short name>]` prefix on the deployed job, next
   to a staging deployment of the same bundle without the prefix, from Challenge 4.
