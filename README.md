# SJOCA Website Overhaul

Rebuilding the parish website — **www.sjoca.org**.

<!-- TODO: confirm the parish's full formal name and put it here. -->

This repository holds the planning, research, design decisions, and eventually the site
itself. All development work is donated by members of the parish.

---

## Where the project stands

**Phase A, Step 1 — not yet started.** We have a plan and the survey data. Nothing has
been proposed to the Parish Council yet, and no design or technology decisions have been
made. Deliberately: the council approves the project before we build anything, and the
requirements come before the design.

**Start here:** [`PROJECT-PLAN.md`](PROJECT-PLAN.md) — all 14 steps, in order, with the
approval gate on each. Read it first. It is the source of truth for what happens next.

---

## What's in here

| Path | What it is |
|---|---|
| `PROJECT-PLAN.md` | The full plan: 14 steps in 5 phases, from council proposal to post-launch follow-up. **Read this first.** |
| `CLAUDE.md` | Working context and handoff notes. Read it if you're picking the project up on a new machine or after a gap. |
| `data/survey/` | Parish survey results (anonymized). See the note below. |
| `docs/` | Working documents, one per step, created as we reach each step. |
| `deck/` | The Parish Council proposal slides (Step 1). |

Empty directories mean we haven't reached that step yet, not that something is missing.

---

## About the survey data

`data/survey/responses-anonymized.csv` — **22 responses** from a Google Form.

The original export had a `Username` column containing each respondent's real email
address; the form collected them only to prevent duplicate submissions. Those addresses
have been replaced with `R01`–`R22`. **The raw export is not in this repository and must
never be committed** — this repo is public, and the respondents are parishioners who did
not consent to having their contact details published. `.gitignore` blocks the raw
filenames as a safety net.

If the raw data is ever genuinely needed, Mitch can re-export it from the original
Google Form.

The survey's structure matters: each topic was asked as a **pair** of questions — *how
important is this to you* and *how well does the current site do it*. The gap between
those two numbers is the whole argument for the project, and it sets the priority order
for features.

---

## Working on this

### Getting started

```bash
git clone git@github.com:catmando/sjoca-website.git
cd sjoca-website
```

Then read `PROJECT-PLAN.md`, then `CLAUDE.md`. There is nothing to install and nothing to
build yet — at this stage the work is research and writing, not code.

### How we work

- **We do one step at a time, in order.** Steps have approval gates; we don't build ahead
  of an approval. If a step feels blocked, the answer is usually that an earlier step
  isn't finished.
- **Every step produces a file.** A discussion that didn't result in a committed document
  didn't happen.
- **Decisions get written down with their reasoning**, so that the person who picks this
  up in three months understands *why*, not just *what*.
- **Ask before deciding anything the parish should decide.** Design direction, content,
  cost, and scope belong to Fr. David and the parish council — not to us.

### Some things that are already settled

Don't reopen these without talking to Mitch first:

- **Giving stays with ChurchTrac.** This project does not change how the parish takes money.
- **The ChurchTrac calendar and giving integration carries forward at minimum.** Both work
  on the current site today; whatever we build does at least as well.
- **Development is donated.** The only money the council approves is annual hosting.
- **No technology has been chosen**, and it isn't chosen until Step 8 — after we know who
  has to maintain the site and what it has to do.

### Contributing

The repo is public so anyone can read and clone it. Write access is granted as needed —
ask Mitch. Commit directly to `main` for now; we're a small group and there's no code to
break yet. That changes when we reach Step 9.

---

## Contacts

| Role | Who |
|---|---|
| Project lead | Mitch VanDuyn (`catmando`) |
| Approval | Fr. David, through the Parish Council or its appointed representatives |
| Parish liaison | To be named at the Step 1 proposal meeting |
