# CLAUDE.md — Project Briefing
## Read this at the start of every session.

---

## Who We Are

- **Developer:** Ray (Readycheck Studios)
- **AI Partner:** Claude Code
- **Platform:** Linux
- **Work Schedule:** ~30 hours/week together

---

## The Game

### Title: Steel Eternal

### Concept
A 2D Rogue-Vania (roguelike + metroidvania) built in Godot 4.x. Two interlocking gameplay states:

1. **Tank Mode (N.O.V.A.)** — Side-scrolling. Player commands N.O.V.A. (Neural Operations Versatile Armature), a semi-sentient combat tank. Heavy artillery, momentum-based physics, terrain interaction. The tank is the player's greatest weapon and only sanctuary.
2. **Pilot Mode (Jason)** — Side-scrolling platformer. Jason disembarks to infiltrate tight spaces, hack terminals, and activate Quantum Cores. Glass health profile — most hits are critical or lethal. Jason is agile but extremely vulnerable.

### Target Completion Time
**15 hours** for a full playthrough. Tight, focused scope. Quality of feel over quantity of content.

### Unique Selling Points
- **Pilot/Tank Symbiosis:** Dual-state combat. Tank provides power; Pilot provides precision. Neither survives alone.
- **Quantum Core World-Shifting:** Players hack and activate Quantum Cores to physically shift room geometry in real-time (Phase A ↔ Phase B).
- **Neural Tether:** Jason is bound to N.O.V.A. by a proximity-based life support link. Stray too far and the run ends.
- **Synaptic Bypass:** Real-time waveform alignment hacking mini-game. World doesn't pause — Jason is exposed while hacking.
- **Diegetic UI:** No traditional HUD for the Neural Link. Proximity stress communicated through glitch shaders and audio.

### Inspirations
- **Dead Cells** — Combat feel, juice (hit-stop, screen shake, particles), roguelike structure, enemy telegraphing
- **Blaster Master (NES)** — Core concept: tank + pilot dual gameplay loop, world structure
- **Hollow Knight** — World-building, atmosphere
- **Armored Core** — Mechanical customization feel

### Art Direction
- **Aesthetic:** "Neon-Gothic Industrial"
- **Palette:** High-contrast Onyx & Amber. Deep shadows pierced by amber mechanical glows and sickly violet Quantum Flora.
- **Resolution:** 640x360 rendered at 2–3x scale (1080p/4K)
- **Style:** "Hi-Bit" pixel art — Dead Cells approach (3D-informed 2D)
- Placeholder graphics for now — geometric shapes, color-coded by type
- Ray will replace placeholder art later with acquired assets
- Claude Code generates all placeholder art

### Platform Target
- PC primary (Steam)
- Mobile later (cross-save support)

---

## Tech Stack

- **Engine:** Godot 4.x
- **Language:** GDScript (~95% of all code)
- **Data:** JSON for room configs, enemy stats, balance tables, save data
- **Utility:** Python for build automation, Bash for install scripts

---

## Architecture (from TDS v1.0)

### Module 1: Scene Tree & Player Architecture

**Manager-Pawn Pattern.** A central `PlayerManager` handles all state — camera, UI, input — regardless of which entity is active.

```
PlayerRoot (Node2D | player_manager.gd)
├── NOVA_Tank (CharacterBody2D | Collision Layer: 2)
│   ├── Sprite2D/AnimatedSprite2D
│   ├── CollisionShape2D
│   └── WeaponHardpoint (Marker2D)
├── Jason_Pilot (CharacterBody2D | Collision Layer: 3 | Visible: false)
│   ├── Sprite2D/AnimatedSprite2D
│   └── CollisionShape2D
├── CameraManager (Camera2D)
│   └── RemoteTransform2D
└── NeuralTetherLogic (Node | tether_handler.gd)
    └── TetherTimer (Timer)
```

**Pawn Swap Sequence (on `p_interact`):**
1. Verify Jason is within mount radius of N.O.V.A.
2. Disable `set_physics_process` and `set_process_unhandled_input` on current pawn
3. Enable same on target pawn
4. Update `RemoteTransform2D.remote_path` to target pawn
5. Trigger glitch effect transition
6. If switching to Pilot: start NeuralTetherLogic distance tracking

**Input Map (context-sensitive):**

| Action | Input | Tank Context | Pilot Context |
|--------|-------|--------------|---------------|
| p_interact | Space/Cross | Disembark | Mount Tank / Hack |
| p_attack | L-Click/R2 | Fire Main Cannon | Data-Spike Stun |
| p_dash | L-Shift/L2 | Quantum Dash | Sprint / Slide |
| p_utility | Q/L1 | Switch Weapon | Deploy Decoy |

### Module 2: Global Signal Bus

All cross-system communication goes through `Events.gd` (Autoload). No direct node references between systems.

**File:** `res://scripts/globals/Events.gd`

```gdscript
# Events.gd
extends Node

signal on_pawn_swapped(active_node: Node2D)
signal on_tether_strained(severity: float)   # 0.0 to 1.0
signal on_world_shifted(new_phase: int)
signal on_hack_started(difficulty: int)
signal on_tank_stalled                        # NOVA Stability = 0
```

**Standards:**
- Never use `get_parent().get_node()` to trigger cross-system events
- Emit: `Events.signal_name.emit()`
- Connect in `_ready()`: `Events.signal_name.connect(_on_event)`

### Module 3: Physics & Collision Matrix

**Layer Definitions:**

| Layer | Name | Description |
|-------|------|-------------|
| 1 | World | Static geometry (floors, walls, ceilings) |
| 2 | N.O.V.A. | Tank body and tread hitboxes |
| 3 | Jason | Pilot body and hurtbox |
| 4 | Heavy Gates | Barriers only N.O.V.A. can destroy/trigger |
| 5 | Neural Vents | Small corridors accessible only by Pilot |
| 6 | Projectiles | Bullets, missiles, energy beams |
| 7 | Enemies | All hostile AI |

**Masking Rules:**
- N.O.V.A. scans layers: 1, 4, 7 (ignores Layer 5 — vents are solid walls to tank)
- Jason scans layers: 1, 5, 7 (ignores Layer 4 — can pass heavy gates)

**Physics:**
- N.O.V.A.: `move_and_slide()`, gravity 1.5x, crush damage signal on velocity collision with Layer 7
- Jason: `move_and_slide()` with coyote time (0.15s) and jump buffering; vent entry swaps CollisionShape2D to crouch profile (60% height reduction)

### Module 4: Data Management & Save System

**Resource-Based Weapons (`WeaponData.gd` extends Resource):**
- Properties: `damage`, `fire_rate`, `ammo_type`, `projectile_scene`, `screen_shake_intensity`
- New weapons = new `.tres` file in inspector, no code changes

**Save System ("Quantum State"):**
- Format: JSON (encrypted for release builds)
- Path: `user://save_data.json`

| Category | Examples | Persistence |
|----------|----------|-------------|
| Meta-Progression | Unlocked Cores, Phase Dust, Upgrade Tree levels | Permanent |
| Run-State | Current HP, Equipped Modules, Current Sector | Deleted on Death |
| World-State | Active Phase ID per Quantum Core | Run-specific |

**`GameData.gd` (Autoload singleton):** Holds current session numbers, handles save/load via `FileAccess`.

### Module 5: UI & Shader Specifications

**Glitch System (Neural Link Feedback):**
- `ColorRect` covering full viewport with `ShaderMaterial`
- Driven by `on_tether_strained` signal (`interference_strength` 0.0–1.0)
- Features: Chromatic Aberration (edge R/B offset), Pixel Displacement (scanline shifting), Vignette (corner darkening)

**Tether Zones:**
- Safe Zone: < 80% max distance — full clarity
- Danger Zone: ≥ 80% — glitch effects intensify
- Severed: Exceeded max distance — rapid health depletion or immediate run failure

**Synaptic Bypass (Hacking Mini-Game):**
- Diegetic — rendered near Jason in world space via `SubViewportContainer`
- World does NOT pause during hacking — Jason is exposed
- Player adjusts Amplitude (W/S), Frequency (A/D), Phase Shift (L1/R1) to match target sine wave
- Success: Player wave within ±5% tolerance for 1.5 consecutive seconds
- Firewalls in advanced hacks reset progress and alert enemies

**UI Z-Index Hierarchy:**
- Z 100: Glitch shaders (top)
- Z 90: Hacking mini-game & dialogues
- Z 80: Static HUD (Stability bar, Phase Dust count)
- Z 0: Game world

### Module 6: Art & Graphical Pipeline

**Environmental Parallax (4 layers):**
- Layer -2: Silhouette brutalist architecture, Quantum Fog
- Layer -1: Rusted pipes, violet flora
- Layer 0: Full-detail collision geometry (play area)
- Layer +1: Dark foreground silhouettes (depth)

**Key Shaders:**
- Phase-Shift Shader: Lerps between texture sets on `on_world_shifted`
- CRT/Scanline Filter: Global CanvasLayer shader reinforcing Neural Link theme

---

## Game Systems

### Neural Tether
Jason bound to N.O.V.A. by proximity life support. Sentry Mode: N.O.V.A. stationary and targetable while Jason is away. If N.O.V.A. is destroyed, run ends.

### N.O.V.A. Combat
- **Stability Meter** (not HP): Hits reduce stability. Zero = "Stalled" state — Jason must disembark and perform manual restart (rhythm timing event) while exposed.
- **Momentum Scaling:** Faster movement = higher collision/close-range damage.
- **3 Hardpoints:** Main Turret (kinetic/energy, sustained), Auxiliary Mount (utility/defensive), Heavy Ordnance (burst/AoE, high cooldown).

### Jason Combat
- **Data-Spike:** Melee/stun — temporarily disables biological and mechanical enemies.
- **System Overload:** Hack a terminal → damage all enemies on that sector's power grid.
- **Final Stand:** If N.O.V.A. at 0 Stability, Jason performs rhythm-based "Quick-Fix" to restore partial power.

### Quantum Core System
- Cores exist in multiple Phases (e.g., Phase A, Phase B)
- Shifting a core changes surrounding room geometry instantly (e.g., solid wall → open bridge)
- Requires N.O.V.A. power + Jason's Synaptic Bypass to activate
- Flux Zones: Rooms that shift layout based on Core alignment

### Enemy Archetypes
- **Bulwarks:** Immune to frontal cannon — Jason must flank through vents to hack cooling vents
- **Neural Parasites:** Ignore N.O.V.A., target Jason directly or block hatch access
- **Void-Walkers:** Phase-shifting enemies — must time Quantum Core shifts to catch them tangible

### Meta-Progression (Aegis Hub)
**Upgrade Tree — 3 Paths:**
| Branch | Focus | Example |
|--------|-------|---------|
| Titan | N.O.V.A. Durability & Firepower | Reactive Plating: damage taken creates shockwave |
| Ghost | Jason Agility & Hacking | Ghost-Step: invisible 2s after disembarking |
| Flux | World Manipulation & Cores | Phase-Bleed: enemies slowed on World Shift |

**Two Progression Layers:**
- **Neural Imprints (Permanent):** Base stat increases — never lost on death
- **Quantum Modules (Run-Based):** Weapon modifiers found in-run — lost on N.O.V.A. destruction

### Biomes
- **The Iron Wastes:** Heavy machinery and scrap-metal dunes — Tank-focused combat
- **The Void-Vents:** Narrow toxic corridors, low gravity — Pilot-focused platforming

### Dynamic Soundtrack
1. Exploration (Tank): Industrial synth-wave, steady driving beat
2. Exploration (Pilot): Beat drops, eerie minimalist ambient drone
3. Combat: Heavy distorted guitars + orchestral brass layers in
4. Hacking: All music fades to rhythmic pulse matching target System Frequency

---

## Project Structure

```
steeleternal/
├── CLAUDE.md                  # This file — read every session
├── .env                       # API keys — never commit
├── .gitignore
├── godot/                     # Godot project root
│   ├── project.godot
│   ├── scenes/
│   │   ├── player/            # PlayerManager, NOVA, Jason scenes
│   │   ├── levels/            # Room templates, biome scenes
│   │   ├── enemies/           # Enemy scenes
│   │   ├── ui/                # HUD, hacking UI, menus
│   │   └── shared/            # Shared components
│   ├── scripts/
│   │   ├── globals/           # Events.gd, GameData.gd (Autoloads)
│   │   ├── player/            # player_manager.gd, tether_handler.gd, nova.gd, jason.gd
│   │   ├── weapons/           # WeaponData.gd (Resource), projectile scripts
│   │   ├── enemies/
│   │   ├── quantum/           # Quantum Core, world-shifting logic
│   │   ├── ui/                # HUD, hacking mini-game, glitch shader controller
│   │   ├── pcg/               # Procedural room stitching
│   │   └── utils/
│   ├── shaders/
│   │   ├── neural_glitch.gdshader
│   │   ├── phase_shift.gdshader
│   │   └── crt_scanline.gdshader
│   ├── assets/
│   │   ├── placeholder/       # Geometric placeholder art
│   │   └── audio/
│   └── data/
│       ├── weapons/           # .tres WeaponData resources
│       ├── rooms/             # JSON room templates
│       └── enemies/           # JSON enemy configs
├── docs/
│   ├── GDD.md
│   └── TDS.md
└── scripts/                   # Utility scripts
    └── build.sh
```

---

## Coding Standards

- All GDScript files: `snake_case`
- Scene names: `PascalCase`
- Every script has a comment header explaining its purpose
- Signals preferred over direct function calls between systems
- No magic numbers — use constants or exported variables
- Every system gets its own script — no monolithic files
- `Events.gd` is the only cross-system communication channel

---

## Development Workflow

### Every Session
1. Read this CLAUDE.md
2. Build the feature
3. Commit to GitHub with descriptive message
4. Keep `main` always playable

### Git Branching
- `main` — stable, always playable
- `dev` — active development
- Feature branches: `feature/player-manager`, `feature/quantum-core`, etc.

---

## Roles

### Ray (Human)
- Launch Godot and test
- Report what felt wrong or broken
- Make design decisions when presented with options
- Acquire replacement art assets (later)
- Final approval on milestone builds

### Claude Code
- Write all GDScript
- Commit to GitHub
- Generate placeholder art
- Design systems architecture
- Debug and fix issues autonomously

---

## API Keys (in .env — never commit)

```
GITHUB_PERSONAL_ACCESS_TOKEN
GOOGLE_OAUTH_CLIENT_ID
GOOGLE_OAUTH_CLIENT_SECRET
TRELLO_API_KEY
TRELLO_TOKEN
BRAVE_SEARCH_API_KEY
DISCORD_BOT_TOKEN
FIGMA_ACCESS_TOKEN
```

---

*Last updated: Feb 2026 — Steel Eternal v1 kickoff. 15-hour target playthrough.*
