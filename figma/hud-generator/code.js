// Steel Eternal — HUD Layout Generator
// Figma Plugin (run-once)
//
// Builds 5 annotated 640×360 frames covering every HUD state:
//   01 Tank Mode · 02 Pilot Mode · 03 Danger Zone · 04 Stalled · 05 Run Failed
//
// Palette matches hud.gd exactly.

(async () => {

  // ── Fonts ────────────────────────────────────────────────────────────────
  await figma.loadFontAsync({ family: "Inter", style: "Regular" });
  await figma.loadFontAsync({ family: "Inter", style: "Bold" });

  // ── Palette (0–1 range, matches hud.gd constants) ────────────────────────
  const AMBER  = { r: 0.961, g: 0.620, b: 0.043 }; // N.O.V.A. / tank UI
  const BLUE   = { r: 0.251, g: 0.647, b: 0.961 }; // Jason / pilot UI
  const VIOLET = { r: 0.380, g: 0.100, b: 0.800 }; // Quantum / glitch
  const ONYX   = { r: 0.067, g: 0.067, b: 0.098 }; // Background
  const RED    = { r: 0.900, g: 0.100, b: 0.100 }; // Alerts / run failed
  const GRAY   = { r: 0.200, g: 0.200, b: 0.250 }; // World placeholder

  // ── Helpers ──────────────────────────────────────────────────────────────

  const solid = (c, a = 1) => [{ type: 'SOLID', color: c, opacity: a }];

  function addRect(parent, name, x, y, w, h, color, alpha = 1, radius = 0) {
    const r = figma.createRectangle();
    r.name = name;
    r.x = x; r.y = y;
    r.resize(Math.max(1, w), Math.max(1, h));
    r.fills = solid(color, alpha);
    if (radius) r.cornerRadius = radius;
    parent.appendChild(r);
    return r;
  }

  async function addText(parent, name, str, x, y, size, color, bold = false, alpha = 1) {
    const t = figma.createText();
    t.name = name;
    t.fontName = { family: "Inter", style: bold ? "Bold" : "Regular" };
    t.fontSize = size;
    t.characters = str;
    t.fills = solid(color, alpha);
    t.x = x; t.y = y;
    parent.appendChild(t);
    return t;
  }

  function addAnnotation(parent, str, x, y) {
    // Dashed-border label used for non-interactive annotations
    const g = figma.createFrame();
    g.name = "Annotation";
    g.x = x; g.y = y;
    g.fills = [];
    g.strokes = [{ type: 'SOLID', color: GRAY, opacity: 0.4 }];
    g.strokeWeight = 1;
    g.dashPattern = [3, 3];
    g.resize(1, 1); // resized after text added
    g.clipsContent = false;
    parent.appendChild(g);
    const t = figma.createText();
    t.fontName = { family: "Inter", style: "Regular" };
    t.fontSize = 7;
    t.characters = str;
    t.fills = solid(GRAY, 0.7);
    t.x = 4; t.y = 2;
    g.appendChild(t);
    g.resize(t.width + 8, t.height + 4);
    return g;
  }

  // ── Scene builder ─────────────────────────────────────────────────────────
  //
  // opts:
  //   pilotMode  bool    — show Jason HP panel, tether line
  //   stalled    bool    — show ⚠ STALLED alert, stability = 0
  //   runFailed  bool    — show ✖ RUN FAILED label
  //   glitch     0..1   — glitch overlay opacity (0 = none)
  //   damage     0..1   — stability bar fill fraction
  //   hpRatio    0..1   — Jason HP bar fill fraction
  //   dustCount  int    — phase dust number shown

  async function buildScene(label, xOffset, opts = {}) {
    const {
      pilotMode = false,
      stalled   = false,
      runFailed = false,
      glitch    = 0,
      damage    = 1.0,
      hpRatio   = 1.0,
      dustCount = 12,
    } = opts;

    // Root frame — 640×360 game viewport
    const f = figma.createFrame();
    f.name  = label;
    f.x     = xOffset;
    f.y     = 0;
    f.resize(640, 360);
    f.fills = solid(ONYX);
    f.clipsContent = true;
    figma.currentPage.appendChild(f);

    // ── World placeholder ───────────────────────────────────────────────────
    await addText(f, "[ World ]", "Game World  640×360", 232, 172, 11, GRAY, false, 0.35);

    const BAR_W = 152; // width of all progress bars

    // ── N.O.V.A. Panel ─────────────────────────────────────────────────────
    addRect(f, "NOVAPanel_BG", 8, 8, 192, 50, ONYX, 0.88, 2);

    await addText(f, "NOVALabel",      "N·O·V·A",  12, 11, 9,  AMBER, true);
    await addText(f, "StabilityLabel", "STABILITY", 12, 24, 6,  AMBER, false, 0.55);

    // Stability bar
    addRect(f, "StabilityBar_BG",   12, 32, BAR_W, 8, ONYX);
    if (damage > 0) {
      addRect(f, "StabilityBar_Fill", 12, 32, Math.round(BAR_W * damage), 8, AMBER);
    }
    const stabVal = Math.round(damage * 100);
    await addText(f, "StabilityValue", `${stabVal}`, 167, 31, 8, AMBER);
    await addText(f, "StabilityMax",   "/100",        181, 31, 7, AMBER, false, 0.40);

    addAnnotation(f, "hud.gd → StabilityBar (ProgressBar)", 204, 8);

    // ── Phase Dust Panel ───────────────────────────────────────────────────
    addRect(f, "PhaseDustPanel_BG", 8, 62, 108, 17, ONYX, 0.88, 2);

    await addText(f, "DustIcon",  "◆",              12, 64, 9, AMBER);
    await addText(f, "DustCount", `${dustCount}`,   24, 64, 9, AMBER);
    await addText(f, "DustLabel", "PHASE DUST",      38, 66, 6, AMBER, false, 0.50);

    addAnnotation(f, "hud.gd → dust_count (Label)", 120, 62);

    // ── Jason Panel — Pilot Mode only ──────────────────────────────────────
    if (pilotMode) {
      addRect(f, "JasonPanel_BG", 8, 83, 192, 36, ONYX, 0.88, 2);

      await addText(f, "PilotLabel", "PILOT", 12, 86,  9, BLUE, true);
      await addText(f, "HPLabel",    "HP",    12, 98,  6, BLUE, false, 0.55);

      // HP bar
      const hpPx = Math.round(BAR_W * hpRatio);
      addRect(f, "HPBar_BG",   12, 105, BAR_W, 8, ONYX);
      if (hpRatio > 0) {
        addRect(f, "HPBar_Fill", 12, 105, hpPx, 8, BLUE);
      }
      const hpVal = Math.round(hpRatio * 30);
      await addText(f, "HPValue", `${hpVal}`,  167, 104, 8, BLUE);
      await addText(f, "HPMax",   "/30",        178, 104, 7, BLUE, false, 0.40);

      addAnnotation(f, "hud.gd → JasonPanel (visible in Pilot Mode)", 204, 83);

      // Tether distance reference line (floor level)
      const tetherLine = figma.createLine();
      tetherLine.name = "Neural Tether — 400px max";
      tetherLine.x = 120; tetherLine.y = 330;
      tetherLine.resize(400, 0);
      tetherLine.strokes = [{ type: 'SOLID', color: AMBER, opacity: 0.30 }];
      tetherLine.strokeWeight = 1;
      tetherLine.dashPattern = [6, 4];
      f.appendChild(tetherLine);
      await addText(f, "TetherAnnotation", "← 400px max tether →", 186, 334, 7, AMBER, false, 0.40);
    }

    // ── Mode Label (bottom-left, always visible) ────────────────────────────
    const modeStr = pilotMode ? "◉  PILOT MODE" : "◉  TANK MODE";
    await addText(f, "ModeLabel", modeStr, 8, 340, 9, AMBER);
    addAnnotation(f, "hud.gd → mode_label", 108, 337);

    // ── Stalled Alert (centre, conditional) ────────────────────────────────
    if (stalled) {
      addRect(f, "StalledAlert_BG", 188, 98, 264, 26, ONYX, 0.92, 2);
      await addText(f, "StalledAlert", "⚠  N·O·V·A  STALLED", 205, 104, 11, AMBER, true);
      addAnnotation(f, "hud.gd → stalled_alert (visible when Stability = 0)", 188, 128);
    }

    // ── Run Failed (centre, conditional) ───────────────────────────────────
    if (runFailed) {
      addRect(f, "RunFailed_BG", 96, 160, 448, 26, ONYX, 0.92, 2);
      await addText(f, "RunFailedLabel",
        "✖  RUN FAILED  —  N·O·V·A DESTROYED", 106, 166, 10, RED, true);
      addAnnotation(f, "hud.gd → run_failed_label", 96, 190);
    }

    // ── Glitch Overlay (always top, opacity driven by tether_handler) ───────
    // Always shown as a dashed annotation; filled when glitch > 0
    const glitchAlpha = glitch > 0 ? glitch : 0.03;
    const glitchRect = addRect(
      f, "GlitchOverlay — neural_glitch.gdshader\n(interference_strength 0.0–1.0)",
      0, 0, 640, 360, VIOLET, glitchAlpha
    );
    glitchRect.strokes = [{ type: 'SOLID', color: VIOLET, opacity: glitch > 0 ? 0.6 : 0.25 }];
    glitchRect.strokeWeight = 1;
    glitchRect.dashPattern = [6, 4];

    if (glitch > 0) {
      await addText(f, "GlitchLabel",
        `Glitch intensity: ${Math.round(glitch * 100)}%  (Danger Zone active)`,
        8, 8 + (pilotMode ? 128 : 88), 7, VIOLET, false, 0.80);
    }

    return f;
  }

  // ── Build all 5 states ───────────────────────────────────────────────────
  figma.currentPage.name = "Steel Eternal — HUD";

  const W   = 640;
  const GAP = 40;

  await buildScene("01 — Tank Mode",
    (W + GAP) * 0,
    { damage: 1.0 });

  await buildScene("02 — Pilot Mode",
    (W + GAP) * 1,
    { pilotMode: true, damage: 0.75, hpRatio: 0.73, glitch: 0, dustCount: 7 });

  await buildScene("03 — Danger Zone (Tether Strained)",
    (W + GAP) * 2,
    { pilotMode: true, damage: 0.60, hpRatio: 0.43, glitch: 0.28, dustCount: 7 });

  await buildScene("04 — Stalled",
    (W + GAP) * 3,
    { stalled: true, damage: 0.0, dustCount: 3 });

  await buildScene("05 — Run Failed",
    (W + GAP) * 4,
    { runFailed: true, damage: 0.0, hpRatio: 0.0, dustCount: 3 });

  // Zoom to fit all frames
  figma.viewport.scrollAndZoomIntoView(figma.currentPage.children);

  figma.notify("✓ Steel Eternal HUD — 5 states created");
  figma.closePlugin();

})().catch(err => {
  figma.notify("Plugin error: " + err.message, { error: true });
  console.error(err);
  figma.closePlugin();
});
