# Module 2 — Lab Guide

**YAML and the Databricks workspace**
Day 1 · Foundations · 3 hours (105 min teaching, 15 min break, 60 min at your keyboard)

Six challenges. Four on YAML, two on the Databricks CLI. Times are guides, not
gates; each challenge ends with a **Going further** step if you finish early.

Every command and every expected output in this guide has been executed. If your
result differs, the cause is a version difference or a typo, not a mistake in
the guide — tell your instructor either way.

| Challenge | Topic | Time |
|---|---|---|
| 1 | Read a document you did not write | 6 min |
| 2 | Predict the type | 7 min |
| 3 | Break it, then read the message | 10 min |
| 4 | Author a configuration from requirements | 12 min |
| 5 | Configure and verify a CLI profile | 8 min |
| 6 | Full job lifecycle from the terminal | 17 min |

---

## Pre-flight — tools

Run once, before Challenge 1. On Ubuntu:

```bash
bash assets/prep-ubuntu.sh
cd ~/m2-demo
```

That installs `yq`, `actionlint`, `yamllint`, `jq` and the Databricks CLI, and
writes every fixture file this guide uses.

Confirm:

```bash
yq --version
jq --version
databricks --version
```

Expected — versions may be newer:

```
yq (https://github.com/mikefarah/yq/) version v4.53.3
jq-1.7.1
Databricks CLI v0.230.0
```

> **Do not install yq with `apt`.** Ubuntu's package of that name is a Python
> wrapper around `jq`. It reports `yq 0.0.0` and none of the commands below
> work. If `yq --version` says `0.0.0`, remove it and re-run the prep script.

---

# Part A — YAML

## Challenge 1 — Read a document you did not write (6 min)

**Goal:** state the structure of a YAML file before running anything.

### 1.1 Read it on paper first

Open `fixtures/pipeline.yml`. Do not run any command yet.

```yaml
pipeline:
  name: customer_features
  enabled: true
  owners:
    - data-science
    - data-engineering
  settings:
    retries: 3
    timeout_minutes: 20
tasks:
  - name: prepare_data
    notebook: notebooks/prepare
    retries: 2
  - name: train_model
    notebook: notebooks/train
    retries: 1
```

On paper, draw the tree. Mark every node as a **mapping**, a **sequence**, or a
**scalar**. Then write down two numbers:

- How many elements does `tasks` have?
- How many keys does each element have?

### 1.2 Now check

```bash
yq -o json . fixtures/pipeline.yml
```

Expected:

```json
{
  "pipeline": {
    "name": "customer_features",
    "enabled": true,
    "owners": [
      "data-science",
      "data-engineering"
    ],
    "settings": {
      "retries": 3,
      "timeout_minutes": 20
    }
  },
  "tasks": [
    {
      "name": "prepare_data",
      "notebook": "notebooks/prepare",
      "retries": 2
    },
    {
      "name": "train_model",
      "notebook": "notebooks/train",
      "retries": 1
    }
  ]
}
```

Confirm your two numbers directly:

```bash
yq '.tasks | length' fixtures/pipeline.yml
```

```
2
```

<details>
<summary>The answer, and the line that decides it</summary>

Two top-level keys, `pipeline` and `tasks`, because both start in column 1.

`owners` is a **sequence** because the lines below it begin with `- `. Remove
those two markers and indent the values, and it becomes a mapping instead.

`tasks` is a **sequence of mappings**: two elements, three keys each. The `- `
and `name:` share a line, and `notebook:` and `retries:` line up with the `n` of
`name`, which is what places them inside the same element.

</details>

**Going further:** write the whole document as a Python literal, then check it:

```bash
python3 -c "import yaml,pprint;pprint.pprint(yaml.safe_load(open('fixtures/pipeline.yml')))"
```

### Success check

- [ ] Your drawing and the JSON have the same shape.
- [ ] You can point at the line that makes `owners` a list.

---

## Challenge 2 — Predict the type (7 min)

**Goal:** see that the parser, not the author, decides what a value is.

### 2.1 Commit to an answer first

Write down the resolved type of each of these nine values. A guess you did not
write down does not count.

```
42        1.0        3.10        0755        true
null      1e3        2026-08-16  "3.10"
```

### 2.2 Check each one

```bash
echo 'k: 3.10' > t.yml
yq '.k | type' t.yml
yq '.k' t.yml
```

Expected:

```
!!float
3.10
```

Note that `yq '.k'` prints `3.10`, because it echoes the token from the source.
The type is the only thing that reveals the problem. Force the arithmetic and
the stored value appears:

```bash
yq '.k + 0' t.yml
```

```
3.1
```

Now work through the rest.

<details>
<summary>All nine answers</summary>

| Written | Type | Value |
|---|---|---|
| `42` | `!!int` | 42 |
| `1.0` | `!!float` | 1.0 |
| `3.10` | `!!float` | **3.1** — the trailing zero is not stored |
| `0755` | `!!int` | **755** under yq |
| `true` | `!!bool` | true |
| `null` | `!!null` | null |
| `1e3` | `!!float` | 1000 |
| `2026-08-16` | `!!timestamp` | a date object |
| `"3.10"` | `!!str` | the two characters, unchanged |

The rule: an unquoted value is matched against a table of patterns and the
first match decides. Quoting suppresses the matching entirely.

</details>

### 2.3 The same file, a different parser

Two of those values are read differently by a YAML 1.1 parser:

```bash
printf 'a: 0755\nb: 1e3\n' > o.yml
yq -o json . o.yml
python3 -c "import yaml;print(yaml.safe_load(open('o.yml')))"
```

Expected:

```json
{
  "a": 0755,
  "b": 1e3
}
```

```
{'a': 493, 'b': '1e3'}
```

`0755` is **755** to yq and **493** to PyYAML, which reads a leading zero as
octal. `1e3` is the number **1000** to yq and the **string** `'1e3'` to PyYAML.

The same characters, two numbers and two types, decided by which library opened
the file.

### Success check

- [ ] You can state the rule that decides each of the nine, not only the answer.
- [ ] You can name a value whose meaning depends on the parser rather than the file.

---

## Challenge 3 — Break it, then read the message (10 min)

**Goal:** recognise the four most common faults, and read what the parser says.

Work on a copy, and restore it before each step:

```bash
cp fixtures/pipeline.yml work.yml
```

### 3.1 A tab in the indentation

Replace the leading spaces on the `name: customer_features` line with a single
tab character, then:

```bash
yq . work.yml
```

Expected:

```
Error: bad file 'work.yml': yaml: while scanning for the next token at line 2: found character that cannot start any token
```

Make the tab visible — this is the only reliable way to see one:

```bash
cat -A work.yml | sed -n '2p'
```

```
^Iname: customer_features$
```

`^I` is the tab. Restore the file: `cp fixtures/pipeline.yml work.yml`

### 3.2 A missing space after a colon

Change `name: customer_features` to `name:customer_features`, then:

```bash
yq . work.yml
```

Expected:

```
Error: bad file 'work.yml': yaml: line 3, column 10: mapping values are not allowed in this context
```

The colon needs a space after it to separate a key from a value. Without one,
the parser reads the whole thing as a plain scalar, and then fails when the next
line tries to be a key. Restore the file.

### 3.3 A misaligned sequence marker

Add one extra space before the second element of `owners`:

```yaml
  owners:
    - data-science
     - data-engineering
```

```bash
yq -o json '.pipeline.owners' work.yml
```

Expected — and note there is **no error**:

```json
[
  "data-science - data-engineering"
]
```

One element instead of two. The second `- ` was absorbed into the first value as
ordinary text. Nothing reports this. Restore the file.

### 3.4 A duplicate key

Add a second `retries:` under `settings` with a different value:

```yaml
  settings:
    retries: 3
    timeout_minutes: 20
    retries: 9
```

```bash
yq -o json '.pipeline.settings' work.yml
python3 -c "import yaml;print(yaml.safe_load(open('work.yml'))['pipeline']['settings'])"
yamllint -c .yamllint.yml work.yml
```

Expected:

```json
{
  "retries": 3,
  "timeout_minutes": 20,
  "retries": 9
}
```

```
{'retries': 9, 'timeout_minutes': 20}
```

```
work.yml
  10:5      error    duplication of key "retries" in mapping  (key-duplicates)
```

PyYAML silently keeps the last value and discards the first. `yq` emits both
keys, which is not valid JSON. `yamllint` is the only one of the three that
objects. Restore the file.

<details>
<summary>Which check catches which</summary>

| Fault | `yq .` | `yq \| type` | `yamllint` |
|---|---|---|---|
| Tab | reports it | — | reports it |
| Missing space after colon | reports it | — | reports it |
| Misaligned `- ` | passes | passes | passes |
| Duplicate key | passes | passes | **reports it** |
| `3.10` unquoted | passes | **reports it** | passes |

The first two stop you immediately. The last three do not, which is why a check
is worth running rather than trusting a careful read.

</details>

**Going further:** run `./validate.sh` against each of the five `lint-*.yml`
fixtures and record which level rejected each one. One of them passes every
check and is still wrong. Find it.

### Success check

- [ ] For each fault you can state the symptom and predict which check catches it.
- [ ] You can name a fault that no check in this module reports.

---

## Challenge 4 — Author a configuration from requirements (12 min)

**Goal:** write a document from a specification, not from a template.

### 4.1 The starting point

```bash
cp fixtures/skeleton.yml myconfig.yml
cat myconfig.yml
```

```yaml
project:
  name:
  owner:
environments:
tasks:
```

### 4.2 The requirements

Produce a document containing all of the following:

1. A project name and owner.
2. `development` and `production` environments, each with a different worker count.
3. At least two tasks, each with a name, an entrypoint and a retry count.
4. A boolean controlling whether notifications are enabled.
5. A multi-line description, with the line breaks preserved.
6. A list of at least two tags.
7. A `version` field whose exact text must survive parsing.

Requirements 5 and 7 each have one correct construct. Decide which before you
type.

### 4.3 Validate it

```bash
yq -o json . myconfig.yml
```

Check three things in the output rather than in your file:

- `environments` is a mapping, not a list.
- `tasks` is a list, and it has the number of elements you intended.
- `version` is a string. Confirm it: `yq '.version | type' myconfig.yml`

### 4.4 Swap

Exchange files with your neighbour. Read their document aloud as a structure —
*"a mapping called project, containing two scalars"* — before they tell you what
they meant. Where you read it differently from how they wrote it, work out which
line is responsible.

<details>
<summary>One correct answer</summary>

```yaml
project:
  name: customer-churn
  owner: data-science
  version: "1.0"

environments:
  development:
    workers: 1
  production:
    workers: 4

tasks:
  - name: prepare_features
    entrypoint: notebooks/prepare_features
    retries: 2
  - name: train_model
    entrypoint: notebooks/train_model
    retries: 1

notifications:
  enabled: true

description: |
  Prepare customer features and train
  the production churn model.

tags:
  - machine-learning
  - customer-analytics
```

`environments` is a mapping because the names matter and you refer to them by
name. `tasks` is a sequence because the elements are alike and nothing refers to
one by name.

`version` is quoted, or `1.0` becomes the number 1 and the text is lost.

`description` uses `|`, which preserves the line breaks. `>` would fold them
into spaces.

</details>

### Success check

- [ ] `yq -o json` shows the tree you intended.
- [ ] Your neighbour read your structure the same way you wrote it.
- [ ] `yq '.version | type'` returns `!!str`.

---

# Part B — The workspace and the CLI

## Challenge 5 — Configure and verify a profile (8 min)

**Goal:** get a working CLI profile, and recognise what a broken one looks like.

### 5.1 Generate a token

In the Databricks UI: your avatar → **Settings** → **Developer** →
**Access tokens** → **Generate new token**.

Set a short lifetime — 7 days is enough for this course. Copy the token now; it
is shown once.

> A personal access token is a bearer credential. Anyone holding it acts as you.
> Do not commit it, paste it into a notebook, or send it in a chat message.
> Module 7 replaces it with a service principal.

### 5.2 Configure

```bash
databricks configure --host https://<your-workspace> --profile dev
```

Paste the token when prompted.

```bash
cat ~/.databrickscfg
```

Expected:

```
[dev]
host  = https://adb-1502583690645883.3.azuredatabricks.net
token = dapi********************************
```

The file is in your home directory, outside any repository. That, rather than
`.gitignore`, is what keeps the token out of a commit.

### 5.3 Verify before doing anything else

```bash
databricks current-user me --profile dev | jq -r .userName
```

Expected:

```
santitham.pro@kmutt.ac.th
```

This one command confirms three things: the configuration file parsed, the host
is reachable, and the credential was accepted.

### 5.4 Break it deliberately

Edit `~/.databrickscfg` and change the host to something wrong, then re-run the
command above. Read the error. Restore the correct host.

<details>
<summary>Three failures worth recognising</summary>

| Message | Cause |
|---|---|
| `cannot configure default credentials` | No profile selected — add `--profile dev` |
| `403 Forbidden` | Token expired, revoked, or lacking access |
| `dial tcp: lookup ...: no such host` | Host wrong or mistyped |

Running `current-user me` first turns any of these into one clear failure at a
point where you know what you just changed.

</details>

### Success check

- [ ] `current-user me` returns your username.
- [ ] You recognise the error a wrong host produces.

---

## Challenge 6 — Full job lifecycle from the terminal (17 min)

**Goal:** upload code, create a job, run it, poll it, and read its result,
without opening the workspace UI.

Set these once. They live only in the current shell — open a new terminal and
you must set them again.

```bash
PROFILE=dev
WS="/Users/<your-email>"                 # your workspace user folder, no trailing slash
CLUSTER_NAME="Training_Cluster"
```

### 6.1 The notebook

```bash
cat > hello_world.py <<'EOF'
import sys, datetime

msg = (f"Hello, world! at {datetime.datetime.now(datetime.timezone.utc).isoformat()} "
       f"| Python {sys.version.split()[0]}")
print(msg)
dbutils.notebook.exit(msg)
EOF
```

`dbutils.notebook.exit()` is required. Without it the notebook runs correctly
and the API returns nothing — `print()` output goes to the notebook's cell
output, which is only visible in the browser.

### 6.2 Upload

```bash
databricks workspace import \
  --file hello_world.py \
  --format SOURCE --language PYTHON \
  --overwrite \
  --profile $PROFILE \
  "$WS/hello_world"

databricks workspace list "$WS" --profile $PROFILE | grep hello_world
```

Expected:

```
hello_world
```

> If you see `Error: Path () doesn't start with '/'`, the variable `$WS` is
> empty. The empty parentheses in the message are the evidence. Set it and
> re-run.

### 6.3 Find the cluster

```bash
CLUSTER_ID=$(databricks clusters list --profile $PROFILE -o json \
  | jq -r ".[] | select(.cluster_name==\"$CLUSTER_NAME\") | .cluster_id")
echo "cluster: $CLUSTER_ID"
```

Expected:

```
cluster: 0318-031919-b3fa4xtr
```

Empty means the name does not match. List them and check:

```bash
databricks clusters list --profile $PROFILE -o json | jq -r '.[].cluster_name'
```

### 6.4 Create the job

```bash
JOB_ID=$(databricks jobs create --profile $PROFILE -o json --json "{
  \"name\": \"hello-world-$(whoami)\",
  \"tasks\": [{
    \"task_key\": \"say-hello\",
    \"existing_cluster_id\": \"$CLUSTER_ID\",
    \"notebook_task\": { \"notebook_path\": \"$WS/hello_world\" }
  }]
}" | jq -r .job_id)
echo "job: $JOB_ID"
```

Expected:

```
job: 752310395422527
```

The task is a `notebook_task`, because `workspace import --format SOURCE
--language PYTHON` creates a notebook. A `spark_python_task` would not find it.

### 6.5 Run it

```bash
RUN_ID=$(databricks jobs run-now "$JOB_ID" --no-wait --profile $PROFILE -o json \
         | jq -r .run_id)
echo "run: $RUN_ID"
```

Expected:

```
run: 320453046596912
```

`--no-wait` matters. Without it the command blocks until the run finishes —
default timeout twenty minutes — and the next step has nothing left to poll.

### 6.6 Poll

```bash
databricks jobs get-run "$RUN_ID" --profile $PROFILE -o json | jq .state
```

While running:

```json
{
  "life_cycle_state": "RUNNING",
  "state_message": "In run"
}
```

After it finishes:

```json
{
  "life_cycle_state": "TERMINATED",
  "result_state": "SUCCESS",
  "state_message": "",
  "user_cancelled_or_timedout": false
}
```

Or wait for it:

```bash
while true; do
  STATE=$(databricks jobs get-run "$RUN_ID" --profile $PROFILE -o json \
          | jq -r .state.life_cycle_state)
  echo "$STATE"
  [ "$STATE" = "TERMINATED" ] && break
  sleep 10
done
```

### 6.7 The single field that matters

```bash
databricks jobs get-run "$RUN_ID" --profile $PROFILE -o json \
  | jq -r '.state.result_state'
```

```
SUCCESS
```

Remember this line. It is the smoke test in Module 8: one command, one word of
output, which a pipeline can act on.

### 6.8 The output

```bash
TASK_RUN_ID=$(databricks jobs get-run "$RUN_ID" --profile $PROFILE -o json \
              | jq -r '.tasks[0].run_id')

databricks jobs get-run-output "$TASK_RUN_ID" --profile $PROFILE -o json \
  | jq -r '.notebook_output.result'
```

Expected:

```
Hello, world! at 2026-08-16T04:46:48.235000+00:00 | Python 3.11.11
```

Note the **task** run id, not the job run id. `get-run-output` operates on a
task; the two ids differ. Passing the job run id returns
`"notebook_output": {}`.

### 6.9 Two fields worth knowing

```bash
databricks jobs get-run "$RUN_ID" --profile $PROFILE -o json | jq -r '.run_page_url'

databricks jobs get-run "$RUN_ID" --profile $PROFILE -o json \
  | jq -r '"setup: \(.setup_duration/1000)s   execution: \(.execution_duration/1000)s"'
```

Example:

```
https://adb-1502583690645883.3.azuredatabricks.net/?o=.../run/899390193047849
setup: 321s   execution: 21s
```

`run_page_url` is what to print in CI when something fails, so whoever reads the
log can go straight to the run.

The two durations are the argument for the compute-types discussion in one line:
this run spent 321 seconds acquiring a machine and 21 seconds doing the work.

### Success check

- [ ] You obtained `SUCCESS` from a command, not from the UI.
- [ ] You used `jq` to extract at least three separate fields.
- [ ] You can say which of the six steps Module 3 replaces with `databricks bundle deploy`.

---

## Common errors

| Symptom | Cause | Fix |
|---|---|---|
| `yq 0.0.0`, unknown commands | apt's `yq`, a `jq` wrapper | Remove it; install the Go binary |
| `Path () doesn't start with '/'` | `$WS` unset in this shell | Set it; note the empty `()` in the message |
| `unknown flag: --job-id` | Modern CLI takes the id positionally | `databricks jobs run-now "$JOB_ID"` |
| `run-now` returns only when finished | It blocks by default | Add `--no-wait` |
| `"notebook_output": {}` | Job run id used, or no `dbutils.notebook.exit()` | Use the task run id; add the exit call |
| `jq: Cannot index array with string` | The response is a bare array | Use `.[]`, not `.field[]` |
| `cannot configure default credentials` | No profile selected | Add `--profile dev` |
| `403 Forbidden` | Token expired or insufficient | Generate a new token |
| YAML "looks right" but behaves wrongly | A value resolved to a type you did not intend | `yq '<path> \| type'` |

---

## Quick reference

```bash
# --- reading YAML ---------------------------------------------------------
yq . file.yml                     # does it parse?
yq -o json . file.yml             # what does the tool receive?
yq '.a.b[0].c' file.yml           # one value
yq '.a.b | type' file.yml         # !!str  !!int  !!float  !!bool  !!null
yq '.list | length' file.yml      # how many elements
cat -A file.yml                   # make tabs visible as ^I

# --- checking it ----------------------------------------------------------
yamllint -c .yamllint.yml file.yml    # duplicate keys, truthy values
actionlint file.yml                    # workflow schema (explicit path)
./validate.sh file.yml                 # all three, stopping at the first failure

# --- the CLI --------------------------------------------------------------
databricks current-user me --profile dev | jq -r .userName
databricks workspace import --file f.py --format SOURCE --language PYTHON \
    --overwrite --profile dev "$WS/name"
databricks workspace list "$WS" --profile dev
databricks clusters list --profile dev -o json | jq -r '.[].cluster_name'
databricks jobs create --profile dev -o json --json '{...}' | jq -r .job_id
databricks jobs run-now "$JOB_ID" --no-wait --profile dev -o json | jq -r .run_id
databricks jobs get-run "$RUN_ID" --profile dev -o json | jq -r '.state.result_state'
databricks jobs get-run-output "$TASK_RUN_ID" --profile dev -o json \
    | jq -r '.notebook_output.result'
```

Ids are positional in the modern CLI. `--profile` and `-o json` work on every
command.

---

## Before Module 3

- [ ] You can read a nested YAML document and state its structure without running it.
- [ ] You quote versions, identifiers, dates and country codes by reflex.
- [ ] You know which of `|` and `>` to use for a multi-line command, and why.
- [ ] You can name the three layers of correctness and the tool that checks each.
- [ ] `yq --version` reports v4, not 0.0.0.
- [ ] `databricks current-user me --profile dev` returns your username.
- [ ] You have run a job and read its result state without opening the UI.
