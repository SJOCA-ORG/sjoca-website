# ChurchTrac calendar integration

**Status:** Built and working — 2026-10-11

The parish keeps its calendar in ChurchTrac, and that does not change. This
mirrors it into our database so the site can render services in its own style,
show the next service anywhere, survive ChurchTrac being slow or down, and
eventually publish an iCal feed people can subscribe to.

---

## There is no scraping

ChurchTrac's embedded widget is FullCalendar, backed by a plain JSON endpoint:

```
GET https://www.churchtrac.com/calendar_events
      ?source=public
      &church_ui=AE8E0B4D
      &start=2026-10-01
      &end=2026-11-01
```

Each event looks like this:

```json
{ "id": "103", "UID": "g986a22…@ctonline", "title": "Divine Liturgy",
  "start": "2026-10-11 10:00:00", "end": "2026-10-11 11:30:00",
  "allDay": false, "recurring": "1",
  "location": "855 South Goodman (St. John's)", "notes": "",
  "calendar": "Church Calendar" }
```

`church_ui` is not a secret — it is visible in the embed on the current site —
so it lives in `config/initializers/church_trac.rb` rather than credentials.

---

## Four things that will catch you out

**A plain request gets 403, and a headless browser gets redirected.** Their load
balancer rejects requests without a browser-like `User-Agent`, and anything
identifying as HeadlessChrome is 302'd to ChurchTrac's marketing homepage —
which returns 115KB of HTML that parses as zero events.

This cost us real time and produced a wrong conclusion. Screenshots of the
current site taken with headless Chrome showed *"No events to display"*, and we
believed for a while that the parish calendar was empty. It never was. With an
ordinary desktop User-Agent the same page renders nineteen events in October.
Hence `CalendarFeed::USER_AGENT`, and hence a non-JSON response raises rather
than being treated as "no events".

**`start` and `end` are a hint, not a filter.** Asking for October returns
events from months either side, so we filter after fetching.

**Times have no timezone and are local.** `"2026-10-11 10:00:00"` is 10am in
Rochester. The app sets `config.time_zone = "America/New_York"` for this reason;
parsed as UTC the Divine Liturgy would appear at 6am.

**`id` and `UID` identify a series, not an occurrence.** They are 1:1 — 291 of
each across 869 events — because recurring services share them. The occurrence
key is `(id, start)`, which is unique across the entire feed. That pair is the
natural key, and it is what makes re-syncing idempotent instead of duplicating.

---

## How the mirror behaves

```
bin/rails churchtrac:sync      # fetch and apply
bin/rails churchtrac:status    # what we hold, when it last ran
```

**Window: one month back, twelve months forward.** A month behind keeps the
current month whole; we never backfill further. The past does not change, and
re-fetching it could only risk rewriting it.

**Inside the window the mirror is authoritative.** An event cancelled in
ChurchTrac disappears here too, so a cancelled service cannot linger on the
site. Outside the window nothing is touched.

**It cannot empty the calendar by accident.** This is the part worth protecting,
because a failed import and a parish with nothing scheduled look identical from
the front of the site:

| Upstream behaviour | What happens | Events deleted |
|---|---|---|
| Normal response | applied | only genuinely cancelled ones |
| Redirect to homepage / non-JSON | `failed` | none |
| Valid but empty response | `refused` | none |
| Network error or timeout | `failed` | none |

**Every run is logged** to `calendar_syncs` — status, counts, duration, and the
error if any. `CalendarSync.stale?` reports whether anything has succeeded in
the last two days, which is what an admin staleness indicator should read.

---

## Running it regularly

Not yet scheduled. Once there is a host, this wants to run a few times a day —
cron, a scheduled job, or whatever the platform offers:

```
bin/rails churchtrac:sync
```

The task exits non-zero on failure so a wrapper notices.

**A manual "refresh now" button in the admin should be an override, not the
mechanism.** If the calendar is only as fresh as the last time somebody
remembered to press something, we have rebuilt the problem we are solving.

---

## What this makes possible

- Services rendered in the parish's own styling rather than inside an iframe
- *"Next service: Sunday 10am"* on the home page, in the footer, anywhere
- The weekly services section of the bulletin, filled in automatically
- An iCal feed so people can subscribe in their own phone calendars
- A calendar that still displays when ChurchTrac is unavailable

The bulletin is the one worth noting: its Weekly Services block is exactly this
data, and generating it removes a chunk of the work a volunteer currently does
by hand.
