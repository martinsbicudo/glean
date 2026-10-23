#!/usr/bin/env python3
"""Generates every Glean mark from code so the brand can be tweaked and rebuilt.

The mark: a fanned hand of three cards; the words you gleaned from your meetings, ready to study.
Usage: python3 brand/generate.py   (writes into brand/svg/)
"""
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent / "svg"

GRAPHITE = "#16181D"
IRIS = "#9A7CFF"
PAPER = "#F4EFE6"
PLUM = "#6B3FD4"

CARD = (74, 56, 182, 204)
LIFT = 18  # the front card is pulled up out of the hand
RADIUS = 24
PIVOT = (128, 236)
ANGLE = 15


def rrect(x0, y0, x1, y1, r):
    return (
        f"M{x0 + r:g},{y0:g}H{x1 - r:g}A{r:g},{r:g} 0 0 1 {x1:g},{y0 + r:g}V{y1 - r:g}"
        f"A{r:g},{r:g} 0 0 1 {x1 - r:g},{y1:g}H{x0 + r:g}A{r:g},{r:g} 0 0 1 {x0:g},{y1 - r:g}"
        f"V{y0 + r:g}A{r:g},{r:g} 0 0 1 {x0 + r:g},{y0:g}Z"
    )


def hline(x0, x1, cy, h):
    r = h / 2
    return (
        f"M{x0:g},{cy - r:g}H{x1:g}A{r:g},{r:g} 0 0 1 {x1:g},{cy + r:g}"
        f"H{x0:g}A{r:g},{r:g} 0 0 1 {x0:g},{cy - r:g}Z"
    )


def rotate(p, degrees):
    a = math.radians(degrees)
    dx, dy = p[0] - PIVOT[0], p[1] - PIVOT[1]
    return (PIVOT[0] + dx * math.cos(a) - dy * math.sin(a), PIVOT[1] + dx * math.sin(a) + dy * math.cos(a))


def outline(x0, y0, x1, y1, r):
    """The card outline clockwise as (kind, start, end, center) segments, kind 'L' or 'A'."""
    def arc(cx, cy, a0, a1):
        return ("A", (cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))),
                (cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))), (cx, cy, a0, a1))
    return [
        ("L", (x0 + r, y0), (x1 - r, y0), None), arc(x1 - r, y0 + r, -90, 0),
        ("L", (x1, y0 + r), (x1, y1 - r), None), arc(x1 - r, y1 - r, 0, 90),
        ("L", (x1 - r, y1), (x0 + r, y1), None), arc(x0 + r, y1 - r, 90, 180),
        ("L", (x0, y1 - r), (x0, y0 + r), None), arc(x0 + r, y0 + r, 180, 270),
    ]


def point_at(seg, t):
    kind, a, b, c = seg
    if kind == "L":
        return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
    cx, cy, a0, a1 = c
    ang = math.radians(a0 + (a1 - a0) * t)
    r = math.dist(a, (cx, cy))
    return (cx + r * math.cos(ang), cy + r * math.sin(ang))


def side_card(cut):
    """The part of the right-hand card that shows past the front card: world x >= cut."""
    segs = outline(*CARD, RADIUS)
    vis = lambda p: rotate(p, ANGLE)[0] - cut
    pieces, entry = [], None
    for seg in segs:
        lo, hi, steps = 0.0, 1.0, 64
        prev_t, prev_v = 0.0, vis(point_at(seg, 0))
        crossings = []
        for i in range(1, steps + 1):
            t = i / steps
            v = vis(point_at(seg, t))
            if (prev_v < 0) != (v < 0):
                a, b = prev_t, t
                for _ in range(60):
                    m = (a + b) / 2
                    if (vis(point_at(seg, a)) < 0) == (vis(point_at(seg, m)) < 0):
                        a = m
                    else:
                        b = m
                crossings.append(((a + b) / 2, v >= 0))
            prev_t, prev_v = t, v
        pieces.append((seg, crossings, vis(point_at(seg, 0)) >= 0))
    # Walk the outline twice so the visible run is contiguous, collecting it.
    run, inside = [], False
    for seg, crossings, starts_in in pieces * 2:
        t0 = 0.0
        if not inside and crossings and crossings[0][1]:
            inside, t0 = True, crossings[0][0]
            run.append(("start", point_at(seg, t0)))
        if inside:
            exits = [t for t, entering in crossings if not entering and t > t0]
            t1 = exits[0] if exits else 1.0
            run.append((seg, t0, t1))
            if exits:
                break
    start = rotate(run[0][1], ANGLE)
    d = f"M{start[0]:.2f},{start[1]:.2f}"
    for seg, t0, t1 in run[1:]:
        end = rotate(point_at(seg, t1), ANGLE)
        if seg[0] == "L":
            d += f"L{end[0]:.2f},{end[1]:.2f}"
        else:
            d += f"A{RADIUS},{RADIUS} 0 0 1 {end[0]:.2f},{end[1]:.2f}"
    return d + "Z", [rotate(p, ANGLE) for p in [run[0][1]] + [point_at(s, t1) for s, _, t1 in run[1:]]]


def mirror(d):
    """Mirror a path made of M/L/A/Z around x = 128 (flip arc sweep)."""
    out, i, tokens = "", 0, d.replace("M", " M ").replace("L", " L ").replace("A", " A ").replace("Z", " Z ").split()
    while i < len(tokens):
        cmd = tokens[i]
        if cmd in "ML":
            x, y = map(float, tokens[i + 1].split(","))
            out += f"{cmd}{256 - x:.2f},{y:.2f}"
            i += 2
        elif cmd == "A":
            rx = tokens[i + 1]
            flags = tokens[i + 2:i + 5]
            x, y = map(float, tokens[i + 5].split(","))
            out += f"A{rx} {flags[0]} {flags[1]} {1 - int(flags[2])} {256 - x:.2f},{y:.2f}"
            i += 6
        else:
            out += "Z"
            i += 1
    return out


def mark(gap=12, line=18, lines=True):
    right, _ = side_card(CARD[2] + gap)
    x0, y0, x1, y1 = CARD
    front = rrect(x0, y0 - LIFT, x1, y1 - LIFT, RADIUS)
    if lines:
        front += LINES(line)
    return front + right + mirror(right)


def LINES(h=18):
    top = CARD[1] - LIFT + 50
    return hline(102, 154, top, h) + hline(102, 130, top + h + 14, h)


# The cards span y 38..202; this centres the mark optically (a touch above the middle).
CENTER = "translate(0 8)"


def svg(body, view="0 0 256 256", title="Glean"):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}"><title>{title}</title>{body}</svg>\n'


def path(d, fill):
    return f'<path d="{d}" fill="{fill}" fill-rule="evenodd"/>'


def symbol(fill):
    return svg(f'<g transform="{CENTER}">{path(mark(), fill)}</g>')


def app_icon(small=False):
    scale = 3.1 if small else 2.85
    body = (
        f'<rect x="100" y="100" width="824" height="824" rx="185" fill="{GRAPHITE}"/>'
        f'<g transform="translate(512 512) scale({scale}) translate(-128 -128) {CENTER}">'
        + path(mark(gap=16 if small else 12, line=22 if small else 18), IRIS) + "</g>"
    )
    return svg(body, view="0 0 1024 1024", title="Glean app icon")


def menubar(fill):
    # Drawn on the 256 grid with wider gaps and no inner lines, then fitted into 22 x 18.
    body = f'<g transform="translate(11 9) scale(0.104) translate(-128 -128) {CENTER}">{path(mark(gap=20, lines=False), fill)}</g>'
    return svg(body, view="0 0 22 18", title="Glean menu bar")


def wordmark_text(fill):
    return (
        '<text x="0" y="0" font-family="Inter, SF Pro Display, -apple-system, Helvetica Neue, sans-serif" '
        f'font-weight="650" font-size="120" letter-spacing="-3" fill="{fill}">glean</text>'
    )


def lockup(mark_fill, text_fill):
    body = (
        f'<g transform="{CENTER}">{path(mark(), mark_fill)}</g>'
        f'<g transform="translate(262 158)">{wordmark_text(text_fill)}</g>'
    )
    return svg(body, view="0 0 640 256", title="Glean lockup")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    files = {
        "glean-symbol.svg": symbol(GRAPHITE),
        "glean-symbol-iris.svg": symbol(IRIS),
        "glean-symbol-plum.svg": symbol(PLUM),
        "glean-symbol-black.svg": symbol("#000"),
        "glean-symbol-white.svg": symbol("#FFF"),
        "glean-app-icon.svg": app_icon(),
        "glean-app-icon-small.svg": app_icon(small=True),
        "menubar.svg": menubar("#000"),
        "glean-lockup.svg": lockup(GRAPHITE, GRAPHITE),
        "glean-lockup-plum.svg": lockup(PLUM, GRAPHITE),
        "glean-lockup-reversed.svg": lockup(IRIS, PAPER),
    }
    for name, content in files.items():
        (OUT / name).write_text(content)
    print(f"wrote {len(files)} files to {OUT}")


if __name__ == "__main__":
    main()
