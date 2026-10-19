# The weekly bulletin

**Status:** design settled 19 October 2026, building.

The parish wants to describe a bulletin the way it describes a web page, and get
three things out of it: a printable PDF, an HTML email, and a page on the site.

---

## What was decided

| Question | Answer |
|---|---|
| Published to the website? | **Yes**, as well as PDF and email |
| Imposition — the 4\|1, 2\|3 fold order | **Not ours.** The printer takes four 5.5 × 8.5 pages in reading order and imposes them |
| Bleed, crop marks | **None.** The printer does not want them |
| More than four pages | **Easy** — the printer handles any count |
| Email format | **HTML**, not RTF |
| Personal information | **Editorial, not structural** — first name and last initial only, birthdays as a date with no year. The editor and the reviewer are responsible |

The imposition answer is the one that changes the shape of the work. Four
sequential pages at a fixed size is an ordinary print stylesheet; a folded
signature is not.

---

## How it is built

A bulletin is **a page like any other** — sections, columns, blocks, Liquid
templates, revisions — with three differences.

**It has a fixed physical extent.** A web page overflows by scrolling. A
bulletin cannot: 5.5 × 8.5 is 5.5 × 8.5. So the browser check that already
measures pages at phone and desktop width also measures each bulletin page at
print size and reports what overflows. "It is finished" cannot be said while a
page does not fit.

**It is dated, and they accumulate.** Bulletins live at
`bulletins/2026-10-19`, which gives an archive for nothing — and the survey
asked for visible currency more than for anything else.

**It renders three ways from one source.** The site page, a PDF of
5.5 × 8.5 pages, and an HTML email. The email is the awkward one: mail clients
ignore external stylesheets, so its styles are inlined. That is a different
renderer, not a different document.

---

## The balance between standard fields and free text

Not a form. **A new bulletin is last week's bulletin with the dated parts
recomputed** — which is the revision model this site already runs on, pointed at
a different kind of page.

Three categories, by how often a thing actually changes:

**Computed every time, never typed**
: the day's commemoration, the appointed readings, this week's services. All
  three are already in the database, mirrored from oca.org and ChurchTrac.
  Typing them weekly is how a wrong date reaches print.

**Carried forward from last week**
: the masthead, the address, the giving line, the closing prayer. Set once.

**Written fresh**
: announcements, birthdays and anniversaries, the rector's note. The only part
  anybody actually composes.

Flexibility is preserved because it is the same block and template machinery as
the rest of the site: anything not anticipated is a new block kind, and the AI
can add one.

---

## The thing to watch

The bulletin can legitimately contain what the website must not. The current
one reads "Birthdays: Sonya T. (10/16)" — a parishioner's name and date, which
is exactly what CLAUDE.md says keeps off a public site.

Mitch's decision is that this is **editorial**: first name and last initial,
dates without years, checked by the editor and the reviewer. That is a
reasonable call for a parish that knows its own people.

Worth adding anyway, because it is cheap and it is what the mechanism is for: a
**standing promise that no bulletin shows a four-digit year beside a birthday**.
A promise is a check, not a restriction — it cannot stop anyone writing
anything, but it will say so before it is published. A surname is not reliably
detectable; a birth year is.

---

## Order of work

1. Bulletin pages — dated, under one parent, with a print stylesheet at
   5.5 × 8.5
2. "Make this week's bulletin" — copy last week's, recompute the dated parts
3. The fit check, at print size
4. PDF out
5. HTML email out

Chrome does the PDF, over the same connection that already drives the layout
checks. No new dependency — but see `docs/TODO.md`: Chrome, ImageMagick and
ffmpeg are all missing from Render's native Ruby runtime, and this makes a
fourth reason to settle that once.
