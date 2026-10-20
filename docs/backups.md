# Backing up, and getting back

The database is the only copy of some of this. Not the code — the code is on
GitHub — but the content, and above all the photographs, whose bytes live in
the `photos` table and nowhere else once the Google Site goes away.

So `pg_dump` is the whole backup. There is no second thing to remember.

---

## Taking one

```bash
mkdir -p ~/sjoca-backups
pg_dump -Fc -d sjoca_development -f ~/sjoca-backups/sjoca-$(date +%Y%m%d-%H%M).dump
```

About 145MB, nearly all of it photographs.

`-Fc` is the custom format: compressed, and it allows restoring one table
rather than all of them, which matters on the day you want the photographs
back but not the rest.

**Never into the repository.** `.gitignore` blocks `*.dump`, `*.sql` and
`db/dumps/` as a backstop, but the right place is outside the checkout
entirely, so a backup survives whatever happens to the working copy.

---

## Checking it is real

A dump is not a backup until it has restored. This takes a minute and is the
only way to know:

```bash
createdb sjoca_restore_check
pg_restore -d sjoca_restore_check --no-owner --no-privileges ~/sjoca-backups/<file>.dump

psql -d sjoca_restore_check -c "SELECT count(*) FROM photos WHERE length(data) > 1000;"
dropdb sjoca_restore_check
```

That last query is the one that matters. Row counts can look right while every
photograph is an empty column — count the ones with actual bytes in them.

Verified on 20 October 2026: 0 restore errors, 7 revisions, 88 pages, 1,391
blocks, 184 photographs all carrying real image data, matching the live
database exactly.

---

## Getting back

```bash
bin/rails db:drop db:create
pg_restore -d sjoca_development --no-owner --no-privileges ~/sjoca-backups/<file>.dump
```

Everything comes back together: content, drafts, the conversation, the
photographs, the standing promises, the published revision.

### Only the photographs

The case that actually happens — content has moved on, but something has
eaten an image:

```bash
pg_restore -d sjoca_development --no-owner --data-only -t photos ~/sjoca-backups/<file>.dump
```

---

## When to take one

**Before publishing**, which is the moment this document was written for.
Publishing is a pointer flip and reversible by republishing the previous
revision — but that is only true while the previous revision still exists, and
a backup is what makes "only true while" stop mattering.

**Before anything that rewrites rows in bulk** — a migration that touches
content, a bulk retag, stripping metadata from every photograph.

**On a rhythm once the parish is editing it**, at which point this becomes a
parish-archive concern rather than a developer one: the production database
will hold photographs that exist nowhere else.
