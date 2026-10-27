# CLAUDE.md — working context for the SJOCA website project

Context for anyone (person or Claude session) picking this project up. This file is
committed so it travels with the repo; it is the handoff, not a scratchpad.

**Last updated:** 2026-10-27 — the replay test is done and was presented to the parish
council on 20 October; a login protects the admin; every trace of this particular parish
is out of the Ruby and lives in the database; the `sjoca.org` registration has moved to
Namecheap and the DNS move is the next thing in front of us.

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

**Phase 1 — Rails clone of the current site. Deployed and live on Render.**

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

Run the specs with `bundle exec rspec`. See [`docs/testing.md`](docs/testing.md) — the
suite is mostly regression specs for bugs that actually shipped, and it is a
prerequisite for Phase 2, not a nicety.

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
2. Browser specs — the largest gap in the suite (`docs/TODO.md`).
3. **The replay test — this is where the project is.** The site is back at the
   Phase 1 baseline (revision 8 live, no open drafts) and the task is to
   reproduce everything since **through the admin conversation alone**, with no
   developer edits. See the acceptance test in
   [`docs/ai-admin.md`](docs/ai-admin.md). Mitch drives it.

   The AI admin is built: 54 tools, Liquid templates as database rows, revisions
   as copy-on-write sandboxes, standing promises checked in a real browser, and
   a change log. See [`docs/liquid-vocabulary.md`](docs/liquid-vocabulary.md)
   for the whole surface in one page.

### The model, and what a session costs

The admin runs **Opus 5** (`ANTHROPIC_MODEL`, defaulting to `claude-opus-5`)
with **prompt caching on**. Both were decided on 17 October against measured
numbers, not preference.

A 30-turn session before caching: **5,979,000 input tokens against 87,000
output**. Almost all of that was re-reading its own past — the instructions,
fifty-odd tool definitions, and a conversation that only grows — and a turn
with ten tool calls re-sends the whole thing ten times. That session cost about
**$19 on Sonnet** and would have been **$96 on Opus**.

Caching changes the arithmetic rather than shaving it. Measured on a real call:
the second request paid full price for **8 tokens instead of 11,300**. That
puts Opus at roughly what uncached Sonnet used to cost, which is why the better
model became affordable rather than a luxury.

Watch `cache_read` in the usage line under each reply. If it is near zero,
caching has broken — most likely because something that changes every turn got
in front of a breakpoint, which puts the whole prefix on the wrong side of it.

### Three things to know before touching the AI admin

- **It can see.** `check_appearance` opens a page in real Chrome at 390px and
  1280px and returns the screenshots to the model (~2,460 tokens). Before 17
  October it drove the browser and threw the pixels away, which is why it once
  put a home-page box in the footer: nothing was measurably broken, it just
  looked wrong, and it had no way to perceive that. If a layout judgement goes
  wrong, check that the screenshots are still arriving before blaming the model.

  **And check what the eyes actually saw before believing a fault they report.**
  On 20 October the admin said, twice and in good faith, that Pani Jan's
  photograph was missing from the Leadership page. It was not. Every photograph
  carries `loading="lazy"`, and the screenshot is taken with
  `captureBeyondViewport` -- the whole page at once, without the viewport ever
  moving down it -- so Chrome never loaded the LAST picture on a 3,292px page
  and it was captured as an empty box. `script/visual_check.mjs` now forces
  every image to load before it measures or photographs anything, and states it
  as a finding when one genuinely will not load. A tool that invents faults is
  worse than one that misses them, because somebody then goes and fixes the
  thing that was right.

- **There are no feed-specific drops, deliberately.** `site.calendar`,
  `site.upcoming`, `site.recordings` and `site.lectionary` were deleted on 17
  October. Outside data comes in through `add_data_source` → the server fetches
  and caches the address → `{{ site.data.<name>.json_tag }}` writes it into the
  page as JSON → admin-written JavaScript formats it. **Do not add a drop for a
  new feed.** The reason is in `docs/ai-admin.md`: `site.upcoming` silently
  excluded every regularly scheduled service and the AI built a page on top of
  it that was missing Vespers and the Divine Liturgy, because the filter was
  invisible to it. Judgement in Ruby is judgement nobody can review.

- **`Site::OutboundFetch` is a security boundary, not a helper.** It is the only
  place the app fetches a URL chosen by the AI rather than by a developer, and
  the request leaves our server inside Render's network. Read the comments
  before changing anything in it, and keep its 17 specs passing — each one
  stands for an attack. Notably: the private-address check runs **again after
  every redirect**, because a public URL may redirect to `127.0.0.1`.

### The ChurchTrac, YouTube and lectionary mirrors

`CalendarEvent`, `ClassRecording` and `LectionaryDay` still exist with their
importers and cron jobs. The fetch primitive makes the **ChurchTrac** one
redundant and it will go once the replay test has rebuilt the calendar through
the admin. The other two cannot go yet: YouTube serves an HTML page with the
data brace-matched out of ~1MB of markup, and oca.org serves one HTML page per
day. Both need the bytes parsed before there is JSON to hand over —
`docs/TODO.md` has the two possible routes.

Deployment is done — see [`docs/deployment.md`](docs/deployment.md). The site runs on
Render at **https://sjoca.onrender.com** (service `srv-db6kqurl550s73bd5h90`), deployed
from `main` via `render.yaml`, with three cron jobs for the calendar, class recordings
and lectionary mirrors. `sjoca.org` is **not** cut over yet, but the domain
and its DNS are now **ours**. The registration moved from Amazon Registrar to
Namecheap on 26 October 2026 (renewal now January 2028, auto-renew on) and the
nameservers moved to Namecheap BasicDNS on 27 October. The AWS account that held it
was never recovered — AWS Support issued a transfer code after verifying Mitch as
the registrant — so Route 53 was never editable and the zone had to be read out of
public DNS rather than exported. SPF and DMARC went in with the move; neither had
ever existed. **The website being served is still Google Sites**, deliberately: the
domain move and the website cutover are separate, and the parish noticed nothing.

The procedure, the captured zone and an honest account of doing it are in
[`docs/dns.md`](docs/dns.md). Two scripts, neither needing any account access:
`script/zone_compare.sh` separates *what the authoritative nameserver holds* from
*what public resolvers are handing out* — conflating those two produced a false
"mail is broken" alarm on a zone that was already correct — and
`script/domain_watch.sh` reports registrar, status and the records that must not
move. What remains: DKIM, and on cutover day an **ALIAS on the bare domain** in the
same edit as repointing `www`.

The parish favicon is in place — the Flower City logo behind an Orthodox three-bar
cross. Design history, provenance and the regeneration command are in
[`docs/favicon.md`](docs/favicon.md). It is generated from `public/icon.svg`;
regenerate the rasters rather than hand-editing a PNG.

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

- GitHub: `SJOCA-ORG/sjoca-website`, **public** (read). Write access granted as needed.
  Owned by the **SJOCA-ORG** organisation, not a personal account, so the site does
  not depend on one person's GitHub login — and so the org can enforce 2FA on
  whoever holds SuperAdmin (see [`docs/ai-admin.md`](docs/ai-admin.md)).
  Transferred from `catmando/sjoca-website` on 13 October 2026; GitHub redirects
  the old path, but use the new one.
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
- ~~Who controls the `sjoca.org` domain and the Google Sites account?~~ Answered: the
  domain is at Namecheap under Mitch's account as of 26 October 2026, and
  `itmanager@sjoca.org` reaches admin.google.com. What remains is getting the Namecheap
  login into shared parish credentials rather than a personal account — which is the
  whole reason this question was hard to answer in the first place.
