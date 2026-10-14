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

## The 16 templates

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

### Live-data widgets — 4 templates

These pull from the mirrors and take no content of their own. The parish places
them; the content maintains itself.

| template | shows |
|---|---|
| `block/calendar` | the parish calendar, grouped by week, from ChurchTrac |
| `block/upcoming` | what is *different* about the coming week |
| `block/classes` | the three most recent adult-education recordings |
| `block/lectionary` | today's appointed readings, from oca.org |

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

**`site`** — name, address, email, and the four live feeds:

- `site.calendar.weeks[].events[]` — title, day, date_num, time_text,
  elsewhere, notes, cancelled, noteworthy, today
- `site.upcoming.events[]` — the same
- `site.classes.recordings[]` — title, number, date_text, watch_url, thumbnail
- `site.lectionary.today.appointed[]` — kind, citation, body, verses, paragraphs

---

## The 35 tools

**Looking** — `list_pages`, `get_page`, `list_photos`, `list_templates`,
`get_template`, `get_styles`, `get_scripts`, `describe_photo`, `liquid_guide`

**Content** — `add_block`, `update_block`, `move_block`, `delete_block`,
`add_section`, `update_section`, `move_section`, `delete_section`,
`add_page`, `update_page`, `delete_page`

**Appearance** — `set_styles` (CSS), `set_scripts` (JavaScript),
`set_template`, `add_template`

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
| Daily lectionary page | `add_page` + place the widget | yes |

**Three gaps were found writing this table**, and all three are now closed — which
is exactly why the table was worth writing before the test rather than after.

### What still needs a developer

Honestly, so the test is not judged against the wrong bar:

- **Anything in `public/`** — the favicon, `robots.txt`, the web manifest. Files,
  not rows.
- **New live data.** A fifth widget — a sermon archive, say — needs a model, an
  importer and a drop. The *templates* for it would be editable afterwards.
- **Exposing something a drop does not carry.** If a template needs a field no
  drop offers, that is a Ruby change. The AI is told to say so rather than
  pretend.
- **The `<head>`** — meta tags, CSP, the stylesheet link. Security-relevant, and
  deliberately left in ERB.
- **Routes, models, migrations, the Liquid drop surface.**

### The one thing I would watch

`set_styles` replaces a **single** overrides stylesheet wholesale. That is fine
for "make the headings larger" and crude for a season's worth of accumulated
changes — read it, change part, send the whole thing back. If the replay turns
that into a reliable source of mistakes, splitting CSS into named sections is the
obvious fix, and it is a small one.

---

## How to read the result of the test

The question is **not** "did the AI manage everything?" It is:

> **Is the set of things needing a developer small, comprehensible, and shrinking?**

Anything hit during the replay that needs a code change is an ordinary bug, fixed
the way it would be fixed a year from now — a change, reviewed, deployed. That is
the second route working as designed, not a failure of the first.
