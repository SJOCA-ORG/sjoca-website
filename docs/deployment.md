# Deploying to Render

**Status:** Blueprint written, not yet deployed — 2026-10-12

Everything is defined in [`render.yaml`](../render.yaml): the web service, a
managed Postgres, and the three sync jobs. Render reads it and builds all four.

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

**Content changes** are a push plus a reseed:

```bash
FORCE_CONTENT_RESEED=1 DATABASE_URL="postgres://…" bin/rails db:seed
```

Note the flag. Without it, existing pages are left alone — which is deliberate,
because once the Phase 2 editor exists, a deploy that silently overwrote
parishioners' edits would be a disaster.

**New photographs** need no code change: add the file to the photo library, add
an entry to `db/seeds/curated.yml`, push, reseed. A new version appears under
the same name and the newest wins.

---

## The three cron jobs

| Job | Runs | Why that often |
|---|---|---|
| `churchtrac:sync` | every 6 hours | Events change during the day; the feed is light |
| `lectionary:sync` | daily, 05:40 | Each date is fetched once ever, then skipped |
| `classes:sync` | daily, 05:55 | Fr David posts about one a week |

All three fail safe: a bad response is refused rather than applied, so a broken
sync leaves stale data rather than an empty page. Check `lectionary:status` and
`churchtrac:status` to see what is held and when it last ran.

---

## Worth knowing

**The database holds the photographs.** After cutover it is the parish's only
copy of the Miter Ceremony, the 2023 events, and everything photographed since
— the Google Sites original will be gone. Check the backup retention on
whichever Postgres plan is chosen, and confirm a restore actually works before
relying on it.

**Do not use the free web plan.** It sleeps after inactivity, and a parish site
that takes thirty seconds to wake up is worse than a slow one.

**Pointing sjoca.org here is a separate job** and should not happen before the
AGM. See `docs/TODO.md` — the domain sits in an AWS account we are still
identifying, and the bare domain does not currently resolve at all.
