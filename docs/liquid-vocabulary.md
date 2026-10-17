# The vocabulary — what the parish can change without a developer

**For review before the replay test begins.** This is the answer to "what is the
minimum set of templates and tools needed to rebuild this site by talking to the
admin?" If something here is not comprehensible to a non-technical maintainer on
paper, it will not be usable by one in practice — which is the point of reading it
before any of it is relied on.

The AI gets this same information generated from the code, through a
`liquid_guide` tool, so the two cannot drift apart. This file is the human copy.

---

## The shape of a page

```
Page  ──  the thing at a URL, e.g. /about-us/choir
 └─ Section   a full-width horizontal band (white, grey or maroon)
     └─ Column   one, two or three, in measured proportions
         └─ Block   one heading, paragraph, photo, list, button or widget
```

Nothing else. Every page on the site is bands of columns of blocks.

## The 12 templates

Each is a database row. Editing one changes how that thing renders **everywhere**.

### Structure — 4 templates

| template | what it is |
|---|---|
| `page` | the hero image and heading, then each band in turn |
| `section` | one band: its colour, its columns, their proportions |
| `header` | the parish name and the whole navigation menu |
| `footer` | the name, address and email at the bottom |

### Content blocks — 8 templates

| template | renders |
|---|---|
| `block/heading` | a section heading |
| `block/subheading` | a smaller heading, used for service times |
| `block/text` | a paragraph |
| `block/image` | a photograph, optionally linked |
| `block/list` | a bulleted list, one item per line |
| `block/quote` | an indented quotation |
| `block/button` | a link styled as a button |
| `block/embed` | a map or a video from elsewhere |

### Live-data widgets — removed, 17 October 2026

There were four: `block/calendar`, `block/upcoming`, `block/classes`,
`block/lectionary`, each backed by a Ruby drop that decided what was worth
showing. They are gone, and so are the drops.

The reason is the most useful thing we learned building this. `site.upcoming`
quietly excluded every regularly scheduled service — reasonable in the abstract,
since nobody needs telling that Vespers is on Saturday again. The AI was told
only that it meant "notable events in the coming week". So when asked for the
next seven days it produced a home-page box with **no Vespers and no Divine
Liturgy in it**, added a dedup hack when events appeared to repeat, and had no
way to discover the filter it was arguing with.

Editorial judgement in Ruby is judgement nobody downstream can read, question,
or roll back. Anything from outside now arrives through one primitive and every
decision about it is written in JavaScript, in the revision, in the open.

**A new kind of block is one new template.** Write `block/scripture` and a
scripture block can be placed immediately — no developer, no deploy. Verified end
to end.

---

## What a template can read

Templates can read these and nothing else. There is no way to reach the database,
the filesystem, or Ruby.

**`page`** — slug, title, nav_title, path, sections, hero_heading,
hero_subheading, hero_detail, hero_photo, hero_tall, has_hero

**`section`** — id, style, columns, grid_template

**`block`** — id, kind, content, align, width, url, column, photo, items,
is_map, template

**`photo`** — name, url, alt, width

**`nav`** — title, path, slug, current, children, has_children, self_title

**`site`** — name, address, email, and `data`

**`site.data`** — outside data, by whatever name it was set up under. It has no
fixed properties: `site.data.calendar` exists if a source called `calendar`
does.

**`site.data.<name>`** — `json_tag`, `json`, `id`, `name`, `note`, `urls`, and
for a template that wants to say something went wrong: `ok`, `error`, `stale`,
`age`, `bytes`.

That is the whole of it. One primitive where there were four feeds:

```liquid
{{ site.data.calendar.json_tag }}
```

writes `<script type="application/json" id="data-calendar">…</script>` into the
page, and the site's own JavaScript takes it from there:

```javascript
const events = JSON.parse(
  document.getElementById("data-calendar").textContent);
```

The server does the fetching because a browser cannot: ChurchTrac sends no
`Access-Control-Allow-Origin` header, so a fetch from sjoca.org is blocked
outright. Addresses are checked hard before anything is fetched — see
`Site::OutboundFetch`, and `docs/TODO.md` for what it refuses and why.

---

## The 54 tools

**Looking** — `list_pages`, `get_page`, `list_photos`, `list_templates`,
`get_template`, `get_styles`, `get_scripts`, `describe_photo`, `liquid_guide`

**Content** — `add_block`, `update_block`, `move_block`, `delete_block`,
`add_section`, `update_section`, `move_section`, `delete_section`,
`add_page`, `update_page`, `delete_page`

**Appearance** — `add_styles`, `edit_styles`, `find_styles` (CSS),
`add_script`, `edit_script`, `find_script` (JavaScript),
`set_template`, `add_template`

These send only what changes. `set_styles` and `set_scripts` still exist and
are the wrong tool: a reply is capped at 4096 tokens, so replacing a whole
26KB stylesheet is arithmetically impossible and fails by being cut short.

**Looking at the result** — `view_page`, `check_page`, `check_appearance`

`check_appearance` opens the page in a real browser at 390px and 1280px and
**returns the screenshots**, so the AI can see the page rather than infer it
from measurements. Added 17 October, after it put a box in the footer that
belonged in the right-hand column: nothing was measurably broken, it just
looked wrong, and "looks wrong" was not something it could perceive.

**Outside data** — `add_data_source`, `peek_data`, `list_data_sources`,
`remove_data_source`

`peek_data` is the one to notice. It reports a feed's type, size, field names
and a short sample, so the AI writes JavaScript against the real shape of
someone else's data instead of guessing at it.

**Photographs** — `crop_photo`, `resize_photo`, `rotate_photo`, `trim_photo`,
`adjust_photo`, `grayscale_photo`, `feather_photo`, `round_photo_corners`,
`convert_photo`, `combine_photos`

**Memory** — `record_lesson`, for things it works out that should not have to be
worked out twice.

Every photograph operation writes a **new** photograph. Nothing is overwritten, so
an unfortunate crop is undone by publishing the previous version.

---

## Is this enough to rebuild the site?

Checked against what actually happened between the Phase 1 baseline and today.

| the change | how | covered |
|---|---|---|
| Service times moved above the photo | `move_block` | yes |
| Live-streaming paragraph removed | `delete_block` | yes |
| Miter Ceremony page retired | `delete_page` | yes *(added while writing this)* |
| Address and phone became links | `update_block` — inline `<a>` is allowed | yes |
| "Donate" relabelled "Giving" | `update_page` — the slug stayed `/donate` | yes |
| Giving split into two sections, eight ministries | `add_section`, `add_block` | yes |
| Clergy titles corrected | `update_block` | yes |
| Education section with two pages under it | `add_page`, `parent_slug` | yes *(added while writing this)* |
| "Calendar" and "Adult Education" submenu entries | `self_nav_title` | yes *(added while writing this)* |
| Hero sizes changed | `update_page` | yes |
| Navigation reordered | `update_page` position | yes |
| Mobile menu rebuilt | `set_styles`, and `header` if the markup must change | yes |
| Feathered photograph edges | `feather_photo` | yes |
| Daily lectionary page | `add_page`, `add_data_source`, a template and a script | yes — and it is now real work rather than placing a widget |

**Three gaps were found writing this table**, and all three are now closed — which
is exactly why the table was worth writing before the test rather than after.

### What still needs a developer

Honestly, so the test is not judged against the wrong bar:

- **Anything in `public/`** — the favicon, `robots.txt`, the web manifest. Files,
  not rows.
- ~~**New live data.** A fifth widget — a sermon archive, say — needs a model, an
  importer and a drop.~~ **No longer true, 17 October.** `add_data_source` takes
  any https address, and the formatting is a template and a script. A sermon
  archive is now a conversation, not a deploy. The remaining limit is that the
  payload reaches the page as raw bytes: a feed serving JSON works today, and
  one serving HTML needs the page's own JavaScript to pick it apart (or the
  server-side transform in `docs/TODO.md`, not built).
- **Exposing something a drop does not carry.** If a template needs a field no
  drop offers, that is a Ruby change. The AI is told to say so rather than
  pretend.
- **The `<head>`** — meta tags, CSP, the stylesheet link. Security-relevant, and
  deliberately left in ERB.
- **Routes, models, migrations, the Liquid drop surface.**

### The one thing I would watch

~~`set_styles` replaces a single stylesheet wholesale.~~ **Closed.**
`add_styles`, `edit_styles` and `find_styles` send only what changes, and the
same three now exist for JavaScript. The whole-file tools remain, marked in
their own descriptions as the wrong choice.

What I would watch instead: **the AI now writes the judgement that used to be
hidden in Ruby, and judgement can be wrong in ways a renderer cannot.** A drop
that excluded the regular services was invisible and wrong. A line of
JavaScript that excludes them is visible and can still be wrong — the gain is
that it can be read, argued with, and rolled back, not that it is correct. The
test to watch for is whether a mistake of that kind surfaces in review, or
whether the code being present is mistaken for the code being right.

---

## How to read the result of the test

The question is **not** "did the AI manage everything?" It is:

> **Is the set of things needing a developer small, comprehensible, and shrinking?**

Anything hit during the replay that needs a code change is an ordinary bug, fixed
the way it would be fixed a year from now — a change, reviewed, deployed. That is
the second route working as designed, not a failure of the first.
