# AI as admin — the editing model for Phase 2

Status: **built and running locally, 14 October 2026.** The sandbox, the Liquid
template store, the tool surface and the chat all work; the site is rendered from
database templates. Not deployed — the admin refuses to serve outside development.
This supersedes the "minimum CMS" sketch in `IMPLEMENTATION-PLAN.md` — see
[What this changes](#what-this-changes-about-phase-2) at the end.

---

## The Problem

The survey indicated several problems including accuracy, and freshness of the information on the site.
Currently the site contains photos that are years old, lists people that have died as current church
leaders, and pages on activities that we no longer participate in.  It does not have any information
on important events like the weekly video classes.

The reasons that the site had gotten stale was threefold:  First, it required some expertise using
Google Sites.  Second, it was easy to break something, and difficult to recover.  Both these
things led to reluctance to update the site.  To compound this volunteers to update the site rotate in
and out, and have little time to spend updating the site.

## The Solution

As a first step we converted the existing site to a new Ruby-on-Rails application, while leaving the
existing site in place.  Once we had a RoR site up in development, we began updating the site: 
cleaning up the styling, adding new pages, and features, updating photos.  

All the cleanup was done by chat interaction with Claude code.  Changes would be requested, and Claude
would update the site, and further adjustments could be made.

It then occurred to us that instead of building a more traditional set of form based CMS tools for ongoing site
maintenance, we could just provide an AI chat interface as the means to make changes to the site.

Changes would be made in "sandbox" mode ensuring that revisions to the site could be previewed and approved
before being updated to production.  Furthermore the AI would not access or change any ruby code.  If such changes
were needed (which happens even the best CMS systems) these would be made in the normal manner, within a code
development environment.  However the goal is to minimize such changes.

UI assets (html, javascript, stylesheets) would all be stored as database records, and any changes or additions
would be new records.

The whole of the site is thus under version control, so nothing is ever unrecoverable.

Editors can update the site, play with different improvements easily and without worrying about hurting the current site.

Once a Revision is ready it can be marked for approval by an "Approver"


---

## Roles

| role | granted by | can |
|---|---|---|
| *(none)* | self-registration | authenticate, and nothing else — **cannot see drafts** |
| Viewer | Approver | view sandboxes, comment |
| Editor | Approver | create and edit a sandbox — content, templates, styles, photographs |
| Approver | **SuperAdmin only** | approve and publish; manage users up to Editor |
| SuperAdmin | GitHub | everything, including Ruby, routes, migrations, and the Liquid drop surface |

**Login is OAuth.** Google for most people, so they use the account they already have.
**SuperAdmin is GitHub**, and specifically requires being a collaborator on the site
repo — so there is one source of truth for who holds the keys, and removing someone
from the repo revokes their access automatically. (Cache that check with a TTL, so a
GitHub outage does not sign a SuperAdmin out mid-session.)

**There is no SuperEditor tier.** An earlier draft had one, gating theme and template
changes separately because they affect every page. It was removed on review for a
good reason: *everything goes through approval anyway*, so a second permission tier
added friction without adding safety. Blast radius still matters — but for deciding
**what to test**, not **who may act**. See the review checks below.

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

**Photographs are the exception and are never copied.** `photos` is ~32MB
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
| `photos` | photographs, already append-only |

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
  `block/<kind>` exists", an Editor can add a `scripture_quote` type by writing one
  Liquid template. The work a developer has to do shrinks again.

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

**Show who holds the lock, with their email and phone number**, so a waiting editor
can simply ring them. A lock whose holder is anonymous turns a thirty-second
conversation into a support request. The timeout is settable by a SuperAdmin and
defaults to **one day**; a SuperAdmin can also steal a stale one.

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

### How this relates to Claude Code

They are **not the same thing**, and the difference is the whole security story.

*Claude Code* — what built this site — is a CLI agent on a developer's machine with
a shell and the filesystem. That is appropriate for a developer and completely
inappropriate for a server-side admin reachable by a parish volunteer.

*The admin AI* is a call to the Anthropic API from the Rails application, with a
**fixed set of tools that are Ruby methods** operating on revision rows. No shell, no
filesystem, no `eval`. It cannot write code because nothing in its tool surface can.

But yes to the important half of the question: **the system prompt and the tool
definitions are part of the codebase**, versioned and reviewed like any other source,
and a developer inherits them. Tuning the admin's behaviour is a pull request.

And the two meet: because the admin is an API, a developer *using* Claude Code can
drive it — same tools, same approval path, different client.

## What the AI may change

**The AI can only create new records of types that already exist.** That is the whole
rule, and it is simpler than the tiered model an earlier draft proposed.

It writes rows: pages, sections, blocks, templates, theme assets, settings,
photographs. It creates new versions rather than editing in place, so nothing is
destroyed. It cannot add a *type* and cannot touch Ruby — not because it is
forbidden to, but because no tool in its surface does those things.

### Outside data, and why four drops became one primitive

*17 October 2026. Mitch's call, and the best correction the design has had.*

There were four drops reading mirrored data: `site.calendar`, `site.upcoming`,
`site.recordings`, `site.lectionary`. Each was written by a developer, and each
encoded a judgement about what was worth showing. `site.upcoming` left out every
regularly scheduled service, on the reasoning that nobody needs telling Vespers
is on Saturday again. Defensible. But the AI was told only that it meant
"notable events in the coming week."

So when asked for the next seven days on the home page, it built a box with **no
Vespers and no Divine Liturgy in it** — the two things a visitor most wants —
added a string-accumulator hack to deduplicate events that seemed to repeat, and
guarded the whole thing on a different list than it looped over. Three symptoms,
one cause: it was arguing with a filter it could not see, and no amount of
intelligence would have found it.

**The lesson is not "document the drops better."** It is that a judgement
embedded in Ruby is a judgement the editor cannot read, cannot question, and
cannot roll back. The drop was the wrong *shape*, not badly described.

All four are gone. In their place, one primitive:

```
DataSource        a revision row: a name, and one or more https addresses
Site::OutboundFetch   the guarded fetch — the only place this app reaches the
                      internet on behalf of something the AI wrote
FetchedPage       the cache, keyed by URL, shared across revisions
site.data.<name>.json_tag   writes the payload into the page as
                            <script type="application/json">
```

Everything after that is JavaScript and CSS written through the admin. What
"upcoming" means is now a line of code in the revision, where it can be read,
argued with, and reverted.

This cost something, and the cost is worth naming. A drop that wrongly excluded
the services was invisible and wrong. A script that wrongly excludes them is
visible and **still wrong**. The gain is reviewability, not correctness. The
thing to watch in review is whether a mistake of that kind gets caught, or
whether code being present gets mistaken for code being right.

**Reaching the internet is a real escalation, and it is guarded as one.** The
URL arrives from a conversation and the request leaves *our* server, inside
Render's private network, where `169.254.169.254` is the cloud metadata endpoint
and `localhost:5432` is the parish database. So: HTTPS only; every address the
host resolves to checked against the private, loopback, link-local, carrier-NAT
and reserved ranges; **re-checked after every redirect**, because a public URL
may redirect to `127.0.0.1` and that is the bypass people actually ship; no
cookies and no credentials; size and time caps; text and data types only. There
are 17 specs, one per attack.

The list of permitted domains is deliberately **open**. An allowlist would have
to be maintained by a developer, which reintroduces exactly the dependency this
removes. Instead the first fetch from an unfamiliar domain is named on the
approval screen: *"This change fetches data from example.com for the first time
— worth checking with whoever looks after the technical side."* A new outbound
connection is never invisible to the person saying yes to it.

**What it does not yet cover.** The payload reaches the page as raw bytes. A feed
serving JSON works today, verified against ChurchTrac. A source serving HTML —
the YouTube playlist, the oca.org readings — needs parsing before there is JSON
to hand over, so those two importers stay for now. See `docs/TODO.md`.

### Seeing the page

*Same day, and the other half of the same failure.*

Asked to put a week's events on the home page, the AI appended a band at the
bottom of the page. It belonged beside the welcome text. Nothing was *broken* —
no sideways scroll, no overlap, no unreachable menu item — so every check
reported success. It simply looked wrong.

It could not have known. `check_appearance` drove a real browser, took the
measurements, and threw the screenshot away; tool results went back as JSON
text, so an image could not have reached the model in any case.
`Anthropic::Client.image_block` had been written for exactly this and never
called. The AI had never seen the website.

It does now, at 390px and 1280px, for about 2,460 tokens a look. Asked to
describe the home page it reported the gold vestments in the hero, the
green-robed icon, the script lettering, the two-column photo grid, and that the
upcoming box sits on the right at desktop width and moves below on a phone. None
of that is in the findings list.

Worth separating two explanations that were both available for the footer
mistake. One is "the model is not clever enough." The other is "it was working
blind, on a twelve-step budget, with tools that made appending cheap and
restructuring expensive." The second was true, and fixing it was a day's work.
Reach for that one first.

### Image processing, and why "no subprocess" was the wrong rule

An earlier draft said the AI could reach no program at all. That was the easy
answer rather than the correct one, and it gave up something genuinely useful:
the image work — crops, feathered edges, format conversion — was among the more
valuable things done by hand on this site.

**The danger was never ImageMagick. It is four specific things, and each closes
separately:**

1. **Shell interpolation.** Closed by never building a command *string*.
   Processes are spawned with an argv array, so there is no shell to inject
   into — no quoting bugs, no `;`, no backticks.
2. **Filesystem reach.** Closed by the AI never naming a path. It names
   *photographs* and *operations*; the paths are ours, in a temp directory we
   create and destroy. It cannot express a path, so it cannot traverse one.
3. **Network exfiltration.** ImageMagick will read `https://…` as an input
   file. `config/imagemagick/policy.xml` refuses that, along with the delegates
   and coders behind the ImageTragick family of bugs.
4. **Runaway work.** A wall-clock timeout, an output size cap, and pixel and
   memory limits in the same policy file.

So the rule is not *"the AI may not run programs"*. It is **"the AI may run three
known programs — ImageMagick, rsvg-convert, potrace — with validated arguments,
on files it cannot name, in a directory it cannot leave."** That is a boundary
enforceable in code rather than by good intentions, and
`spec/services/admin/image_tools_spec.rb` is that boundary written down: shell
metacharacters, path traversal, URL inputs and format allowlists each have a
spec that fails if the firewall slips.

Output is always a **new** photograph row, never an overwrite, so an unfortunate
crop is undone by publishing the previous version.

Where the line still holds: **no general shell.** Image processing has a bounded
shape — images in, images out, a known vocabulary. A general shell has no shape,
nothing to validate against, and no way to say what it may not do.

So there are exactly two ways the site changes:

1. **Someone talks to the AI**, which writes records, which an Approver publishes.
2. **A developer commits code**, which is reviewed and deployed in the normal way.

There is no third path and no tiered permission gate. Everything in route 1 goes
through the same single approval step regardless of how much of the site it touches.

### Image tools

Photographs are records too, so the AI needs real tools for them: **crop, resize,
rotate, adjust, feather or mask edges, convert format, generate the responsive
sizes.** Each produces a *new* `photos` row rather than overwriting — the append-only
rule applies to derived images exactly as it does to originals, so an unfortunate
crop is undone by publishing the previous version.

These are the same operations used throughout this project's own image work
(ImageMagick and librsvg), and they are the difference between an editor being able
to use a photograph and having to ask someone with Photoshop.

### Blast radius still matters — for testing, not permissions

Dropping the permission tiers does not make a change to the header equivalent to a
change on one page. The system knows which pages use which templates and blocks, so
it can compute what a change reaches and **put that in front of the reviewer**:
"this touched the header → all 13 pages → here they are at 390px and 1280px, before
and after." That is the job blast radius does now.

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

Photographs go into the database, as they already do: `photos` is append-only,
keyed by a semantic `human_name`, newest published row wins. During a conversation
uploaded photos are recorded; when the session is finalised the AI proposes names and
the author accepts or changes them.

**The consent table gates this absolutely.** The AI must be unable to place a
photograph of a child on a page without a consent record. Every new photograph is approved
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

### When the AI cannot do something, it should say so in the repository

The AI cannot change code. So when an editor asks for something outside its tool
surface, the right response is not a shrug — it is to **open a GitHub issue**,
quoting the request verbatim and explaining what capability was missing.

That closes the loop between the two routes. The parish's actual unmet needs arrive
as a prioritised list written by the people who hit them, instead of a developer
guessing at what to build next. It is also the honest alternative to the failure mode
this whole design guards against: an editor quietly giving up and the site going
stale again, with nobody knowing why.

Proposing the change as a **pull request** is the natural next step and worth
building once the issue flow is working. It needs code generation and a checkout, so
it is a bigger job than filing an issue — and an issue with a real user's words in it
is already most of the value.

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

The content-presence checks matter most for template changes. A broken theme
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

## Standing promises

Designed 15 October 2026, **built 17 October 2026**.

Writing code, every change comes with a spec. The equivalent here is a **standing
promise**: something about the site that should remain true after the next
change, and which a person cannot be relied upon to re-check every time.

Not every verification deserves to become one. The test is: **would a future
change that breaks this be a bug, or a different choice?**

| | |
|---|---|
| "the home page shows the service times" | breaking it is a bug — **keep** |
| "the service times sit above the photograph" | that is what was asked for — **keep** |
| "the heading reads exactly *Financially Support*" | rewording is legitimate — **do not keep** |
| "the heading is 2.2em" | a styling decision someone may revisit — **do not keep** |

### What a promise is made of

Four things:

1. **An id.** Promises are immutable; changing one means creating a new one.
2. **A short summary**, shown on the approval screen.
3. **The full intent in plain language**, revealable there, and read by the AI
   when it has to judge a failure.
4. **A script** that checks it, which runs *without the model*.

The AI writes it in that order: understand the intent in language, compile it to
a script, prove the script works, then condense the summary.

Splitting intent from execution is what makes this affordable. The script is
free to run, so promises can be checked every turn. The intent survives for the
moment that matters — when something fails and the question is *"is the site
wrong, or is the promise now wrong?"* The model has both the original reasoning
and the actual check in front of it, which is the only way to tell those apart.

It is the same shape as a remembered command: reason it out once, compile it to
something cheap, keep the reasoning attached.

### The scripts are JavaScript, run in the rendered page

The infrastructure already exists — `script/visual_check.mjs` evaluates
JavaScript inside the real page over CDP. A promise is a script returning
`{ pass, message }`.

Three reasons, in order of importance:

- **The sandbox comes free.** JavaScript in a page cannot reach the server, the
  database or the filesystem. The browser *is* the boundary, so there is no new
  firewall to design — unlike every other "let it run something" decision here.
- **It can see what matters.** Promises can assert on *rendered* output, not
  just markup: whether something is visible, where it sits, whether it is
  reachable without scrolling.
- **It batches.** One page load evaluates every promise for that page.

The alternative — inventing a small assertion language over the markup — is
cheaper still, but cannot see layout and would have to be designed and
maintained. There is no reason to invent a language when a sandbox is already
sitting there.

### The manifest

Promises are immutable rows. **A revision carries a list of promise ids**, copied
forward when a sandbox is opened.

- Adding one appends an id.
- Changing one removes an id and adds a new one, so a diff of two revisions'
  lists *is* the history of what the site promises.
- Removing one drops the id. Nothing is deleted; the promise still exists.

A list rather than a query, for the reason the photograph versions taught us:
a query has to infer intent from ordering, and a branch from an old revision
makes that inference wrong. A list infers nothing.

### Verifying a promise actually promises something

A script returning `true` unconditionally also "works", and a promise that cannot
fail is **worse than none** — it manufactures confidence.

So a new promise is proved twice: it passes **now**, and it fails when the thing
it asserts is **removed**.

`add_promise` enforces the first leg — it runs the script before saving and
refuses a promise that does not already hold. The second leg is currently the
AI's word: it records, in `proof`, what would make the promise fail, and that
sentence sits beside the summary at review.

**That is not good enough, and here is the evidence.** Writing this feature, a
promise was added asserting the parish is named on the home page. The name also
appears in the hero title, so deleting the heading it was meant to protect left
it green. A promise that cannot fail is worse than none, and the first leg
cannot catch it — only actually removing the thing and confirming red can.
Automating that is the obvious next improvement.

### The risk: erosion

The AI both breaks a promise and judges whether the break was legitimate. Each
judgment will be defensible. The danger is not one bad call, it is thirty
reasonable ones: **a removal is the hardest change for a reviewer to notice**,
because "removed a check that no longer applies" reads as tidying.

Two things guard against it. A removal is agreed **with the editor, while they
are editing** — see below — so nobody drops a promise without a person saying yes
with it in front of them. And removals are louder than additions at approval: a
new promise is a line, a removed one names what it asserted and how long it
stood — *"the home page shows the service times, promised since October 2026, is
no longer checked."*

### Where the first ones come from

Nothing creates the initial set. The AI writes promises for changes it makes, so
the site starts with none — yet the ones that matter most were never anyone's
"change": the service times are present, the parish is contactable, the calendar
renders, no page is orphaned from the navigation. Those are seeded once,
deliberately.

### When a promise fails

**It is detected during editing, and settled by talking to the editor.** Not
decided by the AI and caught later by the approver.

The AI does not quietly fix the content, and does not quietly rewrite the
promise. It says what happened and asks:

> You have moved the service times to a Services page. There is a standing
> promise that the home page shows them. Should I update the promise, or did you
> want them on the home page as well?

Whatever is agreed appears in the list of changes at approval — so **two people
see any change to a promise**: the one who caused it, at the moment they caused
it, and the one approving afterwards.

Nothing blocks publishing, and nothing needs to: by the time a revision reaches
approval there is nothing unresolved left in it. The parish must never be unable
to correct a service time because an assertion has gone stale — but that is
settled during the edit, not at the gate.

## The acceptance test: replay the whole site through the admin

**Dn Mitch runs it, as a non-technical user** — which, where the visual design of the
site is concerned, is an accurate description rather than a pretence.

The claim this document makes is that the parish can run its own website without a
developer. That claim is **falsifiable**, and there is an obvious way to test it.

Once the admin works:

1. **Roll the site back as far as it goes** — not to the end of Phase 1 but to its
   *beginning*: the Google Sites clone as first extracted, before any styling or
   content work. With the revision model this is not a revert at all, it is
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
real scope rather than one we imagined at a whiteboard.

### Derive the vocabulary first, then replay

An earlier draft framed this as discovering the gaps purely by running the test. That
is backwards, and the better order is:

1. **Analyse the site as it stands today** and extract the **minimum set of Liquid
   macros** that could reproduce it. Minimum is the point — a large vocabulary proves
   nothing, because anything is reproducible given enough bespoke templates.
2. **Dn Mitch reviews that set before the replay begins.** If it is not
   comprehensible to him on paper, it will not be usable by a volunteer in practice,
   and that is worth finding out before any code is written.
3. **Then replay**, and treat every "that needs a code change" as **an ordinary bug**
   — fixed the way it would be fixed a year from now: a code change, reviewed,
   deployed. Not a failure of the test, just the second route working as designed.

That last point matters for how the result is read. The test is not "did the AI
manage everything?" — it is **"is the set of things needing a developer small,
comprehensible, and shrinking?"**

The consequence worth stating plainly: **this defines what must already exist in the
site before the replay starts.** Anything that cannot be reproduced by writing
database rows has to be pre-implemented. Working that list out *is* the design of
tier 1.

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

0. ~~Build the revision model first.~~ **Done.** `revisions`, `revision_id` on the
   content tables, `/preview/:id` as a session flag, `revision_messages`,
   `templates` and `theme_assets`. The site renders from Liquid stored in the
   database; 12 of 13 pages were verified DOM-identical to the ERB they replaced.

1. **Tests are a prerequisite, not a nice-to-have.** The repo currently has none. The
   template layer and refactoring are both unsafe without them, and the automated
   checks above are the same machinery. Build this first.
2. **The content model matters more than the editor UI.** `Block::KINDS` is already a
   bounded vocabulary with typed fields and a real grid — that is the hard part and it
   exists. Getting the vocabulary right beats building forms.
3. **Adopt Liquid for page bodies and block templates**, and design the drop surface
   deliberately.
4. **Build the revision/sandbox model and the approval audit trail** before any AI
   wiring. The AI slots into the *draft* stage of a flow that must work without it.

## Open questions

**Settled on review:**

- *Invites.* For now a SuperAdmin adds people and sets roles by hand. A self-service
  invite flow can wait until there is anyone to invite.
- *Locks.* Timeout is settable by a SuperAdmin, default **one day**, with a SuperAdmin
  steal. The lock screen shows who holds it, with their email and phone number.
- *The Liquid drop surface is Ruby* — so yes, the only way to change it is a developer
  editing code and committing. That is exactly why it is the load-bearing security
  decision: it is the one boundary a template author cannot move.

**Still open:**

- *(none from this review — `legacy_assets` was renamed to `photos` on 14 Oct 2026.)*
- **Make `owner/repo` a config value** before the SuperAdmin check is written, so it
  is never hardcoded. (The organisation move itself is **done** — the repository is
  now `SJOCA-ORG/sjoca-website`. The org's 2FA requirement is still permissive; see
  above.)
