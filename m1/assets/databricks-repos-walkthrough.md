# Databricks Repos — a beginner's walkthrough

> If you've never used Databricks Repos before, this is the orientation. ~10 minutes to read.

## What it is

Databricks Repos lets you bring a Git repository (from GitHub, GitLab, Bitbucket, or Azure DevOps) into your Databricks workspace as a regular folder. The folder behaves like the GitHub repo: same files, same branches, same commits.

You can:

- Clone a GitHub repo into the workspace ("Add Repo").
- Switch branches, create new branches, commit, push, pull — all from a button in the UI.
- Open notebooks and Python files side-by-side with full Git history.

You do **not** need to install Git inside Databricks. The workspace talks to GitHub over HTTPS using a Personal Access Token you provide once.

## When to use Repos vs. local development

| Situation | Best workflow |
|---|---|
| Heavy Python refactor across many files | Edit locally (VS Code, etc.), push to GitHub, pull in Repos |
| Exploratory notebook on a real dataset | Edit in Databricks Repos directly, commit & push when done |
| Mixed: some code, some notebooks | Either works. Pick whichever screen you have open. |
| You don't have Databricks Connect set up | Use Repos — your code runs *in* the workspace |

Most data and ML teams end up doing both. Repos is the glue.

## Setup, step by step

You do this **once per Databricks user**.

### 1. Generate a GitHub PAT

GitHub → click your avatar → **Settings** → scroll to bottom of left sidebar → **Developer settings** → **Personal access tokens** → **Fine-grained tokens** → **Generate new token**.

| Field | Value |
|---|---|
| Token name | `databricks-<workspace-name>` |
| Expiration | 90 days (calendar a reminder to rotate) |
| Repository access | Only select repositories → pick the repos you want Databricks to read |
| Repository permissions | **Contents: Read and write**, **Metadata: Read**, **Pull requests: Read and write** |

Click **Generate token** and copy the value immediately. It won't show again.

### 2. Link the PAT in Databricks

In Databricks:

- Click your avatar (top right) → **User Settings**.
- **Linked accounts** tab (or "Git integration" in older UIs).
- **Git provider:** GitHub.
- **Username:** your GitHub username (not your email).
- **Personal Access Token:** paste the PAT.
- **Save**.

### 3. Add a repo

- Left sidebar → **Workspace**.
- Open your home folder. Click **Add → Git folder** (in newer UI) or open the legacy **Repos** folder and click **Add Repo**.
- **Git repository URL:** `https://github.com/<owner>/<repo>.git`.
- **Git provider:** GitHub (auto-detected from the URL).
- **Repo name:** leave default.
- **Create**.

The repo appears in your workspace. Navigate into it as you would any folder.

## Day-to-day operations

Every Git operation in Repos is one click. Each notebook (or any file) has a **branch chip** at the top of the screen. Click it to open the Git dialog.

| You want to… | Click |
|---|---|
| See the current branch | The branch chip (top of any file in the repo) |
| Switch to another branch | Branch chip → branch dropdown → pick |
| Create a new branch | Branch chip → "Create branch" |
| See your uncommitted changes | Branch chip → "Changes" tab |
| Commit + push | Branch chip → write message → "Commit & push" |
| Pull the latest from GitHub | Branch chip → "Pull" button |
| Discard local changes | Changes tab → click the X next to a file |

## Notebooks as source files

A key Repos detail: notebooks are stored as `.py` files (with a magic comment header `# Databricks notebook source`), not as `.ipynb`. This is what makes the diffs clean.

When you open one of these `.py` files in Databricks, the UI renders it as a notebook with cells. When you open it locally, it's a plain Python file. They're the same content.

If you're used to Jupyter `.ipynb` files: the equivalent in Databricks Repos is a `.py` file with cell-divider comments. The format is called **Databricks Source** (look at any of this course's `assets/*.py` files — they all use it).

## Gotchas

- **Don't `git pull` inside the Repos folder from a terminal you SSH into.** Use the UI's pull button. The workspace tracks the repo state in its own metadata.
- **Large files**: Repos works best with text files. For data or binaries, store them in a workspace **Volume** or DBFS, not in the Repo.
- **Conflicts**: if Databricks-side edits conflict with what's on GitHub, the pull will fail. Discard the local edits (if they were experimental) or commit them first.
- **Forks**: Repos doesn't natively support GitHub forks of a different upstream. If you need that, add the upstream as a remote yourself in a separate clone.

## Cleanup

If you want to remove a Repo from your workspace:

- Workspace → right-click the repo → **Delete**.

This only removes it from Databricks. The GitHub repo is unaffected.

## Further reading

- Official docs: https://docs.databricks.com/repos/index.html
- Notebook source format: https://docs.databricks.com/notebooks/notebook-export-import.html
