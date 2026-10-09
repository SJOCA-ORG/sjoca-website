# Capturing the current site

The site we are replacing is a **Google Sites** page, which builds itself in
JavaScript. `curl` returns an empty shell, so everything here goes through a
real headless Chrome.

## One command

```bash
node capture.mjs          # from this directory, or give the full path
```

Needs Chrome (or Chromium) installed and Node 22+. No npm install — the script
drives Chrome's DevTools Protocol over Node's built-in WebSocket.

Produces, for all 11 pages:

| Output | What it is | Committed? |
|---|---|---|
| `dom/*.html` | rendered DOM — *what the content is* | no |
| `geometry.json` | bounding boxes — *where it sits* | **yes** |
| `images/`, `images/manifest.tsv` | the photos | no |
| `shots-desktop/`, `shots-mobile/` | visual reference to build against | no |

Then turn that into seed data:

```bash
cd ../..                                            # repo root
bin/rails runner script/extract_current_site.rb     # -> db/seeds/*.yml
bin/rails db:seed
```

## Three things that will bite you

**Capture has to happen in one browser pass.** Google serves images from signed
URLs that rotate between browser sessions and expire in about twenty minutes.
An earlier version dumped the DOM in one run and measured geometry in another;
the two runs produced completely disjoint URL sets with nothing to join on, and
40% of images silently lost their layout. Hence one script, one pass, DOM and
geometry and bytes taken together.

**Document order is not visual order.** Sites places grid cells explicitly. The
home page reads as two rows of two in the DOM and *renders* as two columns of
stacked items. That is why we measure bounding boxes instead of trusting the
markup, and why columns and their widths are derived from geometry.

**Reset the viewport after screenshotting.** The mobile screenshot sets a 390px
device override, and it persists across navigations. Leave it set and every
page after the first gets measured as a single mobile-width column — which
looks like a layout bug in your own code, not a measurement bug.

## Why none of the photos are committed

The capture is ~90MB, and it is photographs of parishioners, including
identifiable children. This repository is public. The images go into the
`legacy_assets` table instead; see `db/seeds/legacy_assets.rb` for how, and why
production becomes their system of record after cutover.
