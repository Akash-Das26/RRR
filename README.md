# PRINCE OF PERSIA: ECHOES OF TIME

> **Master your past to survive your present.**

A 2D cinematic action-platformer built in **Godot 4.7 / GDScript**, created for the
**RRR — Rewind. Reimagine. Reconnect.** competition.

The game reinterprets **Prince of Persia (1989, Brøderbund)** — its side-scrolling
palace platforming, precision movement, traps and swordplay — around a single new
system: the **Temporal Echo**. You record your own actions, release that recording
as a physical entity, and then solve problems *in cooperation with your own past*.

---

## Table of contents

- [The reimagining](#the-reimagining)
- [The Temporal Echo](#the-temporal-echo)
- [Current status](#current-status)
- [Controls](#controls)
- [Running the game](#running-the-game)
- [Verification](#verification)
- [Building a release](#building-a-release)
- [Project structure](#project-structure)
- [Architecture notes](#architecture-notes)
- [Known limitations](#known-limitations)
- [Roadmap](#roadmap)
- [Credits and asset licensing](#credits-and-asset-licensing)
- [Competition information](#competition-information)

---

## The reimagining

**This is not a remake.** No original Prince of Persia asset, level, sprite, sound
or map is used or reproduced. The connection is through *game design*, and the
result deliberately differs in every other respect:

| | Prince of Persia (1989) | Echoes of Time |
|---|---|---|
| Core loop | Escape a dungeon in 60 minutes | Cooperate with recorded versions of yourself |
| Signature system | One-hour countdown, sword duel timing | **Temporal Echo** — deterministic replay you puzzle with |
| Progression | Floor-by-floor escape | Teach → practice → combine → challenge |
| Combat | Turn-based sword duels | Real-time light/heavy attack, block, dodge |
| Structure | Single continuous dungeon | Distinct levels, each built around one idea |
| Art | Rotoscoped cinematic sprites | Procedural sandstone + temporal-energy art direction |

What is *kept* is the recognisable DNA: side-scrolling palace traversal, precision
jumping, lethal traps, sword combat, and a persistent sense of being an intruder
in a collapsing ancient place.

---

## The Temporal Echo

This is the game's thesis, and it is a **real system, not a visual effect**.

Press <kbd>Q</kbd> to begin recording. Every physics frame, the recorder captures
your position, rotation, velocity, animation state and facing, plus any gameplay
events (an interaction press, for example). Press <kbd>Q</kbd> again to stop, and
the take is released as a **Temporal Echo**.

An echo is a genuine gameplay entity:

- It has its own collision volume and is **visible to pressure plates, triggers and
  enemy detection** — geometry ignores it, mechanisms do not.
- It **replays the exact recorded transforms**, so it walks the same path at the
  same speed every time. This is what makes "my past self opens the door for me" a
  deterministic puzzle rather than a physics lottery.
- It **re-emits recorded gameplay events**, so it can throw a lever you pressed
  during the take.
- When a non-looping take ends, the echo **holds its final pose** until it expires.
  That single decision is what makes standing on a pressure plate a stable solution.
- Enemies can target an echo, so a memory can be used as bait.
- It costs **Temporal Energy**, which regenerates, and the number of simultaneous
  echoes is capped.

**Level 2 — Hall of Echoes — is built to prove it.** One recording must do two jobs
at once: pass through an echo-only rune to open the far gate *and* start the bridge
platform, then finish standing on a pressure plate to raise the near gate. Neither
the player alone nor a single-purpose recording can solve it.

---

## Current status

This repository is a **complete, running vertical slice** (development Phases 0–6 of
the project directive). It is honest about what exists:

**Implemented and verified**

- Godot 4.7 project, GDScript only, no external dependencies
- Player controller: 13-state modular state machine with coyote time, jump
  buffering, variable jump height and asymmetric rise/fall gravity
- Combat: light/heavy attacks with wind-up → active → recovery frames, directional
  block with damage reduction, dodge and roll with invulnerability frames, hurt,
  death
- Two enemy archetypes on a 7-state AI (`IDLE, PATROL, ALERT, CHASE, ATTACK, HURT,
  DEAD`) with ledge/wall probing, data-driven stats, and echo-baiting
- **The full Temporal Echo system** — recorder, snapshots, deterministic replay,
  event replay, energy economy, lifetime and capacity limits
- Reusable puzzle framework: `Activator` → `PressurePlate` / `Lever` /
  `TemporalSwitch`, driving `Door` / `TimedGate` / `MovingPlatform`
- `Hazard`, `Checkpoint`, `Ladder`, `LevelExit`
- Two data-driven levels, HUD, title / pause / level-complete / victory screens
- A headless test suite of **50 assertions**, plus a one-command verification gate

**Not yet implemented** (planned, not faked — see [Roadmap](#roadmap))

- Audio of any kind (no audio assets exist yet)
- Levels 3 and 4, and the Time Warden boss encounter
- The third enemy archetype (`TemporalSentinel`)
- Persistence of checkpoint progress to disk
- Gamepad support, sprite animation, export builds, and the gameplay video

---

## Controls

| Action | Key |
|---|---|
| Move | <kbd>A</kbd> <kbd>D</kbd> or <kbd>←</kbd> <kbd>→</kbd> |
| Climb up / down | <kbd>W</kbd> <kbd>S</kbd> on a climbable volume |
| Jump | <kbd>Space</kbd> |
| Light attack | <kbd>J</kbd> |
| Heavy attack | <kbd>K</kbd> |
| Block (front-facing) | <kbd>L</kbd> (hold) |
| Dodge / crouched roll | <kbd>Shift</kbd> (<kbd>Shift</kbd> while crouching rolls) |
| Interact | <kbd>E</kbd> |
| **Record / release Temporal Echo** | <kbd>Q</kbd> |
| Restart level | <kbd>R</kbd> |
| Pause | <kbd>Esc</kbd> |

Bindings are registered at runtime from a single table in
`scripts/systems/input_actions.gd`, so they are diffable in one place and cannot be
corrupted by a hand-edited config file.

---

## Running the game

**Requirements:** [Godot 4.7](https://godotengine.org/download) (standard build, no
Mono). Nothing else — the project has zero external dependencies.

1. Clone the repository.
2. Open `project.godot` in the Godot editor, or run from a terminal:

```bash
godot --path .
```

**Boot straight into a level** (skips the title screen — useful while iterating):

```bash
godot --path . -- --level=2      # 1-based level index
```

---

## Verification

The project ships a verification gate that downloads a headless Godot build on first
use, imports the project, boots **every** level, and runs the assertion suite:

```bash
./verify.sh
```

It exits non-zero on any failure, so it works as a CI step. Current status:

```
==> 1/3 Importing project          ok
==> 2/3 Booting levels headless    level 1 ok, level 2 ok
==> 3/3 Running test suite         50 passed, 0 failed
ALL CHECKS PASSED
```

Run the suite alone with:

```bash
./.tools/godot --headless --path . res://tests/test_main.tscn
```

See [`docs/QA_REPORT.md`](docs/QA_REPORT.md) for the bug log — including the
game-breaking wiring defect and the memory leak the suite was written to catch.

---

## Building a release

Export presets are **not** committed (they contain machine-specific paths). To build:

1. In the Godot editor, install the export templates for 4.7
   (*Editor → Manage Export Templates*).
2. *Project → Export…*, then add a **Windows Desktop** or **Web** preset.
3. Export.

The project currently targets **desktop first**; the web build has not been
validated and should be treated as untested.

> `.tools/` and `export_presets.cfg` are git-ignored. The headless Godot binary used
> by `verify.sh` is a 140 MB build artifact and is deliberately never committed.

---

## Project structure

```
project.godot           Engine config: autoloads, physics layers, renderer
icon.svg                Original project icon (hand-authored SVG)
verify.sh               One-command verification gate

scenes/main/            Entry-point scene (all content is built at runtime)
scripts/
  main/                 Bootstrap + QA level shortcut
  systems/              GameManager, EventBus, GameLayers, InputActions,
                        Health, Hitbox, Hurtbox, Palette
  temporal/             TemporalManager, Recorder, Snapshot, Echo, Config
  player/               Player + PlayerStateMachine + PlayerState
    states/             One file per state (13 total)
  enemies/              EnemyBase FSM, EnemyStats, PalaceGuard, ShadowEcho
  objects/              Activator pattern, ActuatorUtil, plates, levers, doors,
                        platforms, hazards, checkpoints, ladders, exits
  level/                LevelBuilder, Platform, LevelBackdrop
  ui/                   Hud, MenuScreen
data/levels/            Declarative level definitions
tests/                  Headless assertion suite
docs/                   GDD, presentation outline, QA report, asset licences
```

---

## Architecture notes

Four decisions are worth knowing before reading the code.

**1. Levels are data; the builder is code.** `data/levels/level_catalog.gd` declares
only *what exists and where*. `LevelBuilder` knows how to instantiate each prop. A
level never contains puzzle logic.

**2. Puzzles are wired, not scripted.** `Activator` is a mechanism with an on/off
state; `Door`, `TimedGate` and `MovingPlatform` listen to a list of sources. A level
says `"listens_to": ["plate_near"]` and nothing else. The same `Door` class serves a
one-plate tutorial gate and a two-source vault door with no new code.

**3. The state machine defers transitions.** A state requests a change and returns;
the machine applies it after the current state's update finishes. This makes it
structurally impossible to swap the active state mid-execution, which is the usual
source of one-frame glitches.

**4. The echo replays transforms, not physics.** It reproduces recorded positions
exactly. That is the whole basis of the puzzle design — the same memory produces the
same result, every time.

Two implementation details worth flagging:

- **`PlayerStateMachine` is a `Node`, not a `RefCounted`.** The machine owns the
  states and every state references the machine back. As reference-counted objects
  that is an uncollectable cycle that leaked all 13 states per level load. It is a
  `Node` precisely so the cycle cannot form.
- **`Door._recompute()` accepts the signal's argument.** It is bound directly to
  `Activator.active_changed`, so a zero-argument signature silently means doors
  never open. The test suite asserts this specific behaviour.

---

## Known limitations

Stated plainly, because a claim of completeness that is not true is worse than an
admitted gap.

- **No audio.** No sound effects or music exist yet; the audio phase has not begun.
- **Two levels.** Levels 3 and 4 and the boss are not built.
- **Visuals are procedural.** Every character and prop is drawn with `_draw()` in a
  coherent palette, not sprite animation. This is a deliberate art direction, but it
  is not final-production art.
- **Input is keyboard only.** No gamepad bindings yet.
- **Progress is session-only.** Checkpoints reset when the game is closed; there is
  no save file.
- **Not verified with human input.** The headless suite proves systems, wiring and
  determinism, but no automated test can confirm the game *feels* good to play. The
  feel values (acceleration, coyote time, jump height) are tuned by reasoning and
  should be play-tested.
- **Export builds untested.** No Windows or web build has been produced from this
  repository.
- **The gameplay video does not exist.** Recording it requires running the game with
  a display, which was not available in the environment this was built in.

---

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| 0–2 | Environment, foundation, player controller | Done |
| 3 | Combat, enemy AI | Done |
| 4 | Temporal Echo system | Done |
| 5 | Puzzle system | Done |
| 6 | Vertical slice (Levels 1–2) | Done |
| 7 | Levels 3–4, third enemy, Time Warden boss | Not started |
| 8 | Visual polish, transitions | Not started |
| 9 | Audio integration | Not started |
| 10 | Persistence | Not started |
| 11+ | QA, performance profiling, builds, video, GDD, presentation | Partially done (QA harness exists) |

---

## Credits and asset licensing

- **Design, code, art direction and level design:** original work created for this
  project.
- **Engine:** [Godot Engine 4.7](https://godotengine.org) — MIT licence.
- **All visual content** is drawn procedurally at runtime from the palette in
  `scripts/systems/palette.gd`. No third-party sprites, textures, fonts or artwork.
- **Original icon** (`icon.svg`) is hand-authored for this project.
- **No Prince of Persia asset of any kind** — sprite, map, sound, music, UI or
  character design — is included, reproduced or derived from.

Full detail in [`docs/ASSET_LICENSES.md`](docs/ASSET_LICENSES.md).

---

## Competition information

**Event:** RRR — Rewind. Reimagine. Reconnect.
**Brief:** Build a polished, original, playable game inspired by a video game first
released in the 20th century.
**Original title:** Prince of Persia (1989), Brøderbund — released within the
required 1900–1999 window.
**Deliverables:** playable build, gameplay video (<2 min), game design document,
presentation (<10 slides), original or properly licensed assets.

Submission document status:

| Deliverable | Status |
|---|---|
| Playable build (source) | ✅ This repository |
| Game design document | ✅ [`docs/GDD.md`](docs/GDD.md) |
| Presentation | ✅ Outline in [`docs/PRESENTATION.md`](docs/PRESENTATION.md) |
| QA report | ✅ [`docs/QA_REPORT.md`](docs/QA_REPORT.md) |
| Asset / licence record | ✅ [`docs/ASSET_LICENSES.md`](docs/ASSET_LICENSES.md) |
| Exported binary / APK | ⬜ Not produced |
| Gameplay video (<2 min) | ⬜ Not produced |
