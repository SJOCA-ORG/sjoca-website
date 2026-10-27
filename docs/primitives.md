# What Ruby is allowed to know

Written 27 October 2026, after Mitch said the thing this document exists to
record:

> Ruby level should have no knowledge of service times. The user will say to the
> AI we have these regularly defined services. X, Y and Z. display here in this
> format, and over there in that format, keep em consistent... In other words
> the whole calendar should be built from primitives that know nothing about
> calendars, or service times, or even that we are a church.

---

## The line

**Ruby knows generic shapes. The revision holds particular facts.**

| Ruby may know | Ruby may not know |
|---|---|
| A site has a name, an address, an email | That the name is Saint John the Baptist |
| A page is rendered by a template | That "bulletin" is a kind of page |
| A URL can be fetched and cached | That this URL is a church calendar |
| Bytes can be resized, a page screenshotted | What a Vespers is |

The test is simple: **could a second parish run this code unchanged?** Anything
that fails that test is a fact, and belongs in the revision where it can be read
and corrected by asking.

---

## What was moved, and what it cost

### The parish's own facts

`Site::Seo` and `SiteDrop` held the name, the street, the city, the postcode and
the description as Ruby constants. A parish could not correct its own address
without a developer, and the code asserted which parish it was.

They are now `site_settings`, one row per fact, **scoped to the revision** — so
changing the address is published and rolled back like any other change. The AI
reads and writes them with `list_settings` and `set_setting`; templates read
`{{ site.name }}` and `{{ site.settings.anything }}`.

The fallbacks are deliberately **not** this parish's details. They were for an
hour, and that is a trap: a second parish installing this with no settings would
have published a Rochester address on its own website. A site that has not been
told its name now says "This site".

### The structured data

`Site::Seo#structured_data` asserted `"@type": "Church"`, the address, the
parent body, and the service times. It is now a **`head` template** in the
revision — ordinary Liquid, rendered into every page's `<head>`, which the
parish owns.

The service times in it were derived from the ChurchTrac feed by
`scheduled_service?`: *recurring, and the title matches one of these patterns.*
Nobody could read that filter, and **it was wrong**. The Hours at 9:30 on a
Sunday are on the home page and were missing from what Google was told, because
they did not match a pattern nobody could see. That is the second time an
invisible Ruby filter has quietly dropped services — see `ai-admin.md` on
`site.upcoming`.

### The mirrors and their crons

`CalendarEvent`, `LectionaryDay`, `LectionaryReading`, `ClassRecording`,
`CalendarSync`, three importers and three cron jobs: **deleted.** Nothing on the
site read them. The pages are built on data sources — fetched on demand, cached
for as long as the source says, with the judgement in JavaScript.

The tables are left in place, empty of consequence. Dropping them is a separate
decision for a quiet week, and needs a dump first; the code is revertible with
git, a dropped table is not.

### A page's kind

`Page::LAYOUTS` was `%w[page bulletin]`. A layout now names a template, so a
quarterly newsletter needs a template called `newsletter`, not a developer.
`add_page` takes `layout` and `dated_on`, and the AI is told to use the
parish's own word for a thing this site has never had.

---

## What Ruby still provides, and should

- Fetching a URL safely (`Site::OutboundFetch` — a security boundary)
- Caching what was fetched, for as long as asked, `0` meaning never
- Putting data into a page as JSON (`{{ site.data.x.json_tag }}`)
- Rendering templates; revisions; publishing as a pointer flip
- Images, video frames, screenshots, PDFs — operations on bytes
- Who may sign in

None of those know what a parish is.

---

## How to tell when this has slipped

Ask of any new Ruby: **would this be wrong for a different parish?** If the
answer is yes, it is a fact and belongs in the revision.

Two signals that it has slipped already:

- A constant holding words that appear on the website.
- A method deciding which of someone's data *counts* — `scheduled_service?`,
  `noteworthy?`, `upcoming`. Filtering is judgement, and judgement in Ruby is
  judgement nobody can review.
