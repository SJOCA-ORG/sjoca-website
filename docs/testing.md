# Testing

```bash
bundle exec rspec                      # everything
bundle exec rspec spec/models          # one directory
bundle exec rspec spec/requests/icons_spec.rb:12   # one example
```

The test database is prepared with `RAILS_ENV=test bin/rails db:prepare`. Note that
this **seeds** a freshly created database, so your test DB may arrive full of real
parish content — `spec/rails_helper.rb` truncates everything before the suite so that
cannot affect results.

**Every outbound HTTP request must be stubbed.** WebMock is configured to refuse real
connections. ChurchTrac, oca.org and YouTube are third parties; a test run must never
touch them.

---

## What this suite is for

It is not here for coverage. It is here because **Phase 2 hands editing to people who
cannot read the code**, and two specific things in `docs/ai-admin.md` are unsafe
without it:

- the **SuperEditor** layer, where a template change affects every page at once
- **refactoring**, which is invisible to screenshot diffs by definition — a good
  refactor changes nothing visible, so a human reviewer has nothing to look at

So the suite's job is to be the thing that stands behind a change when no one is
looking at it.

## How specs are written here

**Each spec says why it exists.** A spec that only restates the code is noise; the
comment should carry the reason the behaviour matters, usually a real consequence for
the parish. Compare:

```ruby
it "returns the newest row"                            # restates the code
it "ignores drafts, so an unapproved photo never reaches the site"
```

**Regression specs name the bug in a comment block.** Six specs exist because
something actually broke. Those carry a `THE REGRESSION THIS FILE EXISTS FOR` header
explaining the symptom, because the symptom is usually what a future contributor will
recognise, not the cause.

**Builders over factories.** `spec/support/content.rb` has `build_page`,
`build_section`, `build_block`, `build_asset` and `build_event`. They are deliberately
thin — a spec that spells out the structure it is testing reads better than one hiding
it behind a factory.

## The regressions this suite pins down

Every one of these shipped, and every one was found by accident rather than by review.
Each has been verified to fail when the bug is reintroduced — a spec that cannot fail
is worth nothing.

| spec | the bug |
|---|---|
| `requests/legacy_assets_spec.rb` | `stale?` plus `head :not_modified` renders twice → **500 on every conditional request**. The symptom was baffling: the image loaded once, broke on reload, and reappeared on back-navigation, because only the revalidating request failed. |
| `requests/icons_spec.rb` | `get "*path"` matches `"manifest"`, so the catch-all swallowed `/manifest.json` and `/service-worker.js` — which were absent from `routes.rb` anyway. Neither had ever resolved. |
| `assets/favicon_spec.rb` | The first parish mark was `#873131` on `#212121` — 1.93:1, invisible in a real tab. It looked fine at 512px, the only size anyone checked. |
| `services/church_trac/calendar_feed_spec.rb` | A HeadlessChrome User-Agent gets 302'd to ChurchTrac's marketing homepage: ~115KB of HTML that parses as zero events. A day was lost to this. |
| `services/church_trac/calendar_importer_spec.rb` | A sync that fails open would silently empty the parish calendar, and **an empty calendar looks entirely plausible**. |
| `models/section_spec.rb` | An empty section emitted an empty `grid-template-columns`. Found by this suite, not in production. |

### A note on the favicon thresholds

`assets/favicon_spec.rb` holds the cross to 4.5:1 against its ground but the flower to
only **2.0:1**. That looks lax and is deliberate. The shipped mark measures 2.17:1 and
reads perfectly well, because it is a large solid silhouette rather than sub-pixel
line-work. The version that failed measured 1.93:1 — so the floor still catches it.

The lesson is narrower than "check contrast": **contrast ratio alone is the wrong
instrument for a small icon.** Solidity mattered more than the ratio. See
`docs/favicon.md`.

## What is not covered yet

Honestly, so that nobody mistakes a green suite for a safe one:

- **No system/browser specs.** `capybara` and `selenium-webdriver` are in the Gemfile
  but unused. The responsive checks that `docs/ai-admin.md` calls for — render every
  page at 390px and 1280px, screenshot-diff, assert no horizontal overflow and every
  nav item reachable — need these. **The mobile-menu bug would still not be caught
  today.** This is the most valuable gap.
- **No specs for the YouTube or lectionary importers.** They share the ChurchTrac
  importer's fail-closed shape, so the pattern is proven, but their own parsing is not.
  `Oca::LectionaryFeed` does brace-matched JSON extraction, which is exactly the sort
  of thing that breaks silently when a third party changes a page.
- **No seed specs.** `db/seeds/content.rb` prunes orphaned pages behind
  `FORCE_CONTENT_RESEED`; that guard is untested, and it deletes things.
- **No content-presence checks against real seed data** — "service times still appear
  on the home page" is asserted against fixtures, not against what actually ships.

## Adding to it

When something breaks, the fix is not finished until a spec fails without it. Write
the spec first, watch it fail, then fix. State the symptom in a comment: six months on
the symptom is what someone will recognise, not the cause.
