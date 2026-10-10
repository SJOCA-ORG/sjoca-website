# SJOCA Website — Implementation Plan

**Parish:** St John the Baptist Orthodox Church - Rochester NY (OCA) — **SJOCA**
**Status:** Draft for review, v0.2 — 2026-10-10
**Supersedes:** Phase A of [`PROJECT-PLAN.md`](PROJECT-PLAN.md). See *Relationship to the
original plan* at the end.

This is the active plan. The parish council has already approved the project and the
approach; what follows is how we build it and what we show the parish in November.

---

## 1. Decisions already made

A proposal was presented to the Parish Council by another parishioner and **accepted**.
The approved approach: **clone the current site into a Rails application.**

### Why — the rationale, recorded

These are the reasons the council accepted, kept here so they survive the people who
made them:

1. **Keep the current look.** No immediate shock of change for the parish. Replace the
   engine underneath first; change the appearance later, deliberately.
2. **Easy maintenance for non-technical people is the first real improvement.** Keeping
   the site *fresh* is the point, and freshness is a maintenance problem, not a design
   problem.
3. **Further changes come over time**, once the foundation is in place.
4. **The fallback is intact.** The alternative was contracting the site to **Orthodox Web
   Solutions** — a genuinely good option. Because the Rails site is built for free by a
   volunteer team, nothing is lost by trying: if there is ever nobody left to maintain it,
   the parish can still go that route.
5. **Maintenance capacity exists.** At least **three current parish members** have the
   skills to be on the site maintenance team.
6. **The ChurchTrac calendar is already integrated.** The regular service times are a
   fixed block; **below it sits an iframe pulling live data from ChurchTrac.**

Point 4 is the one to repeat at the AGM. It is the reason this is a low-risk undertaking:
the volunteer effort is a free option, not a bet.

---

## 2. Sequence

| Phase | What | When |
|---|---|---|
| **1** | Move the site to Rails. **No changes.** | Now |
| **2** | Add a minimum of CMS features; make any immediately necessary structural changes | Before the AGM |
| **3** | Present to the parish at the **Annual General Meeting** | **November 2026** |
| **4** | On parish approval, repoint `sjoca.org` to the new site | After the AGM |
| **5** | Further improvements, from a backlog | Ongoing |

### What the parish is approving at the AGM

Two distinct things, and the presentation should keep them distinct:

1. **The new site, and the process for keeping it fresh.** Not just the pages — the
   workflow that stops the site going stale again. This is why the CMS approval flow has
   to be demonstrable, not described.
2. **Funding for hosting.** Mitch funds hosting until the AGM, so this is a request to
   take over an already-running cost rather than to authorize an unknown one.

---

## 3. Corrections to earlier assumptions

Two things in the repo were wrong and are now fixed here:

- **ChurchTrac calendar integration exists.** A live iframe below the fixed service-time
  block. An earlier note in `PROJECT-PLAN.md` / `CLAUDE.md` said the integration was
  minimal-but-present, then a fetch of the site suggested it was absent entirely. Both
  readings were wrong: the iframe is real, and it was invisible to a fetch because Google
  Sites renders embeds with JavaScript. **Lesson: don't audit a Google Sites page with a
  plain HTTP fetch.** Phase 1 must capture it from a real browser.
- **Giving is an outbound link**, not an embed — it goes to
  `https://sjoca.churchtrac.com/give`. Trivial to carry forward exactly as-is.

Separately, and still true: the *hand-maintained* "Upcoming Events and Services" blocks
on the Events page advertise **St. Nicholas Day 2023** and **Youth Day at Seabreeze**.
That content is roughly three years stale. It is the clearest possible illustration of why
Phase 2 matters, and it belongs in the AGM presentation — not as criticism of anyone, but
as evidence that hand-maintenance always loses eventually.

---

## 4. Phase 1 — Rails clone, no changes

**Goal:** the same site, same appearance, running on Rails. A parishioner should not be
able to tell the difference.

### Current site structure

Nine pages, as far as can be determined:

```
Home
About Us          → Our Story · Leadership · Choir
Events & Services → Weekly Bulletin · Miter Ceremony
Donate
Community Outreach
Contact
```

Plus, in the footer on every page: address (855 S. Goodman St., Rochester, NY 14620),
`fr.david@sjoca.org`, the OCA / Diocese of New York and New Jersey affiliation, and
"Our services are entirely in English!"

### Tasks

- [ ] **Capture the current site properly, from a real browser** — every page's text,
      images, layout, and the ChurchTrac iframe's exact embed URL and parameters. Save
      screenshots at desktop and phone width as the visual reference to build against.
      → `docs/current-site-inventory.md`
- [ ] **Download every image and asset** off Google Sites, at full resolution.
- [ ] **Record every current URL**, so links out in the wild and anything in print
      still resolve after cutover.
- [ ] Rails app skeleton; Postgres; Active Storage; Action Text.
- [ ] **Content models from the start** — don't hardcode page content into views. Phase 2
      is only weeks away and would have to tear it out. Model it as data now, render it
      through views; visual parity is a layout and CSS problem, not a storage problem.
- [ ] Shared layout: header, navigation, footer.
- [ ] All nine pages, built to match.
- [ ] ChurchTrac calendar iframe, in place below the fixed service-time block.
- [ ] Donate link out to ChurchTrac.
- [ ] Photo galleries.
- [ ] Deploy to a temporary public URL.
- [ ] **Side-by-side visual comparison pass**, desktop and phone, page by page.

**Exit criteria:** every page matches, on a real phone and a real desktop; the calendar
iframe shows live ChurchTrac data; the donate link works; nothing 404s.

**Explicitly not in Phase 1:** design improvements, new pages, restructuring, new
features. Those are Phase 2 or Phase 5. Resisting this is the main discipline of the phase.

---

## 5. Phase 2 — Minimum CMS, with staged approval

**Goal:** a non-technical parishioner can update the site, and nothing reaches the public
without review.

This is the phase the AGM presentation actually turns on. The parish is being asked to
approve *a process for keeping the site fresh* — so the workflow must be demonstrable
live, with real content, not shown as screenshots.

### The approval requirement

Changes must be **staged for approval before publishing**. This matters most for:

- Big event announcements
- **Photos containing children**
- Anything doctrinal or anything speaking for the parish

### Recommended design

The pattern is well established — it's editorial workflow, the same thing a newsroom CMS
does. Nothing exotic is required.

**Draft and published versions, plus a review queue.**

- Every page carries a **published version** (what the public sees) and optionally a
  **draft version** (work in progress). The public never sees a draft.
- An editor edits the draft freely. Nothing is live.
- The editor **submits for review**.
- An approver opens a **preview URL that renders the draft exactly as it will appear**,
  then approves or rejects **with a comment**. Rejection with a reason matters — a
  volunteer who gets a silent "no" stops volunteering.
- On approval, the draft becomes published and the previous version is retained, so any
  change can be undone.
- **Every action is logged**: who changed what, when, who approved it. For photos of
  children, an audit trail isn't bureaucracy — it's the thing that lets you answer a
  parent's question a year later.

**Roles:** Editor (can draft and submit) · Approver (can publish) · Admin (can manage
users). Fr. David is an approver by definition; who else is a decision for him.

**My recommendation: require approval for everything.** The temptation is to let trusted
editors publish small fixes directly. Don't, at least not initially — the volume on a
parish site is a few changes a week, the rule is easy to explain at the AGM, and "nothing
goes public without a second pair of eyes" is a much stronger promise than "most things
don't."

**Photos need their own handling.** On upload, require an answer: *does this contain
identifiable children?* If yes, approval is mandatory and the image is flagged in the
audit trail. This encodes the parish's policy as a rule rather than relying on whoever
is uploading to remember it at the time.

### Build it, or adopt a CMS?

**Recommendation: build it on Rails primitives** — Action Text, Active Storage, a `Page`
model with versions, a small admin area. Reasons: the site is nine pages; the approval
requirement is specific enough that a general-purpose CMS would need fighting; and the
maintenance team knows Rails, not a particular CMS's conventions.

**The fair counter-argument:** a mature Rails CMS gives you a lot for free, and
**Alchemy CMS** in particular already separates draft and public page versions, which is
most of the requirement. If volunteer time is the binding constraint — and with a
November deadline it may well be — that's worth something.

**Suggested resolution:** spend **one day** evaluating Alchemy against this list before
committing either way. A day spent now is cheap; discovering in week three that you're
fighting a framework is not.

### Idea parked for Phase 2: content with a release date

Content should be able to carry a **release date** — prepared in advance, approved now,
and published automatically when that date arrives.

Worth recording because it falls out of the design we already have rather than fighting
it. The approval flow is "newest *approved* version wins"; adding a date makes it
"newest approved version whose release date has passed". The same change serves both
page content and `legacy_assets`, so a photo can be swapped on a date too.

What it buys the parish is sequencing, which is most of what a church calendar is:
a Nativity message written in November and appearing on the day, a Pascha banner that
puts itself up, a new leadership page that goes live the morning after the annual
meeting rather than whenever someone remembers. Approval and timing stop being the same
decision — Fr. David can approve something once, in advance, without having to be
available at the moment it should appear.

Two things to decide when we build it:

- **Does anything retire?** A release date implies an end date for seasonal content.
  Easy to add later; awkward to retrofit if the model assumes content is forever.
- **What does the editor see?** Something scheduled is neither draft nor live, and if the
  queue does not show that clearly, people will assume their change failed and submit it
  again.

Not in the AGM scope — but worth demonstrating as "what comes next" if the build goes
well, because it is the clearest answer to *how does the site stay fresh*.

### Scope discipline

Minimum means minimum. For the AGM, in scope:

- Edit text on existing pages
- Add, replace, caption, and remove photos
- Create and edit event announcements
- Draft → submit → preview → approve/reject → publish, with comments
- Audit log
- The photos-of-children flag

Out of scope until after the AGM: user self-registration, a media library with search,
scheduled publishing, redesign, new page types, anything touching the ChurchTrac
calendar's contents, bulletin automation.

### Immediate structural changes

Phase 2 also carries any structural change that genuinely cannot wait. Keep this list
short and write down the justification for each — the Phase 1 discipline of "no changes"
is worth protecting, and every exception weakens it.

---

## 6. Phase 3 — The AGM presentation (November)

**Audience:** the whole parish, not the council. Less detail, more reassurance.

Shape of it:

- Here is the site. *(It looks the same — that's deliberate, and here's why.)*
- Here is what was broken: the events page still advertises 2023, because updating it by
  hand was the only option.
- **Here is the new process, demonstrated live** — make a change, submit it, Fr. David
  approves it, it appears. This is the heart of the presentation.
- Here is who maintains it: three parishioners, named.
- Here is the cost, and the ask.
- Here is the safety net: if the volunteer team ever goes away, Orthodox Web Solutions
  remains available and nothing has been lost.
- **The ask:** approve the new site and the process; approve taking over the hosting cost.

**Deliverable:** `deck/agm-presentation/` plus a written demo script. Rehearse the demo
against the real deployed site. A live demo that fails in front of the parish costs more
than one that was never attempted.

---

## 7. Phase 4 — Cutover

- [ ] Final content review with Fr. David — everything published is approved.
- [ ] Repoint `sjoca.org` DNS to the Rails app.
- [ ] **Keep the Google Site intact and recoverable**, not deleted, for at least a few
      months.
- [ ] Verify old URLs still land somewhere sensible.
- [ ] Confirm the ChurchTrac calendar and the donate link work on the live domain.
- [ ] Announce: from the ambon, in the bulletin, and through ChurchTrac email and text.
- [ ] Hosting billing transfers from Mitch to the parish.

---

## 8. Phase 5 — After

A backlog, worked by priority, from the survey findings and whatever the parish asks for
at the AGM. The 22 survey responses in `data/survey/` are still the best evidence of what
members actually want, and that analysis hasn't been done yet — it's still worth doing,
now as input to the backlog rather than to a proposal.

---

## 9. Development setup

### Viewing local changes against live data

No formal staging server. What's needed is the ability to run the app locally against a
copy of the live database.

**Mechanism:** a `bin/db-pull` script — `pg_dump` from production, restore into the local
database.

**The gotcha: Active Storage.** A database dump alone gives you image *references* with
no image *files*, so every photo breaks locally and the site looks wrong in exactly the
area you're most likely to be working on. Two workable answers:

- **Point local Active Storage at the production bucket, read-only.** Cleanest, if
  production uses S3-compatible storage. Make sure it really is read-only.
- **Sync the blobs along with the dump.** Fine at this scale — a parish site's photos are
  likely well under a gigabyte.

Decide this when hosting and storage are chosen, and make `bin/db-pull` handle both the
database and the files. A script that only does half the job will quietly mislead people.

**Keep dumps out of the repo.** Add them to `.gitignore`. Once there are admin accounts —
and especially once there are photo consent records — a production dump is sensitive and
shouldn't be passed around casually.

### A note on staging

A formal staging server genuinely isn't needed, and here's why it's a non-issue until
November: **the Phase 1 and 2 site is deployed at a temporary URL and isn't live for the
parish yet.** Until cutover it serves as a shared preview — for Fr. David to review
approvals, for the maintenance team to look at, for rehearsing the AGM demo. The question
of whether to add staging only becomes real *after* Phase 4, and it can wait until then.

### Hosting and cost

Needed before the AGM: a real monthly number, and what it buys.

Rough expectation for a small Rails app with a database: **roughly $10–25/month**,
depending on host. `sjoca.org` is already owned, so no new domain cost. The figure should
be confirmed against whichever host is chosen rather than quoted from this document.

Choose the host for *who can operate it*, not for what's cheapest or most interesting.
With a three-person volunteer maintenance team, a platform that makes deploys boring is
worth a few dollars a month.

### NixOS

One contributor works on **NixOS**, which was already causing friction at the editor
stage. A Rails toolchain there — Ruby, Postgres, native extensions — needs a working Nix
setup, and that is a day of work rather than an afternoon. **Start it now, in parallel
with Phase 1 planning**, not in week three. Commit a flake or shell file to the repo once
it works, so the next person doesn't repeat it.

---

## 10. Risks

**The November deadline is the main risk.** As of 2026-10-09 the AGM is somewhere between
three and seven weeks away, and that range is the difference between comfortable and not
achievable. **Get the actual date first** — it determines how hard Phase 2 has to be cut.

Specifically:

- **Scope creep in Phase 2.** The CMS could absorb unlimited effort. The in-scope list
  above is deliberately short; treat additions as requiring a reason.
- **Phase 1 "no changes" erosion.** Once the site is in Rails, every small improvement
  will look cheap. Each one spends November.
- **Dev environment setup**, NixOS especially, competing with build time.
- **A failed live demo at the AGM.** Rehearse against the real deployment.
- **Approval bottleneck.** If Fr. David is the only approver, the workflow stalls whenever
  he's unavailable. Name a second.

**If time gets short, cut Phase 2 scope, not Phase 1 fidelity.** A faithful clone with a
rough CMS demos well. A half-finished clone with an elegant CMS does not.

---

## 11. Open questions

**Needed now:**
- **What is the actual AGM date?** Everything above scales off this.
- Confirmed monthly hosting cost, once a host is chosen.
- Who are the three maintenance team members, and who among them is the second approver
  besides Fr. David?

**Needed for Phase 2 design:**
- Who gets Editor accounts at launch?
- Is there, or should there be, a **photo consent record** for children — a way to know
  which families have agreed? The approval flow can flag photos reliably, but it can't
  answer "did we have permission," and that question will eventually be asked. Worth
  deciding whether that's in scope or explicitly deferred.
- Does the Weekly Bulletin stay a PDF, or become editable content?
- Does anything bypass approval, or does the everything-gets-reviewed rule hold?

**Needed before cutover:**
- Who controls `sjoca.org` DNS and the Google Sites account?
- Where does the hosting account live, and who holds the credentials? (Not one person.)

---

## Relationship to the original plan

[`PROJECT-PLAN.md`](PROJECT-PLAN.md) was written before the council had been approached
and assumed a sequence where the technology choice came late, at its Step 8. Events
overtook it: a proposal was made and accepted, and Rails was chosen as part of that
acceptance.

**Superseded:** its Phase A (the council proposal), its ordering of approval gates, and
its deferral of the technology decision.

**Still useful, and worth returning to:** the survey analysis (not yet done), the content
inventory, the stakeholder questions in its Step 2, the launch and testing checklists, the
maintenance guide, and the follow-up survey idea. Those are referenced from the phases
above where they apply.

The original plan stays in the repo as the record of how the project was first framed.
This document is the one to work from.
