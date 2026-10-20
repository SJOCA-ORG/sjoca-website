#!/usr/bin/env python3
"""Ring numbered areas on a page screenshot, with a legend beside it.

For the AGM walkthrough: show the old site with the problem areas ringed and
numbered, talk through them, then switch to the live new site.

Spec is JSON so the callouts are data, not code:

    {"image": "...png", "out": "...png", "title": "Home page — as it is today",
     "callouts": [{"box": [0.08, 0.49, 0.36, 0.72], "text": "..."},
                  {"point": [0.9, 0.97], "text": "..."}]}

Boxes and points are FRACTIONS of the image (left, top, right, bottom), so a
spec written against a thumbnail lands correctly on the full-resolution shot.

Two things the layout has to survive:

  * The output must be LANDSCAPE and legible on a small laptop. These captures
    are 1440 wide and anywhere from 2400 to 11573 tall, so a page is sliced
    into as many columns as it takes to fill the frame rather than being shrunk
    to a thread.

  * Rings are drawn at full resolution and then scaled down with the page, so
    every stroke and badge is multiplied by 1/scale first. Drawn at their
    nominal size they arrive three pixels thick and invisible.
"""
import json, subprocess, sys, textwrap

FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
INK  = "#00A8E8"          # cyan: the site is red and white, so nothing clashes
HALO = "#003049"          # dark outline, so the cyan survives a light background

OUT_W, OUT_H = 1920, 1080
LEGEND_W     = 640
GUTTER       = 10         # between sliced columns, at output scale
MAX_COLS     = 4
PAD          = 30


def size(path):
    out = subprocess.run(["magick", "identify", "-format", "%w %h", path],
                         capture_output=True, text=True, check=True).stdout
    return tuple(int(n) for n in out.split())


def blank_runs(path, min_run=180):
    """Rows of near-white, as (top, bottom) pairs.

    These captures run to a fixed 2400px whatever the page needed, so a short
    page ends in a field of white that does not exist in a browser. Shown on a
    slide it eats half the frame and reads as though the site had a hole in it.

    Averaging each row to one pixel is enough: a row carrying any part of the
    page -- or any part of a ring drawn over it -- is not white.
    """
    out = subprocess.run(["magick", path, "-resize", "1x!", "-depth", "8", "txt:-"],
                         capture_output=True, text=True, check=True).stdout
    white = []
    for line in out.splitlines()[1:]:
        try:
            rgb = line.split("#")[1][:6]
        except IndexError:
            continue
        white.append(all(int(rgb[i:i+2], 16) >= 250 for i in (0, 2, 4)))

    runs, start = [], None
    for i, is_white in enumerate(white + [False]):
        if is_white and start is None:
            start = i
        elif not is_white and start is not None:
            if i - start >= min_run:
                runs.append((start, i))
            start = None
    return runs


def collapse_blanks(src, dst, keep=40):
    """Squeeze every long blank run down to a thin gap."""
    runs = blank_runs(src)
    if not runs:
        return src, 0

    W, H = size(src)
    pieces, cursor, removed = [], 0, 0
    for n, (top, bot) in enumerate(runs):
        if top > cursor:
            piece = f"{dst}.keep{n}.png"
            subprocess.run(["magick", src, "-crop", f"{W}x{top-cursor}+0+{cursor}",
                            "+repage", piece], check=True)
            pieces.append(piece)
        gap = f"{dst}.gap{n}.png"
        subprocess.run(["magick", "-size", f"{W}x{keep}", "xc:white", gap], check=True)
        pieces.append(gap)
        removed += (bot - top) - keep
        cursor = bot
    if cursor < H:
        piece = f"{dst}.keeplast.png"
        subprocess.run(["magick", src, "-crop", f"{W}x{H-cursor}+0+{cursor}",
                        "+repage", piece], check=True)
        pieces.append(piece)

    subprocess.run(["magick"] + pieces + ["-append", "+repage", dst], check=True)
    subprocess.run(["rm", "-f"] + pieces, check=True)
    return dst, removed


def columns_for(w, h, avail_w):
    """How many slices make the page fill the frame without overflowing it."""
    for n in range(1, MAX_COLS + 1):
        col_h = h / n
        col_w = w * OUT_H / col_h            # each slice scaled to the full height
        if n * col_w + (n - 1) * GUTTER > avail_w:
            return max(1, n - 1) if n > 1 else 1
    return MAX_COLS


def badge(cx, cy, n, r, bounds=None, pointsize=None):
    """A filled numbered disc: dark halo, then ink, then the number."""
    if bounds:
        W, H = bounds
        cx = min(max(cx, r + 8), W - r - 8)
        cy = min(max(cy, r + 8), H - r - 8)
    ps = pointsize or int(r * 1.15)
    return [
        "-stroke", HALO, "-strokewidth", str(max(2, int(r * 0.30))), "-fill", INK,
        "-draw", f"circle {cx},{cy} {cx},{cy - r}",
        "-stroke", "none", "-fill", "white", "-font", BOLD, "-pointsize", str(ps),
        "-gravity", "NorthWest",
        "-annotate", f"+{cx - int(ps * (0.30 if n < 10 else 0.58))}+{cy - int(ps * 0.72)}",
        str(n),
    ]


def render(spec):
    src = spec["image"]
    W, H = size(src)
    avail = OUT_W - LEGEND_W - PAD
    cols  = columns_for(W, H, avail)

    # Everything drawn on the page is about to shrink by this much, so draw it
    # that much bigger.
    col_h = H / cols
    scale = OUT_H / col_h
    k     = 1.0 / scale

    ring_w  = max(3, int(7 * k))
    halo_w  = max(5, int(13 * k))
    badge_r = max(14, int(30 * k))

    marked = spec["out"] + ".marked.png"
    args = ["magick", src]
    for i, c in enumerate(spec["callouts"], 1):
        if "box" in c:
            l, t, r, b = c["box"]
            x1, y1, x2, y2 = int(l * W), int(t * H), int(r * W), int(b * H)
            for stroke, width in ((HALO, halo_w), (INK, ring_w)):
                args += ["-stroke", stroke, "-strokewidth", str(width), "-fill", "none",
                         "-draw", f"roundrectangle {x1},{y1} {x2},{y2} {int(18*k)},{int(18*k)}"]
            args += badge(x1, y1, i, badge_r, bounds=(W, H))
        else:
            px, py = c["point"]
            cx, cy = int(px * W), int(py * H)
            rad = int(58 * k)
            for stroke, width in ((HALO, halo_w), (INK, ring_w)):
                args += ["-stroke", stroke, "-strokewidth", str(width), "-fill", "none",
                         "-draw", f"circle {cx},{cy} {cx + rad},{cy}"]
            args += badge(cx - rad, cy - rad, i, badge_r, bounds=(W, H))
    args += ["-stroke", "none", "+repage", marked]
    subprocess.run(args, check=True)

    if spec.get("collapse_blanks", True):
        squeezed = spec["out"] + ".squeezed.png"
        made, removed = collapse_blanks(marked, squeezed)
        if removed:
            subprocess.run(["rm", "-f", marked], check=True)
            marked = made
            H = size(marked)[1]
            cols = columns_for(W, H, avail)
            col_h = H / cols
            scale = OUT_H / col_h

    # Slice into columns, scale each to the full output height, lay them out.
    slices = []
    for n in range(cols):
        top = int(n * H / cols)
        bot = int((n + 1) * H / cols)
        piece = f"{spec['out']}.col{n}.png"
        subprocess.run(["magick", marked, "-crop", f"{W}x{bot-top}+0+{top}", "+repage",
                        "-resize", f"x{OUT_H}", piece], check=True)
        slices.append(piece)

    page = spec["out"] + ".page.png"
    cmd = ["magick"]
    for n, s in enumerate(slices):
        if n:
            cmd += ["-size", f"{GUTTER}x{OUT_H}", "xc:#dddddd"]
        cmd += [s]
    cmd += ["+append", "+repage", page]
    subprocess.run(cmd, check=True)

    page_w, _ = size(page)
    leg_w = OUT_W - page_w
    legend = spec["out"] + ".legend.png"

    wrap_at = max(24, int((leg_w - 2 * PAD - 56) / 14))
    title_lines = textwrap.wrap(spec.get("title", ""), max(18, wrap_at - 6))

    leg = ["magick", "-size", f"{leg_w}x{OUT_H}", "xc:white",
           "-font", BOLD, "-pointsize", "32", "-fill", "#111", "-gravity", "NorthWest"]
    for n, line in enumerate(title_lines):
        leg += ["-annotate", f"+{PAD}+{PAD + n * 40}", line]

    y = PAD + 40 * len(title_lines) + 26
    for i, c in enumerate(spec["callouts"], 1):
        wrapped = textwrap.wrap(c["text"], wrap_at)
        leg += badge(PAD + 22, y + 14, i, 22, pointsize=26)
        leg += ["-stroke", "none", "-fill", "#111", "-font", FONT, "-pointsize", "25"]
        for n, line in enumerate(wrapped):
            leg += ["-annotate", f"+{PAD + 56}+{y + 22 + n * 32}", line]
        y += 32 * len(wrapped) + 26

    leg += ["+repage", legend]
    subprocess.run(leg, check=True)

    subprocess.run(["magick", page, legend, "+append", "+repage",
                    "-bordercolor", "#bbbbbb", "-border", "1",
                    "-depth", "8", spec["out"]], check=True)
    subprocess.run(["rm", "-f", marked, page, legend] + slices, check=True)
    print(f"{spec['out']}  {size(spec['out'])}  columns={cols}")


if __name__ == "__main__":
    render(json.load(open(sys.argv[1])))
