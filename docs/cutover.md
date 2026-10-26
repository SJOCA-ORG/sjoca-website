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

---

## Shrinking the database before it goes to a server

Done 26 October 2026, before the first copy up.

**843 MB, of which 827 MB was photographs** — on a Postgres plan whose storage
is measured in gigabytes. Two separate problems behind that figure:

- **Photographs stored at phone resolution.** 4000x3000 at six or seven
  megabytes each, 56 of them over 4 MB. The site never draws a picture wider
  than about 1280 points, so every one of these was roughly ten times larger
  than anybody would ever see — and every page view pulled the whole file.
- **Dead rows.** 408 MB of live photo bytes sat in an 827 MB table. Most of the
  difference was the 216 duplicate uploads deleted a week earlier, whose space
  Postgres had not reclaimed.

### What was done, in this order

1. **`script/export_photo_originals.rb`** wrote all 261 photographs out at full
   resolution to `~/sjoca-photo-library/from-database/`, with a manifest naming
   each one's original size, hash and alt text. **This matters:** for anything
   uploaded through the editor the database was the only copy, so reducing it
   without this would have destroyed the originals of parish photographs.
2. **Intake now shrinks on arrival** — longest side 2000, and only ever
   shrinks, so a small picture is left exactly as it is rather than blown up
   into a blurry larger one. Two specs pin both halves.
3. **`script/shrink_stored_photos.rb`** did the same to what was already there:
   90 of 261 reduced, 408 MB to 169 MB, in place rather than as new versions —
   it is the same photograph, so a page pointing at version 2 should go on
   meaning version 2.
4. **`VACUUM FULL`** reclaimed the dead space.

### The result

| | |
|---|---|
| Database | **843 MB → 189 MB** |
| Photographs | 408 MB → 169 MB of bytes, 827 MB → 177 MB of table |
| Pages | all 20 still render, all photo references still resolve |
| Originals | 409 MB, safe in the photo library with a manifest |

Checked by looking at the pictures afterwards, not only by counting bytes.
