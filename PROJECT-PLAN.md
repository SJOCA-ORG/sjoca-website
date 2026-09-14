# SJOCA Website Overhaul — Project Plan

**Parish:** St John the Baptist Orthodox Church - Rochester NY (OCA) — abbreviated **SJOCA** throughout.
**Status:** Draft outline, v0.4 — 2026-09-14
**Purpose of this document:** name every step between today and a launched website, in
order, so that any contributor can see where we are and what comes next. This is an
outline of *steps*, not a design, a specification, or a technology choice. Each step
below gets expanded into its own working document as we reach it.

---

## What we already have

| Asset | Where | Notes |
|---|---|---|
| Existing website | www.sjoca.org | Hosted on **Google Sites**, maintained by parish members. The thing being replaced. Not yet inventoried. |
| Parish survey results | `data/survey/responses-anonymized.csv` | 22 responses. Each topic asked as a pair: *how important is X* + *how well does the current site do X*. Plus free-text comments. Respondent emails removed — see the README. |
| ChurchTrac | Existing parish system | See below — the most important constraint on this project. |

The survey's paired structure is the spine of the whole project: the gap between
"important" and "currently works well" is the argument for doing this at all, and it is
also our priority order for features. Five topics were measured:

1. Accurate schedule information
2. Keeping in touch with the parish community (events, photos, member news)
3. Learning about the Orthodox faith
4. Information about the parish (history, leadership)
5. Online donations

---

## ChurchTrac — the systems we already run on

The parish uses **ChurchTrac** for:

- Member list
- Calendar
- Email and text communication
- Accounting
- Online giving

**The floor is what we already have.** The current site already integrates the
ChurchTrac **calendar** and **online giving** — minimally, but sufficiently. The
proposal commits to *at least that same level of integration*. This is a guarantee we
can make without qualification, because it is already working today.

**Everything else is TBD and conditional.** Drawing on the member list, email and text
communication, or accounting is worth exploring and will be done only where practical.
None of it is promised in the proposal.

Why the calendar matters more than it might appear: the loudest finding in a parish
survey is usually stale schedule information, and stale information is what happens when
the same facts are kept in two places by two different people. A calendar maintained
once, in ChurchTrac, and displayed on the website is a structurally different thing from
a calendar someone has to remember to update twice. We already have this; the job is to
carry it forward and, if practical, present it better.

Giving stays with the current provider — this project does not change how the parish
takes money.

**Privacy note:** the member list and the accounting data must never be exposed to the
public site. Where member data appears at all, it does so only behind whatever
protection the parish agrees to, and only with consent.

---

## Ground rules

- **Nothing technical reaches the parish council.** No tool names beyond ChurchTrac
  (which they already know), no code, no hosting mechanics, no jargon. Council decides
  *whether* and *what*, not *how*.
- **Development work is a voluntary donation** by members of the parish. The only money
  the council is asked to approve is the recurring cost of hosting the site.
- **One approval at a time.** Each approval gate below is a separate, explicit yes.
  We do not build ahead of an approval.
- **Everything lives in this repo**, committed, so a contributor on any machine can pull
  and continue.
- **Every step produces an artifact** — a document, a deck, a mockup. "We discussed it"
  is not a deliverable.

**Who approves:** the Rector (Fr. David), through the parish council or its appointed
representatives. A single named liaison is to be identified at the proposal meeting.

---

## The steps

### Phase A — Approval to proceed

#### Step 1. Survey analysis and proposal to the Parish Council *(slide show)*

Steps 1 and 2 of the previous draft are combined: we know our own parish well enough
that the survey analysis is proposal preparation, not a separate phase.

- **Goal:** get a yes to proceed, approval of the annual hosting cost, a named liaison,
  and a decision on timing.

- **Preparation — analysis:**
  - Score each topic's importance-vs-satisfaction gap from the 22 responses
  - Code the free-text comments into themes; pull the quotable lines
  - Note where respondents disagree, if the data supports the split
  - Produce the one chart that carries the case
  - **Caveat to keep in mind:** 22 responses sets direction; it does not settle a close
    call. We say so plainly rather than over-claiming.

- **Preparation — action items to complete before the meeting:**
  - [ ] **Calculate the annual hosting cost.** This is a genuinely new cost — Google Sites
        costs the parish little or nothing today — and the deck says so plainly rather
        than letting it surface in discussion. The council is prepared for a reasonable
        monthly or yearly figure; our job is to bring them a real number and what it buys.
  - [ ] **Name the initial contributors** — who is donating development work, and roughly
        what each is taking on.

- **Content of the deck (outline only — written in the next working session):**
  - Why now — what the parish told us in the survey, in their own words
  - The importance-vs-satisfaction gap, shown plainly
  - What a visitor to our parish experiences today, and what we want them to experience
  - What we propose to build, described in terms of what people can *do*
  - How it fits with ChurchTrac — the calendar and giving integration we have today
    carries forward at minimum; anything further only where practical
  - Who is donating the work
  - What it costs: development donated; annual hosting cost is the ask
  - How long it will take, in phases
  - **The ask:** approval to proceed, approval of the annual cost, a named liaison, and a
    conversation about timing

- **Approval gate:** Parish Council, with the Rector.
- **Exit criteria:** written record of approval, named liaison, approved annual cost, a
  decision on timing, and any conditions attached.
- **Deliverables:** `deck/` (the slides) and `docs/survey-findings.md` (the analysis
  behind them, kept separately so the reasoning survives).

---

### Phase B — Find out what's actually needed

#### Step 2. Stakeholder interviews — gathering additional requirements

- **Goal:** collect the requirements the survey could not surface, especially operational
  ones.
- **Who to talk to** (each has different needs):
  - Fr. David — liturgical calendar accuracy, doctrinal review, tone
  - Parish council / treasurer — giving, what may and may not be published
  - Whoever maintains the current Google Sites pages today — *critical:* they, or someone
    like them, will maintain the new one
  - Whoever administers ChurchTrac — how the calendar is actually kept, who has access
  - Choir director, church school, ministry and committee leads — who owns what content
  - Newcomers and inquirers — the audience least served by most parish websites
  - Whoever produces the bulletin and sends the email and text messages
- **Key questions:** who updates what, how often, with what skill level; what must never
  be published (member names, photos of children, addresses); what is kept in ChurchTrac
  versus kept elsewhere by hand; accessibility and language needs.
- **Deliverable:** `docs/requirements.md` — needs separated into *must have*, *should
  have*, *later*, with the source of each.
- **Approval gate:** Fr. David and the liaison sign off that the list is right and
  complete.

#### Step 3. Audit of the current site and the ChurchTrac connection

- **Goal:** know exactly what exists before deciding what survives, and document how the
  working ChurchTrac integration is wired so we can carry it forward without losing it.
- **Activities:**
  - Full page inventory of www.sjoca.org: what each page is, when it was last accurate,
    who owns it, and keep / rewrite / merge / drop
  - Capture current URLs so inbound links don't break
  - Inventory photos, documents, PDFs, and their permissions
  - Check whether any analytics exist on the Google Sites property
  - **Document exactly how the current site surfaces the ChurchTrac calendar and giving**
    — embed, feed, link, or otherwise — so the mechanism is written down and reusable
  - **Survey what else ChurchTrac can expose**, to see whether anything beyond calendar
    and giving is practical. Findings feed the *should have* / *later* lists, not promises.
  - Confirm who controls the `sjoca.org` domain and the current hosting account
- **Deliverable:** `docs/content-inventory.md` and `docs/churchtrac-integration.md`.

---

### Phase C — Decide the shape of the site

#### Step 4. Information architecture — what pages exist and how they nest

- **Goal:** agree the site's structure before anyone draws anything.
- **Activities:** draft the sitemap and main navigation; write the top few user journeys
  end to end ("a visitor finds service times for this Sunday", "a newcomer decides
  whether to visit", "a member gives online", "a parent finds church school info");
  decide what lives on the home page.
- **Deliverable:** `docs/sitemap.md` + journey walkthroughs.
- **Approval gate:** Fr. David and the liaison approve the sitemap. **This is the
  cheapest place to change our minds — moving a page here costs minutes, after Step 7 it
  costs days.**

#### Step 5. Content plan and ownership

- **Goal:** know who writes every word, and who keeps it current after launch.
- **Activities:** assign an owner and a due date to each page from the sitemap; decide
  what is rewritten vs. carried over from Google Sites; agree the photo policy and gather
  photos; decide what needs clergy review before publishing; decide explicitly what is
  maintained *in ChurchTrac* rather than on the site.
- **Deliverable:** `docs/content-plan.md` — page, owner, due date, status.
- **Note:** content is the usual reason projects like this stall. Starting it here, in
  parallel with design, is deliberate.

#### Step 6. Design direction

- **Goal:** agree the look and feel, in the abstract, before spending effort on pages.
- **Activities:** present 2–3 distinct directions (not 10 — too many choices stalls a
  committee); each shown as a mood/style board: color, typography, use of iconography and
  photography, overall feeling. Orthodox parishes carry real aesthetic expectations —
  reverence, warmth, and appropriateness of imagery are design requirements, not taste.
- **Deliverable:** `docs/design-direction.md` + the boards.
- **Approval gate:** **one** direction chosen, in writing, by Fr. David and the liaison.
  Recorded so it isn't relitigated at Step 8.

---

### Phase D — Show it before building it

#### Step 7. Mockups

- **Goal:** let people see and react to real pages while changes are still cheap.
- **Activities:** mock up the handful of pages that carry the design — home, service
  schedule/calendar, about/our faith, giving, and one ordinary interior page. Show each
  at phone width as well as desktop; phones are how most people will actually arrive.
  Use real content from Step 5 wherever possible — placeholder text hides problems.
- **Deliverable:** shareable mockups (clickable if practical) + a written summary of what
  is being asked for feedback on.
- **Approval gate:** Fr. David and the liaison approve. Optionally show the council here
  as a progress check — it costs one meeting and buys a lot of goodwill.
- **Expect a round of revisions.** Budget for two.

#### Step 8. Technical approach *(this is where technology gets decided, and not before)*

- **Goal:** choose how it gets built and hosted, driven by the requirements — above all
  by who has to maintain it (Step 2) and what it must do (Step 4).
- **Decisions to make and record:** how pages get edited after launch and by whom;
  hosting, and the annual cost approved at Step 1; domain and email continuity off Google
  Sites; how the ChurchTrac calendar is surfaced; how giving is linked or embedded;
  backups; who holds the accounts and passwords; ongoing cost.
- **Deliverable:** `docs/technical-approach.md`, with the reasoning, so a future
  contributor understands *why*, not just *what*.
- **Approval gate:** liaison approves the maintenance model. Anything exceeding the
  annual cost approved at Step 1 goes back to the council.

---

### Phase E — Build and launch

#### Step 9. Build

- **Goal:** a working site, in this repo, reviewable by contributors.
- **Activities:** build the approved structure and design; connect the ChurchTrac
  calendar and giving; wire up contact and any forms; get it working properly on phones;
  accessibility as we go (contrast, alt text, keyboard navigation, readable type — a
  meaningful part of the parish is older).
- **Deliverable:** a preview site others can visit and comment on, plus regular commits.

#### Step 10. Content loading

- **Goal:** the real site, with real words and real photos.
- **Activities:** load content from Step 5; migrate anything worth keeping from Google
  Sites; proofread; clergy review of anything doctrinal.
- **Approval gate:** Fr. David approves all published content.

#### Step 11. Review and testing

- **Activities:** test on real phones, tablets, and older desktops; check every link and
  form; **verify giving works end to end with a live test transaction**; confirm the
  calendar reflects a change made in ChurchTrac; accessibility pass; a small group of
  parishioners try to complete the Step 4 journeys while we watch and say nothing.
- **Deliverable:** `docs/test-results.md` and a punch list, worked to zero.

#### Step 12. Launch

- **Activities:** decide the cutover moment; point the domain; keep the Google Sites
  version recoverable; make sure old links still land somewhere sensible; announce it —
  from the ambon, in the bulletin, and through ChurchTrac email and text.
- **Approval gate:** liaison says go.

#### Step 13. Handoff, training, and upkeep

- **Goal:** the parish can run the site without the people who built it.
- **Activities:** train whoever maintains it, with them driving; write a short plain
  guide, in this repo; hand over accounts and passwords properly; agree who fixes what,
  and a review cadence (quarterly is realistic).
- **Deliverable:** `docs/maintenance-guide.md` + a written handoff record.

#### Step 14. Follow-up

- **Activities:** 30 and 90 days after launch — re-ask the parish a short version of the
  original survey and compare the gaps to Step 1. That closes the loop and gives the
  council evidence that what they approved was worth it.

---

## Approval gates, collected

Approval is by Fr. David, through the parish council or its appointed representatives.

| # | Step | Gate | Who decides |
|---|---|---|---|
| 1 | 1 | Proceed with the project; annual hosting cost; liaison; timing | Parish Council + Rector |
| 2 | 2 | Requirements are right and complete | Fr. David + liaison |
| 3 | 4 | Sitemap and navigation | Fr. David + liaison |
| 4 | 6 | Design direction (one of 2–3) | Fr. David + liaison |
| 5 | 7 | Mockups | Fr. David + liaison (council optional) |
| 6 | 8 | Maintenance model | Liaison (Council if cost exceeds Step 1) |
| 7 | 10 | All published content | Fr. David |
| 8 | 12 | Launch | Liaison |

---

## Open questions

**Settled:**
- ~~Budget~~ — development donated by parish members; annual hosting cost is the only ask.
- ~~Who maintains the current site~~ — parish members, on Google Sites.
- ~~Giving provider~~ — staying with ChurchTrac.
- ~~Who approves~~ — Fr. David through the parish council or appointed representatives.
- ~~ChurchTrac integration~~ — calendar and giving already work on the current site;
  the proposal commits to at least that. Anything more is conditional on being practical.
- ~~Is the hosting cost new~~ — yes. The council is prepared for a reasonable figure.

**To answer while preparing the proposal (Step 1):**
- What is the annual hosting cost we are asking the council to approve, and what does it buy?
- Who are the initial contributors, and what is each taking on?

**To raise at the proposal meeting:**
- Who is the parish liaison — one person with authority to approve?
- Is there a target date, or anything real to anchor one to — a feast, an anniversary, a
  stewardship campaign?

**To confirm during Step 3:**
- Who controls the `sjoca.org` domain and the current Google Sites account?

---

## Working notes

- Repo: `sjoca-website`, to be pushed to GitHub under `catmando`.
- Survey data is committed under `data/survey/`.
- Steps are expanded into `docs/` one at a time, as we reach them.
- The council deck will live in `deck/`.
