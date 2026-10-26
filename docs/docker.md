# The image the site runs in

Written 26 October 2026, when the site moved off Render's plain Ruby runtime.

---

## Why

The editor shells out to five programs by name: `magick`, `ffmpeg`, `ffprobe`,
`rsvg-convert`, `potrace` — plus `node` and headless Chromium. Render's Ruby
runtime has none of them.

Deployed that way, publishing and rolling back worked and **nothing else did**:
no photograph could be uploaded, the AI could not see the page it had just
changed, and no bulletin PDF could be made. Those are most of the reasons the
editor exists.

---

## What is in it, and the three things that nearly went wrong

Base: **`ruby:3.4.7-slim`**, which is **Debian 13 (trixie)**.

**Debian 13, not 12.** Trixie ships ImageMagick **7**, where the command really
is `magick`. Debian 12 ships ImageMagick 6, where it is `convert` — and every
image call in this application would have failed with "command not found".
Checked in the image: `ImageMagick 7.1.1`.

**Node 22 from NodeSource, not Debian's 20.** `script/visual_check.mjs` drives
Chromium over a WebSocket and uses the global `WebSocket` class on purpose, so
that it needs no dependencies at all. That global only arrived in Node 22. On
Node 20 the editor's eyes fail with `WebSocket is not defined`, returned as
JSON saying the check could not run — quiet enough to miss.

**Fonts.** `fonts-liberation`, `fonts-dejavu-core`, `fonts-noto-color-emoji`.
Without them a screenshot is a page of empty boxes and a bulletin PDF prints
blank, which looks like a layout bug and is not one.

Also: `chromium`, `ffmpeg`, `librsvg2-bin`, `potrace`, `postgresql-client`,
`libpq5`. It runs as a non-root user; Chromium's own sandbox is already
disabled in the scripts because it cannot work in a container without extra
privileges, so the container user is what stands between a bug in an image
library and the rest of the machine.

---

## Proved, not assumed

Built and run locally under colima before Render ever saw it:

| | |
|---|---|
| ImageMagick | 7.1.1; a 4000x3000 image resized to 2000x1500 |
| Hardened `policy.xml` | loads — URL, HTTP and FTP coders refused |
| ffmpeg / ffprobe | a one-second video turned into a still |
| rsvg-convert, potrace | present and answering |
| Chromium | renders, and the screenshot has 183 colours in it rather than being blank |
| The AI's eyes | `visual_check.mjs` against a real page: 28 blocks, no findings, **no images failing to load** |
| Bulletin PDF | `%PDF-1.4`, MediaBox `[0 0 396 612]` — 5.5 x 8.5 inches exactly |
| Photo intake | 3600x2700 arrived, 2000x1500 stored |
| The real site | the 190MB database restored into the container and every page served |

Two faults were found this way rather than on a deploy: the missing Node
WebSocket, and `.dockerignore` excluding `db/seeds` while `db/seeds.rb` loads
from it, which killed `db:prepare` on a fresh database.

A third was found because of it: a database with nothing published answered
with a **500 and a backtrace**. That is how a new parish's instance starts, so
it now says "Nothing has been published yet" and returns 503.

---

## Running it here

```bash
colima start --cpu 4 --memory 6 --disk 40      # once

docker build -t sjoca:test .
docker run --rm -i sjoca:test bash -s < script/verify_image.sh
```

To run the whole thing against a copy of the real database, see the commands in
the history of this file — a `postgres:17-alpine` container, `pg_restore` of a
local dump, and the web container pointed at it with
`RENDER_EXTERNAL_HOSTNAME=localhost` so Rails' host checking lets requests
through.

---

## On Render

`render.yaml` carries it: `runtime: docker` for the web service and all three
cron jobs, from the same image.

- **`plan: standard` (2GB)** for the web service. Headless Chromium takes a few
  hundred megabytes on its own; on 512MB the container is killed mid-screenshot,
  which looks like the editor dying halfway through a change.
- **`preDeployCommand: ./bin/rails db:prepare`** — migrations cannot run during
  a Docker build, which has no database. Render runs this after the build and
  before the new version goes live, so a failed migration does not take the
  site down with it.
- `bin/render-build.sh` is now unused by the web service and kept only for
  reference.
