# Instructor repo setup — Module 1 collaboration lab

> **Do this the week before the course, not on the morning.** GitHub
> collaborator invitations must be accepted by each person, and chasing 25
> acceptances while the class waits is the one thing that can sink this lab.

The lab runs in two rounds against a single repository you own:

| Round | Workflow | What it teaches | Conflicts? |
|---|---|---|---|
| 1 | Fork → branch → PR to upstream | Forks, upstream remotes, the PR mechanic, peer review | No — each person edits their own file |
| 2 | Collaborator → branch → PR to main | Shared-repo reality, merge waves, conflict resolution | Yes, guaranteed |

Round 1 is safe practice. Round 2 is where it gets real.

---

## 1. Create the repository

```bash
# Public repo — required for free-tier branch protection and required reviews
gh repo create <org-or-you>/dataops-course-2026 --public --clone
cd dataops-course-2026
```

Copy the seed content from this course pack:

```bash
cp -r <course-pack>/Day1-Foundations/Module-01-Git/assets/seed/. .
git add .
git commit -m "chore: seed course collaboration repo"
git push
```

You now have:

```
dataops-course-2026/
├── README.md                      instructions students read first
├── ROSTER.md                      ← the conflict engine. One shared list.
├── config/
│   └── deploy-order.yml           ← planted line-level conflict
├── teams/
│   └── team-template.md           copied per team by you (below)
└── .github/
    └── pull_request_template.md
```

## 2. Create one file per team

For 17–30 students, use teams of three or four — six to eight teams.

```bash
mkdir -p teams
for i in $(seq -w 1 8); do
  sed "s/TEAM_NUMBER/$i/g" teams/team-template.md > "teams/team-$i.md"
done
rm teams/team-template.md
git add teams/ && git commit -m "chore: add team files" && git push
```

Per-team files keep Round 1 conflict-free. `ROSTER.md` is what everyone shares.

## 3. Protect main

This is what makes the PR workflow feel necessary rather than ceremonial.

```bash
gh api -X PUT "repos/{owner}/dataops-course-2026/branches/main/protection" \
  --input - <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
```

Or in the UI: **Settings → Branches → Add branch protection rule**, pattern
`main`, tick *Require a pull request before merging* and *Require approvals: 1*.

Leave `enforce_admins` false so you can merge without an approval when the
class needs unblocking.

Verify it works before the class — try to push a commit straight to main and
confirm you are refused:

```
! [remote rejected] main -> main (protected branch hook declined)
```

## 4. Invite collaborators (a week ahead)

```bash
# one line per student GitHub username
for u in $(cat students.txt); do
  gh api -X PUT "repos/{owner}/dataops-course-2026/collaborators/$u" \
    -f permission=push
done
```

Send a reminder to accept the emailed invitation. Confirm on the morning:

```bash
gh api "repos/{owner}/dataops-course-2026/collaborators" --jq '.[].login' | wc -l
```

> Students only *use* collaborator access in Round 2, but granting it early
> costs nothing and removes the only unrecoverable delay in the lab.

## 5. Pre-class checklist

- [ ] Repo is public and seeded
- [ ] `ROSTER.md` has the alphabetical list and its instruction comment
- [ ] One team file per team exists
- [ ] `main` is protected: PR required, one approval required
- [ ] You have personally been refused a direct push to main
- [ ] Every student appears in the collaborators list
- [ ] You have `students.txt` mapping real names to GitHub usernames
- [ ] Team assignments are decided and on a slide
- [ ] The two students for the planted line conflict are chosen (see
      `conflict-choreography.md`)

## 6. Resetting between cohorts

```bash
git checkout main && git pull
git checkout --orphan fresh && git add -A
git commit -m "chore: reset for new cohort"
git branch -D main && git branch -m main
git push -f origin main          # temporarily lift protection to do this
gh api -X DELETE "repos/{owner}/dataops-course-2026/branches/main/protection"
# then re-apply protection from step 3
```

Simpler alternative: delete the repo and re-run this guide. It takes four
minutes and avoids surprises from leftover branches.

## 7. What can go wrong, and the fix

| Symptom | Cause | Fix |
|---|---|---|
| Student's push rejected with 403 | Invitation never accepted | Have them check github.com/notifications; fall back to fork-and-PR for that student |
| "Nothing to compare" on the PR page | PR opened against their own fork, not upstream | Change the base repository dropdown to your repo |
| No conflicts appear in Round 2 | You merged all PRs before students pulled | Merge in waves and pause; see `conflict-choreography.md` |
| A student force-pushes over someone's work | Force push on a shared branch | Protection blocks it on main; on their own branch, reflog recovery is a teaching moment |
| PR queue stalls at 25 open PRs | Reviewing serially | Assign reviewer pairs in advance: team N reviews team N+1 |
