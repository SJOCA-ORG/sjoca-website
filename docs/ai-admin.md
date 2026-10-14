# AI as admin — the editing model for Phase 2

Status: **agreed design, not yet built.** Decided in conversation on 13-14 October 2026.
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

## The sandbox is a revision, not a second site

There is **no separate sandbox instance**. The sandbox is a set of rows.

```
revisions(id, state, title, created_by, based_on_id,
          approved_by, approved_at, published_at)
          state: draft -> in_review -> published -> superseded   (or discarded)
```

`pages`, `sections`, `blocks`, `templates` and `theme_assets` each carry a
`revision_id`. The live site renders the published revision; a preview at
`/preview/:id` is **the same Rails application rendering a different revision**.

**A revision is a full copy, not a delta.** That sounds expensive until you count:
this site is 13 pages, 66 sections and 204 blocks — about 300 small rows, copied
in milliseconds. Deltas would save nothing and would make deletion need tombstones
and every query need a fallback join.

**Photographs are the exception and are never copied.** `legacy_assets` is ~32MB
and already versions itself; blocks reference a photo by `human_name`, so
revisions share them.

### Why not a second deployment

A separate staging site was considered and rejected, and the reason is specific to
this project: **the content lives in the database and the photographs live only
there.** A second site would need either production's database — in which case it
is not a sandbox — or its own, which then needs a periodic dump restore, has stale
photographs, and leaves approved changes needing a database-to-database diff to get
home. The same objection applies to Codespaces, and to any model where the preview
is a different process.

The second obstacle is latency. A sandbox deploying from a branch means every
change is commit, push, and a three-minute build before the editor sees anything.
Conversational editing does not survive that.

A revision overlay has neither problem, and it keeps the single-editor lock
*optional* rather than architectural — each editor could eventually hold their own
revision.

### Everything non-Ruby becomes a row

| table | holds |
|---|---|
| `pages` / `sections` / `blocks` | already exist, already rows |
| `templates` | `layout/page`, `block/heading`, `partial/icon_card` … in Liquid |
| `theme_assets` | CSS and JS |
| `settings` | service times and similar (see `cms-capabilities.md`) |
| `legacy_assets` | photographs, already append-only |

Nesting works through a custom `Liquid::FileSystem`: `{% render 'icon_card' %}`
loads from the `templates` table instead of from disk, so templates include
templates, recursively, all from the database.

**Versioning needs nothing new.** Use the pattern `legacy_assets` already uses —
append-only rows keyed by name, newest published wins. Photographs and templates
then version identically.

Two things fall out of this:

- **Adding a page already works.** `pages` is a row and the route is a catch-all,
  so a new page needs no migration, no Ruby and no deploy. What needs Liquid is a
  *layout* that is not "bands of columns of blocks" — a gallery, cards, a two-up
  comparison.
- **`Block::KINDS` stops being a Ruby constant.** If a kind is "a template named
  `block/<kind>` exists", a SuperEditor can add a `scripture_quote` type by
  writing one Liquid template. Tier 2 shrinks again.

## The workflow, in detail

1. **Editor signs in** with Google.
2. **Starts editing.** The system checks the lock, creates a `draft` revision based
   on the published one, copies ~300 rows, holds the lock. Sub-second.
3. **Describes a change.** The request carries their session and the revision id. A
   background job calls the model with tools **scoped to that revision** —
   `add_block`, `move_block`, `update_block`. Production is untouched throughout.
4. **Previews** at `/preview/:id`. Client-side checks run at 390px and 1280px.
5. **Uploads a photograph.** Stored at once as a `draft` asset with no consent
   record. Named at finalisation.
6. **Closes the laptop.** Nothing is "saved" because nothing was ever unsaved —
   every turn already wrote rows.
7. **Returns tomorrow** and resumes. **This is the part easy to get wrong:**
   resuming needs the *conversation*, not just the rows, or the AI cannot resolve
   "move it back up a bit". A `revision_messages` table persists role, content and
   tool calls per turn. Without it the feature works on day one and is useless on
   day two.
8. **Submits for review.** Lock stays held so nothing shifts under the reviewer.
9. **Approver sees four things:** the plain-language change log, the preview, each
   new photograph individually for consent, and the check results.
10. **Approves.** One database transaction: revision published, previous
    superseded, draft photographs published with consent records, approver and
    timestamp recorded, lock released.

### Approval is a transaction, not a deployment

An earlier draft of this document said "approval is deployment". That is true only
for tier 2. **A tier-1 publish is a pointer flip** — instant, no build, no wait.
Rollback is flipping back, and any revision can be made live again, forward or
back, like checking out a tag.

One sharp edge: blocks reference photographs by `human_name` and
`LegacyAsset.current` returns the newest published one, so **rolling back content
does not roll back a photograph that was swapped since.** Pinning asset ids in
revisions would fix that, at the cost of the "replace a photo without touching any
page" property that was deliberate. Not decided.

### Git is not in the approval path

Committing on every approval was considered and dropped. It buys little — the
audit trail is already in the database, reviewers look at the preview rather than
diffs, and recovery comes from revisions — while costing git credentials on the
server, push-failure handling, and the question of whether a failed push rolls back
an approval.

The decisive argument: **it would make publishing depend on GitHub being
available.** Tier 2 already cannot ship during a GitHub outage; there is no reason
to extend that to the 95% case for a record we already hold.

Instead, **export-to-git is an on-demand action** that turns the database into
ordinary Rails files — a standard application someone else could host. It is the
exit hatch, not the workflow. Build it when it is wanted.

### Two rules that must not be forgotten

- **The lock is what removes merge conflicts entirely.** One editor, one revision,
  and approval requires the lock, so two people can never diverge from one base.
  That is the whole reason to accept its inconvenience.
- **Once this ships, deploys must stop re-seeding content.** `db/seeds/content.rb`
  loads `content.yml` and prunes orphaned pages. With the database authoritative, a
  re-seeding deploy would silently revert every parish edit since the last export —
  and it would look like a bug in the CMS rather than what it was. The seed becomes
  bootstrap-only, for an empty database.

## The admin is an API; the browser chat is one client

A developer must be able to drive the AI admin from wherever they happen to work —
a Mac, someone's Linux box, a Codespace. **Tier-2 environment choice is the
developer's, not the architecture's**, so nothing here is designed around it.

What that *does* require is that the capabilities are an authenticated HTTP API,
with the browser chat as one client of it. A CLI is another. Claude Code on a
developer's machine is another, plausibly over MCP. Pointing any of them at a local
application or at production is then a difference of base URL and token.

Build the chat UI first and extract the API later and the tools end up tangled in
controller and session code, and the CLI never happens. This is the part that
cannot be retrofitted cheaply, so decide it before anything is written.

Authorisation lives in the API rather than the UI — not to constrain SuperAdmins,
who are repository collaborators with deploy access and nothing to circumvent, but
so an Editor's token grants Editor permissions whatever client it arrives from.

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

### Where these actually run

Not on the server, at least not first. The web service is on Render's **starter**
plan (512MB) using the native Ruby runtime; headless Chrome needs 300–500MB for a
single page on top of Rails and **will not run there**. It would want a larger
instance and probably a Docker runtime.

Two things make that less limiting than it sounds.

The tooling already exists — `reference/current-site/capture.mjs` drives Chrome
over CDP with no npm dependencies and already does device-metric emulation and
screenshots. It simply runs locally today.

And **most of these checks need no server-side browser at all.** The preview
renders in the editor's own browser, and overflow, nav reachability, contrast and
content presence are DOM measurements — `scrollWidth > clientWidth`, computed
styles, element boxes — doable from injected JavaScript in the preview frame at
several widths. That catches the mobile-menu class of bug, which was an *assertion*
failure rather than a visual-diff one. No infrastructure, no cost.

So: client-side assertions first; a separate worker with Docker and Chrome later,
only if screenshot diffing proves worth paying for.

**Rule one option out now:** no third-party screenshot service. Drafts contain
unreleased announcements and photographs of children, and sending those to an
external API crosses the line this project has held everywhere else.

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

## The acceptance test: replay the whole site through the admin

The claim this document makes is that the parish can run its own website without a
developer. That claim is **falsifiable**, and there is an obvious way to test it.

Once the admin works:

1. **Roll the site back to the original Google Sites clone** — the look it had when
   Phase 1 finished. With the revision model this is not a revert at all, it is
   publishing the first revision.
2. **Keep every Ruby widget** already built: the ChurchTrac calendar mirror, the
   lectionary and class-recording importers, the block renderers behind
   `upcoming`, `calendar`, `lectionary` and `classes`. Those are tier 2 by
   definition and are not what is being tested.
3. **Redo every change made since, through the AI admin only**, on a development
   machine, with no developer intervention of any kind.
4. **Watch where it fails**, and fix the admin rather than the content.

The target is unambiguous — the site as it looks today — and the work is real
rather than invented: **62 commits, of which 34 touched content and 16 touched
views or stylesheets.** Service times moved above the hero. Live-streaming removed.
The Miter Ceremony page retired. Address and phone turned into links. Giving
restructured into "Financially Support" and "With your time and talent", with 1 Cor
15:58 and eight ministries. Clergy titles corrected. Mobile menu rebuilt. The
leadership page reorganised. Hero sizes changed. Nav restructured so About Us
behaves and Events gets a calendar tab.

### Why this is the right test

Every failure is informative in a way guessing is not. **Each thing the AI cannot
do is a missing capability, named precisely**, and the list that comes out is the
real tier-1 scope rather than one we imagined at a whiteboard. Some will be content
(rows, should already work), some style (the `theme_assets` layer), some structural
(new pages, nav order), and some will turn out to genuinely need Ruby — which is
itself the answer to "how big is tier 2, really?"

### Two cautions

**Judge the outcome, not the method.** These changes were originally made by a
developer with full repository access, sometimes in ways a constrained system
cannot reproduce. If the AI reaches the same visual result by a different route,
that is a pass, not a workaround.

**Some of it may legitimately be out of scope.** The favicon is files in `public/`,
not database rows; a new block *kind* may need its renderer before it can be
placed. Deciding deliberately that something is tier 2 is a valid outcome. Quietly
doing it by hand and counting it as a pass is not — that is how a system gets
declared finished while still needing a developer.

## What this changes about Phase 2

0. **Build the revision model first** — `revisions`, a `revision_id` on the content
   tables, a `/preview/:id` route and `revision_messages`. Content-only, no Liquid
   store, no template system. Pages, sections and blocks are *already* rows, so
   this is small, and it puts a working conversational editor in front of the
   parish long before the rest of the architecture is finished.

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
