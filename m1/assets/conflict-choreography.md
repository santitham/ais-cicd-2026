# Conflict choreography — running the Module 1 collaboration lab

> **Instructor only.** This is the timing script for the final lab. With 17–30
> students, conflicts do not need to be hoped for — they are produced on demand
> by *when you merge*, and that is entirely under your control.

## The core mechanism

Every student adds a line to the same alphabetical list in `ROSTER.md`. They all
branch from the same commit, so at the moment they branch, no conflict exists.

The instant you merge the first pull request, every other open branch is based
on a stale `main`. When those students bring `main` into their branch, Git finds
two different sets of changes to the same region of the same file, and stops.

So: **the merge is the trigger.** Merge nothing and nobody conflicts. Merge in
waves and everyone conflicts, in a sequence you control.

```
        all 25 branch from here
                 │
   main  ─────────●─────────────────────────────────────►
                  ╲   wave 1 merges (4 PRs)
                   ╲            │
                    ●───────────●  ← now 21 branches are stale
                                    and every one of them conflicts
```

## Wave plan for 17–30 students

Teams of three or four; six to eight teams. Reviewer pairing is fixed in
advance: **team N reviews team N+1**, and the last team reviews team 1.

| Time | You do | Students do |
|---|---|---|
| 0:00 | Confirm everyone has cloned and branched | Branch, edit `ROSTER.md`, push, open PR |
| 0:08 | Announce: "reviews open" | Review your assigned team's PRs, approve one |
| 0:12 | **Merge wave 1** — exactly 4 PRs, from one team | Watch the repo. Nothing breaks yet. |
| 0:14 | Announce: "wave 1 is merged, bring your branch up to date" | `git switch main && git pull`, then `git merge main` on their branch → **conflict** |
| 0:20 | Circulate. Do not fix anything for anyone. | Read the markers, resolve, `git add`, `git commit`, push |
| 0:28 | **Merge wave 2** — the next 8 PRs | Whoever has not resolved yet now conflicts against a bigger diff |
| 0:34 | **Merge wave 3** — everything remaining that is green | Resolve, push, confirm the PR turns mergeable |
| 0:40 | Final `git pull` on main, read `ROSTER.md` aloud | Confirm their line survived and nobody was deleted |

Total: about 40 minutes. Add ten if the room is new to the terminal.

## The planted line-level conflict

The roster produces *adjacent-line* conflicts, which are the common kind. Also
demonstrate the *same-line* kind, which reads differently and frightens people
more.

Nominate two confident participants. Privately, give each a different
instruction for `config/deploy-order.yml`:

- **Student A:** change `default_target: dev` to `default_target: staging`
- **Student B:** change `default_target: dev` to `default_target: prod`

Both branch, both commit, both push, both open a PR. Merge A's. Then ask B to
bring `main` into their branch in front of the room, on the projector:

```
<<<<<<< HEAD
default_target: prod
=======
default_target: staging
>>>>>>> main
```

Ask the room the question that matters: **which one is correct?** Git cannot
know. Neither can B alone. The answer requires talking to A. That is the real
lesson about conflicts — they are a communication event that Git surfaced, not a
technical failure Git caused.

## What to say when someone panics

The single most common beginner reaction is "I've broken the repository." They
have not, and reassurance works best when it is specific:

- **"Nothing you do on your branch can hurt anyone else."** Main is protected.
  The worst case is that your branch is messy and we delete it.
- **"Every state is recoverable."** `git merge --abort` puts you back exactly
  where you were before the conflict, every time.
- **"The markers are not damage."** `<<<<<<<` is Git writing you a note. The
  file is a normal text file and you are allowed to edit it by hand.
- **"Deleting someone's line is the only real mistake."** Resolving means
  keeping both contributions unless the two genuinely cannot coexist.

## Deliberate teaching moments to catch in the wild

Watch for these and stop the room when one occurs — they are worth more than
the slide that preceded them.

| What you'll see | Say this |
|---|---|
| Someone resolves by deleting the other person's line | "You just merged over a colleague's work. In a real repo, that is how people lose an afternoon. Undo it and keep both." |
| Someone runs `git push --force` to escape | "That worked, and it is also how teams lose commits. Let's look at what would have happened if this were a shared branch." |
| Someone's PR says "This branch has conflicts that must be resolved" | "GitHub is refusing to guess. It is doing you a favour." |
| Someone edits directly on GitHub's web editor to dodge the conflict | "Legitimate for a one-line fix — and notice you still had to resolve it, just in a browser." |
| Two students discover they need to talk to each other | Stop the room. This is the point of the entire lab. |

## Success criteria for the lab

By the end, every participant should be able to say:

1. I pushed a branch and opened a pull request.
2. Someone reviewed my work and I reviewed theirs.
3. I hit a merge conflict, understood what the markers meant, and resolved it
   without deleting anyone's contribution.
4. My line is in `ROSTER.md` on `main`, and so is everyone else's.

If a participant achieved 1, 2 and 4 but never conflicted, they resolved too
early. Ask them to add a second line to the roster after wave 3 — they will
conflict immediately.
