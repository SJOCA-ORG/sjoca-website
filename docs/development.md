# Setting up a development environment

Everything here was verified on macOS (Apple Silicon) on 14 October 2026. Linux
notes are given where they differ; Windows means WSL2 and then follow Linux.

---

## What must be installed

| | version | why |
|---|---|---|
| Ruby | **3.4.7** | pinned in `.ruby-version` and the `Gemfile` |
| Node | **24** | pinned in `.node-version`; only used by the capture script |
| PostgreSQL | **18** | production runs 18, and `pg_dump` cannot read a server newer than itself |
| Google Chrome | any recent | the capture script drives it over CDP |
| ImageMagick (`magick`) | any | icon and image work |
| librsvg (`rsvg-convert`) | any | renders the SVG parish mark to PNG |
| potrace | any | only needed to re-derive the parish mark from bitmap artwork |

The last three are easy to miss: nothing references them until something fails,
and `docs/favicon.md` is the only other place they appear.

### macOS

```bash
brew install postgresql@18 imagemagick librsvg potrace
brew services start postgresql@18
brew link --overwrite --force postgresql@18     # see the warning below
```

Ruby and Node are managed with [mise](https://mise.jdx.dev) on this machine;
`rbenv`, `asdf` or `nvm` are equally fine. The pinned files are what matter.

> **If you already have another PostgreSQL from Homebrew**, stop it first —
> both want port 5432:
>
> ```bash
> brew services stop postgresql@14
> brew unlink postgresql@14
> ```
>
> `brew link` is what makes `psql` and `pg_dump` on your `PATH` resolve to 18.
> Without it you get an 18 *server* and a 14 *client*, which fails in a way that
> reads like a connection problem rather than a version problem.

### Linux

```bash
sudo apt install postgresql-18 imagemagick librsvg2-bin potrace
```

---

## First run

```bash
bundle install
bin/rails db:create db:migrate
```

Then get some content. **Two routes, and the second is better if you have access:**

**A. Build it from the live Google Sites site** — no credentials needed:

```bash
node reference/current-site/capture.mjs        # needs Chrome; ~2 minutes
bin/rails runner script/extract_current_site.rb
bin/rails db:seed
```

**B. Pull production** — faster, and gives you the real current site:

```bash
export RENDER_API_KEY=…        # from the Render dashboard
bin/pull-production-db
```

Then:

```bash
bin/rails server               # http://localhost:3000
bundle exec rspec              # 106 examples
```

### Why the capture step exists at all

Parish photographs are **not in git**. The repository is public and the photos
include identifiable children, so a fresh clone has no image bytes until you
either capture them or pull production. This is deliberate — see `CLAUDE.md`.

---

## Pulling production data

`bin/pull-production-db` dumps the live database and replaces your local one. A
`pg_dump` is a *complete* copy of the site, because photo bytes live in the
`legacy_assets` table rather than on disk or in object storage — so there is no
second artifact to sync.

**The file it writes is the most sensitive artifact this project produces.** It
contains every parish photograph, children included, and it sits on your laptop.
Dumps go to `db/dumps/`, which is gitignored, and `.gitignore` also covers
`*.sql`, `*.dump` and `*.sql.gz` as a backstop. Delete them when you are done,
and do not move them somewhere more convenient.

The script refuses to run with `RAILS_ENV=production`, and checks your client
version against the server before starting, so the version trap below fails
immediately and legibly rather than halfway through a 40MB dump.

### The version trap

Production is PostgreSQL **18**. `pg_dump` refuses to read a server newer than
itself:

```
pg_dump: error: server version: 18.6; pg_dump version: 14.19
pg_dump: error: aborting because of server version mismatch
```

If you see that, your client is old. `brew link --overwrite --force
postgresql@18` and try again.

---

## Running the checks

```bash
bundle exec rspec                       # everything
bundle exec rspec spec/models           # one directory
```

See [`docs/testing.md`](testing.md). The suite is mostly regression specs for
bugs that actually shipped, and `docs/ai-admin.md` treats it as a prerequisite
for Phase 2 rather than a nicety.

## Deploying

Pushing to `main` deploys automatically. See
[`docs/deployment.md`](deployment.md), which also covers what breaks if the
repository ever changes owner again.
