# What the admin can do without a developer

**Status:** Draft for discussion, v0.1 — 2026-10-10
**Companion to:** [`../IMPLEMENTATION-PLAN.md`](../IMPLEMENTATION-PLAN.md)

Derived from a walk through every page of the current site, plus the features a parish
site plausibly grows into. The question throughout: *what must exist in the Rails app so
a non-technical parishioner can build these pages, and where do we stop generalising?*

---

## The principle

**Generality lives in a small toolkit. Everything shaped gets coded once, then handed
over.**

Leadership is the worked example. We do *not* build meta-tooling that lets an admin
define a "person" type with fields and generate its own admin screen. We code the
Leadership page and its admin form, with no content in it, and the parish fills it
forever after. That is one afternoon of developer time instead of a quarter spent
building a worse Squarespace.

The same line applies to Contact. Squarespace lets you assemble an elaborate contact
page from form widgets. We hard-code the page and let the admin change the text and the
details. The parish gains nothing from the extra freedom and loses a page that cannot
be broken.

**The test for anything proposed below:** would a developer touching this once, ever,
be cheaper than the tooling that avoids it? Usually yes.

---

## Layer 1 — The toolkit

Everything here is usable by a parishioner with no developer involved. This is what has
to be built for *any* of the specialised pages below to be worth having.

### Pages

| Capability | Notes |
|---|---|
| Create a page from a template | Template chosen at creation, not assembled from scratch |
| Delete / unpublish a page | Unpublish should be reversible; delete should be rare |
| Edit the hero | Title, subtitle, background photo, tall or standard |
| Add, edit, reorder, remove blocks | Heading, subheading, text, image, gallery, button, embed, spacer |
| Arrange blocks into columns | One, two or three columns per section — not free positioning |
| Choose a section band | White, light grey, maroon — the three the site already uses |
| Set the URL | With a sane default from the title |
| Place in the navigation | Parent and position, including as a child of an existing page |
| Move a page | **Must leave a redirect behind automatically** — see below |

### Media

| Capability | Notes |
|---|---|
| Upload photos | Resized automatically; no manual cropping tools |
| Required consent answer | "Does this contain identifiable children?" asked at upload, every time |
| Alt text | Prompted, for an older parish and for search |
| Replace a photo | New version under the same name; the page is not touched |
| Reuse an existing photo | Pick from what is already there rather than re-uploading |
| See where a photo is used | Before anyone deletes one |

### Review and timing

| Capability | Notes |
|---|---|
| Draft, submit, preview, approve or reject | Rejection carries a comment — a silent "no" loses volunteers |
| Preview exactly as it will appear | Not an approximation |
| Start and end dates, both optional | No start = live on approval; no end = until pulled |
| Version history and rollback | Every published version recoverable |
| Audit log | Who changed what, when, who approved |

### Site-wide

| Capability | Notes |
|---|---|
| Settings | Parish name, address, email, phone, affiliation line, service times — **used in many places, edited in one** |
| Footer and navigation labels | Global chrome, not page content |
| Alert banner | With an expiry date. Snow closures, schedule changes |
| Theme: colour palette | A curated set of named roles, not an arbitrary colour picker |
| Theme: font menu | An admin curates the choices; editors pick from them |

### Housekeeping

| Capability | Notes |
|---|---|
| Site search | **The current Google Sites header has search. Losing it is a regression** |
| Redirects | Created automatically when a page moves; manually editable |
| Staleness report | Pages untouched for six months. Makes neglect visible |
| Users and roles | Editor, Approver, Admin. Invite and deactivate |
| Analytics | What people actually open — evidence for later decisions |

---

## Layer 2 — Specialised resources

Each is a model, an admin form, and a template: **developer work once, parish-managed
forever.** The layout is not the parish's problem; only the content is.

Priority is about sequencing, not importance. "AGM" means wanted for the November
demonstration.

| Resource | What the admin manages | Effort | Priority |
|---|---|---|---|
| **People** | Name, role, photo, bio, order, active | S | **AGM** |
| **Events + albums** | Title, dates, description, photos | M | **AGM** |
| **Synced calendar** | Nothing — pulled from ChurchTrac, with a manual refresh | M | **AGM** |
| **News / announcements** | Title, date, body. *Not* an event | S | Soon |
| **Bulletin** | One record rendering to page, email and PDF | L | Soon |
| **Sermons / media** | Synced from the YouTube channel | M | Soon |
| **Ministries / groups** | Same shape as People | S | Soon |
| **Rotas** | Person, role, date — readers, servers, coffee hour | M | Later |
| **Daily readings / saint** | Synced from OCA | M | Later |
| **Prayer requests** | Submitted by parishioners, moderated | M | Later — see risks |
| **Members-only area** | Accounts, directory, minutes, reports | L | Later — see risks |
| **Designated giving** | Named funds, campaign progress | M | Later |

Three of those are the same pattern — **dated records with people and photos attached.**
People, Events, Ministries and Rotas are one piece of machinery wearing four hats. Build
it once and most of the list becomes configuration.

### The ones that are pages, not resources

Coded templates with admin-editable text. No resource, no collection.

- **Contact** — fields bound to Settings, plus page-specific text
- **Visiting us / what to expect** — the highest-value page for an inquirer, and the
  parish already wrote it (there is a PDF, *"Some Basics on What to Do When You're in an
  Orthodox Church"*)
- **Sacraments and life events** — how to arrange a baptism, wedding, funeral
- **Directions and parking** — probably folded into Contact

---

## Layer 3 — Deliberately not generalised

Stated so it does not get relitigated every time someone sees a feature elsewhere.

- **No meta-admin.** No UI for defining new content types. New shapes mean a developer,
  once.
- **No raw HTML or CSS editing.** Not by editors, not "just for admins".
- **No per-page style overrides.** Styling is site-wide. Restyle once, every page
  follows — the property that stops eleven pages drifting apart.
- **No free-positioning canvas.** Blocks in columns, not drag-anywhere. A volunteer
  should not be able to produce a broken page.
- **No form builder.** Forms are coded. The contact form is not a feature the parish
  assembles.
- **No arbitrary colour picker.** A curated palette with named roles.
- **No in-browser template editing.**

Every one of these is a thing Squarespace does and we are choosing not to. The reason is
the same each time: **constraint is what makes review meaningful and what keeps the site
from decaying.** If an editor can only change a heading, a paragraph or a photo, then
Fr. David can see at a glance what changed, and nobody can wreck a layout from a phone.

---

## Risks worth flagging before anyone commits

**Prayer requests** publish health information about named people. Most parishes do it;
most have not thought about it. The same reflex as photo consent applies — who agreed,
and does it ever come down.

**A members-only area** means accounts, authentication, and the most sensitive data the
parish holds in one place. Valuable, and the clearest answer to the survey's "keeping in
touch with the parish community" — but a materially larger undertaking than anything
else here, and not a November project.

**Page moves without redirects** silently break every inbound link — search results, the
printed bulletin, a QR code on a flyer. The damage is invisible to whoever caused it.
This is why redirects are in Layer 1 and not an enhancement.

---

## Suggested cut for November

Not a plan, a starting point for one. The AGM has to demonstrate *a process*, not a
feature list.

**In:** page editing with blocks, media with the consent question, the full review
workflow with preview and comments, start and end dates, People, Events with albums,
the synced calendar, Settings, and the alert banner.

**Out, and say so plainly:** theme editing, search, bulletin, sermons, rotas, members
area, prayer requests.

The demonstration that matters is one change going from a parishioner's hands through
Fr. David's approval to the live site, in front of everyone. Everything above is in
service of that minute.
