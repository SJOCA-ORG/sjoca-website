# CLAUDE.md — working context for the SJOCA website project

Context for anyone (person or Claude session) picking this project up. This file is
committed so it travels with the repo; it is the handoff, not a scratchpad.

**Last updated:** 2026-09-14, end of the first working session.

---

## What this project is

Replacing the parish website at www.sjoca.org, currently on Google Sites and maintained
by parish members. Development is donated by parishioners. Driven by a parish survey that
found real gaps between what members say matters and how well the current site delivers.

Read [`PROJECT-PLAN.md`](PROJECT-PLAN.md) first — 14 steps in 5 phases. Everything else
is detail hanging off that.

---

## Where we are

**Phase A, Step 1 — proposal to the Parish Council. Not yet started.**

Nothing has been proposed, designed, or built. The plan itself is the only completed work.

### Next actions, in order

1. **Analyze the survey** — importance-vs-satisfaction gap per topic, themes from the
   free text, quotable lines, and the one chart that carries the case.
   → produces `docs/survey-findings.md`
2. **Get the two open numbers from Mitch:**
   - the annual hosting cost, and what it buys
   - who the initial contributors are, and what each is taking on
3. **Draft the council deck** → `deck/`

The deck can't be finished without item 2, but the analysis in item 1 is unblocked and is
the sensible place to start.

---

## Things that are settled — don't reopen without asking

- **Approval path:** Fr. David, through the Parish Council or its appointed
  representatives. A single named liaison gets identified at the Step 1 meeting.
- **Money:** development is a donated effort. The only ask of the council is the annual
  hosting cost. It is a genuinely *new* cost (Google Sites is ~free today) and the deck
  should say so plainly. The council is prepared for a reasonable figure.
- **Giving stays with ChurchTrac.** This project does not change how the parish takes
  money.
- **ChurchTrac calendar + giving integration already works** on the current site — minimal
  but sufficient. The proposal commits to *at least* that level. Everything else
  ChurchTrac could offer (member list, email/text, accounting) is TBD and conditional on
  being practical. Do not promise it.
- **No technology has been chosen.** That happens at Step 8, after we know who maintains
  the site and what it must do. Resist the urge to jump ahead — the maintenance question
  drives the answer more than any technical consideration.

---

## The survey data

`data/survey/responses-anonymized.csv` — 22 responses, Google Form.

- Topics are asked in **pairs**: *how important is X* + *how well does the current site do
  X*. The gap is the finding. This structure is the spine of the analysis, the deck, and
  the feature priority order.
- Five topics: schedule accuracy · parish community · learning the Orthodox faith · parish
  info and leadership · online giving. Plus 5 free-text questions, 83 answers total.
- **A `Username` column of real respondent emails was removed** and replaced with
  `R01`–`R22`. The Google Form collected them only to block duplicate submissions. The raw
  export is **not** in this public repo and must never be committed. `.gitignore` blocks
  the filenames as a backstop. Mitch can re-export from the form if it's ever needed.
- The free-text answers were scanned and contain no names or identifying details.
- **22, not 24.** A line-count of the raw file reads 25 because long free-text answers wrap
  across lines; parsed properly it's 22 rows. Use a CSV parser, not `wc -l`.

---

## Working agreements

- **Propose, then wait for confirmation.** Mitch wants to see the intended actions before
  commands run or files get written — especially anything that touches the repo or goes
  public. Don't describe a plan and execute it in the same breath.
- **One step at a time, in order.** Steps have approval gates. Don't build ahead of one.
- **Every step produces a committed artifact.** An undocumented discussion didn't happen.
- **Write down the reasoning, not just the decision** — a contributor three months from now
  needs the *why*.
- **Nothing technical goes to the parish council.** No tool names beyond ChurchTrac (which
  they already know), no hosting mechanics, no jargon. They decide *whether* and *what*;
  we decide *how*, later.
- **Watch for privacy.** Member data, photos of children, home addresses, and the
  ChurchTrac member list stay off the public site and out of this public repo.

---

## Repo facts

- GitHub: `catmando/sjoca-website`, **public** (read). Write access granted as needed.
- Small team, direct commits to `main` for now. Revisit when real code lands at Step 9.
- `docs/` and `deck/` fill in as we reach each step; empty means not yet started.

---

## Open questions

**Before the council meeting:**
- Annual hosting cost, and what it buys?
- Who are the initial contributors, and what is each taking on?

**At the meeting:**
- Who is the parish liaison?
- Is there a target date, or something real to anchor one to — a feast, an anniversary, a
  stewardship campaign?

**Housekeeping:**
- Confirm the parish's full formal name (there's a TODO in `README.md`).
- Who controls the `sjoca.org` domain and the Google Sites account? (Step 3.)
