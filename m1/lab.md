# Module 1 — Lab Guide

**Git that survives a real team**
Day 1 · Foundations · ~3.75 hours

> This module assumes you have never used Git or GitHub. Not "a bit rusty" —
> never. If you have used them, the challenges still have something for you;
> skip ahead within each part and help your neighbour.
>
> Nothing you do today can break anything. Everything in Git is recoverable,
> and by the end of the module you will know how to recover it.

---

## How this module runs

Eight short cycles. Each one is a few minutes of explanation, a demonstration,
then a small challenge you complete at your keyboard. Then one long
collaboration lab where the whole room works on the same repository.

Times below are guides, not gates. If you finish a challenge early, the
**Going further** box gives you something extra.

---

## Pre-flight — install and configure (15 min)

### P.1 Check what you have

```bash
git --version
```

Expected — any version 2.30 or newer:

```
git version 2.43.0
```

Nothing? Install it: `brew install git` on macOS, `sudo apt install git` on
Linux, or the installer from git-scm.com on Windows (choose "Git Bash" when
offered).

### P.2 Tell Git who you are

Git stamps every commit with a name and email. Do this once per laptop, ever.

```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --global pull.rebase false
```

Verify:

```bash
git config --global --list
```

Expected:

```
user.name=Your Name
user.email=you@example.com
init.defaultbranch=main
pull.rebase=false
```

> Use the same email as your GitHub account, or your commits won't be linked to
> your profile. If you'd rather not publish your address, GitHub gives you a
> `@users.noreply.github.com` address under Settings → Emails.

### P.3 Sign in to GitHub from the terminal

```bash
gh auth login
```

Choose GitHub.com → HTTPS → *Login with a web browser*, and paste the code.

Check it:

```bash
gh auth status
```

Expected:

```
github.com
  ✓ Logged in to github.com account your-username (keyring)
  - Active account: true
```

No `gh`? Install it (`brew install gh`) or use a browser plus HTTPS pushes;
Git will prompt for credentials and cache them.

---

## Part 1 — Git is not GitHub (10 min)

This is the distinction that makes everything else make sense, so we do it
first and we do it properly.

**Git** is a program on your laptop. It records snapshots of your files. It
works on a plane with the wi-fi off. Commands like `commit`, `branch`, and
`merge` are Git.

**GitHub** is a website that stores copies of Git repositories and adds things
Git has no concept of: pull requests, reviews, issues, and Actions. Commands
that talk to it — `push`, `pull`, `clone` — cross the network.

### Challenge 1 (3 min)

Without running anything, decide for each item: **Git**, **GitHub**, or **both**?

1. Recording that you changed three lines in `train.py`
2. Asking a colleague to review those changes
3. Making a branch called `fix/null-handling`
4. Requiring two approvals before code reaches `main`
5. Seeing the history of a file going back two years
6. Running tests automatically when you upload code

<details>
<summary>Answers</summary>

1. Git — commits are local.
2. GitHub — pull requests are a GitHub feature; Git has no such concept.
3. Git — branches are local until you push them.
4. GitHub — branch protection is a hosting-platform rule.
5. Git — the whole history is on your laptop after a clone.
6. GitHub — Actions. This is Module 6.

</details>

> Why it matters: when something goes wrong, this tells you *where* to look. A
> commit problem is on your machine. A pull request problem is in a browser.

---

## Part 2 — A repository, and the one command you'll run most (15 min)

A repository is a folder Git is watching. It becomes one in two ways: `git init`
creates a new one, `git clone` copies an existing one.

```bash
mkdir ~/git-practice && cd ~/git-practice
git init
```

Expected:

```
Initialized empty Git repository in /Users/you/git-practice/.git/
```

That hidden `.git/` folder *is* the repository — the entire history lives
there. Delete it and you have an ordinary folder again.

Now the command you will run more than all others combined:

```bash
git status
```

Expected:

```
On branch main

No commits yet

nothing to commit (create/copy files to add and commit)
```

### The three places a change can be

Every file in a repo is in one of these, and `git status` always tells you
which:

| Place | What it means | How things arrive |
|---|---|---|
| **Working directory** | Files as they are on disk right now | You edit them |
| **Staging area** | Changes you've chosen for the next snapshot | `git add` |
| **Repository** | Committed snapshots, permanent history | `git commit` |

There is a fourth place — the **remote** on GitHub — reached with `git push`.

### Challenge 2 (8 min)

1. Create a file: `echo "# My practice repo" > README.md`
2. Run `git status`. Which of the three places is `README.md` in?
3. Create a second file `notes.txt` with any text in it.
4. Run `git status` again. What does "Untracked files" mean, in your own words?
5. Run `git status -s` (short format). Work out what `??` means.

<details>
<summary>Expected output after step 4</summary>

```
On branch main

No commits yet

Untracked files:
  (use "git add <file>..." to include in what will be committed)
        README.md
        notes.txt

nothing added to commit but untracked files present (use "git add" to track)
```

**Untracked** means Git can see the file but has never been told to care about
it. It is in the working directory only.

</details>

**Going further:** run `ls -a` and then `ls .git`. Look at what's inside. You
don't need to understand it — just see that it's ordinary files.

---

## Part 3 — Staging and committing (20 min)

```bash
git add README.md
git status
```

Expected — note the new section, and that `notes.txt` has not moved:

```
Changes to be committed:
  (use "git rm --cached <file>..." to unstage)
        new file:   README.md

Untracked files:
        notes.txt
```

`README.md` is now **staged**. Commit it:

```bash
git commit -m "docs: add readme"
```

Expected:

```
[main (root-commit) 8f3c1a2] docs: add readme
 1 file changed, 1 insertion(+)
 create mode 100644 README.md
```

### Why staging exists

It lets you commit *some* of your changes. You fixed a bug and also renamed a
variable? Stage and commit them separately, so the history explains itself.

### Reading history

```bash
git log
git log --oneline
git log --oneline --graph --all      # worth an alias; you'll use it constantly
```

Expected from `--oneline`:

```
8f3c1a2 (HEAD -> main) docs: add readme
```

### Challenge 3 (10 min)

1. Stage and commit `notes.txt` with the message `docs: add scratch notes`.
2. Edit `README.md` — add a line describing what you want from this course.
3. Run `git status`. The file is tracked now, so the wording changed. What does
   "Changes not staged for commit" mean?
4. Commit that edit.
5. Run `git log --oneline`. You should have three commits.
6. **Write a bad commit message on purpose:** make any small edit and commit it
   with `-m "stuff"`. Then look at your log and ask whether future-you could
   work out what changed.

<details>
<summary>What a good message looks like</summary>

```
feat: add churn scoring weights
fix: drop null tenant_id rows before windowing
docs: explain the recency cap in the readme
chore: ignore .databricks state directory
```

Format: a short prefix, then what changed, in the imperative. The prefix is a
team convention, not a Git rule. The real test: **will this line make sense to
someone reading it in six months with no other context?**

</details>

**Going further:** `git commit` with no `-m` opens an editor, where you can
write a longer message: a summary line, a blank line, then paragraphs
explaining *why*. Try it once.

---

## Part 4 — Seeing what changed, and ignoring what shouldn't be there (15 min)

```bash
echo "another line" >> README.md
git diff
```

Expected:

```diff
diff --git a/README.md b/README.md
index 1f3a2b1..7c9e4d2 100644
--- a/README.md
+++ b/README.md
@@ -1,2 +1,3 @@
 # My practice repo
 What I want from this course: stop deploying by hand
+another line
```

`-` is the old version, `+` the new, and unmarked lines are context. After
staging, plain `git diff` shows nothing — use `git diff --staged` to see staged
changes.

### .gitignore

Some files must never be committed: credentials, build output, caches, and the
40 MB wheel your bundle build produces in Module 3.

```bash
cat > .gitignore <<'EOF'
# Python
__pycache__/
*.pyc
.venv/

# Databricks — generated state and build output (Module 3)
.databricks/
dist/
build/
*.egg-info/

# Editors and OS
.vscode/
.idea/
.DS_Store

# Never commit credentials
.env
*.pem
EOF

git add .gitignore
git commit -m "chore: add gitignore"
```

### Challenge 4 (8 min)

1. Create a file that should be ignored: `mkdir -p __pycache__ && touch __pycache__/x.pyc`
2. Run `git status`. Confirm Git does not mention it.
3. Now the trap: `touch secret.env`, add `secret.env` to `.gitignore`, then run
   `git status`. Is it ignored?
4. Harder: commit a file first, *then* add it to `.gitignore`. Run
   `git status`. Is it ignored now? Why not?

<details>
<summary>Answer to 4 — the thing that catches everyone</summary>

**No.** `.gitignore` only affects files Git isn't already tracking. Once a file
is committed, ignoring it does nothing; you must untrack it:

```bash
git rm --cached secret.env
git commit -m "chore: stop tracking secret.env"
```

And remember: it stays in the history. If it was a real credential, **rotate
it** — removing the file does not remove it from past commits.

</details>

---

## Part 5 — Connecting to GitHub (20 min)

So far everything has been local. Time to `push`.

```bash
gh repo create git-practice --public --source=. --remote=origin --push
```

Expected:

```
✓ Created repository your-name/git-practice on GitHub
✓ Added remote https://github.com/your-name/git-practice.git
✓ Pushed commits to https://github.com/your-name/git-practice.git
```

`origin` is just a nickname for that URL:

```bash
git remote -v
```

```
origin  https://github.com/your-name/git-practice.git (fetch)
origin  https://github.com/your-name/git-practice.git (push)
```

### push, fetch, pull

- `git push` — send your commits to GitHub
- `git fetch` — download what's on GitHub, but **don't** change your files
- `git pull` — fetch, then merge it into your current branch

`pull` is the one that can surprise you, because it changes your working files.

### Challenge 5 (10 min)

1. Open your repo in a browser: `gh repo view --web`. Find your commits.
2. **Edit a file on the GitHub website** — click `README.md`, the pencil icon,
   add a line, commit directly to `main`.
3. Back in your terminal, run `git status`. Does Git know about that edit?
4. Run `git fetch`, then `git status`. What does it say now?
5. Run `git pull` and confirm the line appears in your local file.
6. Make a local edit, commit, and push it. Refresh the browser.

<details>
<summary>Expected output at step 4</summary>

```
On branch main
Your branch is behind 'origin/main' by 1 commit, and can be fast-forwarded.
  (use "git pull" to update your local branch)
```

At step 3 it said nothing, because Git had not looked at the network yet. Git
never contacts GitHub unless you ask it to. **A stale `git status` is almost
always a missing `fetch`.**

</details>

---

## Part 6 — Branching and merging (25 min)

A branch is a movable label pointing at a commit. Making one is instant and
costs nothing.

```bash
git switch -c feature/add-scoring
```

Expected:

```
Switched to a new branch 'feature/add-scoring'
```

(`git checkout -b` does the same thing; `switch` is the newer, clearer command.)

```bash
echo "def score(): return 42" > score.py
git add score.py
git commit -m "feat: add placeholder scoring function"
git log --oneline --graph --all
```

Now go back and look:

```bash
git switch main
ls
```

`score.py` is **gone**. It exists on the other branch. Switch back and it
returns. This is the moment branching clicks for most people.

Merge it in:

```bash
git switch main
git merge feature/add-scoring
```

Expected:

```
Updating 8f3c1a2..4d9e1f7
Fast-forward
 score.py | 1 +
 1 file changed, 1 insertion(+)
```

"Fast-forward" means main had no new commits, so Git just slid the label
forward. No merge commit was needed.

### Challenge 6 (12 min) — make a conflict on purpose

You are going to break something deliberately, in a repo nobody else can see.

1. On `main`, create `config.txt` containing the single line `target = dev`.
   Commit it.
2. Branch: `git switch -c change-to-staging`. Change the line to
   `target = staging`. Commit.
3. Go back: `git switch main`. Change the **same line** to `target = prod`.
   Commit.
4. Now: `git merge change-to-staging`

Expected:

```
Auto-merging config.txt
CONFLICT (content): Merge conflict in config.txt
Automatic merge failed; fix conflicts and then commit the result.
```

5. Before opening anything, ask Git where you stand:

```bash
git status
```

```
On branch main
You have unmerged paths.
  (fix conflicts and run "git commit")
  (use "git merge --abort" to abort the merge)

Unmerged paths:
  (use "git add <file>..." to mark resolution)
        both modified:   config.txt

no changes added to commit
```

`both modified` is the phrase to look for. Notice Git has just told you the
next two commands — and the escape hatch. It always does.

6. Open `config.txt`. You will see:

```
<<<<<<< HEAD
target = prod
=======
target = staging
>>>>>>> change-to-staging
```

Read it as: *between `<<<<<<<` and `=======` is what's on your current branch
("ours"); between `=======` and `>>>>>>>` is what's on the branch you're
merging in ("theirs").*

It is now an ordinary text file of seven lines. You are allowed to edit it by
hand — that is the whole idea.

7. Resolve it. Edit until the file reads exactly one line, with all three
   marker lines gone:

```bash
cat config.txt
```

```
target = prod
```

8. Staging the file **is** the resolution. That is how you tell Git you have
   decided:

```bash
git add config.txt
git status
```

```
On branch main
All conflicts fixed but you are still merging.
  (use "git commit" to conclude merge)

Changes to be committed:
        modified:   config.txt
```

9. Conclude the merge and look at what you made:

```bash
git commit -m "merge: keep prod as the target"
git log --oneline --graph
```

```
*   4c5d6e7 (HEAD -> main) merge: keep prod as the target
|\
| * 5d6e7f8 (change-to-staging) chore: point config at staging
* | 9a8b7c6 chore: point config at prod
|/
* 1a2b3c4 chore: add config
```

The merge commit has **two parents**. Both branches' history survived — you
chose the content, not which history got thrown away.

10. **Now do it again, and escape instead.** Repeat steps 2–4, then run
    `git merge --abort`. Confirm with `git status` that you are back exactly
    where you started.

> `git merge --abort` is the most reassuring command in Git. A conflict is
> never a trap.

**Going further:** conflicts where two people added *different* lines near each
other look the same and resolve differently — you usually keep **both**. You'll
meet that version in the final lab.

---

## Part 7 — The undo toolkit (15 min)

Beginners are slow with Git because they're afraid. Here is the ladder out of
every hole. Learn these five and the fear goes.

| You want to | Command | Destroys work? |
|---|---|---|
| Throw away edits to a file | `git restore <file>` | **Yes** — the edits are gone |
| Unstage, but keep the edits | `git restore --staged <file>` | No |
| Fix the last commit's message | `git commit --amend` | No (rewrites history) |
| Undo a commit, keep the changes | `git reset --soft HEAD~1` | No |
| Undo a *pushed* commit safely | `git revert <sha>` | No — adds a new commit |
| Park work and come back later | `git stash`, then `git stash pop` | No |

### Challenge 7 (8 min)

1. Edit `README.md`, then throw the edit away with `git restore README.md`.
   Confirm with `git diff` that it's clean.
2. Edit it again, `git add` it, then unstage with
   `git restore --staged README.md`. Confirm the edit is still there.
3. Commit something with the message `oops`. Fix it with
   `git commit --amend -m "docs: clarify readme"`. Check `git log --oneline`.
4. Commit a change, then `git revert HEAD`. Look at the log — how many commits
   are there now, and what happened to the original?
5. Edit a file, run `git stash`, run `git status` (clean!), then
   `git stash pop`.

<details>
<summary>The rule about rewriting history</summary>

`amend` and `reset` change commits. That is fine for commits **only you have**.
Once you have pushed and someone else may have pulled, use `revert` instead —
it adds a new commit that undoes the old one, so nobody's history is rewritten
underneath them.

Short version: **rewrite local history freely, never rewrite shared history.**

</details>

> **Lost something?** `git reflog` lists everywhere `HEAD` has been, including
> commits you thought you destroyed. It has saved more afternoons than any
> other Git command.

---

## Part 8 — Pull requests and review (20 min)

A pull request is GitHub asking: *may I merge this branch into that one?* It
gives you somewhere to discuss the change before it lands.

```bash
git switch -c docs/add-purpose
echo "This repo is practice for the DataOps course." >> README.md
git add README.md
git commit -m "docs: explain the purpose of the repo"
git push -u origin docs/add-purpose
```

Expected — Git even gives you the link:

```
remote: Create a pull request for 'docs/add-purpose' on GitHub by visiting:
remote:      https://github.com/your-name/git-practice/pull/new/docs/add-purpose
branch 'docs/add-purpose' set up to track 'origin/docs/add-purpose'.
```

`-u` sets the upstream, so future pushes on this branch are just `git push`.

```bash
gh pr create --fill
gh pr view --web
```

### Challenge 8 (10 min)

1. Open the PR. Read the **Files changed** tab — this is what a reviewer sees.
2. Leave a comment on your own diff, on a specific line.
3. Push another commit to the same branch. Watch it appear in the same PR
   without you doing anything.
4. Merge the PR on the website. Then, locally: `git switch main && git pull`.
5. Delete the merged branch: `git branch -d docs/add-purpose`.
6. Look at `git log --oneline --graph` and find the merge.

**Going further:** in Settings → Branches, add a protection rule on `main`
requiring a pull request. Then try `git push` straight to main and read the
rejection. You will meet this for real in the next lab.

---

## FINAL LAB — The whole room, one repository (55 min)

Everything so far was solo. Now the part that actually resembles work.

Your instructor owns a repository. You will contribute to it twice: first
safely through a fork, then directly as a collaborator, where conflicts are
guaranteed.

**Repo URL:** ______________________________________
**Your team number:** ______   **You review team:** ______

### Round 1 — Fork and pull request (20 min)

The open-source model. You work on your own copy and propose changes back.

1. Open the repo in a browser and click **Fork** (top right).
2. Clone **your fork**:

```bash
git clone https://github.com/<your-username>/dataops-course-2026.git
cd dataops-course-2026
```

3. Branch: `git switch -c add-<yourname>`
4. Open `teams/team-NN.md` for your team and add your section, following the
   format in the comment.
5. Commit and push to your fork:

```bash
git add teams/team-NN.md
git commit -m "docs: add <yourname> to team NN"
git push -u origin add-<yourname>
```

6. Open a pull request **against the instructor's repo**, not your fork. On the
   PR page, check the base repository dropdown says the instructor's name.
7. Fill in the template. It's short; do it properly.
8. **Review the assigned team's pull requests.** Read the diff, leave one
   substantive comment, and approve one.

> Because each of you edits a different section, these should merge cleanly.
> That's deliberate — learn the mechanic before adding difficulty.

### Round 2 — Collaborator, shared file, real conflicts (35 min)

You have push access to the instructor's repo directly. No fork.

1. Clone the **real** repo (not your fork) into a different folder:

```bash
cd ..
git clone https://github.com/<instructor>/dataops-course-2026.git shared
cd shared
```

2. **Try to break the rules first.** Commit straight to main and push:

```bash
echo "test" >> ROSTER.md
git commit -am "test: push to main"
git push
```

Expected:

```
! [remote rejected] main -> main (protected branch hook declined)
error: failed to push some refs
```

Good. Undo it: `git reset --hard origin/main`

3. Do it properly:

```bash
git switch -c roster-<yourname>
```

4. Add yourself to `ROSTER.md` **in alphabetical order by first name**, in the
   exact format the file specifies. Do not append to the bottom.
5. Commit, push, open a PR, get an approval from your review partner.
6. **Wait.** Your instructor merges in waves. When your wave hasn't merged yet
   and another has, your branch is now behind:

```bash
git switch main
git pull
git switch roster-<yourname>
git merge main
```

Expected:

```
Auto-merging ROSTER.md
CONFLICT (content): Merge conflict in ROSTER.md
Automatic merge failed; fix conflicts and then commit the result.
```

7. Resolve it. **Keep both your line and theirs** — this is the difference
   between a real resolution and quietly deleting a colleague's work.

```bash
git add ROSTER.md
git commit
git push
```

8. Confirm on GitHub that the PR now says it can be merged.
9. When everything is merged: `git switch main && git pull`, then read
   `ROSTER.md`. Every person in the room should be in it, including you.

### The rules

- Never force-push to a shared branch.
- Never resolve a conflict by deleting someone else's line.
- If you are stuck for more than three minutes, say so out loud. Being stuck
  is normal; being silently stuck wastes your morning.

**Success:** your line is on `main`, you reviewed someone's work, someone
reviewed yours, and you resolved at least one conflict without losing anyone's
contribution.

---

## Part 9 — Git inside Databricks: Repos (20 min)

Everything so far happened on your laptop. Databricks has Git built into the
workspace, so the same repository can be opened, edited, and run there.

### What Repos is

A folder in your workspace that is a real Git clone. It can pull, branch,
commit, and push. It is the workspace-side view of the repo you have been
working in all morning.

### R.1 Connect the workspace to GitHub (7 min)

1. In Databricks: your avatar → **Settings** → **Linked accounts**
   (older workspaces: **User Settings** → **Git integration**).
2. Git provider: **GitHub**.
3. Choose **Link Git account** and complete the OAuth flow in the popup.

> If your workspace requires a token instead of OAuth, ask your instructor.
> We are not creating personal access tokens in this course.

### R.2 Clone your own repo into the workspace (5 min)

1. Left sidebar → **Workspace** → your user folder → **Create** → **Git folder**
   (older UI: **Repos** → **Add Repo**).
2. Paste the HTTPS URL of the `git-practice` repo you made in Part 5.
3. Click **Create Git folder**.

You now see your files in the workspace. Open `README.md` — it is the same file
you edited in your terminal.

### R.3 The round trip (5 min)

1. On your **laptop**, add a line to `README.md`, commit, and push.
2. In **Databricks**, click the branch name at the top of the Git folder, then
   **Pull**.
3. Confirm your new line appears.

That is the loop you will use for the rest of the week: edit and commit
wherever you prefer, push, and pull on the other side.

### R.4 Clone a real ML repository (3 min)

Create a second Git folder from a public ML repo, so you can see what someone
else's project looks like in the workspace:

```
https://github.com/mlflow/mlflow-example
```

Browse `train.py`. Notice it is ordinary Python in ordinary files — not a
notebook. That is what "code-driven" looks like, and it's where we're heading.

> **The gotcha to remember for Module 3.** From tomorrow, your code will exist
> in the workspace **twice**: once in this Git folder (the copy you browse and
> edit) and once under `/Workspace/Users/<you>/.bundle/...` (the copy a deployed
> job actually runs). Editing the Git folder does not change what a deployed
> job executes. Confusing these two is the single most common beginner incident
> with bundles.

---

## Checklist before you leave

- [ ] `git --version` works and `git config --global --list` shows your name
- [ ] You can explain the difference between Git and GitHub in one sentence each
- [ ] You have made a commit, pushed it, and seen it on github.com
- [ ] You have created a branch, switched to it, and merged it
- [ ] You have caused a merge conflict and resolved it — twice
- [ ] You have run `git merge --abort` and seen it rescue you
- [ ] You know which command undoes a *pushed* commit safely (`revert`)
- [ ] Your line is in the instructor repo's `ROSTER.md` on `main`
- [ ] You reviewed someone else's pull request
- [ ] A Databricks Git folder shows a commit you made on your laptop

---

## Tomorrow — sorry, later today

Module 2 takes the repo you now own and puts real configuration in it: YAML,
the language every tool this week reads, and the Databricks CLI. From here on,
work is committed and pushed *before* it is deployed.

---

## Quick reference

```bash
# where am I, what's changed
git status                  git status -s
git diff                    git diff --staged
git log --oneline --graph --all

# the everyday loop
git add <file>              git add .
git commit -m "type: what changed"
git push                    git pull

# branches
git switch -c <name>        # create and switch
git switch main             # move between
git merge <name>            # bring changes in
git branch -d <name>        # delete when merged

# conflicts
git merge --abort           # escape hatch
git add <file> && git commit   # after resolving

# undo
git restore <file>              # discard edits
git restore --staged <file>     # unstage, keep edits
git commit --amend              # fix last commit (local only)
git revert <sha>                # undo a pushed commit
git stash / git stash pop       # park work
git reflog                      # find "lost" commits

# github
gh repo create / gh repo view --web
gh pr create --fill / gh pr view --web
```
