# AI as admin — the editing model for Phase 2

Status: **agreed design, not yet built.** Decided in conversation on 13 October 2026.
This supersedes the "minimum CMS" sketch in `IMPLEMENTATION-PLAN.md` — see
[What this changes](#what-this-changes-about-phase-2) at the end.

---

## The idea

Rather than building a form-based admin screen for every kind of change, the parish
edits the site **by describing what it wants**. A maintainer says "add a photo of the
Nativity vigil to the home page, above the service times" and an AI makes that change
in a sandbox. Someone with authority looks at the sandbox, approves it, and it ships.

The whole of it is under version control, so nothing is ever unrecoverable.

### Why, in one paragraph

The survey said schedule accuracy matters most; the site advertised 2023 events. The
cause was never that editing was *hard* — it was that editing was **frightening**.
There was no undo on Google Sites, so the few people willing to touch the site became
protective of it and everyone else stayed away. A sandbox that cannot damage anything
is not primarily a safety feature. It is permission to experiment, and that is the
actual fix for a stale website.

---

## Roles

| role | granted by | can |
|---|---|---|
| *(none)* | self-registration | authenticate, and nothing else — **cannot see drafts** |
| Viewer | Approver | view sandboxes, comment |
| Editor | Approver | create and edit a sandbox |
| SuperEditor | Approver | the above, plus theme and block templates (changes that affect every page) |
| Approver | **SuperAdmin only** | approve and deploy; manage users up to Editor/SuperEditor |
| SuperAdmin | GitHub | everything, including Ruby, routes, migrations, and the Liquid drop surface |

**Login is OAuth.** Google for most people, so they use the account they already have.
**SuperAdmin is GitHub**, and specifically requires being a collaborator on the site
repo — so there is one source of truth for who holds the keys, and removing someone
from the repo revokes their access automatically.

Two details that are easy to get wrong:

- **Self-registration lands at *none*, not Viewer.** A Viewer can see sandboxes, and
  sandboxes contain unreleased announcements and photographs of children. Anyone may
  sign in; nobody sees anything until a human grants a role. Rate-limit registration
  or the pending list becomes a spam queue.
- **Only SuperAdmin may create an Approver.** If Approvers could promote Approvers, one
  compromised account could mint more and nothing would notice. Promoting an Approver
  is rare, so the friction costs nothing. Role changes are written to an audit log that
  SuperAdmins can read.

### The organisation's 2FA policy *is* the SuperAdmin authentication policy

SuperAdmin is defined as "collaborator on the site repo", so whatever GitHub requires
to hold that account is the only thing standing between an attacker and the Ruby,
the routes, the migrations and the deploy. **Loosening the organisation's two-factor
setting silently weakens the top tier of this permission model**, and it will not look
like a security change at the time — it will look like an accommodation for one
person's phone.

GitHub's requirement is tiered: it can demand two-factor authentication generally, or
only the stronger methods (authenticator app, passkey, security key), excluding SMS.
Prefer the stronger setting, because **only SuperAdmins ever need a GitHub account at
all.** Everyone else — Editors, Approvers, Viewers — authenticates to the application
with Google. So this organisation will only ever hold a handful of technical people,
and requiring strong methods of them costs nothing. The accessibility argument for
SMS belongs to the parish volunteers, and they are not here.

As of 13 October 2026 the organisation permits the weaker methods, because the one
member's personal account still has SMS enabled. That is a temporary state, not a
decision.

### When GitHub is unavailable

Nothing ships — deployment runs through GitHub, and that is acceptable; outages are
short. But the SuperAdmin collaborator check must be **cached with a TTL** so a brief
blip does not sign people out or lose sandbox work in progress. Fail closed on the
*role*; never on the work.

---

## The sandbox

Every editing session happens in a sandbox that cannot affect the live site. The
promotion path is: **sandbox → review → approve → deploy**, with a deployment date
optionally in the future (the scheduled-publishing design already in
`IMPLEMENTATION-PLAN.md`: start and end dates both optional, no end means "until
pulled", the undated version is evergreen and dated ones layer on top).

**Concurrency:** one sandbox at a time. Creating one locks out other editors. Because a
single AI mediates, it can tell a waiting editor who holds the lock and what they are
doing. A SuperAdmin can steal a stale lock — the realistic failure is not a merge
conflict, it is somebody opening a sandbox and going on holiday. Revisit if the parish
ever has enough simultaneous editors to need real branching.

**Approval is deployment.** Whoever clicks approve is the release manager. Keep `/up`
wired to an automatic rollback so a bad promotion heals itself rather than waiting for
somebody to notice.

---

## What the AI may change, and who approves it

The gate is chosen by **blast radius, computed** — not by file type, declared. File
type is a crude proxy for the thing that actually matters, which is how much of the
site a change can affect. The system already knows which pages use which templates and
blocks, so it can work this out.

| change | reaches | gate |
|---|---|---|
| text, images, blocks on one page | that page | Editor → Approver |
| a page body's Liquid | that page | Editor → Approver |
| a palette, the header, a block template | every page using it | SuperEditor → Approver |
| layout, routes, models, migrations, the Liquid drop surface | the application | SuperAdmin |

### Templates are Liquid, not ERB

This is the decision that makes the whole thing safe. **`.html.erb` is not markup — it
is Ruby**, with the application's full privileges. A view template can call
`User.destroy_all`. So "restrict the AI to HTML" sounds like a boundary and is not one.

[Liquid](https://shopify.github.io/liquid/) is built for exactly this: user-authored
templates that cannot call arbitrary Ruby and see only what you deliberately expose.
Page bodies **and block/theme templates** become Liquid, which means "render the
lectionary with smaller verse numbers" stops being a developer task. App chrome stays
ERB.

Two things stay ERB and SuperAdmin-only regardless, because they are security-relevant
rather than stylistic: the **layout** (it carries CSP, CSRF and meta tags) and anything
needing Rails helpers that mint tokens or asset digests.

**The load-bearing caveat:** Liquid's safety is a property of the *drops and filters you
expose*, not of Liquid itself. Expose a drop that wraps an ActiveRecord relation too
loosely and you have handed back query or write access, and the whole tier boundary
becomes decorative. One person owns that surface and reviews additions to it. Also
configure Liquid's resource limits (`render_length_limit`, `render_score_limit`,
`assign_score_limit`) — Liquid cannot run Ruby but it can loop itself into a hung
request, and limits turn that into a clean error.

---

## Photographs and consent

Photographs go into the database, as they already do: `legacy_assets` is append-only,
keyed by a semantic `human_name`, newest published row wins. During a conversation
uploaded photos are recorded; when the session is finalised the AI proposes names and
the author accepts or changes them.

**The consent table gates this absolutely.** The AI must be unable to place a photograph
of a child on a page without a consent record. Every new photograph is approved
*individually* on the review screen, and the approval records who approved it and when.

This is the one irreversible harm in the entire system. Everything else in this document
can be fixed with a revert; a photograph of somebody's child on a public website cannot
be un-published.

### Approve what, exactly

Record a hash or version id of the precise change alongside the approver and timestamp.
Otherwise, months later, you can show that somebody approved *something* on that page
but not that it is what shipped.

And **tier the review effort to the risk**, or approval becomes rubber-stamping. A
session touching forty blocks must not demand forty clicks — that is how people learn
to click without reading. Photographs individually and always. Text in bulk with a
diff, individually only when a check flags it.

---

## Remembered commands

When the AI does something that looks repeatable it offers to remember it:
*"shall I remember that as `load pascha palette`?"* This is what removes the need for a
bespoke admin screen per feature, which is the expensive part of CMS work.

**Commands are stored in the repo as data, never as model memory.** Memory is not
versioned, not diffable, not reviewable, and does not survive changing models or losing
a file. Committed data is all four. The AI should not *remember* the Pascha palette; it
should **write it down and read it back**. This repo's own rule — an undocumented
discussion didn't happen — applies to the AI as much as to people.

### Commands crystallise from recipe to data

A stored *prompt*, re-run by a language model, will not reproduce itself exactly. So a
command has two lives:

1. **First time — a recipe.** Natural language, the AI reasons it out, a human reviews
   the result. Non-deterministic, which is fine, because somebody is checking.
2. **Once approved — frozen to data.** The palette becomes a record of actual values.
   Next year, `load pascha palette` *applies a record*: deterministic, instant, no model
   call, no cost, no drift. The friendly name survives; what is underneath has hardened
   from prose into data.

A worked example, which is the one that prompted this design:

> The maintenance team proposes brighter colours for Pascha. The council agrees. The
> team describes it to the AI, which builds a palette in a sandbox. It is approved with
> a deployment date. Pentecost comes and they want green, so the same thing happens
> again — at which point the AI notices a pattern and asks whether these should be kept
> as named looks. Yes. From then on each season is a command.

Two things follow:

- **Seasonal palettes are the scheduled-publishing feature applied to colour.** Start and
  end dates, layering over an evergreen default. That design already exists.
- **Liturgical dates are computable.** Pascha drives the whole calendar, so once a
  palette has dates the paschalion can set them in perpetuity. The parish would not
  switch seasons; the seasons would just happen.

---

## Automated checks

Human review has a measured false-negative rate on this very project. Two real
regressions, both of which would have passed a "go look at the sandbox" review:

- **The mobile menu.** Perfect on desktop. 790px of menu in a 611px viewport, with
  Giving, Community Outreach and Contact *completely unreachable* on a phone. Found by
  accident.
- **The favicon.** Looked right at 512px, shipped, and the flower was invisible in a
  real tab. Measured afterwards at 1.93:1, under the 3:1 floor. Found by accident.

Neither needed a more restrictive toolkit. Both needed a machine looking. Mistakes stay
inevitable; **repeats do not have to be.** Every bug we hit becomes a permanent check:

- render every page at **390px and 1280px**, screenshot-diff against the previous version
- **no horizontal overflow**, and every nav item reachable at phone width
- **contrast ratios** on any new colour pairing
- **content presence** — service times still on the home page, the calendar block still
  renders, the nav still has the expected items
- link check, HTML validity

The content-presence checks matter most at the SuperEditor layer. A broken theme
template does not merely look ugly — it can make content *vanish*, and **a broken site
and a quiet parish look identical from the front.** That is why the importers refuse
empty results, and the theme layer needs the same posture.

## The change log

Every sandbox produces a log in human language — not a git diff. It says what changed
and, more usefully, **computes what to look at**: "this touched the Giving page and the
header partial → 3 pages affected → here they are at 390px and 1280px, before and
after."

That makes review targeted instead of wandering the site, which is precisely the mode
that missed the mobile menu. The log does double duty: it is both the review aid and
the input to choosing the gate, since both need the same blast-radius calculation.

---

## Refactoring

Refactoring here means **consolidating repeated Liquid or style fragments into shared
templates and subfiles** — not restructuring Ruby.

Two rules:

- **Refactors are proposed as independent actions**, never bundled into a content
  change, so they cannot hold up a site update that somebody is waiting on.
- **Factor on the third instance, not speculatively.** Two copies is a coincidence;
  three is a pattern worth naming. An AI told to "factor as much as possible" produces
  abstraction nobody asked for, which makes the *next* change harder.

**A refactor is invisible to every other safety mechanism in this document.** Screenshot
diffs show nothing — that is the definition of a good refactor. Blast radius is maximal
and visible evidence is nil. So refactors are gated on **tests**, not on looking, and
the AI must state what behaviour it believes is unchanged so the reviewer is checking a
claim rather than reading a diff cold.

---

## Cost

Order of magnitude, to be re-checked against current pricing:

| | |
|---|---|
| a normal edit (fix wording, move a photo, add an announcement) | **$0.15–0.30** |
| building something real (a gallery, a new widget) | **$1–3** |
| a parish doing ~20 edits a month | **~$5/month** |
| a parish doing ~100 edits a month | **$20–30/month** |

Noise next to hosting, and the right trade when the parish has more money than
volunteers. Two guardrails regardless: a **hard spend cap** on the API workspace, and
**per-session token logging** surfaced in the admin — not because the bill will be
large, but because a runaway loop is the one way it could be.

Note that commands which have crystallised into data cost **nothing** to re-run.

---

## Why this is a better answer to "what if you get hit by a bus"

Under this design the parish keeps **full content control with zero developers**. If the
volunteer team evaporates — which `CLAUDE.md` explicitly contemplates, with Orthodox Web
Solutions as the fallback — everything except new server-side features still works.
Content, photographs, page layout, seasonal looks, the weekly message: all of it stays
in the parish's hands.

That is a stronger position than the parish has ever been in, and a better answer to the
council than the fallback was.

---

## What this changes about Phase 2

1. **Tests are a prerequisite, not a nice-to-have.** The repo currently has none. The
   SuperEditor layer and refactoring are both unsafe without them, and the automated
   checks above are the same machinery. Build this first.
2. **The content model matters more than the editor UI.** `Block::KINDS` is already a
   bounded vocabulary with typed fields and a real grid — that is the hard part and it
   exists. Getting the vocabulary right beats building forms.
3. **Adopt Liquid for page bodies and block templates**, and design the drop surface
   deliberately.
4. **Build the revision/sandbox model and the approval audit trail** before any AI
   wiring. The AI slots into the *draft* stage of a flow that must work without it.

## Open questions

- The invite flow and the pending-user queue.
- Lock timeout duration, and the SuperAdmin steal UI.
- Who owns the Liquid drop surface and reviews additions to it.
- **The GitHub organisation.** `github.com/Sjoca` is a dormant *personal* account from
  August 2017 — created and never used again, zero repos, no name or email. It is not
  the parish, and no parish organisation exists. Available alternatives include
  `sjoca-rochester`, `sjoca-org`, `sjoca-ny` and `stjohnrochester`. Moving the repo to
  an organisation matters for two reasons: an org can **enforce 2FA** on collaborators
  (a personal repo cannot), and it detaches SuperAdmin from Mitch's personal account.
  GitHub transfers set up redirects, so the move can happen later — but **make the
  owner/repo a config value now** so the SuperAdmin check becomes a one-line change
  rather than a hunt.
