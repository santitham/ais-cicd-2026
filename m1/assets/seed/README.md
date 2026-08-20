# DataOps Mastery — cohort collaboration repo

Welcome. This repository is shared by everyone in the room, and it exists so you
can make every Git mistake here rather than at work.

`main` is protected. You cannot push to it directly — try it, you're meant to.
Everything reaches `main` through a pull request with one approval.

## Round 1 — fork and pull request

1. **Fork** this repo (top right of the GitHub page).
2. **Clone your fork** to your laptop.
3. Create a branch: `git switch -c add-<yourname>`
4. Add your section to your team's file in `teams/`.
5. Commit, push to **your fork**, then open a pull request against **this**
   repository's `main`.
6. Review the pull request of the team you were assigned. Approve it, or ask
   for a change.

Nobody else is editing your section, so this should merge cleanly. That's the
point — learn the mechanic before adding difficulty.

## Round 2 — collaborator, shared file, real conflicts

You have push access to this repo directly. No fork needed.

1. `git clone` this repo (the real one, not your fork).
2. Create a branch: `git switch -c roster-<yourname>`
3. Add yourself to `ROSTER.md`, **in alphabetical order** by first name.
4. Commit, push the branch, open a pull request.
5. Wait. Your instructor merges pull requests in waves.
6. When a wave merges, your branch is now behind and probably conflicting.
   Bring it up to date, resolve the conflict, and push again.

```bash
git switch main
git pull
git switch roster-<yourname>
git merge main          # conflict appears here
# ... resolve, then:
git add ROSTER.md
git commit
git push
```

## The rules

- Never force-push to a shared branch.
- Never edit someone else's line in `ROSTER.md`. Resolving a conflict means
  keeping **both** contributions, not deleting theirs.
- If you get badly stuck, say so out loud. Every Git hole has a ladder, and
  finding it is part of the lesson.

## Files

| File | Purpose |
|---|---|
| `ROSTER.md` | One shared list. Everyone edits it. Conflicts live here. |
| `teams/team-NN.md` | Your team's file, one section per person. |
| `config/deploy-order.yml` | Two nominated people will change the same line here. |
