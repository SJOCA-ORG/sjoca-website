# CLAUDE.md — working context for the SJOCA website project

Context for anyone (person or Claude session) picking this project up. This file is
committed so it travels with the repo; it is the handoff, not a scratchpad.

**Last updated:** 2026-10-09 — Phase 1 Rails clone standing up and rendering.

---

## What this project is

Replacing the parish website at www.sjoca.org for **St John the Baptist Orthodox Church - Rochester NY (OCA)** — abbreviated **SJOCA**
throughout this repo. The current site is on Google Sites and maintained by parish
members. Development is donated by parishioners. Driven by a parish survey that
found real gaps between what members say matters and how well the current site delivers.

Read [`PROJECT-PLAN.md`](PROJECT-PLAN.md) first — 14 steps in 5 phases. Everything else
is detail hanging off that.

---

## Where we are

**Phase 1 — Rails clone of the current site. Rendering, not yet deployed.**

The council already approved the project and the Rails approach; see
[`IMPLEMENTATION-PLAN.md`](IMPLEMENTATION-PLAN.md), which supersedes Phase A of the
original plan. **The AGM is 15 November 2026.**

### What exists

- Rails 8.1 / Ruby 3.4 / Postgres. No Active Storage, no Solid — asset bytes live in
  the database (see below), so there was nothing for them to do.
- All **11 pages** render at their original paths, with the current site's colours,
  fonts, section banding and measured column proportions.
- The **ChurchTrac calendar iframe works** in the Rails app.
- `legacy_assets` holds **110 images** (~32MB) as bytes in the table.

### Run it

```bash
bin/rails db:create db:migrate
node reference/current-site/capture.mjs     # needs Chrome; ~2 minutes
bin/rails runner script/extract_current_site.rb
bin/rails db:seed
bin/rails server
```

The capture step is required: photos are not in git (see below), so a fresh clone has
no image bytes until you run it.

### How the content pipeline fits together

```
Google Sites ──capture.mjs──> dom/ + geometry.json + images/   (not committed)
                     │
       extract_current_site.rb
                     │
                     v
          db/seeds/content.yml + assets.yml   (committed — readable, diffable)
                     │
                 db:seed
                     v
          pages / sections / blocks / legacy_assets
```

Content is both things at once: **in git as YAML** (reviewable in a pull request, which
was the appeal of static pages) and **in the database** (which is what Phase 2's editor
will write to).

### Three traps, all of which cost time once

- **Capture must be a single browser pass.** Google's image URLs are signed, rotate
  between browser sessions and expire in ~20 minutes. Capturing DOM and geometry in
  separate runs yields two disjoint URL sets with nothing to join on.
- **Document order is not visual order.** Sites places grid cells explicitly; the home
  page reads as two rows of two in the DOM and renders as two columns of stacked items.
  Layout therefore comes from measured bounding boxes, never from markup order.
- **Reset the viewport after a mobile screenshot.** The 390px device override persists
  across navigations, and every later page gets measured as one mobile-width column.

### Next

1. Visual comparison pass, page by page, desktop and phone.
2. Choose a host; get it deployed and seeded (see the seed note on running the first
   production seed from a developer machine).
3. Phase 2: the CMS with draft → review → publish, and the photo consent table.

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
- **Rails was chosen and approved**, with a deliberate sequence: clone the current site
  exactly (Phase 1, no visible changes), then add a minimum CMS (Phase 2), then present
  at the AGM. The fallback if the volunteer team ever evaporates is Orthodox Web
  Solutions, so nothing is lost by trying.
- **Asset bytes live in the `legacy_assets` table**, not on disk or in object storage.
  A `pg_dump` is then a complete copy — pulling production down for local work brings
  the photos with it, with no blob syncing to get wrong. Rows are append-only and keyed
  by a semantic `human_name` ("home-hero"), newest published row wins, so a photo can be
  replaced without touching any page.
- **Parish photos are not in git.** The repo is public and the photos include
  identifiable children. They are seeded from a local capture; after cutover the
  production database is their only copy, which makes backups a parish-archive concern
  and not just a site concern.

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

## The photo library

Parish photographs live **outside this repo**, in a folder shared between
contributors:

```
SJOCA_PHOTO_LIBRARY=/path/to/sjoca-photo-library   # defaults to ~/sjoca-photo-library
```

Keep it on Google Drive (or equivalent) so both developers seed from the same
source and it is actually backed up. `db/seeds/curated.yml` lists which files
become which site assets; without the library those entries report "missing"
and the seed carries on.

```
sjoca-photo-library/
  feast-days/ general/ historical/ interior/ people/ receptions/   50 originals
  derived/                        crops made for the site
  manifest.csv                    every file, with sha256, EXIF date, and for
                                  crops, what they came from and how
```

**Not in git, deliberately.** Not because clergy serving publicly are sensitive,
but because once committing parish photographs is normal, someone commits the
ones with children in them.

**The crops are real work.** They exist nowhere else — the originals survive on
a thumbdrive, but the framing decisions do not. `manifest.csv` records the crop
for each so they can be remade.

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
- Who controls the `sjoca.org` domain and the Google Sites account? (Step 3.)
