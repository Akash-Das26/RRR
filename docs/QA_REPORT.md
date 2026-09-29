# QA REPORT
## Prince of Persia: Echoes of Time

**Build:** vertical slice, Phases 0–6
**Engine:** Godot 4.7.2 stable (`4.7.2.stable.official.ed1daf0bf`)
**Method:** headless verification — import, boot every level, run the assertion suite
**Date:** 2026-09-29

---

## Verification harness

`./verify.sh` runs three gates and exits non-zero on any failure:

| Gate | What it proves |
|---|---|
| **1. Import** | Every script parses and every scene loads. Catches syntax errors, bad `const` expressions and broken resource references. |
| **2. Level boot** | Each level is constructed and simulated headless for 400 frames. Catches runtime errors, engine warnings, leaked objects and orphaned resources. |
| **3. Test suite** | 50 assertions across the temporal system, combat components, puzzle wiring, level data and the player state machine. |

**Current result**

```
==> 1/3 Importing project          ok
==> 2/3 Booting levels headless    level 1 ok, level 2 ok
==> 3/3 Running test suite         50 passed, 0 failed

ALL CHECKS PASSED
```

The project boots and simulates with **zero** script errors, warnings, leaked
`ObjectDB` instances or dangling resources.

---

## Automated coverage

| Area | Assertions | Notes |
|---|---|---|
| Input map | 3 | All actions exist, keys bound, `ensure_defaults()` idempotent |
| Health component | 6 | Damage, i-frame refusal, heal, `kill()` bypassing i-frames |
| Temporal recorder | 7 | Start/stop, **duration cap enforced**, minimum-length rejection, event attachment |
| Level data | 9 | Both levels well-formed; **no dangling `listens_to` wiring references** |
| Puzzle wiring | 12 | Plate → door open/close, rune → far door *and* bridge, start states |
| Player state machine | 4 | All 13 states registered, unknown-state rejection, deferred transitions |
| Temporal echo | 9 | Spawn position, **deterministic replay**, **final-pose hold**, echoes trip plates, capacity enforced, cleanup |

The coverage intentionally concentrates on the two systems where a defect is both
easy to introduce and hard to notice: **puzzle wiring** (a door that silently never
opens) and **echo determinism** (a memory that behaves differently on replay).

---

## Defects found and fixed

Every defect below was found by the harness, not by inspection. Each entry follows the
directive's required bug format.

---

### BUG-001 — Doors never opened

| Field | Detail |
|---|---|
| **ID** | BUG-001 |
| **Severity** | **Critical** — made both levels unsolvable |
| **Reproduction** | Boot Level 2. Stand on the pressure plate at x=180. Observe the near door at x=640. |
| **Expected** | Door opens while the plate is held. |
| **Actual** | Door remained shut. The engine logged `Method expected 0 argument(s), but called with 1` on the `active_changed` signal. |
| **Root cause** | `Door._recompute()` was declared with no parameters, but `Activator.active_changed(active: bool)` emits one argument. Godot 4 requires a bound callable's signature to accept the emitted arguments; the mismatch caused the call to fail. `TimedGate` inherited the same defect via its override. |
| **Fix** | Both signatures changed to `_recompute(_active: bool = false)`. The optional parameter keeps direct zero-argument calls working. |
| **Regression test** | `holding the plate opens the door it is wired to`, `releasing the plate closes that door again`, `the rune opens the far door` |

**Why this matters:** without the harness this would have shipped as a game that
boots cleanly, looks correct, and cannot be completed. No amount of code reading
would reliably have caught it — only executing the wiring would.

---

### BUG-002 — Thirteen objects leaked per level load

| Field | Detail |
|---|---|
| **ID** | BUG-002 |
| **Severity** | High — unbounded memory growth on level transitions |
| **Reproduction** | `./.tools/godot --headless --verbose --path . --quit-after 200 -- --level=2` |
| **Expected** | Clean shutdown, no leaked instances. |
| **Actual** | `WARNING: 30 ObjectDB instances were leaked at exit`, including exactly **13 `RefCounted` instances** and 15 `GDScript` references. |
| **Root cause** | `PlayerStateMachine` was a `RefCounted` holding a dictionary of 13 `PlayerState` objects, and every `PlayerState` held a reference back to the machine. That is a **reference cycle**, which Godot's reference counting cannot collect. The 13 leaked `RefCounted` instances were precisely the 13 states. |
| **Fix** | `PlayerStateMachine` changed from `RefCounted` to `Node`, and attached as a child of the player. Nodes are manually managed, so the cycle cannot form and the machine is freed with its owner. |
| **Regression test** | `verify.sh` gate 2 now greps every level boot for `leaked` and `still in use`, and fails the build if either appears. |

**Why this matters:** the leak was invisible during play (it does not crash, it just
grows) and only surfaced because the verification gate checks for it explicitly.

---

### BUG-003 — `Vector2 + float` in the temporal rune renderer

| Field | Detail |
|---|---|
| **ID** | BUG-003 |
| **Severity** | High — `temporal_switch.gd` failed to compile, cascading to every script that referenced it |
| **Reproduction** | Run the import gate. |
| **Actual** | `Parse Error: Invalid operands "Vector2" and "float" for "+" operator` at `temporal_switch.gd:52`. Because `TemporalSwitch` is in the level builder's type registry, the failure cascaded: `LevelBuilder` failed to compile, which failed `GameManager`, which prevented the game from starting at all. |
| **Root cause** | `Rect2(-half + 3.0, ...)` — adding a scalar to a `Vector2` to inset a rectangle. |
| **Fix** | `Rect2(-half + Vector2(3.0, 3.0), ...)`. |
| **Regression test** | Gate 1 (import) now reports zero script errors. |

---

### BUG-004 — Class references in a `const` dictionary

| Field | Detail |
|---|---|
| **ID** | BUG-004 |
| **Severity** | High — project would not compile |
| **Actual** | `Parse Error: Assigned value for constant "OBJECT_TYPES" isn't a constant expression`. |
| **Root cause** | `LevelBuilder` declared `const OBJECT_TYPES := {"door": Door, ...}`. GDScript does not accept a class reference as a constant expression. |
| **Fix** | Converted both registries to `static func object_types()` / `enemy_types()` returning the dictionary. The cost is one small dictionary construction per level build — immeasurable. |
| **Regression test** | Gate 1. |

---

### BUG-005 — `enemy_base.gd` called a player-only helper

| Field | Detail |
|---|---|
| **ID** | BUG-005 |
| **Severity** | High — all enemy AI failed to compile; `PalaceGuard` and `ShadowEcho` could not resolve their base class |
| **Actual** | 8 × `Parse Error: Function "commit_motion()" not found in base self` |
| **Root cause** | `commit_motion()` is a helper defined on `Player`. The enemy state machine used the same name, but `EnemyBase` extends `CharacterBody2D`, which has no such method. |
| **Fix** | All 8 call sites changed to `move_and_slide()`, the direct Godot API. |
| **Regression test** | Gate 1; both levels boot and instantiate enemies cleanly. |

---

### BUG-006 — Test harness called `check()` on a `void` return

| Field | Detail |
|---|---|
| **ID** | BUG-006 |
| **Severity** | Low — test-only |
| **Actual** | `Parse Error: Cannot get return value of call to "heal()" because it returns "void"` |
| **Fix** | Split into a `heal()` call followed by a separate assertion. |

---

## Design decisions corrected during QA

Two behaviours were changed because testing revealed the original design was wrong.
Both are recorded because they are gameplay decisions, not simple fixes.

### The echo holds its final pose instead of looping

**Found by:** reasoning about BUG-001's regression suite while writing the echo tests.

A looping echo walks back to its starting point every lap. On a pressure plate that
means the plate flickers on and off, making every echo puzzle unsolvable or
infuriating. Changing `TemporalConfig.loop_echo` to default **`false`** — so an echo
plays its take once and then holds its final pose — makes *"record yourself standing
on the plate"* a stable, reliable solution. This single default is what makes the core
mechanic work as a puzzle system. It remains configurable for future levels that want
a patrolling echo.

### The moving platform ping-pongs instead of travelling one way

**Found by:** walking the Level 2 route during level authoring.

A one-way platform that travels to its far end and stops leaves the player stranded
once it has moved. `MovingPlatform` gained an `oscillate` mode (default **on**),
driven by a cosine so the motion is smooth and its period is derived from `speed` and
`travel` rather than being a magic number.

---

## Manual verification status

**Honest statement:** no automated test in this repository can confirm that the game
*feels* good to play, and no human-input playtest was possible in the environment
where this was built.

| Area | Automated | Human playtested |
|---|---|---|
| Scripts compile, scenes load | ✅ | n/a |
| Levels construct without errors | ✅ | — |
| Puzzle wiring opens and closes everything it should | ✅ | — |
| Echo replay is deterministic and holds its final pose | ✅ | — |
| Echo trips a pressure plate | ✅ | — |
| Player state machine registers and transitions correctly | ✅ | — |
| Health, damage, i-frames, death, healing | ✅ | — |
| Movement feel (acceleration, coyote time, jump arc) | ❌ | ❌ **Not verified** |
| Combat feel and hit feedback | ❌ | ❌ **Not verified** |
| Level completability by a human player | ❌ | ❌ **Not verified** |
| Frame rate under load | ❌ | ❌ **Not profiled** |
| Input responsiveness | ❌ | ❌ **Not verified** |

**Outstanding risk.** The highest remaining risk is that the tuned movement and combat
values do not *feel* right, or that a level is harder or softer than intended for a
human. These must be resolved by playing the game with a display, which is the
recommended next step before any submission.

---

## Recommended next actions

1. **Play the game** with a display and confirm both levels are completable.
2. **Tune** the exported movement and combat values in `player.gd`, `EnemyStats` and
   `TemporalConfig` based on that playtest.
3. Profile frame time with many echoes and enemies active.
4. Then proceed to the deferred phases (audio, levels 3–4, boss).
