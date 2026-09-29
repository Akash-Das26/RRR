# QA REPORT
## Prince of Persia: Echoes of Time

**Build:** five-level slice, Phases 0–7
**Engine:** Godot 4.7.2 stable (`4.7.2.stable.official.ed1daf0bf`)
**Method:** headless verification — import, boot every level, run the assertion suite
**Date:** 2026-09-29

---

## Verification harness

`./verify.sh` runs three gates and exits non-zero on any failure:

| Gate | What it proves |
|---|---|
| **1. Import** | Every script parses and every scene loads. Catches syntax errors, bad `const` expressions and broken resource references. |
| **2. Level boot** | Every level is constructed and simulated headless for 400 frames. Catches runtime errors, engine warnings, leaked objects and orphaned resources. |
| **3. Test suite** | Assertions across the temporal system, combat components, puzzle wiring, enemy statistics, boss behaviour, level data and the player state machine. |

**Current result**

```
==> 1/3 Importing project          ok
==> 2/3 Booting levels headless    levels 1-5 ok
==> 3/3 Running test suite         116 passed, 0 failed

ALL CHECKS PASSED
```

All five levels boot and simulate with **zero** script errors, warnings, leaked
`ObjectDB` instances or dangling resources.

---

## Automated coverage

| Area | Notes |
|---|---|
| Input map | Actions exist, keys bound, `ensure_defaults()` idempotent |
| Health component | Damage, i-frame refusal, heal, `kill()` bypassing i-frames |
| Temporal recorder | Start/stop, **duration cap enforced**, minimum-length rejection, event attachment |
| Level data (all 5) | Well-formed spawn/bounds/platforms; **no dangling `listens_to` refs**; every wiring target actually supports `bind_sources` |
| Puzzle wiring | Plate → door open/close; rune → far door *and* bridge |
| Advanced levels | Three-source `require_all` door: 1 and 2 of 3 sources insufficient, all 3 opens, losing any one closes |
| Temporal rule tiers | Per-level overrides apply, and stock rules are restored afterwards |
| Boss | Starts shielded; shielded hits fully nullified; plate drops the shield; hits then land; phase thresholds at 60% / 25%; shield restored on release |
| Enemy statistics | 4 archetypes; melee reach inside attack range; ranged stand-off inside firing envelope; disengage ≥ detection |
| Player state machine | All 13 states, unknown-state rejection, deferred transitions |
| Temporal echo | Spawn position, **deterministic replay**, **final-pose hold**, echoes trip plates, capacity enforced, cleanup |

The coverage deliberately concentrates on the two failure modes that are easy to
introduce and hard to notice: **puzzle wiring** (a door that silently never opens)
and **enemy reach** (a weapon that cannot physically connect with the thing it
commits to attacking).

---

## Defects found and fixed

Every defect below was found by the harness or by a deliberate deep-scan pass —
none were found by casual inspection. Each entry follows the directive's required
bug format.

---

### BUG-001 — Doors never opened

| Field | Detail |
|---|---|
| **ID** | BUG-001 |
| **Severity** | **Critical** — made the game unsolvable |
| **Reproduction** | Boot Level 2. Stand on the plate at x=180. Watch the door at x=640. |
| **Expected** | Door opens while the plate is held. |
| **Actual** | Door stayed shut. Engine logged `Method expected 0 argument(s), but called with 1`. |
| **Root cause** | `Door._recompute()` took no parameters, but `Activator.active_changed(active: bool)` emits one. Godot 4 requires a bound callable's signature to accept the emitted arguments; the mismatch made every call fail. `TimedGate` inherited it. |
| **Fix** | Both signatures became `_recompute(_active: bool = false)`. |
| **Regression test** | `holding the plate opens the door it is wired to`, `the rune opens the far door` |

---

### BUG-002 — Thirteen objects leaked per level load

| Field | Detail |
|---|---|
| **ID** | BUG-002 |
| **Severity** | High — unbounded memory growth on level transitions |
| **Reproduction** | `./.tools/godot --headless --verbose --path . --quit-after 200 -- --level=2` |
| **Actual** | `WARNING: 30 ObjectDB instances were leaked at exit`, including exactly **13 `RefCounted` instances**. |
| **Root cause** | `PlayerStateMachine` was a `RefCounted` holding 13 `PlayerState` objects, and every state held a reference back to the machine — an uncollectable **reference cycle**. The 13 leaked instances were precisely the 13 states. |
| **Fix** | `PlayerStateMachine` became a `Node`, attached as a child of the player. |
| **Regression test** | Gate 2 greps every level boot for `leaked` / `still in use` and fails the build if either appears. |

---

### BUG-003 — `Vector2 + float` in the temporal rune renderer

| Field | Detail |
|---|---|
| **ID** | BUG-003 |
| **Severity** | High — cascading compile failure |
| **Actual** | `Parse Error: Invalid operands "Vector2" and "float" for "+" operator`. Because `TemporalSwitch` is in the level builder's registry, the failure cascaded through `LevelBuilder` → `GameManager`, preventing the game from starting at all. |
| **Root cause** | `Rect2(-half + 3.0, ...)` — adding a scalar to a `Vector2`. |
| **Fix** | `Rect2(-half + Vector2(3.0, 3.0), ...)`. |
| **Regression test** | Gate 1. |

---

### BUG-004 — Class references in a `const` dictionary

| Field | Detail |
|---|---|
| **ID** | BUG-004 |
| **Severity** | High — project would not compile |
| **Actual** | `Parse Error: Assigned value for constant "OBJECT_TYPES" isn't a constant expression`. |
| **Root cause** | `const OBJECT_TYPES := {"door": Door, ...}`. GDScript does not accept a class reference as a constant expression. |
| **Fix** | Converted both registries to `static func object_types()` / `enemy_types()`. |
| **Regression test** | Gate 1. |

---

### BUG-005 — `enemy_base.gd` called a player-only helper

| Field | Detail |
|---|---|
| **ID** | BUG-005 |
| **Severity** | High — all enemy AI failed to compile |
| **Actual** | 8 × `Parse Error: Function "commit_motion()" not found in base self` |
| **Root cause** | `commit_motion()` is a helper on `Player`; `EnemyBase` extends `CharacterBody2D`, which has no such method. |
| **Fix** | All 8 call sites changed to `move_and_slide()`. |
| **Regression test** | Gate 1; both levels instantiate enemies cleanly. |

---

### BUG-006 — Test harness called `check()` on a `void` return

| Field | Detail |
|---|---|
| **ID** | BUG-006 |
| **Severity** | Low — test-only |
| **Fix** | Split into a call followed by a separate assertion. |

---

### BUG-007 — Enemies swung at their own chest

| Field | Detail |
|---|---|
| **ID** | BUG-007 |
| **Severity** | **High** — combat was effectively broken in the enemies' favour being unarmed |
| **Found by** | Deep-scan pass over `enemy_base.gd` |
| **Reproduction** | Stand in front of a Palace Guard. Watch it commit to an attack and swing. |
| **Expected** | The swing damages the player standing in front of it. |
| **Actual** | The attack hitbox was configured with **zero offset**, so it was centred on the enemy's own body rather than in front of it. `attack_range` is 52 px but the hitbox only reached ~23 px from the enemy's centre, so a player standing in the intended attack zone was frequently outside it. Swings connected only when the player was already overlapping the enemy. |
| **Root cause** | The enemy's attack hitbox was never positioned by facing. `Player` had `_update_hitbox_placement()`, but `EnemyBase` had no equivalent — the facing logic only re-aimed the ledge and wall probes. |
| **Fix** | Added `WEAPON_REACH` and made `_update_probes()` also place the attack hitbox at `facing * WEAPON_REACH`. Called once at spawn and on every facing change. |
| **Regression test** | `Enemy statistics` asserts `WEAPON_REACH < attack_range` for every melee archetype, so the hitbox can never again be authored to fall short of where the AI commits. |

---

### BUG-008 — Enemy probes uninitialised at spawn

| Field | Detail |
|---|---|
| **ID** | BUG-008 |
| **Severity** | Medium — patrol behaviour wrong for the first seconds of every enemy's life |
| **Found by** | Deep-scan pass |
| **Actual** | `_wall_probe.target_position` defaulted to `Vector2.ZERO`, a zero-length ray, and the ledge probe's lateral offset was never set — because `_update_probes()` was only ever reached from `_flip()` and `_face_target()`. |
| **Root cause** | No initial call to `_update_probes()` in `_ready()`. |
| **Fix** | `_update_probes()` is now called after the body is built and before the first state runs. |
| **Regression test** | Covered by the level-boot gate; enemies now behave identically on frame 1 and frame 100. |

---

### BUG-009 — Echo applied its first frame outside the scene tree

| Field | Detail |
|---|---|
| **ID** | BUG-009 |
| **Severity** | Low at present, latent |
| **Found by** | Deep-scan pass over `temporal_echo.gd` |
| **Actual** | `setup()` called `_apply_frame(0)`, which assigns `global_position` — but `setup()` runs **before** `add_child()`. Setting `global_position` outside the tree writes the *local* position, so the echo silently baked in whatever transform its container happened to have and appeared at the wrong place. |
| **Root cause** | `global_position` is meaningless before a node is parented. |
| **Fix** | The initial frame is now applied in `_ready()`, once the echo is parented. |
| **Regression test** | `echo starts at the first recorded frame` |

---

### BUG-010 — HUD and menus positioned with anchor presets applied after the fact

| Field | Detail |
|---|---|
| **ID** | BUG-010 |
| **Severity** | Medium — HUD elements could land in the wrong place |
| **Found by** | Deep-scan pass over the UI |
| **Actual** | `_make_panel()` set `position`/`size` and *then* called `set_anchors_preset()`. That method rewrites a control's offsets, so it repositions the control rather than decorating an already-placed one. Whether the bars landed correctly was accidentally dependent on call order. |
| **Root cause** | Anchor presets are a layout system; combining them with hard-coded coordinates on a fixed logical viewport is incoherent. |
| **Fix** | Removed every anchor preset from the HUD and menus. The project uses `canvas_items` stretch with a 1280x720 base, so the logical viewport is *always* that size and absolute coordinates are exact. Layout constants are now derived from `VIEWPORT_WIDTH`/`VIEWPORT_HEIGHT`. |
| **Regression test** | Gate 2 (the HUD is constructed at boot on every level); layout is now deterministic. |

---

### BUG-011 — The boss could out-kite the player forever

| Field | Detail |
|---|---|
| **ID** | BUG-011 |
| **Severity** | **High** — boss was effectively unkillable |
| **Found by** | Deep-scan pass while authoring the level |
| **Actual** | `_chase_ranged()` treated a *crowded* player as a reason to retreat: below `preferred_range * 0.55` (≈181 px for the Warden) it backed away. But the player's melee only reaches ~50 px. The Warden would therefore retreat every time the player closed to striking distance, and a chasing player at 250 px/s against a retreating boss at 105 px/s only closes the gap if it never turns to fight. The fight was a chase, not a fight. |
| **Root cause** | Retreat-on-crowd is correct for a hovering skirmisher and wrong for a boss. The behaviour was in shared code with no way to opt out. |
| **Fix** | Added `EnemyStats.retreat_when_crowded` (default `true`, so the `TemporalSentinel` keeps its skirmisher identity; the `TimeWarden` sets `false` and holds its ground at any range). |
| **Regression test** | `the Warden stays grounded, inside melee reach` plus the `Enemy statistics` reach assertions. |

---

## Design decisions corrected during QA

These are gameplay corrections, not simple fixes. They are recorded because they
changed the design.

### The echo holds its final pose instead of looping

A looping echo walks back to its starting point every lap. On a pressure plate that
means the plate flickers on and off, making every echo puzzle unsolvable or
infuriating. `TemporalConfig.loop_echo` now defaults to **`false`**, so an echo plays
its take once and then holds its final pose. This single default is what makes
"record yourself standing on the plate" a stable solution. Still configurable for
future levels that want a patrolling echo.

### The moving platform ping-pongs instead of travelling one way

A one-way platform that travels to its far end and stops strands the player once it
has moved. `MovingPlatform` gained an `oscillate` mode (default **on**), driven by a
cosine so the period derives from `speed` and `travel` rather than a magic number.

### The boss holds its ground

See BUG-011. The Warden also grew `stagger_immune` after analysis showed that a fast
attacker could otherwise cancel every wind-up and stun-lock a 320 HP boss
indefinitely. And both the Warden and the Sentinel gained a reach/stand-off sanity
check in the test suite, because "the enemy commits to an attack it cannot land" and
"the enemy retreats outside its own firing envelope" are the same class of bug.

---

## Level geometry audit

Automated tests prove systems work. They cannot prove a level is *completable*, so
every jump in every level was checked against the player's actual movement
parameters.

**Derived from `Player`'s exported values** (`jump_velocity` 530, `gravity` 1650,
rise multiplier 0.86, `max_run_speed` 250):

| Quantity | Value |
|---|---|
| Apex height | **99.0 px** |
| Apex time | 0.374 s |
| Total air time (flat jump) | 0.720 s |
| **Flat jump range** | **180.0 px** |

Because the rise window is not symmetric, landing on a *raised* platform has a usable
horizontal window rather than a single maximum:

| Landing Δy | Usable horizontal window |
|---|---|
| +40 px | 21.3 – 165.5 px |
| +60 px | 34.8 – 152.0 px |
| +70 px | 42.9 – 143.9 px |
| +80 px | 52.5 – 134.3 px |
| +90 px | 65.3 – 121.5 px |

Every authored gap, checked against that table:

| Level | Gap | Distance | Δy | Verdict |
|---|---|---|---|---|
| 1 | A→B | 140 | +40 | ✅ window 21–165 |
| 1 | B→C | 140 | −40 | ✅ drop, easier |
| 1 | C→D | 40 | 0 | ✅ |
| 2 | A→far platform | 340 | −40 | ✅ bridged by the oscillating platform (edges 15 px apart) |
| 3 | A→B | 140 | +40 | ✅ |
| 3 | B→C | 140 | −40 | ✅ |
| 3 | C→D | 100 | +60 | ✅ window 35–152 |
| 4 | A→B | 160 | +40 | ✅ bridged by the oscillating platform |
| 4 | B→C | 140 | −40 | ✅ |
| 5 | floor→cover slab | — | +80 | ✅ window 53–134 |

**Two geometry defects were found and fixed by this audit:**

- **Level 1** had a decorative fracture ledge 140 px above its platform — outside the
  99 px arc. It was solid geometry that read as a platform the player *should* be able
  to reach. Removed: unreachable collision is a trap.
- **Level 3**'s broken arch was 90 px up with its leading edge 60 px from the natural
  run-up start, and the window for that height begins at 65 px — reachable only from a
  perfect approach. Lowered to 70 px (window 43–144), so it is reachable from a normal
  run-up.

These were **not** caught by any test. They were caught by doing the arithmetic, which
is the reason the arithmetic is recorded here.

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
| Boss shield gating and phase thresholds | ✅ | — |
| Enemy reach / stand-off sanity | ✅ | — |
| Player state machine registers and transitions | ✅ | — |
| Health, damage, i-frames, death, healing | ✅ | — |
| Jump arcs vs. authored gaps | ✅ by arithmetic, not by play | — |
| **Level completability by a human** | ❌ | ❌ **Not verified** |
| **Movement feel** (acceleration, coyote time, jump arc) | ❌ | ❌ **Not verified** |
| **Combat feel and hit feedback** | ❌ | ❌ **Not verified** |
| **Boss fight pacing and length** | ❌ | ❌ **Not verified** |
| **Whether the two-echo puzzle reads as fair** | ❌ | ❌ **Not verified** |
| Frame rate under load | ❌ | ❌ **Not profiled** |

**Outstanding risk.** Level 4 is the highest-risk content: it requires the player to
record two routes, one of which must pass through a rune *and* end on a plate, while
both plates are held simultaneously and the first echo is running out of time. The
logic is verified; whether a human finds the intended solution without frustration is
not, and the echo lifetime (45 s on that level) is a guess rather than a measured
value.

---

## Recommended next actions

1. **Play every level** with a display and confirm each is completable and fairly
   tuned. This is the highest-value remaining work.
2. **Tune** the exported values in `player.gd`, `EnemyStats` and `TemporalConfig`
   from that playtest — especially the Warden's health, the two-echo timing on
   Level 4, and the echo lifetime.
3. **Profile** frame time with two echoes, four enemies and active projectiles.
4. Then proceed to the deferred phases (audio, persistence, builds, gameplay video).
