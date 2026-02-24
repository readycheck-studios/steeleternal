#!/usr/bin/env python3
"""
hud_mockup_svg.py — Steel Eternal HUD Mockup Generator
Outputs: hud-mockup.svg  (5 states, 640×360 each, side-by-side)

Run:   python3 figma/hud-generator/hud_mockup_svg.py
Then:  Figma web → File → Import → select hud-mockup.svg

Palette and element names match hud.gd exactly.
"""

import math

# ── Dimensions ────────────────────────────────────────────────────────────────
W, H, GAP = 640, 360, 48
BAR_W     = 152   # progress bar width (pixels)

# ── Palette (hex, from hud.gd constants) ──────────────────────────────────────
AMBER  = "#F59E0B"   # Color(0.961, 0.620, 0.043)
BLUE   = "#40A5F5"   # Color(0.251, 0.647, 0.961)
VIOLET = "#6119CC"   # Color(0.380, 0.100, 0.800)
ONYX   = "#111119"   # Color(0.067, 0.067, 0.098)
RED    = "#E51919"   # Color(0.900, 0.100, 0.100)
GRAY   = "#33333F"   # Color(0.200, 0.200, 0.250)
BLACK  = "#080810"


# ── SVG helpers ───────────────────────────────────────────────────────────────

def rect(x, y, w, h, fill, opacity=1.0, rx=0, stroke=None, stroke_opacity=1.0,
         stroke_dash=None, stroke_w=1):
    w, h = max(1, round(w)), max(1, round(h))
    attrs = (f'x="{x}" y="{y}" width="{w}" height="{h}" '
             f'fill="{fill}" fill-opacity="{opacity}"')
    if rx:
        attrs += f' rx="{rx}" ry="{rx}"'
    if stroke:
        attrs += (f' stroke="{stroke}" stroke-opacity="{stroke_opacity}"'
                  f' stroke-width="{stroke_w}"')
        if stroke_dash:
            attrs += f' stroke-dasharray="{stroke_dash}"'
    return f'<rect {attrs}/>'


def txt(content, x, y, size, fill, bold=False, opacity=1.0, anchor="start"):
    """y is the top of the text; baseline = y + size."""
    weight = "700" if bold else "400"
    escaped = (content
               .replace("&", "&amp;")
               .replace("<", "&lt;")
               .replace(">", "&gt;"))
    return (f'<text x="{x}" y="{y + size}" '
            f'font-family="Inter, system-ui, sans-serif" '
            f'font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}" fill-opacity="{opacity}" '
            f'text-anchor="{anchor}">{escaped}</text>')


def annotate(content, x, y):
    """Dashed grey annotation box used for spec callouts."""
    char_px = 5.2
    aw = int(len(content) * char_px) + 10
    r  = rect(x, y, aw, 14, "none", stroke=GRAY, stroke_opacity=0.35,
              stroke_dash="3,3", stroke_w=1)
    t  = txt(content, x + 4, y + 2, 7, GRAY, opacity=0.65)
    return r + "\n" + t


def line(x1, y1, x2, y2, stroke, opacity=1.0, dash=None, w=1):
    attrs = (f'x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" '
             f'stroke="{stroke}" stroke-opacity="{opacity}" stroke-width="{w}"')
    if dash:
        attrs += f' stroke-dasharray="{dash}"'
    return f'<line {attrs}/>'


# ── Scene builder ─────────────────────────────────────────────────────────────

def build_scene(label, x_off, damage=1.0, hp_ratio=1.0, pilot=False,
                stalled=False, failed=False, glitch=0.0, dust=12):
    """
    Returns a list of SVG element strings for one 640×360 scene.
    All x values are offset by x_off for side-by-side layout.
    """
    e = []   # element list
    X = x_off  # shorthand

    def r(nx, ny, nw, nh, fill, op=1.0, rx=0,
          stroke=None, sop=1.0, dash=None, sw=1):
        return rect(X + nx, ny, nw, nh, fill, op, rx, stroke, sop, dash, sw)

    def t(content, nx, ny, size, fill, bold=False, op=1.0, anchor="start"):
        return txt(content, X + nx, ny, size, fill, bold, op, anchor)

    def ann(content, nx, ny):
        return annotate(content, X + nx, ny)

    # ── Background ────────────────────────────────────────────────────────────
    e.append(r(0, 0, W, H, ONYX))
    e.append(t("Game World  640×360", 220, 170, 11, GRAY, op=0.30))

    # ── N.O.V.A. Panel ────────────────────────────────────────────────────────
    e.append(r(8, 8, 192, 50, ONYX, 0.88, rx=2))
    e.append(t("N·O·V·A", 12, 11, 9, AMBER, bold=True))
    e.append(t("STABILITY", 12, 24, 6, AMBER, op=0.55))

    e.append(r(12, 32, BAR_W, 8, BLACK, 0.80))
    e.append(r(12, 32, BAR_W * damage, 8, AMBER))
    stab_val = round(damage * 100)
    e.append(t(str(stab_val), 167, 31, 8, AMBER))
    e.append(t("/100", 181, 31, 7, AMBER, op=0.38))

    e.append(ann("hud.gd → StabilityBar", 204, 10))

    # ── Phase Dust ────────────────────────────────────────────────────────────
    e.append(r(8, 62, 112, 17, ONYX, 0.88, rx=2))
    e.append(t("◆", 12, 63, 9, AMBER))
    e.append(t(str(dust), 24, 63, 9, AMBER))
    e.append(t("PHASE DUST", 38, 65, 6, AMBER, op=0.50))

    e.append(ann("hud.gd → dust_count", 124, 63))

    # ── Jason Panel (Pilot Mode only) ─────────────────────────────────────────
    if pilot:
        e.append(r(8, 83, 192, 36, ONYX, 0.88, rx=2))
        e.append(t("PILOT", 12, 86, 9, BLUE, bold=True))
        e.append(t("HP", 12, 98, 6, BLUE, op=0.55))

        e.append(r(12, 106, BAR_W, 8, BLACK, 0.80))
        e.append(r(12, 106, BAR_W * hp_ratio, 8, BLUE))
        hp_val = round(hp_ratio * 30)
        e.append(t(str(hp_val), 167, 105, 8, BLUE))
        e.append(t("/30", 178, 105, 7, BLUE, op=0.38))

        e.append(ann("hud.gd → JasonPanel (visible in Pilot Mode only)", 204, 83))

        # Tether reference line
        e.append(line(X + 120, 330, X + 520, 330,
                      AMBER, opacity=0.28, dash="6,4"))
        e.append(t("← 400px Neural Tether max →", 150, 332, 7, AMBER, op=0.38))

    # ── Mode Label ────────────────────────────────────────────────────────────
    mode_txt = "◉  PILOT MODE" if pilot else "◉  TANK MODE"
    e.append(t(mode_txt, 8, 338, 9, AMBER))
    e.append(ann("hud.gd → mode_label", 112, 337))

    # ── Stalled Alert ─────────────────────────────────────────────────────────
    if stalled:
        e.append(r(192, 98, 256, 26, ONYX, 0.92, rx=2))
        e.append(t("⚠  N·O·V·A  STALLED", 202, 101, 11, AMBER, bold=True))
        e.append(ann("hud.gd → stalled_alert (Stability = 0)", 192, 128))

    # ── Run Failed ────────────────────────────────────────────────────────────
    if failed:
        e.append(r(96, 160, 448, 26, ONYX, 0.92, rx=2))
        e.append(t("✖  RUN FAILED  —  N·O·V·A DESTROYED",
                   106, 163, 10, RED, bold=True))
        e.append(ann("hud.gd → run_failed_label", 96, 190))

    # ── Glitch Overlay (always drawn; opacity = design intent) ────────────────
    g_op  = glitch if glitch > 0 else 0.025
    s_op  = 0.55 if glitch > 0 else 0.18
    e.append(r(0, 0, W, H, VIOLET, g_op,
               stroke=VIOLET, sop=s_op, dash="6,4", sw=1))
    if glitch > 0:
        label_y = 86 if pilot else 62
        e.append(t(f"neural_glitch.gdshader  interference_strength={glitch:.2f}",
                   8, label_y + 18, 7, VIOLET, op=0.75))

    # ── Scene title (below frame) ─────────────────────────────────────────────
    e.append(txt(label, X + W // 2, H + 16, 10, GRAY, bold=True,
                 anchor="middle"))

    return "\n".join(e)


# ── Assemble full SVG ─────────────────────────────────────────────────────────

def main():
    states = [
        ("01 — Tank Mode",
         0 * (W + GAP), dict(damage=1.0)),

        ("02 — Pilot Mode",
         1 * (W + GAP), dict(pilot=True, damage=0.75, hp_ratio=0.73, dust=7)),

        ("03 — Danger Zone",
         2 * (W + GAP), dict(pilot=True, damage=0.60, hp_ratio=0.43,
                              glitch=0.28, dust=7)),

        ("04 — Stalled",
         3 * (W + GAP), dict(stalled=True, damage=0.0, dust=3)),

        ("05 — Run Failed",
         4 * (W + GAP), dict(failed=True, damage=0.0, hp_ratio=0.0, dust=3)),
    ]

    total_w = W * 5 + GAP * 4
    total_h = H + 32   # room for scene titles below

    body = "\n\n".join(
        build_scene(name, xoff, **opts)
        for name, xoff, opts in states
    )

    svg = f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg"
     width="{total_w}" height="{total_h}"
     viewBox="0 0 {total_w} {total_h}">
  <defs>
    <style>text {{ font-family: Inter, system-ui, sans-serif; }}</style>
  </defs>

{body}

</svg>
"""

    out_path = "figma/hud-generator/hud-mockup.svg"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(svg)
    print(f"Written → {out_path}")
    print(f"Canvas size: {total_w}×{total_h}px — 5 states at 640×360 each")


if __name__ == "__main__":
    main()
