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
