# Being found

**Status:** built 20 October 2026.

Mitch's ask: that somebody searching *"orthodox church near me"* in Rochester,
or *"Orthodox church in Rochester"*, finds the parish — and that whatever makes
that work keeps working, without anyone remembering to maintain it.

---

## The thing to say first

**None of this outranks a Google Business Profile.** For "near me" searches that
listing is the single largest factor: the map pack sits above the ordinary
results, and it is populated from Business Profile, not from a website. A parish
with a claimed, accurate, photographed listing and a mediocre site will be found
ahead of a parish with an excellent site and no listing.

So: claim it, keep the address and service times right, add photographs, and
ask parishioners to review it. That is not a website task and this document
cannot do it.

What the website can do is be unambiguous about what it is, where it is, and
when it meets — and not get in its own way.

---

## What the site now does

**One address per page.** `/home` and `/` served identical content at two
addresses, which a search engine reads as two pages competing. `/home` now
redirects permanently to `/`, and every page states its canonical address.

**A title per page that is not doubled.** The home page was titled *"Saint John
the BaptistOrthodox Church — Saint John the Baptist Orthodox Church"* — the
parish named twice, with a missing space in the first. It keeps whatever the
page itself says now, without appending the parish name to a title that already
is the parish name.

**A description per page**, falling back to the parish's general one. The
fallback is the problem rather than the solution: twelve pages sharing one
sentence tells a search engine they are twelve copies of the same page.

**Structured data** — `Church`, with the postal address, the OCA as parent
body, and **the service times taken from the mirrored ChurchTrac calendar**.
That last is the part worth having: it cannot drift from what the parish
publishes, because it is not typed here at all. Today it resolves to Saturday
18:00, Sunday 10:00 and Wednesday 18:00.

**Open Graph tags**, so a link pasted into a message shows the parish name, a
sentence and a photograph instead of a bare URL.

**A sitemap generated from the published revision**, not kept as a file. A file
nobody maintains goes stale, and a sitemap naming pages that no longer exist is
worse than none. `robots.txt` names it.

**Drafts are kept out.** A preview carries `noindex, nofollow`, claims no
canonical address, and `robots.txt` disallows preview links — a draft is at a
signed address and holds words the parish has not agreed to publish, and a link
pasted into a chat is enough to get one crawled.

---

## The evergreen part

`Site::SeoCheck` runs **on the editing page, before every publish**. It reports;
it does not block and it does not fix. A description is parish writing, and a
check that rewrites prose is a check nobody trusts.

It finds:

- a page with no description of its own
- two pages sharing one description
- a title or description that will be cut off (60 and 160 characters)
- a description too short to say anything
- a page with no heading at all
- photographs with nothing said about them

The AI can act on all of it: `check_findability` reports, `set_page_description`
writes one. "Give every page its own description" is a sentence that works.

---

## Left undone, deliberately

**Coordinates.** `geo` is omitted rather than guessed. Coordinates nobody
checked put the pin in the wrong street and no one notices for a year. Set
`SJOCA_LATITUDE` and `SJOCA_LONGITUDE` from the parish's own Business Profile
listing, where they are already correct, and the structured data will carry
them.

**A telephone number.** Not on the site today. Worth adding: for a local search
a phone number is a strong signal, and for a visitor it is often what they
actually want.

**`sameAs` links** — the parish's Facebook, YouTube and Business Profile pages.
These tell a search engine that the website, the listing and the social accounts
are one organisation. The YouTube channel exists; the others need finding.
