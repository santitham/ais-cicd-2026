# Module 2 — Lab Guide

> Two labs. A is YAML, solo, ~60 min. B is the Databricks CLI, solo, ~60 min.

---

## Lab A — Write a workflow file by hand (60 min)

**Goal:** author a GitHub Actions workflow from scratch, validate it locally, observe each YAML trap firsthand, and watch the workflow run.

### A.1 Install yq (5 min)

Pick the install for your OS:

```bash
# macOS
brew install yq

# Linux (one-liner)
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq

# Windows
winget install --id MikeFarah.yq
```

Verify:

```bash
yq --version
```

**Expected output:**

```
yq (https://github.com/mikefarah/yq/) version v4.40.5
```

### A.2 Create the workflow file (15 min)

In the repo from Module 1, create the directory and file:

```bash
mkdir -p .github/workflows
touch .github/workflows/lint.yml
```

Open the empty file in your editor. **Type — don't paste — the following.** Typing it by hand is the point of the lab.

```yaml
name: lint

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Check out code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install flake8
        run: pip install flake8

      - name: Run flake8
        run: flake8 etl/ --max-line-length=100
```

### A.3 Validate locally (5 min)

```bash
yq . .github/workflows/lint.yml
```

**Expected output (re-formatted YAML, no errors):**

```yaml
name: lint
on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Check out code
        uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - name: Install flake8
        run: pip install flake8
      - name: Run flake8
        run: flake8 etl/ --max-line-length=100
```

If you got an error message, fix it before continuing.

Try it as JSON:

```bash
yq -o json . .github/workflows/lint.yml
```

**Expected output:** the same data as a JSON document. Useful for piping into other tools.

### A.4 Trap 1 — Tabs (10 min)

Open the file. Find any indented line. Replace the leading spaces with a single tab character.

```bash
yq . .github/workflows/lint.yml
```

**Expected output:**

```
Error: bad file '.github/workflows/lint.yml': yaml: line 12: found character that cannot start any token
```

The line number points you exactly. Restore spaces. Re-run yq, confirm clean parse.

### A.5 Trap 2 — Number that looks like a string (10 min)

Change `python-version: "3.11"` to `python-version: 3.10` (no quotes).

```bash
yq '.jobs.lint.steps[1].with["python-version"]' .github/workflows/lint.yml
```

**Expected output:**

```
3.1
```

Wait — that's `3.1`, not `3.10`. YAML parsed `3.10` as a float, and `3.10` as a float is `3.1`.

```bash
yq '.jobs.lint.steps[1].with["python-version"] | type' .github/workflows/lint.yml
```

**Expected output:**

```
!!float
```

This is the worst kind of YAML bug: parses cleanly, runs wrong.

Restore the quotes. Re-run:

```bash
yq '.jobs.lint.steps[1].with["python-version"] | type' .github/workflows/lint.yml
```

**Expected output:**

```
!!str
```

### A.6 Trap 3 — The Norway problem (5 min)

Add a new step:

```yaml
      - name: Check (no, really)
        if: no
        run: echo "this never runs"
```

```bash
yq '.jobs.lint.steps[-1].if' .github/workflows/lint.yml
```

**Expected output:**

```
false
```

That `no` was interpreted as the boolean `false`. The step would never run.

Quote it: `if: "no"`. Re-run:

```bash
yq '.jobs.lint.steps[-1].if' .github/workflows/lint.yml
yq '.jobs.lint.steps[-1].if | type' .github/workflows/lint.yml
```

**Expected output:**

```
no
!!str
```

Now it's the string `"no"`. (You'd still want to rename the variable — a string `"no"` is rarely what you mean either.) Delete this step.

### A.7 Trap 4 — Off-by-one indent (5 min)

Add one extra space before `cache: pip`:

```yaml
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"
           cache: pip
```

```bash
yq '.jobs.lint.steps[1].with' .github/workflows/lint.yml
```

**Expected output:**

```yaml
python-version: "3.11 cache: pip"
```

The "cache: pip" got swallowed into the python-version string. Restore the correct indent.

### A.8 Commit and watch CI (5 min)

```bash
git add .github/workflows/lint.yml
git commit -m "ci: add flake8 lint workflow"
git push
```

**Expected output:**

```
[main 7a2b3c4] ci: add flake8 lint workflow
 1 file changed, 22 insertions(+)
 create mode 100644 .github/workflows/lint.yml
...
To https://github.com/<you>/<repo>.git
   89f7e2b..7a2b3c4  main -> main
```

GitHub → **Actions** tab. You should see "lint" in the workflow list, with a run in progress. Click into it.

**What you should see:**

- One job, `lint`, queued or running.
- After ~30 seconds, status `completed`. May be green (✓) or red (✗) depending on whether flake8 found issues in your starter code.

If flake8 fails (likely — the starter file has style issues), open the failed step, read the lines flake8 cites, fix them, push again.

### A.9 Success check

- [ ] `yq` parses your `lint.yml` cleanly.
- [ ] You triggered all four YAML traps and saw what each does.
- [ ] The Actions tab shows a workflow run (green or red, your choice).
- [ ] You can recite the four traps without looking at this guide.

---

## Lab B — Drive the workspace from the CLI (60 min)

**Goal:** complete a full job lifecycle — upload code, create a job, run it, inspect it — without using the Databricks UI.

### B.1 Install the CLI (5 min)

```bash
# macOS
brew install databricks/tap/databricks

# Linux
curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh

# Windows
winget install Databricks.CLI
```

```bash
databricks --version
```

**Expected output:**

```
Databricks CLI v0.230.0
```

(Anything ≥ 0.205 is fine.) If you see something like `databricks-cli, version 0.18.0`, that's the **legacy** CLI — uninstall it and use the modern one.

### B.2 Configure a profile (10 min)

```bash
databricks configure --host https://<your-workspace> --profile dev
```

When prompted, paste a Personal Access Token (generate from **User Settings → Developer → Access tokens**).

```bash
cat ~/.databrickscfg
```

**Expected output:**

```
[dev]
host  = https://<your-workspace>
token = dapixxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Verify:

```bash
databricks current-user me --profile dev | jq .userName
```

**Expected output:**

```
"jane.quinn@example.com"
```

### B.3 Upload code to the workspace (10 min)

```bash
WORKSPACE_PATH="/Workspace/Shared/cicd-course/$(whoami)"
databricks workspace mkdirs "$WORKSPACE_PATH" --profile dev
```

**Expected output:** no output. (Silence = success.)

```bash
databricks workspace import \
  --file assets/hello_world.py \
  --format SOURCE --language PYTHON \
  --profile dev \
  "$WORKSPACE_PATH/hello_world"
```

**Expected output:** no output, exit code 0.

Confirm it landed:

```bash
databricks workspace list "$WORKSPACE_PATH" --profile dev
```

**Expected output:**

```
hello_world
```

Or, with `--output json`:

```bash
databricks workspace list "$WORKSPACE_PATH" --profile dev --output json | jq
```

**Expected output:**

```json
[
  {
    "object_type": "NOTEBOOK",
    "path": "/Workspace/Shared/cicd-course/jane/hello_world",
    "language": "PYTHON",
    "object_id": 4729183746,
    "modified_at": 1716840000000
  }
]
```

### B.4 Create a job (UI for now) (10 min)

In the Databricks UI: **Workflows → Create Job**.

- **Job name:** `hello-world-<yourname>`
- **Task name:** `say-hello`
- **Type:** Python file
- **Path:** `$WORKSPACE_PATH/hello_world.py` (use the absolute path, replacing variables)
- **Cluster:** create a new tiny one (1 worker, smallest node type, latest runtime)

Click **Create**. The job appears. **Copy the Job ID** from the URL (`/jobs/<id>`).

> We're using the UI here on purpose. Tomorrow you'll replace this entire flow with a single `databricks bundle deploy`.

### B.5 Trigger from the CLI (15 min)

```bash
JOB_ID=<your-job-id>
RUN_ID=$(databricks jobs run-now --job-id $JOB_ID --profile dev | jq -r .run_id)
echo "Run started: $RUN_ID"
```

**Expected output:**

```
Run started: 5829374
```

Poll the state:

```bash
databricks jobs get-run --run-id "$RUN_ID" --profile dev | jq .state
```

**Expected output (first call, while running):**

```json
{
  "life_cycle_state": "RUNNING",
  "state_message": "In run",
  "user_cancelled_or_timedout": false
}
```

Wait 60 seconds (cluster start-up). Poll again:

**Expected output (after completion):**

```json
{
  "life_cycle_state": "TERMINATED",
  "result_state": "SUCCESS",
  "state_message": "",
  "user_cancelled_or_timedout": false
}
```

Extract just the result:

```bash
databricks jobs get-run --run-id "$RUN_ID" --profile dev \
  | jq -r '.state.result_state'
```

**Expected output:**

```
SUCCESS
```

This `jq` filter is exactly what Day 4's smoke-test step in CI runs.

### B.6 Read the log output (10 min)

```bash
databricks jobs get-run-output --run-id "$RUN_ID" --profile dev | jq -r .logs
```

**Expected output:** lines like

```
Hello, world! at 2026-05-17T14:30:42.123456+00:00
Python version: 3.11.5 (main, ...) [GCC 9.4.0]
```

### B.7 Success check

- [ ] You configured a profile, uploaded a file, created a job, triggered it, polled, and read its output — all from your terminal.
- [ ] You used `jq` at least three times to extract specific fields.
- [ ] You can name the three Databricks compute types and explain which is appropriate for a CI workflow.

---

## Common errors and recoveries

| Symptom | Cause | Fix |
|---|---|---|
| `Error: cannot configure default credentials` | No profile set, or wrong profile name | Add `--profile <name>` or `export DATABRICKS_CONFIG_PROFILE=<name>` |
| `403 Forbidden` from any CLI command | Token expired or scope insufficient | Re-generate a PAT; check the user has workspace access |
| `yq: command not found` after install | Shell hasn't reloaded PATH | Open a new terminal or `source ~/.zshrc` |
| YAML "looks right" but workflow doesn't trigger | Indentation off-by-one or wrong filename | File must be in `.github/workflows/`, must end in `.yml` or `.yaml`, lowercase |
| `jq: error: 'X' is not defined` | Trying to query an invalid path | Pipe through `jq .` first to see the structure |
