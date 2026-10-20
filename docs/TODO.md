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

### Clearing pre-flight findings — before DNS cutover

A pre-flight run over a draft (render every page, resolve every photo
reference, check the data sources) reports things that are *latent* rather than
broken. Two came up against draft 54 on 20 October, both invisible on screen:

- **`/education-resources` renders 3 bytes.** A real page with a nav entry, no
  hero, no sections, no blocks. Nothing on the site links to it — the header
  template routes a childed parent with a blank `self_nav_title` straight to
  `item.children.first.path`, so the menu points at
  `/education-resources/adult-education` instead. It is reachable only by
  typing the address. **But `sitemap.xml` lists every page unconditionally**, at
  priority 0.8 for a top-level one, so publishing hands Google a blank page as a
  high-priority URL. That cuts against "Being found in a search" below.
- **A hero reference pointing at nothing.** `/education-resources/daily-lectionary`
  carries `hero_asset_name = ""` with `hero_asset_version = 54`. The *name* does
  the lookup, so `hero_photo` is nil, the `{% if page.hero_photo %}` guard drops
  the `style` attribute, and the hero falls back to the default gradient —
  which looks deliberate. The orphan is the version number with no name beside
  it.

Neither matters while the site is on a machine or a preview URL. Both matter
the day `sjoca.org` points here. What needs deciding:

- [ ] **A page with no content should not reach the sitemap.** Either skip
      empty pages when building `sitemap.xml`, or make "empty + in nav" a thing
      the editor must resolve before publishing. Leaning towards the first:
      a nav-only parent is a legitimate shape, it just isn't a destination.
- [ ] **`hero_asset_version` without a `hero_asset_name` should not be
      storable.** Clear it when the name is cleared, or validate the pair. Right
      now it survives as a reference that every future check will report.
- [ ] **Pre-flight needs a way to say "known, accepted."** Otherwise the same
      two findings are read and re-reasoned about on every publish, and the
      real one gets lost among the ones already judged harmless. A suppression
      list keyed by page and finding, recorded with *who* accepted it and
      *when*, is probably enough — the point is that a finding either gets
      fixed or gets a signature, never just ignored.

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

## Developer environment

Nothing here is urgent, but all of it bites the *second* contributor rather than
the first, which is exactly the person this project needs.

- [x] **Pin the language versions.** Done 14 Oct 2026 — `.ruby-version` was the
      literal word `system`, which pins nothing. Now `3.4.7`, with a matching
      `ruby` directive in the Gemfile and `.node-version` at 24.

- [x] **Write `docs/development.md`.** Done 14 Oct 2026. Covers the previously
      undocumented `magick` / `potrace` / `rsvg-convert` / Chrome dependencies,
      both routes to getting content, and the Postgres version trap.

- [ ] **A `.devcontainer/` falls out of that work nearly free**, and then
      Codespaces becomes a valid environment without anything being designed
      around it — which is the point: tier-2 environment choice is the
      developer's, not the architecture's.

- [x] **Postgres 18 locally.** Done 14 Oct 2026 — was 14.19, client and server.
      `postgresql@18` installed and linked, 14 stopped and unlinked, local data
      dumped first and restored into 18 intact. Docker was considered and set
      aside; cross-platform work is theoretical for now.

- [x] **Write `bin/pull-production-db`.** Done 14 Oct 2026 and tested end to end
      against production (40MB, 13 pages / 122 blocks / 122 photographs). Needed
      to build Phase 2 at all, not
      just at the first tier-2 change — revision, preview and template work all
      want realistic content and real photographs. A `pg_dump` is a complete
      copy precisely because photo bytes live in the table, so this is one
      script against Render's external connection string.

      **The dump is the most sensitive artifact this project produces.** It
      contains every parish photograph, children included, and it lands on
      developer laptops. It must default to a gitignored directory, and the
      docs must say plainly what the file is. (`.gitignore` now covers `*.sql`
      as well as `*.dump` and `*.sql.gz` — plain `.sql` was missed, and this
      repo is public.)

## From the ai-admin.md review (14 Oct 2026)

- [x] **Rename `legacy_assets` to `photos`.** Done 14 Oct 2026. Table, model,
      controller, route helper, seed file and specs. The `asset_name` /
      `hero_asset_name` columns were deliberately left alone — they do not say
      "legacy", and renaming them would mean rewriting 30 keys in `content.yml`.
      The public URL `/media/:human_name` is unchanged, so no links broke.

- [ ] **Image tools for the admin.** Crop, resize, rotate, feather or mask edges,
      convert format, generate responsive sizes — each producing a *new* photo
      record rather than overwriting. Same operations used throughout this
      project's own image work. Without these an editor has to find someone with
      Photoshop before they can use a photograph.

- [ ] **The AI opens a GitHub issue when it cannot do something**, quoting the
      request verbatim. Turns unmet needs into a prioritised list written by the
      people who hit them, instead of a developer guessing. A pull request is the
      natural next step and a bigger job; the issue is most of the value.

- [ ] **Derive the minimum Liquid macro set** from the current site, for review
      *before* the replay test begins. Minimum is the point — a large vocabulary
      proves nothing. This list is the design of what must exist before the test
      can start.

## A general way to pull in outside data

Mitch's idea, 14 October 2026. **Built 17 October 2026.**

- [x] **One server-side fetch primitive, instead of per-feed Ruby.** Done:
      `DataSource` (a revision row: a name and one or more https addresses),
      `FetchedPage` (the cache, keyed by URL and shared across revisions), and
      `site.data.<name>.json_tag`, which writes the payload into the page as
      `<script type="application/json">`. JavaScript and CSS written through the
      admin do the rest. `add_data_source`, `peek_data`, `list_data_sources`
      and `remove_data_source` are the tools.

      `site.calendar`, `site.upcoming`, `site.recordings` and `site.lectionary`
      were deleted along with their templates and 231 lines of CSS. The reason
      was sharper than "less Ruby": `site.upcoming` silently excluded every
      regularly scheduled service, its entire description to the AI was
      "notable events in the coming week", and a home-page box got built on it
      with no Vespers and no Divine Liturgy. Judgement buried in Ruby cannot be
      read, questioned or rolled back.

- [ ] **The claim that this covers all three mirrors is WRONG, and that
      matters.** Checked 17 October, after the primitive was built:

      | mirror | what it actually serves |
      |---|---|
      | ChurchTrac | plain JSON — covered, verified against the live feed |
      | YouTube | an HTML page, with `var ytInitialData = {...}` brace-matched out of ~1MB of markup |
      | OCA lectionary | HTML pages, one per day — an index plus a crawl 30 days ahead |

      Only ChurchTrac is a clean fit. The other two need the fetched bytes
      PARSED before there is any JSON to hand over, and the lectionary is not
      one URL at all. Two routes, neither built:

      - the page's own JavaScript parses the raw bytes — `DOMParser` on the
        readings pages, a brace match on the playlist. Works, but ships ~1MB of
        HTML to every visitor on that page.
      - a server-side transform: AI-written JavaScript, a pure function of
        bytes to JSON, run once per refresh in a sandbox with **no network and
        no filesystem**. Keeps the payload small and keeps every outbound
        request inside the one guard.

      The second is better and is more work. Until one of them exists,
      `ClassRecording` and `LectionaryDay` keep their importers. The ChurchTrac
      mirror and its cron job are now redundant (the cache's serve-stale covers
      the argument that justified mirroring) but are left in place until the
      replay test has actually rebuilt the calendar.

- [x] **The SSRF guard.** `Site::OutboundFetch`. HTTPS only; every address the
      host resolves to checked against the private, loopback, link-local,
      carrier-NAT and reserved ranges; re-checked after each redirect; no
      cookies or credentials; size and time caps; text and data content types
      only. 17 specs, one per attack — including the redirect-to-127.0.0.1
      bypass, which is the one people ship.

- [x] **Domain policy: open, but surfaced at review.** `Revision#new_domains`
      drives a panel on the approval screen naming any domain this revision
      fetches from that the live site does not.

- [ ] **Decide whether to serve a stale payload silently.** Today a fetch
      failure with a cached copy serves the copy and sets `.stale`, and nothing
      makes a template mention it. Right for a brief outage, wrong if a feed
      moves and the site shows last month's services for a month. Wants a
      staleness bound, and something visible past it.

## Binaries the admin needs, which the server may not have

- [ ] **ffmpeg and ImageMagick are not in Render's native Ruby runtime, as far
      as we know.** Both are used by the admin and neither is a gem:
      ImageMagick for every photo operation, ffmpeg to take a still out of an
      uploaded video.

      Both fail gracefully rather than crashing -- the upload is refused with
      "video cannot be read on this server" and photo editing says what it
      cannot do -- but on a server without them half the admin is quietly
      unavailable, which is worse than it sounds because nobody would know why.

      This is the same decision as the browser checks: `runtime: ruby` cannot
      install system packages, so it means the Docker runtime, which Mitch has
      already noted needs 2GB. Worth settling once for all three rather than
      three times.

      Until then: a developer machine has them, and the replay test runs there.

## Being found in a search

Built 20 October 2026 — see [`docs/seo.md`](seo.md) for what the site now does
and why. These are the parts that need somebody other than a developer.

- [ ] **Claim and keep the Google Business Profile.** This outranks everything
      the website can do. For "near me" the map pack sits above the ordinary
      results and is populated from that listing, not from any markup. A parish
      with an accurate, photographed listing and a mediocre site is found ahead
      of a parish with an excellent site and no listing. Address, service times,
      photographs, and parishioner reviews.

- [ ] **Set `SJOCA_LATITUDE` and `SJOCA_LONGITUDE`.** The structured data omits
      coordinates rather than guessing them — coordinates nobody checked put the
      pin in the wrong street and no one notices for a year. They are already
      correct on the Business Profile; copy them from there.

- [ ] **Put a telephone number on the site.** There is none anywhere today. For
      a local search it is a strong signal, and for a visitor deciding whether
      to come on Sunday it is often the thing they actually want.

- [ ] **Find the parish's other addresses for `sameAs`** — Facebook, the
      YouTube channel, the Business Profile listing. These tell a search engine
      that the website, the listing and the social accounts are one
      organisation. The YouTube playlist is already known; the rest are not.

- [ ] **The home page title says "Saint John the BaptistOrthodox Church"** — no
      space, and that is the parish's own page title rather than anything the
      code does. Left alone deliberately: it is content, not a bug, and not
      mine to rewrite silently. One sentence to the admin fixes it.

- [ ] **Twenty-five findability problems are listed on the editing page**
      before every publish, most of them pages with no description of their own.
      `Site::SeoCheck` reports and does not fix, because a description is parish
      writing. "Give every page its own description" is a sentence that works.

## Before the parish sees the admin

- [ ] **Take the cost meter off the admin page.** Added 17 October while the
      question was "can a parish afford to edit its own website". A volunteer
      editor should not be watching a till run while they fix a typo, and a
      price per change is an invitation to hesitate over small corrections,
      which is the opposite of what this is for.

      Only the display comes out. The usage is kept on every message either
      way, every turn writes a line to the Rails log, and `Admin::Cost` adds up
      a revision — so whoever is answering to the council can still get a
      figure without anyone having to watch one.

## The admin chat window

Noted by Mitch during the replay test, 17 October 2026. Not urgent.

- [x] **The progress box should be a fixed size and scroll inside itself.**
      Done 17 October, along with the two-pane workbench below.
      Today it grows as the turn goes on, so the page gets longer and longer
      and the useful parts leave the screen.

      It should fill the available height and stay there, with the transcript
      scrolling within it, so that two things stay visible without the reader
      chasing them:

      - **the newest messages, pinned to the bottom** — that is where the turn
        actually is, and it is what you want to read
      - **the bar at the top showing that work is in progress** — scrolled off,
        there is no sign anything is happening

      A long turn is thirty steps. Watching one at the moment means scrolling
      down to find the end and losing the "working" indicator on the way.

- [x] **Two panes: controls and conversation left, the actual page right.**
      Also Mitch, same day. The left column is 27rem and holds the buttons, the
      review cards, the conversation and the input; the right is an iframe of
      the draft with a page selector and a Desktop/Phone toggle. Phone is 390px
      — the same width the automatic browser check uses, so what you see is what
      it saw.

      Which page and which width are remembered per revision in localStorage,
      because a finished turn reloads the page and losing your place on every
      reply would make the pane useless. The preview iframe is loaded with
      `bare=1`, which drops the "you are looking at a draft" banner: the pane
      already says so, and at phone width the banner was a sixth of the screen
      you are trying to judge.

- [x] **The preview pane follows the conversation.** When a reply says which
      page it changed, the pane goes there -- once. The reply's id is
      remembered as followed, so you can click elsewhere afterwards and stay
      there. The page selector is gone: you navigate by clicking the site, as a
      visitor would, and the bar just says where you are.

## Known gaps

- [ ] **No browser specs, so the mobile-menu class of bug is still invisible.**
      `capybara` and `selenium-webdriver` are in the Gemfile and unused. The
      responsive checks `docs/ai-admin.md` calls for — every page at 390px and
      1280px, no horizontal overflow, every nav item reachable — need them.
      This is the largest gap in the suite; see `docs/testing.md`.

- [ ] **`legacy_assets.byte_size` and `calendar_events.synced_at` are NOT NULL
      at the database but neither defaulted nor validated by their models.**
      Every current caller sets them by hand, so nothing is broken today — but
      a programming error surfaces as a `PG::NotNullViolation` 500 rather than
      a validation failure, and `byte_size` is just `data.bytesize`, computed
      in two seed files that could drift apart. Phase 2 will have the CMS (and
      the AI) creating assets, so a `before_validation` that derives it would
      remove the footgun. Found while writing the specs.

- [ ] **No specs for the YouTube or lectionary importers.** They share the
      ChurchTrac importer's fail-closed shape, so the pattern is proven, but
      their own parsing is not — and `Oca::LectionaryFeed` does brace-matched
      JSON extraction off a page we do not control.

- [ ] **`FORCE_CONTENT_RESEED` orphan pruning is untested**, and it deletes
      pages.

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
