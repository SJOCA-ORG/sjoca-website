#!/usr/bin/env python3
"""Draw numbered callouts on a page screenshot, with a legend beside it.

Built for the AGM walkthrough: show the old site with the problem areas
ringed and numbered, talk through them, then switch to the live new site.

Spec is JSON so the callouts are data, not code:

    {"image": "...png", "out": "...png", "title": "Home page — before",
     "callouts": [{"box": [0.08, 0.49, 0.36, 0.72], "text": "..."},
                  {"point": [0.9, 0.97], "text": "..."}]}

Boxes and points are FRACTIONS of the image (left, top, right, bottom), so a
spec written against a thumbnail still lands on the full-resolution shot.
"""
import json, subprocess, sys, textwrap

FONT  = "/System/Library/Fonts/Supplemental/Arial.ttf"
BOLD  = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
INK   = "#00A8E8"        # cyan — the site is red and white, so nothing clashes
HALO  = "#003049"        # dark outline so the cyan survives a light background
LEGEND_W = 780
PAD      = 34


def size(path):
    out = subprocess.run(["magick", "identify", "-format", "%w %h", path],
                         capture_output=True, text=True, check=True).stdout
    return tuple(int(n) for n in out.split())


def badge(cx, cy, n, r=30, bounds=None):
    """A filled numbered disc. Drawn twice: dark halo, then the ink.

    Clamped inside the image, or a badge on a callout that hugs the top edge
    gets its top half sliced off."""
    if bounds:
        W, H = bounds
        cx = min(max(cx, r + 8), W - r - 8)
        cy = min(max(cy, r + 8), H - r - 8)
    return [
        "-stroke", HALO, "-strokewidth", "9", "-fill", INK,
        "-draw", f"circle {cx},{cy} {cx},{cy-r}",
        "-stroke", "none", "-fill", "white",
        "-font", BOLD, "-pointsize", "34",
        "-gravity", "NorthWest",
        "-annotate", f"+{cx - (10 if n < 10 else 19)}+{cy - 22}", str(n),
    ]


def render(spec):
    src = spec["image"]
    W, H = size(src)
    args = ["magick", src]

    for i, c in enumerate(spec["callouts"], 1):
        args += ["-stroke", HALO, "-strokewidth", "13", "-fill", "none"]
        if "box" in c:
            l, t, r, b = c["box"]
            x1, y1, x2, y2 = int(l * W), int(t * H), int(r * W), int(b * H)
            for stroke, width in ((HALO, 13), (INK, 7)):
                args += ["-stroke", stroke, "-strokewidth", str(width), "-fill", "none",
                         "-draw", f"roundrectangle {x1},{y1} {x2},{y2} 18,18"]
            args += badge(x1, y1, i, bounds=(W, H))
        else:
            px, py = c["point"]
            cx, cy = int(px * W), int(py * H)
            for stroke, width in ((HALO, 13), (INK, 7)):
                args += ["-stroke", stroke, "-strokewidth", str(width), "-fill", "none",
                         "-draw", f"circle {cx},{cy} {cx+58},{cy}"]
            args += badge(cx - 58, cy - 58, i, bounds=(W, H))

    args += ["-stroke", "none", spec["out"]]
    subprocess.run(args, check=True)

    # The legend: a white column to the right, so the shot itself stays clean.
    lines = []
    for i, c in enumerate(spec["callouts"], 1):
        wrapped = textwrap.wrap(c["text"], 42)
        lines.append((i, wrapped))

    title_lines = len(textwrap.wrap(spec.get("title", ""), 34))
    y = PAD + 42 * title_lines + 34
    leg = ["magick", "-size", f"{LEGEND_W}x{H}", "xc:white",
           "-font", BOLD, "-pointsize", "34", "-fill", "#111",
           "-gravity", "NorthWest"]
    for k, line in enumerate(textwrap.wrap(spec.get("title", ""), 34)):
        leg += ["-annotate", f"+{PAD}+{PAD + k * 42}", line]
    for i, wrapped in lines:
        leg += badge(PAD + 26, y + 16, i, r=24)
        leg += ["-stroke", "none", "-fill", "#111", "-font", FONT, "-pointsize", "27"]
        for k, line in enumerate(wrapped):
            leg += ["-annotate", f"+{PAD + 66}+{y + 24 + k * 34}", line]
        y += 34 * len(wrapped) + 34

    leg += [spec["out"] + ".legend.png"]
    subprocess.run(leg, check=True)

    # +repage, or the composite keeps the left image's page offset and every
    # later crop against this file lands somewhere surprising.
    subprocess.run(["magick", spec["out"], spec["out"] + ".legend.png",
                    "+append", "+repage", "-bordercolor", "#cccccc", "-border", "1",
                    "-depth", "8", spec["out"]], check=True)
    subprocess.run(["rm", "-f", spec["out"] + ".legend.png"], check=True)
    print(spec["out"], size(spec["out"]))


if __name__ == "__main__":
    render(json.load(open(sys.argv[1])))
