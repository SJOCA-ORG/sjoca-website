# Reverting, rolling forward, and what the clone actually looks like

Rehearsed 26 October 2026, on a laptop, against a verified backup.

---

## The backup

```
~/sjoca-backups/sjoca-20261026-1126.dump      455 MB
```

Restored into a scratch database: **0 errors**, and every table matched the
original — 10 revisions, 148 pages, 2,188 blocks, 261 photographs (all 261
carrying real image bytes), 163 templates, 268 messages, 1 user.

A `pg_dump` is a complete copy because the photographs live in the database.
See [`backups.md`](backups.md).

---

## The rehearsal

Three steps, each fingerprinted — every page fetched, the HTML hashed:

| | Live | Pages |
|---|---|---|
| 1. As it stands | 62 | 20 |
| 2. Revert to the Phase 1 clone | 8 | 11 |
| 3. Roll forward again | 62 | 20 |

**Step 3 came back byte for byte identical to step 1, on all twenty pages.**
Draft 63 was untouched throughout, and no photographs, messages or templates
moved. Publishing is a pointer flip and behaves like one.

`script/site_fingerprint.sh` does the measuring. It strips the CSRF token
first — that is random on every request and a fixed length, so without
stripping it **every page looks changed and none of them is.** Ten confusing
minutes were spent on that the first time; the comment in the script is there
so nobody spends them again.

---

## What the clone does NOT do

**Revision 8 is not a pixel-faithful copy of the Google Sites site.**

Compared against the Phase 1 capture, the home page differs throughout — not in
content, but in layout: text wraps at different points, photographs sit at
different sizes and positions. And the St John icon is a different picture
altogether: the Phase 1 seed used a curated image (`home-icon-st-john` v2)
rather than the one Google Sites serves. Both versions were created on 11
October, before any of the Phase 2 work, so nothing leaked backwards into an
old revision — the clone was always like this.

This is a known gap, not a regression. `CLAUDE.md` still lists "visual
comparison pass, page by page, desktop and phone" as the first unfinished item
from Phase 1. It was never done.

**So the decision at cutover is a real one:**

| | |
|---|---|
| **Serve revision 8** | Recognisably the old site, but not identical to it. Nobody is surprised by new content; a few may notice things moved. |
| **Serve revision 62** | The work the council has already been shown. Plainly different — but plainly better, and the point of the exercise. |

Reverting to 8 was always meant as the cautious option. It is worth knowing it
buys less caution than it looks like, because it does not reproduce what people
see today either.

---

## Doing it for real

```bash
# before anything
pg_dump --format=custom --no-owner --no-acl sjoca_development -f ~/sjoca-backups/sjoca-$(date +%Y%m%d-%H%M).dump

# fingerprint, change, fingerprint, compare
./script/site_fingerprint.sh > /tmp/before.txt
#   ... publish, via /admin or Revision.find(N).publish!
./script/site_fingerprint.sh > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt
```

In the admin, the same thing is "Roll back to this" on a previously published
revision. Rolling back does not discard anything: the revision you leave becomes
`superseded` and can be rolled forward to again, which is exactly what this
rehearsal did.
