# ASSET AND LICENCE RECORD
## Prince of Persia: Echoes of Time

Maintained so that every pixel, glyph and byte in the shipped project has a
traceable origin. Competition rules require original or properly licensed assets;
this record is the evidence that the requirement is met.

---

## Summary

| Category | Origin | Licence | Third-party assets used |
|---|---|---|---|
| Code | Written for this project | Project licence | **0** |
| Visual art | Drawn procedurally at runtime | Project licence | **0** |
| Icons | Hand-authored SVG for this project | Project licence | **0** |
| Audio | None present | — | **0** |
| Fonts | Godot built-in default | Godot Engine (MIT) | 0 external |
| Engine | Godot Engine 4.7 | MIT | 1 (engine) |
| Level data | Authored for this project | Project licence | **0** |

**No asset originating from Prince of Persia (1989), Brøderbund, Jordan Mechner, or
any later Ubisoft title is present, reproduced, traced, sampled or derived from.**

This record covers all five levels and all four enemy archetypes, including the
Time Warden boss: the newest of them were authored the same way as the first, drawn
procedurally from `Palette` at runtime, so the audit below still returns nothing.

---

## Visual assets

**Every visual element is generated at runtime by code.** There are no image files
for characters, environments, props, effects or UI. Nothing was vendored, traced,
rotoscoped or copied.

| Element | Where it is produced | Evidence |
|---|---|---|
| Prince / player sprite | `scripts/player/player.gd` → `_draw()` | Procedural geometry + `Palette` colours |
| Temporal Echo | `scripts/temporal/temporal_echo.gd` → `_draw()` | Procedural silhouette, trail and aura |
| Palace Guard | `scripts/enemies/palace_guard.gd` → `_draw_enemy()` | Procedural geometry |
| Shadow Echo | `scripts/enemies/shadow_echo.gd` → `_draw_enemy()` | Procedural geometry |
| Temporal Sentinel | `scripts/enemies/temporal_sentinel.gd` → `_draw_enemy()` | Procedural geometry |
| The Time Warden (boss) | `scripts/enemies/time_warden.gd` → `_draw_enemy()` | Procedural geometry |
| Projectiles | `scripts/combat/projectile.gd` → `_draw()` | Procedural geometry |
| Platforms / architecture | `scripts/level/platform.gd` → `_draw()` | Procedural rects + deterministic speckle |
| Doors | `scripts/objects/door.gd` → `_draw()` | Procedural geometry |
| Pressure plates | `scripts/objects/pressure_plate.gd` → `_draw()` | Procedural geometry |
| Levers | `scripts/objects/lever.gd` → `_draw()` | Procedural geometry |
| Temporal rune | `scripts/objects/temporal_switch.gd` → `_draw()` | Procedural arcs |
| Hazards | `scripts/objects/hazard.gd` → `_draw()` | Procedural spikes / rupture |
| Moving platform | `scripts/objects/moving_platform.gd` → `_draw()` | Procedural geometry |
| Checkpoints | `scripts/objects/checkpoint.gd` → `_draw()` | Procedural braziers |
| Ladders | `scripts/objects/ladder.gd` → `_draw()` | Procedural rails and rungs |
| Level exit | `scripts/objects/level_exit.gd` → `_draw()` | Procedural light column |
| Backdrop / skyline | `scripts/level/level_backdrop.gd` → `_draw()` | Seeded procedural generation |
| HUD | `scripts/ui/hud.gd` | Godot `Control` primitives |
| Menus | `scripts/ui/menu_screen.gd` | Godot `Control` primitives |
| Colour style guide | `scripts/systems/palette.gd` | Hand-chosen constants (original) |

Drawing the art in code is a deliberate design decision as well as a legal one: it
guarantees the entire game shares one coherent, uncopied visual language, and it means
no asset can be introduced that bypasses this record.

### Icon

`icon.svg` — an hourglass/temporal glyph in the project palette. **Hand-authored for
this project.** No third-party iconography, no traced shapes, no stock assets.

### Fonts

The project uses Godot's built-in default font exclusively. No font files are bundled
or downloaded. Godot's default font ships under the engine's MIT licence.

### Shaders

None. There are no `.gdshader` files in the project. All effects use the standard 2D
drawing API.

---

## Audio assets

**There are no audio assets in this project.** No `.wav`, `.ogg`, `.mp3` or `.import`
files exist for sound. The audio phase has not begun, and no placeholder audio has
been introduced to create the appearance of completion.

When audio is added it will be original, royalty-free, or licensed — and every file
will be recorded in the table below with its source URL and licence terms before it is
committed.

| File | Source | Author | Licence | URL |
|---|---|---|---|---|
| *(none)* | | | | |

---

## Engine and tooling

| Component | Version | Licence | Notes |
|---|---|---|---|
| Godot Engine | 4.7.2 stable | MIT | Runtime dependency. Not redistributed in this repository. |

### Development tooling (never committed)

`verify.sh` downloads a **headless Godot 4.7.2 binary** into `.tools/` on first run.
That directory is git-ignored and the 140 MB binary is deliberately excluded from the
repository and from any distributed build. It is a build tool, not a shipped asset.

---

## Third-party dependencies

**None.** The project contains no addons, no package manifest, no plugin directory,
and no vendored code. Every system — the state machine, the temporal recorder, the
enemy AI, the puzzle framework, the level builder, the UI — is written for this
project using only Godot's built-in API.

This was a deliberate constraint: the project directive requires checking whether the
engine already provides a capability before adding a dependency, and in every case it
did.

---

## Repository contents audit

```
*.png  *.jpg  *.jpeg  *.webp  *.bmp  *.gif   → none
*.wav  *.ogg  *.mp3   *.flac                 → none
*.ttf  *.otf  *.woff                         → none
*.gdshader  *.glsl  *.shader                 → none
*.blend  *.glb  *.fbx  *.obj  *.dae          → none

*.svg                                        → icon.svg  (original, this project)
*.gd  (GDScript)                             → all authored for this project
*.tscn  (scenes)                             → all authored for this project
*.tres  (resources)                          → none committed
```

To re-verify at any time:

```bash
find . -path ./.git -prune -o -path ./.tools -prune -o -path ./.godot -prune \
     -o -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.wav' -o -name '*.ogg' \
     -o -name '*.mp3' -o -name '*.ttf' -o -name '*.otf' -o -name '*.glb' \
     -o -name '*.fbx' -o -name '*.gdshader' \) -print
```

Expected output: nothing.

---

## Provenance statement

All code, level layouts, colour choices, character silhouettes, level names, story
text and UI copy in this repository were created for this project.

The connection to the 1989 original is expressed **exclusively through game design
concepts** — side-scrolling palace traversal, precision platforming, lethal traps,
sword combat, and ancient architecture as a hostile environment. These are ideas and
genre conventions, not protected assets.

No copyrighted art, audio, code, level data, map, character design or UI from the
original game, or from any commercial game, is included.
