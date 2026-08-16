# Module 2 — screenshot capture guide

Ten captures, keyed to the slide numbers in `slide-plan.md`. Every output below was produced by running the command, not transcribed, so a mismatch on your server indicates a version difference worth investigating rather than a typo here.

## Before you start

```bash
bash prep-ubuntu.sh
cd ~/m2-demo
```

Versions the outputs below were produced against:

| Tool | Version |
|---|---|
| yq | v4.53.3 (mikefarah) |
| actionlint | 1.7.7 |
| yamllint | 1.38.0 |
| PyYAML | via `python3-yaml` |

For consistency across the deck, set the terminal to roughly 100×30, use the same profile and font as the Module 1 captures, and run `clear` before each capture so the command sits at the top of the frame.

---

## S18 — a `run:` block under `|` and under `>`

```bash
cat fixtures/runblock.yml
yq -o json . fixtures/runblock.yml
```

Output:

```json
{
  "steps": [
    {
      "name": "literal",
      "run": "pip install flake8\nflake8 etl/ --max-line-length=100\n"
    },
    {
      "name": "folded",
      "run": "pip install flake8 flake8 etl/ --max-line-length=100\n"
    }
  ]
}
```

The point of the capture is the second `run` value: two commands folded onto one line, which the shell receives as a single malformed command. Highlight it in the slide.

---

## S23 — yq on a valid file

```bash
yq . fixtures/lint-valid.yml
yq -o json . fixtures/lint-valid.yml | head -20
```

First command output, first lines:

```
name: lint
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
jobs:
  lint:
```

Note that yq preserves flow style (`[main]`) rather than expanding it. Worth a sentence on the slide, since it shows yq is reprinting the tree and not the file.

---

## S27 — class 1, a tab in the indentation

```bash
cat -A fixtures/lint-tab.yml | sed -n '9p'
yq . fixtures/lint-tab.yml
```

Outputs:

```
^Iruns-on: ubuntu-latest$
```

```
Error: bad file 'fixtures/lint-tab.yml': yaml: while scanning for the next token at line 9: found character that cannot start any token
```

Include the `cat -A` line in the capture. It is the only way to make the tab visible, and it is the practical answer to "how would I ever see this".

---

## S30 — class 2, the float

```bash
yq '.jobs.lint.steps[1].with["python-version"]'        fixtures/lint-float.yml
yq '.jobs.lint.steps[1].with["python-version"] | type' fixtures/lint-float.yml
yq '.jobs.lint.steps[1].with["python-version"] | type' fixtures/lint-valid.yml
```

Outputs, in order:

```
3.10
!!float
!!str
```

All three commands belong in one frame. The first line is the trap: yq prints `3.10` because it echoes the source token, so the naive check appears to confirm the file is correct.

---

## S33 — class 3, one file through two parsers

```bash
cat fixtures/two-parsers.yml
yq -o json . fixtures/two-parsers.yml
python3 -c "import yaml,json;print(json.dumps(yaml.safe_load(open('fixtures/two-parsers.yml')),indent=2))"
```

yq (YAML 1.2):

```json
{
  "on": { "push": { "branches": ["main"] } },
  "python-version": 3.10,
  "enabled": "no",
  "country": "NO"
}
```

PyYAML (YAML 1.1):

```json
{
  "true": { "push": { "branches": ["main"] } },
  "python-version": 3.1,
  "enabled": false,
  "country": false
}
```

Three differences from one five-line file: the key `on` becomes `true`, `3.10` becomes `3.1`, and both `no` and `NO` become `false`. This is the most important capture in Part A — it is the evidence for the claim on S19 that the parser, not the author, assigns meaning.

If the JSON is too wide for one frame, run the two commands in two panes side by side and capture both together.

---

## S42 — actionlint on classes 4 and 3

```bash
actionlint fixtures/lint-position.yml
actionlint fixtures/lint-norway.yml
```

Class 4:

```
fixtures/lint-position.yml:15:11: input "env" is not defined in action "actions/setup-python@v5". available inputs are "allow-prereleases", "architecture", "cache", "cache-dependency-path", "check-latest", "python-version", "python-version-file", "token", "update-environment" [action]
   |
15 |           env:
   |           ^~~~
fixtures/lint-position.yml:16:13: expected scalar node for string value but found mapping node with "!!map" tag [syntax-check]
   |
16 |             TOKEN: abc
   |             ^~~~~~
```

Class 3:

```
fixtures/lint-norway.yml:28:13: undefined variable "no". available variables are "env", "github", "inputs", "job", "matrix", "needs", "runner", "secrets", "steps", "strategy", "vars" [expression]
   |
28 |         if: no
   |             ^~
```

The class 3 message is worth a sentence in the lecture: `if:` is evaluated as an expression, so an unquoted `no` is read as a variable name rather than as a string or a boolean. That is a third interpretation of the same two characters, beyond the two on S32.

---

## S44 — validate.sh across the five fixtures

```bash
for f in lint-valid lint-tab lint-float lint-norway lint-position; do
    printf '\n----- %s -----' "$f"
    ./validate.sh fixtures/$f.yml
done
```

Output, abbreviated to the decisive lines:

```
----- lint-valid -----
[1] parse            : ok
[2] style and truthy : ok
[3] workflow schema  : ok
all three levels passed: fixtures/lint-valid.yml

----- lint-tab -----
[1] parse            : FAILED
Error: bad file 'fixtures/lint-tab.yml': yaml: while scanning for the next token at line 9: found character that cannot start any token

----- lint-float -----
[1] parse            : ok
[2] style and truthy : ok
[3] workflow schema  : ok
all three levels passed: fixtures/lint-float.yml

----- lint-norway -----
[1] parse            : ok
[2] style and truthy : FAILED
fixtures/lint-norway.yml
  28:13     warning  truthy value should be one of [false, true]  (truthy)

----- lint-position -----
[1] parse            : ok
[2] style and truthy : ok
[3] workflow schema  : FAILED
fixtures/lint-position.yml:15:11: input "env" is not defined in action "actions/setup-python@v5" ...
```

Each fixture fails at a different level, and `lint-float` passes all three despite requesting Python 3.1. That result is the whole argument of S41 and is worth leaving on screen while you make it.

---

## S53 — Databricks CLI version

```bash
databricks --version
```

Expected:

```
Databricks CLI v0.2xx.x
```

If you also want the legacy string beside it for the comparison on S52, run this in a throwaway virtual environment so it does not shadow the real CLI:

```bash
python3 -m venv /tmp/legacy && /tmp/legacy/bin/pip install -q databricks-cli
/tmp/legacy/bin/databricks --version    # prints: databricks-cli, version 0.18.0
rm -rf /tmp/legacy
```

---

## S56 — configure, and the file it writes

```bash
databricks configure --host https://<your-workspace> --profile dev
cat ~/.databrickscfg
databricks current-user me --profile dev | jq .userName
```

The token will be visible in `cat` output. Either redact it in the image, or generate a throwaway token, capture, then revoke it immediately. The second option is better, because a redaction box in a slide invites students to wonder what was underneath.

---

## S59 — a complete job lifecycle

Run against a real workspace with the `dev` profile configured. Capture the whole sequence in one frame; shrink the font if necessary rather than splitting it, because the point is that the entire lifecycle fits on one screen.

```bash
WS="/Workspace/Shared/cicd-course/$(whoami)"
databricks workspace mkdirs "$WS" --profile dev
databricks workspace import --file hello_world.py \
    --format SOURCE --language PYTHON --profile dev "$WS/hello_world"
databricks workspace list "$WS" --profile dev

RUN_ID=$(databricks jobs run-now --job-id "$JOB_ID" --profile dev | jq -r .run_id)
databricks jobs get-run --run-id "$RUN_ID" --profile dev | jq .state
databricks jobs get-run --run-id "$RUN_ID" --profile dev | jq -r '.state.result_state'
databricks jobs get-run-output --run-id "$RUN_ID" --profile dev | jq -r .logs
```

`hello_world.py` is already in the module's `assets/` directory. `JOB_ID` comes from the job you create for the demo; the URL ends in `/jobs/<id>`.

The first `get-run` should be run while the job is still starting, so the capture shows `RUNNING` and then `TERMINATED`/`SUCCESS` on the second call. Cluster start-up gives you roughly a minute to do this.

---

## Captures not needed

S17, S29, S35, S40 and S60 are marked `RUN/SEE` in the plan, meaning typeset two-column slides in the Module 1 style rather than screenshots. The commands and outputs for those are in this file too, under the corresponding capture, so the typeset versions can be copied from here rather than re-run.
