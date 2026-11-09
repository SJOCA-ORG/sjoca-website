# Deploying to Render

**Status:** Live at **https://www.sjoca.org** since 9 November 2026, and still at
https://sjoca.onrender.com. `sjoca.org` redirects to `www`. The cutover took
about six minutes of exposure; what it involved, and what to do if it is ever
reversed, is in [the cutover section](#the-cutover-to-sjocaorg) below and in
[dns.md](dns.md).

Everything is defined in [`render.yaml`](../render.yaml): the web service, a
managed Postgres, and the three sync jobs. Render reads it and builds all four.

---

## If the repository ever moves owner

Moving the repo (as it moved from `catmando` to the `SJOCA-ORG` organisation on
13 October 2026) breaks automatic deployment in a way that is easy to miss,
because **nothing reports an error**. Pushes succeed and simply do not ship.

Two separate things have to be fixed, and only the first is obvious:

1. **Re-point every service.** The web service *and all three cron jobs* each
   store the repository URL. Via the API, `repo` is only accepted alongside
   `branch` — sending `repo` alone fails with `"branch does not exist in the
   repository"`, which reads like a problem with the repository rather than a
   missing parameter:

   ```bash
   curl -X PATCH -H "Authorization: Bearer $RENDER_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"repo":"https://github.com/SJOCA-ORG/sjoca-website","branch":"main"}' \
     https://api.render.com/v1/services/<service-id>
   ```

2. **Re-install Render's GitHub App on the new owner.** App installations do
   not follow a repository across accounts. This is **not** a setting in
   Render's dashboard — Render hands off to GitHub — so go directly to
   <https://github.com/apps/render/installations/new> and choose the
   organisation, or Organisation → Settings → GitHub Apps.

   Check it with:

   ```bash
   gh api orgs/SJOCA-ORG/installations
   ```

**A successful manual deploy does not prove step 2 is done.** This repository is
public, so Render can clone it with no permission at all; the clone will work
while the webhook is still missing. The only honest test is to push a commit and
watch whether a deploy starts on its own.

---

## First time

**1. Create the Blueprint.** In Render: New → Blueprint, connect
`SJOCA-ORG/sjoca-website`, pick the `main` branch. Render finds
`render.yaml` and proposes the services. Apply.

**2. Set `RAILS_MASTER_KEY`** on the web service *and* each of the three cron
jobs. The value is the contents of `config/master.key`, which is gitignored and
on your machine only:

```bash
cat config/master.key
```

Without it the app cannot read `credentials.yml.enc` and will not boot. This is
the one secret Render needs and it must never go in the repository — it was
committed once already and had to be rotated.

**3. Wait for the first deploy.** The build runs migrations, so the schema is
created automatically. The site will come up **empty**: no pages, no
photographs.

**4. Seed it from your machine.** This cannot run on the server, because the
photographs are not in git — only `db/seeds/*.yml` is, and it names files that
live in the photo library. So:

```bash
# Render → sjoca-db → Connect → External Connection String
DATABASE_URL="postgres://…render.com/sjoca" bin/rails db:seed
```

That loads the pages, the photographs from `~/sjoca-photo-library`, and the
curated assets. It takes a few minutes, mostly uploading images.

**5. Prime the synced data** — otherwise the calendar and readings stay empty
until the first cron run:

```bash
DATABASE_URL="postgres://…" bin/rails churchtrac:sync
DATABASE_URL="postgres://…" bin/rails lectionary:sync
DATABASE_URL="postgres://…" bin/rails classes:sync
```

**6. Note the URL.** Render gives you `sjoca.onrender.com` or similar. That is
the temporary address for the AGM. Nothing points `sjoca.org` at it yet, and
nothing should until the parish has said yes.

---

## If the first build fails with "type ... already exists"

An interrupted first deploy leaves tables behind without recording them in
`schema_migrations`, so the next build tries to load the schema again and
collides with its own leftovers. There is no data worth keeping at that point,
so empty the database and redeploy:

```bash
psql "<render external connection string>" -c \
  'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'
```

Then Manual Deploy → Clear build cache & deploy.

The build now uses `db:prepare` rather than `db:migrate`, which handles the
empty and the already-migrated case, so this should not recur.

## Afterwards

**Deploys happen on push** to `main`. Migrations run in the
build; seeds do not.

**Content changes need no deploy at all.** The website is not in the code. Pages,
sections, blocks, photograph bytes, the 171 Liquid templates and the site
settings are all rows, and the Ruby is a renderer that knows how to turn rows
into pages without knowing what the pages say. Edit through `/admin`, publish,
and it is live. The image on Render does not change and does not need to.

That is the Phase 2 premise — a parish volunteer editing the site without a
developer — and it has been true since the admin shipped.

### Do not reseed production

An earlier version of this page said content changes were "a push plus a
reseed", and gave this command:

```bash
FORCE_CONTENT_RESEED=1 ...    # DO NOT run this against production
```

That belonged to Phase 1, when the site's content lived in `db/seeds/content.yml`
and git was the source of truth. **It is now the opposite.** The database is the
source of truth, and the YAML in `db/seeds/` is a snapshot of the old Google
Sites capture.

With the flag set, `db/seeds/content.rb` **rebuilds a page's sections and blocks
from scratch** — its own comment says so, and says why. It touches the pages
named in that file's `NAV` constant: home, our story, leadership, choir, the
weekly bulletin, the lectionary, resources, giving, outreach and contact. Not
every page, which is cold comfort — those are the ones a visitor reads first.
There is no undo but a dump.

Seeds are for **populating a database that has none**: a fresh clone, a new
development machine, a restored-from-nothing server. Without the flag they leave
existing pages alone, which is the behaviour to rely on.

**New photographs** go in through `/admin` as well. Uploading one writes the
bytes to the `photos` table and queues `DescribePhotoJob` to write its alt text.
`db/seeds/curated.yml` and the photo library remain how the ORIGINAL set was
established, and how a fresh database is filled — not how a picture is added to
a live site.

---

## The three cron jobs are gone

There were three: `churchtrac:sync` every six hours, `lectionary:sync` and
`classes:sync` daily. They mirrored the ChurchTrac calendar, the daily readings
from oca.org and Fr David's class recordings into local tables.

All of it has been removed — the models, the importers, the rake tasks, and the
entries in `render.yaml`. The three Render services were **suspended** on 9
November 2026 and still await deletion.

**A blueprint does not delete a service you take out of the file.** It orphans
it, so the three went on firing and failing for a fortnight after the code they
ran had gone. Worse, an orphaned service resists deletion: Render hides or
blocks per-service delete while a service is still attached to a blueprint,
which is why suspending was easy to find and deleting was not. The button is
real — **Service → Settings → the bottom of the page** — and it asks you to type
the service name.

**Why they went.** Each importer knew which events mattered and what they were
called, and that knowledge was invisible to the AI editor — which is how a page
once shipped missing Vespers and the Divine Liturgy. They are replaced by one
primitive on the `sayoursite` branch: a data source is a row with a name and a
URL, the server fetches it behind `Site::OutboundFetch`, and admin-written
JavaScript formats the JSON. Judgement in Ruby is judgement nobody can review.

## The cutover to sjoca.org

**Done, 9 November 2026**, six days before the AGM. Fr. David had approved the
site as it stood; the database was pushed from a laptop that afternoon, the
deploy rehearsed, and the records changed at about 16:55 EST. Both certificates
were live by 17:03.

The plan below is kept in the past tense it was written in, because it is the
record of what was decided and why — including two things decided *against*,
which is the part that gets forgotten. The DNS detail and the four traps are in
[dns.md](dns.md).

The thing that makes this safe, and worth saying first: **`www.sjoca.org` has a
TTL of 300 seconds**, and Google Sites is left running and untouched throughout.
If anything goes wrong after the switch, changing the record back puts the old
site in front of people within five minutes. Nothing here is a one-way door.

Worth knowing before you start: **`sjoca.org` has never resolved.** There is no
A record on the bare domain today, which is why it has always been "unreliable".
Only `www` has ever worked.

### What is deliberately NOT being done

**The `sayoursite` branch is not being merged.** It carries the
multi-organization refactor, the operator console and the product spec — eight
migrations, one of them irreversible, and a `default_scope` under every query
that fails closed. The parish needs none of it, and `config.hosts` would become
`Organization.known_host?`, which means a hostname missing from a table serves
nothing. That is a new failure mode introduced at exactly the moment the
hostname changes. Production already runs the approved site; the only thing
missing is a domain pointed at it.

**No canonical-host redirect is being added.** `main` has none, and
`enforce_canonical_host` exists only on `sayoursite`, where it is organization-
based and would not port cleanly. Both hostnames will serve the site, and the
`<link rel="canonical">` tag says which one counts. Search engines honour that.

**This turned out to be unnecessary.** Render redirects the apex to `www` at its
own edge: `https://sjoca.org/` returns a 301 to `https://www.sjoca.org/` with no
application code involved. We get the real redirect without writing one.

### 1. Render, before any DNS changes

Add **both** custom domains to the `sjoca` web service: `sjoca.org` and
`www.sjoca.org`. Render issues a TLS certificate per domain, and it cannot do
that until the name points somewhere it controls — but adding the domain first
means the certificate is waiting rather than being chased. **Do this before the
DNS edit, or the first visitors get a certificate warning.**

### 2. The database swap, while nobody can reach the site

This is the free window. The domain is not pointed yet, so a restore that drops
and recreates every table costs no visitor anything.

| | |
|---|---|
| Local `sjoca_main_development` | the 26 October production dump, plus the work done on top of it |
| Production | nothing newer than 21 October, plus three unused photographs added on 27 October |

So local is strictly ahead, except for `interior-icons`,
`myrrh-bearing-women-closeup` and `st-john-the-baptist-closeup` — none of which
appears anywhere on the live site. Copy them down first if they are wanted;
otherwise they are in the backup.

1. **Publish the draft locally** and look at it at `localhost:3000`. Publish
   state travels in the database, so whatever state the local copy is in is the
   state production comes up in. You could equally publish on the server
   afterwards — but publishing locally means you see the finished thing in a
   place where a mistake costs nothing, and the restore then lands the final
   state in one shot instead of leaving a step to remember.
2. **Suspend the web service** in Render, so nothing writes mid-restore.
3. **Run `bin/push-local-db sjoca_main_development`.** It prints both sides'
   row counts and every photograph that exists only on the server, takes a
   verified production backup, and then asks you to type `REPLACE`. Read what it
   prints. It is the dangerous direction and it is meant to be slow.
4. **Resume the service** and walk every page on `sjoca.onrender.com`.

Nothing about publishing depends on the hostname: `site.url` is read when a page
renders, not when it is published, so a locally-published revision picks up
production's `SITE_URL` as soon as it is there.

### 3. The canonical address

**`www.sjoca.org` is canonical, and `sjoca.org` also works.** That is the
decision; the reasoning is worth keeping because it is close.

Against the bare domain: the apex cannot hold a CNAME — DNS forbids it, since it
would collide with the SOA and NS records — so it needs Namecheap's ALIAS, a
synthetic record their nameservers resolve. It works and BasicDNS supports it,
but it is a vendor feature rather than a standard, and if Render ever moves
addresses you are trusting that implementation to follow. A `www` CNAME follows
by itself. Against it too: everything printed, indexed and listed in the OCA
directory already says `www.sjoca.org`, so making the apex canonical sends all
of it through a redirect.

For the bare domain: it is shorter, and it is what people say out loud.

Set `SITE_URL=https://www.sjoca.org` on the web service. Without it, every
canonical tag, every `og:url` and the whole sitemap keep saying
`sjoca.onrender.com`, and the parish domain gets indexed as a duplicate of a
hosting address.

### 4. DNS, in one edit

At Namecheap, BasicDNS, both records in the same save:

| Type | Host | Value |
|---|---|---|
| ALIAS | `@` | `sjoca.onrender.com` |
| CNAME | `www` | `sjoca.onrender.com` |

Leave the mail records alone. SPF, DKIM and DMARC have nothing to do with where
the website lives, and the one way to turn a website cutover into a parish-wide
email outage is to edit them on the same afternoon.

Then watch it arrive:

```bash
script/zone_compare.sh      # what the nameserver holds vs what resolvers hand out
```

Those are two different questions, and conflating them once produced a
false "mail is broken" alarm on a zone that was already correct. See
[`dns.md`](dns.md).

### 5. Afterwards

- Walk the site on a phone and a laptop. Both hostnames.
- Add both to Google Search Console and submit `https://www.sjoca.org/sitemap.xml`.
- **Leave Google Sites running.** It is the rollback, and it costs nothing.
  Decide what happens to it after the AGM, not before.
- Confirm you can still sign in at `/admin` — the push replaced the users table,
  so the password is now whatever the local database held.

### Rolling back

| If it goes wrong | Do this | Takes |
|---|---|---|
| The site is wrong after the DNS change | Point `www` back at `ghs.googlehosted.com` | ~5 minutes |
| The database is wrong | `pg_restore --clean --if-exists -d "$RENDER_DATABASE_URL" db/dumps/production-before-push-*.dump` | minutes |
| Certificates are not ready | Leave DNS as it is until Render shows both domains verified | — |


---

## Worth knowing

**The database holds the photographs.** After cutover it is the parish's only
copy of the Miter Ceremony, the 2023 events, and everything photographed since
— the Google Sites original will be gone. Check the backup retention on
whichever Postgres plan is chosen, and confirm a restore actually works before
relying on it.

**Do not use the free web plan.** It sleeps after inactivity, and a parish site
that takes thirty seconds to wake up is worse than a slow one.

**Pointing sjoca.org here was a separate job, and it is now done.** The domain
was never recovered from AWS — Support issued a transfer code after verifying
the registrant — so it moved to Namecheap on 26 October 2026 and onto Namecheap
BasicDNS on 27 October. The cutover of the *website* is a different event again,
and is the section above: moving the domain and moving the site were kept apart
on purpose, and the parish noticed neither.
