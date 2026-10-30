# One app, many organizations

How this app serves more than one website, and what keeps one organization's
data away from another's. Written 27 October 2026, when the second one was still
hypothetical and the first one's data was all there was to get wrong.

---

## What an organization is

Whoever a website belongs to. **Not a parish** — a parish is one thing an
organization can be, and a club, a school or a shop are others. Nothing in Ruby
knows which. What an organization *is* lives in its own settings, templates,
photographs and lessons, as rows it can edit. That rule predates multi-tenancy
(see [`primitives.md`](primitives.md)); tenancy is what makes it load-bearing
rather than tidy.

```
organizations        name, slug, active, canonical_url,
                     contact_name, contact_email, time_zone, locale, product
organization_hosts   one hostname -> one organization, host UNIQUE
```

**The account's facts, not the website's.** The website's own name, address and
email are `site_settings`, scoped to a revision, so they version with content and
revert with it. These must not: an organization can roll back its pages, but it
cannot roll back out of who owns the account or which clock its dates are in.

| | |
|---|---|
| `contact_name` / `contact_email` | who we write to about the account, and the reply-to on account mail when the website publishes no address of its own |
| `time_zone` | `Time.zone` for the request. `config.time_zone` is `America/New_York` — one organization's clock applied to everybody's dates |
| `locale` | `I18n.locale` for the request |
| `product` | which organization is this tool's own site. Exactly one, enforced by a partial unique index as well as a validation |

Every one of those has a consumer from the day it landed. A column nobody reads
is the `Site::Seo.coordinates` mistake — a field documented in a TODO list,
wired to nothing, which somebody fills in and reasonably believes is working.

Hosts are a table because every organization has several from the day it starts
— apex, `www`, whatever the platform calls it — and because a hostname must
belong to exactly one organization. That is a unique index, not a convention:
two organizations both claiming `sjoca.org` is not a disagreement to resolve at
request time.

---

## The two halves

**One: the hostname decides.** `OrganizationScoped` runs before everything else
in `ApplicationController` — before the revision is chosen, before the login is
checked, because `Revision.live` is itself scoped and answers nothing until an
organization is set.

**Two: every query filters.** `BelongsToOrganization` adds `belongs_to` and a
`default_scope`, and sits on the six root tables:

| | |
|---|---|
| `revisions` `photos` `tags` `promises` `lessons` `fetched_pages` | scoped directly |
| `pages` `sections` `blocks` `templates` `theme_assets` `site_settings` `data_sources` `revision_promises` `revision_messages` | scoped through their revision |
| `photo_tags` | reached only through a photo, which is scoped |
| `organizations` `organization_hosts` `users` | global, each for a written reason |

Six columns, not thirty, because the content tables already hung off a revision.

**Why a `default_scope` and not a `where` in every query.** There are 67 admin
tools, a Liquid renderer, a photo library and a dozen controllers. Auditing each
for a missing filter is a job with no end and no way to prove you finished.
Putting the filter underneath them all is one decision somebody can review.

It holds on one condition: **nothing in `app/` reaches past ActiveRecord.** No
raw SQL, no `find_by_sql`, no `unscoped`. That was true when this was written and
`spec/requests/nothing_bypasses_the_organization_scope_spec.rb` fails if it stops
being true.

---

## Fail closed

**With no organization set, the scoped models return nothing.** Not the first
organization, not everything — nothing.

A job, script or controller that has not said which organization it means gets an
empty result. So the failure is "nothing is here", which gets investigated, and
never "here is somebody else's", which does not.

The one convenience: `Current.organization` falls back to the only organization
**when there is exactly one**. That keeps the console, the seeds, every rake task
and a single-organization install working without each of them announcing who
they are — and it stops the moment a second organization exists, which is the
moment being forgiving would start being dangerous.

To mean a specific one deliberately:

```ruby
Organization.acting_as(org) { Photo.count }
```

Long and ugly on purpose. It is the only sanctioned way past the scope, and it
should read like a decision in a diff.

---

## Users: authority and reach are different questions

```
role              what you may do INSIDE an organization   ("superadmin")
application_admin WHICH organizations you may act in       (everyone's)
organization_id   where you belong; null for an operator
```

A check constraint in the database, not a validation:

```sql
CHECK (organization_id IS NOT NULL OR application_admin)
```

A user with neither would see nothing and be a puzzle to debug.

**`User` is the one model with no `default_scope`**, because signing in happens
before a hostname has been resolved to anybody, and an application admin belongs
to no organization at all. `User#may_act_in?` does that work instead, and
`Authentication#current_user` calls it on every request — so a valid session
cookie carried to another organization's hostname signs you out rather than in.

Email is unique **system-wide**: one person, one login, whoever they work for.
Enforced by `index_users_on_lower_email` and not by a validation, so creating a
duplicate raises `RecordNotUnique` from the database rather than
`RecordInvalid` from Rails.

An application admin sees **one organization at a time** — the one whose address
they are on. There is no view of everybody's data at once, which is what makes
the access reviewable.

---

## The gotcha that would have shipped

**Rails' uniqueness validator ignores `default_scope`.**

```
activerecord-8.1.4/lib/active_record/validations/uniqueness.rb:113
  relation = klass.unscoped
```

Deliberate on Rails' part, and quietly fatal here. Four validations were
checking uniqueness across every organization in the system:

```
Photo#version   scope: human_name              -> + organization_id
Photo#sha256    scope: human_name              -> + organization_id
Tag#name        scope: (none)                  -> + organization_id
Lesson#body     scope: subject                 -> + organization_id
```

The symptom is not a crash. It is a second organization being told its
photograph name is already taken — which is wrong, and which answers a question
about somebody else's data that nobody should be able to ask.

`spec/models/uniqueness_is_scoped_spec.rb` now audits every uniqueness validator
on every scoped model, so the next one cannot slip through.

---

## The three guards

| Spec | What it refuses to let happen |
|---|---|
| `spec/models/every_table_belongs_to_somebody_spec.rb` | A new model that reaches no organization by any stated route. Four routes; pick one and say which. |
| `spec/models/uniqueness_is_scoped_spec.rb` | A uniqueness validation that runs across organizations. |
| `spec/requests/nothing_bypasses_the_organization_scope_spec.rb` | `unscoped`, raw SQL, a stray `default_scope`, or reassigning `Current.organization` outside the three places that may. |
| `spec/requests/organization_isolation_spec.rb` | Any of it actually leaking. Two organizations, real requests, every surface a stranger can reach. |

The first three read the source and the schema. That is unusual and deliberate:
the failures they catch are not behavioural. **The app works perfectly with one
organization right up until somebody else installs it**, which is exactly when
nobody is looking.

---

## The product's own site, and why it matters

The plan is an organization called **ai-site-builder** whose website advertises
this tool, built with this tool, from a starter, by conversation. Its slug is the
only thing special about it; `organizations.product` decides where the operator
console answers and who owns the "not configured yet" page, and nothing else
about it gets a code path. If it needs one, the architecture is wrong.

It is not a vanity exercise. **"No semantic knowledge in Ruby" is unfalsifiable
while the only site in existence is a church.** The moment the same code builds a
software marketing site, the claim is demonstrated rather than asserted, and
every gap in onboarding is felt by us before a customer finds it.

Two rules that fall out:

- **The operator console answers only on the product organization's hostnames.**
  An application admin signing in on a customer's domain should be rare and
  audited; making it impossible except from our own host is better than logging
  it.
- **An unrecognised hostname still does not serve the marketing site.** Tempting
  — it is only marketing, not customer data. But a customer whose DNS is
  half-configured would be showing their visitors our sales page, which is worse
  for them than an error. Unknown host gets a plain, product-owned "this site is
  not configured yet" page.

---

## A website as files: `WebsiteArchive`

One primitive, two jobs. The sample sites live in git as archives — that is how
a fresh deployment gets its starters, photographs and all, from the repository
and nothing else. And any organization can take an archive of itself and keep
it wherever it keeps things.

A **directory**, not a tarball, because the sample sites are reviewed in pull
requests: a change to a starter should read as a change to a sentence or a
stylesheet, not as a new opaque blob. `organization:export[slug,dir,archive]`
tars it for anyone who wants one file.

```
db/seeds/starters/trade/
  organization.yml     what to call it, and which clock it keeps
  site.yml             settings, templates, theme, pages, blocks, lessons, promises
  photos.yml           every photograph, by name, with its digest
  photos/hero-v1.png   the bytes, under a name a person can read
```

**What travels is a website.** No users, no hostnames, no contact details, no
canonical address — those belong to an account, and an account belongs to
wherever it is installed. Same distinction as `Revision#copy_into`, for the same
reason.

**Live revision only.** Ten revisions of history is a different feature; an
archive is for moving a website, and a database dump is for undoing an accident.

A photograph whose bytes no longer match the digest in `photos.yml` **refuses to
import**. Somebody edited it by hand, and importing it quietly would hide that.

### Proved on the real site, not only on a fixture

Exported the parish — 261 photographs, 170MB — imported it as a second
organization, and rendered all twenty pages from both. **Twenty of twenty
identical**, once three things are normalised, each a fact about the copy rather
than a loss in it:

| Normalised | Because |
|---|---|
| `data-block="123"`, and `id="thing-123"` | a database id, which cannot be equal for two rows |
| `canonical` and `og:url` | each organization's own address, which deliberately does not travel |
| embedded `application/json` | a data source's **definition** travels; what it fetched a moment ago does not |

The fixture spec had only the first of those and only in `data-block`, so it
passed while three real pages differed. The real site taught the spec, and the
spec now says so.

---

## Starters are organizations

A starter is **an organization with the `starter` flag**, seeded out of
`db/seeds/starters/` by `WebsiteArchive`. Creating a customer's website is
`Revision#copy_into` — a copy of that organization's live revision, photographs
and all.

They were folders of YAML read by an installer. Three things were wrong with
that, and all three go away:

- **A look had to be written by a developer** who knew the block kinds and the
  class names, and could get them wrong twice without anything noticing. Now it
  is built by using the product: asked for in words, previewed, looked at.
- **A starter could not hold a photograph.** There is no way to put bytes in a
  manifest, so `studio` — a starter whose entire premise is showing pictures —
  had none.
- **There was nowhere to look at one.** Each is now live on its own hostname,
  so the chooser links to the real thing and the thumbnail script photographs it
  where it lives.

Six: `plain`, `gathering`, `noticeboard`, `trade`, `studio`, `journal`. Each has
its own stylesheet, its own pages and its own pictures, and diverges freely from
the moment a customer copies it — there is no inheritance and no "update from
starter", deliberately. Somebody who has been editing their site for six months
should not have it reshaped by us improving a template.

`Starters.chosen(slug)` falls back to `plain` rather than trusting a form, and
**raises** if an installation has no starters at all: a blank website looks like
a bug in the editor rather than a missing seed.

### What a deployment arrives with

```
bin/rails db:seed            the six sample sites, and in development two test ones
bin/rails organization:bootstrap[you@example.com]
```

**A production database gets the looks and nothing else** — no customer, no
parish, no data anybody has to be trusted with. Organizations arrive afterwards,
created in the console from a starter, or imported from an archive they brought.

Seeds deliberately create **no people**: a password in a seed file is a password
in a repository. `organization:bootstrap` makes the first application
administrator and prints a link for them to set their own password — the same
invitation a customer's owner gets.

The two test organizations under `db/seeds/test-organizations/` are guarded by
`Rails.env.production?` rather than by a flag somebody could pass. Smoke testing
multi-organization behaviour needs more than one organization, and doing it
against a real customer's site is how a real customer's site gets edited by
accident.

### Every new organization gets the house style

`db/seeds/theme/site.css` — about 30KB, installed as the `site.css` theme asset
by `DefaultTemplates.install!`, and therefore by every starter. A starter's own
`theme.css` is **appended** to it, not substituted for it: half a dozen rules
changing colours cannot stand in for the whole layout.

It is lifted from the first site built with this system and stripped of it —
the rules that named one organization's **pages** (`.page-donate`,
`.page-about-us-choir`, and three more) are gone, because a page slug is the
most organization-specific thing there is. What remains is structure: bands,
blocks, heroes, header, footer, type scale.

There is deliberately **no base `site.js`**. The one that existed was written
for one parish's calendar feed and knew what a vespers was. The navigation works
without it — that is a Stimulus controller served to every organization as part
of the application.

### The failure a starter has, and what catches it

A starter's templates are written by somebody who will never meet the customer,
in files nobody runs until an organization is created. The `gathering` starter's
section template invented its own structure — `section.blocks` instead of
`section.columns`, `{% render 'block' %}` instead of `{% include block.template %}`
— and rendered **every band perfectly with nothing inside it**.

Liquid does not complain about a loop over nothing. The page came out plausible
and 5KB, and every check passed: the templates existed, no block kind was
missing one, the page was well over the "renders three bytes" threshold.

What none of them asked was whether the **words in the starter reached the
page**. `spec/requests/starters_spec.rb` asks that now, of every block of every
page of every starter, and it was confirmed to fail on the original bug before
being kept.

**It happened again, in a different disguise.** Every organization created
through the console came out with no stylesheet at all: Times New Roman, blue
underlined links, no layout. Two faults stacked — nothing installed a base
stylesheet, and `Starter#install_theme` wrote its row under the name `css` while
the app looks for `site.css`, so even a starter's own CSS was never served.

Every check passed again. The pages were 200, the words were on them, every
block had a template. Only a person **looking** at one could tell, and the
person who looked was Mitch, at the chooser's thumbnails.

So the spec now follows the stylesheet link the page gives the browser, fetches
it, and insists it is a real stylesheet with `.band` and `.hero` in it. Both
install paths were disabled to confirm it fails before it was kept.

The pattern is worth naming, because it has now caught this project twice: **a
page can be perfectly correct and still be wrong, and nothing but an eye on the
output will say so.**

---

## The operator console

`/operator`, for whoever runs this app for other people. Two locks, different in
kind:

| | |
|---|---|
| `application_admin` | **who** may be here. A customer's own superadmin is the top of their organization and has no business in it. |
| the product hostname | **where** it answers. An application admin signing in on a customer's domain should be rare, so the console is not reachable from one at all. |

Both answer **404, not 403** — a customer's administrator poking at `/operator`
should not learn whether it exists.

### It lists accounts; it does not show their content

Names, hostnames, how many pages and photographs, when anybody last signed in.
To work inside an organization you **go to it**, which redirects to that
organization's own hostname and writes a row in `operator_actions`.

That redirect is deliberate rather than a session flag that makes the app
pretend to be somewhere else. The hostname decides which organization a request
is for, everywhere else in the app; carving an exception for the one person with
universal access is how an invariant stops being one. The cost is signing in
again on that host, which at this boundary is a feature. (In development every
organization shares `localhost`, so it lands back where it started. A
development inconvenience, not worth a code path.)

### The log

An application admin can act inside any customer's data. That power cannot be
made smaller — somebody has to be able to fix a club's broken page on a Tuesday
evening — so it is made accountable instead. `operator_actions` records who did
what, to whose data, from where: `created`, `invited`, `entered`, `suspended`,
`resumed`.

**It belongs to no organization, and that is the point.** An organization whose
own administrators could read it would be reading other customers' business;
one that could edit it would have a log it can rewrite.

### Creating an organization

One transaction: the account, its hostname, a first published revision with the
default templates, a `name` setting, a home page, an owner, an invitation. All
of it or none — a hostname with no revision is worse than nothing, because the
next attempt collides with the leftovers.

The owner is created with a random password nobody ever sees (`has_secure_password`
insists on one) and sent an **invitation**: the same signed-token mechanism as a
password reset, with a seven-day fuse instead of two hours. Two hours is right
for somebody who has just asked to be let back in; it is wrong for a letter that
arrives while they are away for the weekend.

### Designating the product organization

Chicken and egg: the console answers on the product's hostname, and marking an
organization as the product needs the console. So **while no organization is
marked `product`, the console answers everywhere** and says so in red at the top
of the page.

The bootstrap sequence:

```ruby
# 1. a user who may act anywhere
User.create!(email: "you@example.com", password: "...", role: "superadmin",
             application_admin: true, organization: nil)

# 2. sign in anywhere, go to /operator, create the organization whose website
#    advertises this tool -- through the console, from a starter, by conversation

# 3. then make it the one the console lives on
Organization.find_by(slug: "ai-site-builder").update!(product: true)
```

After step 3 the console stops answering on any other hostname, including this
parish's. Exactly one organization can hold the flag — a partial unique index as
well as a validation, because "exactly one" survives a validation right up until
a seed or a console session sets a second.

---

## Hostnames: the shared domain and a customer's own

An organization has **several** hostnames, and that is why `organization_hosts`
is a table. The two kinds arrive at different times and do different jobs.

**A subdomain of the shared domain** — `sjoca.example.com` — exists the moment
the organization is created. One wildcard custom domain on the Render service
covers every tenant there will ever be, which matters: Render includes 2 custom
domains on Hobby and 15 on Pro, and a wildcard counts as one.

```
*                    CNAME → <service>.onrender.com
_acme-challenge      CNAME → <service>.verify.renderdns.com
_cf-custom-hostname  CNAME → <service>.hostname.renderdns.com
```

The root domain must also point at Render or the wildcard configuration fails —
which suits us, because the apex is where the product's own site lives.

**A customer's own domain** — `sjoca.org` — is added later, and is three steps:
add it as a custom domain on the Render service (Render issues the certificate
once DNS resolves), point the customer's DNS at Render, and add the hostname to
`organization_hosts`. Only the first two need anybody with access to anything;
the third is a row, and takes effect without a deploy because
`Organization.known_host?` is the allowlist.

**Both work at once**, which is the useful part. The subdomain is a real address
from the day an organization exists — so an invitation links somewhere, a draft
can be reviewed, and pointing the real domain becomes the LAST step rather than
the first. The parish had to improvise that with `sjoca.onrender.com`.

### One site, one address

Both hostnames work; both **serving** is a different matter. Everything that is
not the canonical host is a `301` to it, so setting `canonical_url` at cutover
is what makes the staging subdomain quietly start forwarding — and the same
mechanism sends a bare `example.org` to `www.example.org`. One feature covering
three problems.

Three guards, each for a specific way it goes wrong:

| | |
|---|---|
| `GET`/`HEAD` only | a 301 on a POST loses the body, and a browser may turn the retry into a GET |
| the canonical host must be one of **this organization's** hostnames | a typo in `canonical_url` would otherwise take a site off the air, or loop |
| off unless `config.x.enforce_canonical_host` | in development you reach the app by whatever name you typed |

### Reserved slugs

A slug becomes a subdomain, so `www`, `mail`, `api`, `admin` and some fifty
others are refused by validation. An organization called `www` would answer for
the product's own site; one called `mail` would break every mail client looking
for autodiscover. Reserved now, while the cost is a validation — with customers
on the system it is a migration and a conversation with somebody who has already
printed their address on something.

### The session cookie is named `__Host-session`

Tenants live on sibling subdomains. Same-origin policy keeps their pages,
storage and scripts apart — but **cookies are not origin-scoped**. Any page may
set a cookie with `Domain=.example.com`, and every sibling receives it.

An ordinary footnote in most applications, and a real risk in this one, because
the premise here is that an AI writes JavaScript into a tenant's pages. Script
on one organization's site could set a cookie named like the session cookie,
scoped to the parent, and have the browser send it to another's — "cookie
tossing". It does not read the other session; it replaces it, which is enough to
confuse an editor into acting in the wrong place.

The `__Host-` prefix is enforced by the browser rather than by us: a cookie with
that prefix is rejected unless it is `Secure`, has `Path=/`, and carries **no
`Domain` attribute**. A tossed cookie must carry a Domain to reach a sibling, so
it can never bear this name.

`Authentication#current_user` checks `may_act_in?` on every request, so a
session from another organization is refused regardless. This stops it being
sent at all, which is the difference between a defence and a backstop.

Development and test keep an ordinary cookie name, because `__Host-` requires
`Secure` and a Secure cookie over plain http is accepted only because localhost
is treated as trustworthy — a rule that does not hold for every tool a
contributor might use.

---

## Adding an organization

```ruby
org = Organization.create!(name: "Second Society", slug: "second",
                           canonical_url: "https://second.example")
org.add_host "second.example"
org.add_host "www.second.example"

Organization.acting_as(org) do
  revision = Revision.create!(state: "published", title: "first")
  DefaultTemplates.install!(revision)
  User.create!(email: "editor@second.example", password: "...", role: "superadmin")
end
```

Then point the hostname at the service. **Note what changes the moment this
runs:** there are now two organizations, so `Current.organization` stops
guessing. Any script or job that did not name an organization will go quiet
rather than wrong — which is the right failure, but it is a failure, so expect
it and read it correctly.

---

## The specs that walk the onboarding path

`spec/requests/a_new_organization_spec.rb` builds a blank organization from
nothing on every run: hostname, first revision, default templates, one page,
then requests it. **This is the path nobody walks twice** — the first
organization took three weeks by hand, the second will be built by a stranger in
an afternoon with nobody watching.

It has already earned its place twice:

- A Liquid comment added to the default header used `{%# ... %}`, which requires
  a `#` on **every** line. The default header did not parse in any organization,
  and nothing else would have noticed until somebody created one.
- `DefaultTemplates.all` merges two templates in from `.liquid` files on disk.
  The source scan was globbing only `templates.rb`, so it was reading two thirds
  of the defaults while looking like it read all of them.

When the operator console arrives, **this spec is its specification**: creating
an organization, installing a starter and inviting an owner should each replace
a step in it, and the assertions should not have to change.

Its most useful assertion is the behavioural twin of the source scan: a brand
new organization's home page is scanned for anything belonging to this parish,
because a source scan can always be one pattern short. That is how `SJTB` would
have been caught — a monogram matches no word-based pattern, and it sat in the
default header for a fortnight.

---

## What a worker process does not know

**A job has no request, so `Current.organization` is nothing there.**

The password-reset email found this the hard way. It is sent with
`deliver_later`, so it is rendered in a worker — where it read
`Current.organization`, got nil, and produced a mail titled "This site" with a
link to `localhost:3000`. Invisible with one organization, because
`Current.organization` finds the only one by itself.

The fix is the shape, not the patch: **the organization is an argument.**
`UserMailer.password_reset(user, token, organization:)` sets it for the duration
of rendering, and `mail()` is inside that block because `mail()` is what renders.

Two things to carry forward:

- `Organization.acting_as` inside `app/` is refused by the scope guard unless the
  file is listed with a reason. The mailer is listed, and the reason is this
  section.
- **A spec that uses `perform_enqueued_jobs` runs the job inline, in the same
  thread, with `Current` still set — so it passes while production is broken.**
  Call `ActiveSupport::CurrentAttributes.clear_all` first. That one line is the
  difference between the spec that caught this and the spec that did not.

---

## Still deployment-wide, not per organization

Honest list of what has not moved yet.

- **`SITE_URL`** remains as the *fallback* for absolute links when no
  organization is resolved — a rake task, a job, the console. The real address
  is `organizations.canonical_url`, and `ApplicationMailer#url_options` decides
  the host per message so a password reset carries the right domain. Before this,
  five places read `SITE_URL` directly and a second organization's email and
  sitemap would have advertised the first one's domain.
- **SMTP** is one account for the whole deployment. Mail is signed with each
  organization's own name and reply-to, but goes out through one sender. See
  `config/initializers/mail.rb` — the note there about moving to a service that
  is nobody's mailbox now matters more, not less.
- **`SJOCA_DEMO`** and some JavaScript keys still carry a four-letter name from
  when there was one of these. Cosmetic, and on [`TODO.md`](TODO.md).
- **Solid Queue** tables are shared infrastructure. A job must carry its
  organization in its arguments and set `Current.organization`; nothing enforces
  that yet, because nothing currently enqueues per-organization work.
