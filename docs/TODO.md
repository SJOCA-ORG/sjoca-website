# Open items

Running list of things deferred, with enough context to pick up cold.
Newest decisions at the top of each section.

---

## Before the AGM (15 November 2026)

- [ ] **Deploy to a server at a private URL.** Not sjoca.org — that switch comes
      only if the parish approves at the AGM.
- [ ] **Seed the photos into production from a developer machine.** The image
      bytes live in `reference/current-site/images/`, which is gitignored, so a
      fresh clone on the server has the manifest but no pixels:
      `DATABASE_URL=<production> bin/rails db:seed`. After that production holds
      them and ordinary deploys skip the step.
- [ ] **Schedule the ChurchTrac sync** — `bin/rails churchtrac:sync`, a few times
      a day. See `docs/churchtrac-integration.md`.
- [ ] **Bulletin builder.** The only work non-technical volunteers do today, so
      it is the parity milestone and the heart of the AGM demonstration.
      *Waiting on:* how the bulletin is produced now, who makes it, whether it
      goes out by email through ChurchTrac, and whether past issues are kept.
- [ ] **Page-by-page visual comparison** against the old site, desktop and phone.
- [ ] **Rehearse the AGM demo** against the real deployment.

## Leadership page — open questions

Council changed over and the page is updated as far as it can be. Still needed:

- [ ] **Parish email addresses for everyone who needs one.** Volunteering
      enquiries currently go to `mitch@catprint.com`, a work address on a public
      parish page: it ties parish business to an employer's mail system, breaks
      if he changes jobs, and gets scraped alongside the parish ones. The
      pattern already exists — Dn Sean has `deacon@`. Role addresses that
      outlive the people holding them, for Dn Mitch and anyone else listed.
- [ ] **Alec's surname.** Listed as "Alec" alone, which is the only entry on the
      page without a full name.
- [ ] **Confirm the email addresses follow the office, not the person.**
      warden@, asstwarden@, secretary@ and treasurer@ look like role addresses,
      so the page now assumes Heather takes warden@ on becoming President rather
      than carrying asstwarden@ with her. If they are actually personal
      aliases, three entries are wrong.
- [ ] **Two domains are in use.** warden@, asstwarden@, secretary@ and
      frdavid@ are all @sjoca.org; treasurer@ and deacon@ are
      @stjohnthebaptistorthodox.org. Probably historical, worth settling.
- [ ] **What happened to Steve F.?** Removed as President. Off the council, or
      in another role?
- [ ] **Does Heather keep "Matushka" in a lay office?** The page used it when
      she was Vice President, so it is kept, but it is the parish's call.
- [ ] **Photographs needed:** Heather (hers is a 271x233 family snapshot that
      cannot be cropped usefully), Alec (none at all), and eventually the
      Buildings & Grounds pair. Ten minutes at coffee hour would settle all of
      them.

## The domain, and getting live

Established by inspection on 2026-10-12 — no account access needed:

| | |
|---|---|
| Registrar | **Amazon Registrar** (registrar.amazon.com) |
| DNS | **AWS Route 53** (ns-118.awsdns-14.com and three others) |
| Registered | 21 January 2021 |
| **Expires** | **21 January 2027** |
| Web | `www.sjoca.org` → CNAME → `ghs.googlehosted.com` (Google Sites) |
| Mail | Google Workspace (`aspmx.l.google.com`) |

So somebody holds an **AWS account** containing the domain and Route 53, and a
**Google Workspace** account for @sjoca.org mail. Both are needed before
cutover, and neither is in our hands yet.

- [x] ~~Find who holds the AWS account~~ — **in progress with AWS Support**,
      case opened 12 October 2026. Mitch is already the registrant contact: the
      January 2026 "confirm your contact information" email for sjoca.org was
      sent to mitch@catprint.com. But the domain does not appear under the
      account he can log into, so AWS is being asked which account holds it.
      (Worth re-checking the region while waiting — the Registered Domains
      screen only renders in us-east-1 and shows an empty list everywhere else.)
- [ ] **Find who holds Google Workspace admin.** Mail must keep working through
      and after the move; it is independent of the website, but only if nobody
      edits the MX records by accident.
- [ ] **Renewal is 21 January 2027**, roughly two months after the AGM. Confirm
      it is on auto-renew with a card that has not expired. Parishes lose
      domains this way.

### sjoca.org does not resolve without the www

A live fault on the current site, not something we introduced:

```
http://sjoca.org        no response
https://sjoca.org       no response
http://www.sjoca.org    301 → https://www.sjoca.org/   ✓
```

There is a CNAME on `www` and nothing on the apex. Anyone who types
`sjoca.org` — which is how it is said aloud, and probably how it is printed —
reaches nothing at all. Worth fixing in Route 53 now, independent of this
project, and must be right at cutover.

- [ ] **Make the bare domain work**, redirecting to www (or the other way).

### Getting live on a temporary URL

- [x] ~~Choose a host~~ — **Render**, decided 12 October 2026.
- [ ] **Deploy it.** Blueprint is written (`render.yaml`) and the steps are in
      `docs/deployment.md`. Needs a Render account, the repo connected, and
      `RAILS_MASTER_KEY` set by hand. Roughly $14/month for web plus database —
      the figure the council is being asked to approve.
- [ ] **Seed production from a machine that has the photo library.** The image
      bytes are not in git, so the server cannot do this itself:
      `DATABASE_URL=<production> bin/rails db:seed`.
- [ ] **Schedule the three syncs** once deployed: `churchtrac:sync`,
      `classes:sync`, `lectionary:sync`.

## Known gaps

- [ ] **The jurisdiction appears only on the home page.** "A parish of the
      Orthodox Church in America (OCA), Diocese of New York and New Jersey" is
      in the mission statement and the maroon band, and nowhere else — so
      anyone landing on Contact, Adult Education or Leadership sees no
      jurisdiction at all. The footer is the obvious home for it, since it
      appears on every page and already carries the address.

- [ ] **Move the photo library to shared storage** (Google Drive), and point
      `SJOCA_PHOTO_LIBRARY` at it. Today it exists on one laptop, is not backed
      up, and a second developer cloning the repo gets "missing" for every
      curated asset. Agreed approach; not yet done.
- [ ] **The admin preview must bypass the image cache.** Asset URLs are stable
      by design, so a five-minute cache window means a parishioner can replace a
      photo and not see the change — which reads as a broken CMS rather than a
      cache. Caught by looking for exactly that.

- [ ] **Allow embedding on the YouTube classes.** The Adult Education page is
      built to play the class recordings inline, but all three videos refuse:
      *"Playback on other websites has been disabled by the video owner."*
      Confirmed — YouTube's oEmbed endpoint returns `Unauthorized` for every one.
      Fix is in YouTube Studio, per video or as a channel default: Edit →
      Advanced settings → **Allow embedding**. Until then the page links out to
      the playlist instead, which works but sends people away from the site.
      Playlist: `PLQsSPU5CSGtY` ("Catechumen Classes 2026-2027").

- [ ] **Site search.** Google Sites gives the parish a search box today and the
      rebuild does not. A regression, not a missing feature — nobody will notice
      until after cutover, when they cannot find the bulletin.
- [ ] **Redirects.** `/events-services/miter-ceremony` now 404s. No redirect
      mechanism exists yet; it is a Layer 1 requirement in
      `docs/cms-capabilities.md`. Moving a page must leave a redirect behind, or
      every inbound link breaks invisibly — and this parish prints QR codes.
- [ ] **Image dimensions.** `<img>` tags carry no width/height, so the browser
      cannot reserve space. Causes layout shift, and with lazy loading can stop
      images loading at all on long pages.
- [ ] **Service times are duplicated** — home page, Events & Services hero, and
      the footer's address. Exactly the duplication the Settings resource is
      meant to end. One place, rendered everywhere.

## Decisions to revisit

- [ ] **Scheduling: Render cron now, Solid Queue later.** The three syncs run as
      Render cron jobs defined in `render.yaml`. Rails 8's own answer is Solid
      Queue with recurring tasks in `config/recurring.yml`, which this app does
      not have — the app was generated with `--skip-solid` to stay lean, and by
      the time scheduling came up the Rails option no longer existed. The choice
      followed from that rather than being made.

      For three independent, idempotent, six-hourly syncs external cron is a
      reasonable fit: it costs pennies, nothing runs between times, and failures
      show in Render's dashboard where a volunteer will actually see them.
      Retries buy little when the next run is hours away and each job already
      refuses to apply bad data.

      **What changes the answer:** the bulletin builder needs background jobs
      regardless — it generates a PDF and an email, neither of which belongs in
      a web request. So Solid Queue is coming. When it does, move the three
      syncs into `config/recurring.yml`: one place for all scheduled work, and
      a schedule that survives leaving Render.

## Worth doing, not urgent

- [ ] **Decide where the daily readings go.** The mechanism is built and
      syncing (`bin/rails lectionary:sync`) — today plus three weeks, with full
      verse text and the day's commemorations. Nothing displays them yet. The
      obvious homes are the home page, a page of their own, and the weekly
      bulletin, whose readings section this fills in automatically.
- [ ] **Schedule `lectionary:sync`** with the other two syncs.

- [ ] **Schedule `bin/rails classes:sync`** alongside the calendar sync, so new
      classes appear without anyone touching the site.
- [ ] **Class thumbnails are Zoom stills of named parishioners in their homes.**
      Already public on YouTube, so this is not new exposure — but the parish
      website gives them far more prominence than a playlist does. Worth a
      glance from Fr David, and the same question the photo consent work asks.

- [ ] **Consistency checks** — page copy against the calendar, duplicated facts,
      dead links, orphaned assets, sync freshness. Designed in
      `docs/cms-capabilities.md`; every check corresponds to something that
      actually went wrong while building this.
- [ ] **Replace the placeholder icons.** The Daily Lectionary rotates a
      different icon each day, currently four public-domain images from
      Wikimedia Commons (each licence checked individually; credits in the
      photo library at `icons-of-the-day/CREDITS.tsv`). A photographer is
      booked to shoot the parish's own icons — drop those into
      `icons-of-the-day/` as `icon-of-the-day-NN` and the rotation lengthens on
      its own. These are placeholders: replace them rather than adding more.
- [ ] **"Our Icons" page under About Us**, once those photographs exist.
- [ ] **Photo archive page.** 81 photos sit in the database unreferenced.
      `db/seeds/photo_archive.yml` groups 76 of them by the event they belonged
      to — St Nicholas Day 2023, Youth Day at Seabreeze, Volunteer Weekends, the
      Miter Ceremony. Without that file their names say nothing.
- [ ] **iCal feed**, so people can subscribe to parish services in their own
      phone calendars. Nearly free now the events are rows in our database.
- [ ] **"Next service" on the home page**, drawn from the calendar rather than
      typed.
- [ ] **Recent event photographs** to replace the 2023 ones. The parish is
      looking.
- [ ] **Photo rotators** — agreed, but never auto-advancing.
- [ ] Apply the outstanding edits to `IMPLEMENTATION-PLAN.md`: the 15 November
      date, the consent table design, and removing the staging section.

---

## Parish archive — not a website concern

A distinction worth keeping: **the website is for someone deciding whether to
visit this Sunday. The archive is for whoever writes the centenary history.**
Different audiences, different lifetimes, different storage. Material does not
belong on the site merely because it is important.

- [ ] **Miter Ceremony document.** The page we retired was not a photo album. It
      carried a biography of Fr Ken James Stavrevsky including his marriage to
      Natalie Eskoff, an explanation of what a miter is and its history, and an
      account of Archbishop Michael presenting it during Divine Liturgy.
      Produce a document from that content and the 23 photographs, store it in
      Google Docs, and print a copy. This is the sort of thing that is
      impossible to find in forty years when somebody is assembling the
      hundred-year anniversary.
      *Source:* `db/seeds/photo_archive.yml`, and the full text in git at
      `git show 0b9ce70^:db/seeds/content.yml`.

- [ ] **Proto-Deacon Stephen.** Removed from the Leadership roster, having
      died, and so currently leaves no trace on the site. The parish clearly
      felt his loss — the photo library holds three photographs from his funeral
      and one captioned "in memory of". Whether he is commemorated on the site,
      in the archive, or both is for Fr David to say; the point is that a
      deletion should not be the whole answer.
      *Source:* `~/sjoca-photo-library/historical/historical-*-dn-steven*.jpg`

Candidates for the same treatment as they come up: anything retired from the
site that records who was here and what happened.
