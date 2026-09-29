# GAME DESIGN DOCUMENT
## Prince of Persia: Echoes of Time

*RRR — Rewind. Reimagine. Reconnect.*

---

### 1. Game title

**Prince of Persia: Echoes of Time**

One-line hook: **"What if your past could fight beside you?"**

---

### 2. Original inspiration

**Prince of Persia** (1989), designed by Jordan Mechner and published by Brøderbund.
Selected because it falls inside the required 1900–1999 window and because its
identity is built on *systems*, not on a specific look — precision traversal, lethal
architecture, swordplay, and time pressure as a design language.

---

### 3. Game overview

A 2D cinematic action-platformer for desktop. The player crosses a palace that is
tearing itself apart across different moments in time, and learns to weaponise their
own recorded past. Traversal and light combat frame a puzzle system built entirely
around one mechanic: **the Temporal Echo**.

---

### 4. Design goal

**Small, polished, complete** — not large and broken.

Priority order: functionality → gameplay feel → stability → core mechanic → level
design → visual polish → audio → performance → presentation. A simple system that
works is worth more than an ambitious one that almost does.

---

### 5. Story

The palace was severed from a single timeline by a temporal anomaly. Corridors,
courtyards and chambers now exist in different eras simultaneously, and the
architecture is collapsing through the fractures.

An intruder inside it — the protagonist — discovers that the anomaly will grant
physical form to his own recent past: a **Temporal Echo**. He cannot fight the
collapse directly. He can only become better at cooperating with the person he was
thirty seconds ago, because the palace's mechanisms no longer respond to a single
person acting alone.

---

### 6. Player character

A nameless, agile intruder — the "prince" role from the original, retained as a
design function rather than a licensed character.

- Fast, light, precision-oriented movement with real recovery frames.
- Fights with a blade: light and heavy strikes, a directional block, and an
  invulnerable dodge.
- Physically fragile. The toolkit is *evasion and positioning*, not attrition.
- Defined entirely by the Echo: the character's strength is that he can be in two
  places in one room, provided he earns it with planning.

---

### 7. Core gameplay loop

```
EXPLORE  →  OBSERVE ENVIRONMENT  →  MOVE / PLATFORM
   →  FIGHT OR AVOID  →  DISCOVER PUZZLE
   →  RECORD TEMPORAL ACTION  →  RELEASE TEMPORAL ECHO
   →  COOPERATE WITH YOUR OWN PAST  →  SOLVE  →  PROGRESS
   →  CHECKPOINT  →  REPEAT, HARDER
```

The distinctive step is the middle one. Every puzzle is authored so that the answer
is *a choreography you perform before you need it*.

---

### 8. Temporal Echo mechanic

**The signature system.**

| Step | Behaviour |
|---|---|
| Start recording | <kbd>Q</kbd>. Every physics frame is sampled into a bounded buffer. |
| Capture | Position, rotation, velocity, animation state, facing, and gameplay events. |
| Stop | <kbd>Q</kbd> again, or the duration cap (default 8 s). Takes shorter than 0.3 s are discarded. |
| Release | The take becomes a physical `TemporalEcho` entity. |
| Replay | The echo reproduces recorded transforms **exactly** — no physics re-simulation. |
| Interact | It trips pressure plates, throws levers via replayed events, and can be targeted by enemies as bait. |
| Hold | A non-looping take ends by *holding its final pose* until the echo expires. |
| Expire | After its lifetime (default 24 s), or when replaced by the capacity limit. |

**Design rules that make it a puzzle rather than a toy**

1. **Determinism.** Playback is positional, so the same recording always produces the
   same result. Puzzles can be authored with confidence.
2. **Hold the final pose.** Looping would walk the echo back off a pressure plate
   every lap and make plates flicker. Holding is what makes "stand still on the
   plate" a *stable* solution — and it is what turns recording into a deliberate
   authoring act rather than a lucky one.
3. **Visible to mechanisms, invisible to geometry.** An echo passes through walls and
   trips plates. It is a memory, not a body.
4. **Costly and limited.** Temporal Energy is spent per echo and regenerates slowly.
   One active echo by default. The player cannot spam their way through a puzzle.
5. **Not a second player.** An echo cannot be steered, does not react, and has no
   health. It is a recording — the intelligence is entirely the player's.

**Starting limits → later upgrade:** 8 s / 1 echo ships in this slice. The directive's
12 s / 2 echoes upgrade exists in code as `TemporalConfig.advanced_variant()` and is
awaiting a level designed for it.

---

### 9. Combat

Simple, responsive, readable. Three-beat attacks with meaningful commitment.

| Action | Notes |
|---|---|
| Light attack | 0.09 s wind-up → 0.11 s active → 0.13 s recovery |
| Heavy attack | 0.20 s wind-up → 0.15 s active → 0.22 s recovery, stronger knockback |
| Block | Hold. Reduces frontal damage to 25%. Rear attacks land in full. |
| Dodge | Committed, invulnerable dash. Aimable, including backwards. |
| Roll | Crouched variant. Longer, lower, also invulnerable. |

Combat's design job is to *punish bad positioning*, which is the same skill the echo
puzzles reward. Enemies telegraph their attacks with a long enough wind-up to react
to; getting hit is a positioning error, not a reflex failure.

---

### 10. Enemy design

Two archetypes shipped, both on one 7-state AI
(`IDLE → PATROL → ALERT → CHASE → ATTACK → HURT → DEAD`):

| Enemy | Role | Behaviour |
|---|---|---|
| **Palace Guard** | Teaches the combat rules honestly | Grounded melee, patrols, stops at ledges, gives up if you flee far enough |
| **Shadow Echo** | Punishes relying on the floor | Hovers (ignores gravity), steers in both axes, faster to aggro |

Both acquire **echoes as valid targets**, so a memory can be used as bait while the
player repositions. Stats live in `EnemyStats` resources, so variants are data, not
code.

*Planned third archetype:* **Temporal Sentinel** — a ranged threat, deferred.

---

### 11. Level design

Every level follows **introduce → practice → combine → challenge → payoff**, and
introduces exactly one new idea at a time.

**Level 1 — The Collapsing Gate** *(tutorial)*
1. Gaps that teach jump arcs and stopping distance.
2. A spike run that must be jumped.
3. A latched lever raising a gate — teaches interaction with zero pressure.
4. A plate that releases the instant you step off, and a gate far behind it. You
   cannot outrun it. **Record yourself standing on the plate and leave the memory
   behind.** This is the first echo, taught as an obvious necessity rather than a
   tutorial prompt.

**Level 2 — Hall of Echoes** *(the thesis)*
One recording must do two jobs simultaneously:
- pass through an **echo-only rune** (which latches, opening the far gate *and*
  starting the bridge platform), and
- finish standing on the **pressure plate** that raises the near gate.

Neither the player acting alone nor a single-purpose recording can solve it.
The player must author a route that serves two mechanisms at once — and the moment it
clicks is the moment the game has taught itself.

---

### 12. Puzzle design

Built from a small set of **reusable, wireable** mechanisms rather than bespoke rooms.

| Component | Role |
|---|---|
| `Activator` | Base for anything with an on/off state |
| `PressurePlate` | Floor weight trigger; filterable to player, echo, or either |
| `Lever` | Hand-operable; can be latched; throws when an echo re-emits an interact event |
| `TemporalSwitch` | Echo-only, latched rune — the "only your past can reach this" affordance |
| `Door` | Barrier driven by one or more sources (all-of or any-of) |
| `TimedGate` | Opens for a fixed window, then closes itself |
| `MovingPlatform` | Travels or ping-pongs while engaged; carries riders |
| `Hazard` | Spikes and temporal ruptures |
| `Checkpoint` / `Ladder` / `LevelExit` | Progression and traversal |

A level expresses puzzles declaratively:

```gdscript
{"type": "door", "id": "door_near", "pos": Vector2(640, 560),
 "params": {"size": Vector2(56, 155)},
 "listens_to": ["plate_near"]}
```

**Rule enforced by design:** no puzzle may be solvable without understanding the echo
mechanic. If a room can be brute-forced by the player alone, it is not finished.

---

### 13. Art direction

**Stylized cinematic ancient Persian fantasy** — warm sandstone architecture shot
through with cold temporal energy.

- **Palette:** sandstone deep/shade/base/light/edge; temporal core/glow/deep; distinct
  enemy hues; restrained UI.
- **Temporal visual language:** blue-white energy, afterimage trails, distortion
  seams, suspended motes, fractured architecture.
- **Executed procedurally.** Every surface, silhouette and effect is drawn at runtime
  from `Palette`. This keeps the visual identity perfectly coherent, guarantees no
  asset is borrowed, and lets the placeholder-to-final transition happen without
  touching gameplay code.
- **Never copied.** No original Prince of Persia art, UI or character design appears.

---

### 14. Audio direction *(not yet implemented)*

Planned, and deliberately not faked with placeholder silence passed off as complete.

The sonic identity should reinforce the mechanic: temporal effects carry a pitched
reverse-tone signature; recording begins with a rising tone that resolves when the
echo is released; echoes are EQ'd slightly hollow, as if heard through time. Combat
prioritises clear impact separation over volume. No third-party audio will be used
without a recorded licence.

---

### 15. Technology

| | |
|---|---|
| Engine | Godot 4.7 (stable) |
| Language | GDScript |
| Renderer | GL Compatibility (desktop-first, web-capable) |
| Target | Desktop primary; web secondary and currently unvalidated |
| Dependencies | **None** — every system uses built-in Godot functionality |
| Physics | 2D, fixed 60 Hz, explicit 10-layer collision matrix |
| Verification | Headless CI gate: import → boot every level → 50-assertion suite |

---

### 16. Connection to the original game

The inspiration is designed to be legible within seconds:

- Side-scrolling palace traversal with precision platforming
- Lethal architectural traps
- Sword combat against armed guards
- Being an intruder in a hostile, ancient, crumbling palace
- Climbing and ledge-style vertical movement

---

### 17. Major reinterpretations

| Dimension | Original | Echoes of Time |
|---|---|---|
| Central system | One-hour countdown | Temporal Echo replay |
| Genre emphasis | Cinematic platforming | Action-platforming **+ temporal puzzle** |
| Combat | Turn-based duel timing | Real-time three-beat combat |
| Structure | One continuous dungeon | Tuned levels, each built on one idea |
| Antagonist | Jaffar | The collapse itself, and time |
| Time as a mechanic | Pressure (a clock counting down) | **A resource you author (a clock you write)** |
| Player fantasy | Escape | Cooperate with yourself |
| Visual identity | Rotoscoped sprites | Procedural sandstone + temporal energy |

The single sentence: **the original used time as pressure; this uses time as a tool.**

---

### 18. Development scope

Built as a **vertical slice first**, exactly as the directive requires.

- **Delivered:** Phases 0–6 — foundation, player controller, combat, the complete
  Temporal Echo system, the reusable puzzle framework, and two finished levels.
- **Protocol followed:** inspect → plan → smallest reliable implementation → run →
  fix → regression test → verify → document.
- **Verification discipline:** nothing is claimed as working that was not executed.
  The suite caught one game-breaking defect (doors never opened) and one memory leak
  (13 player states leaked per level load) before either could ship.

---

### 19. Controls

| Action | Key |
|---|---|
| Move | <kbd>A</kbd>/<kbd>D</kbd> or <kbd>←</kbd>/<kbd>→</kbd> |
| Climb | <kbd>W</kbd>/<kbd>S</kbd> on a climbable volume |
| Jump | <kbd>Space</kbd> |
| Light / heavy attack | <kbd>J</kbd> / <kbd>K</kbd> |
| Block | <kbd>L</kbd> (hold) |
| Dodge / roll | <kbd>Shift</kbd> |
| Interact | <kbd>E</kbd> |
| **Record / release echo** | <kbd>Q</kbd> |
| Restart level | <kbd>R</kbd> |
| Pause | <kbd>Esc</kbd> |

---

### 20. Future expansion

1. **Levels 3–4** — Broken Courtyard (combat + echo combined) and Clockwork Sanctum
   (multi-mechanism timing puzzles, temporal hazards).
2. **Time Warden boss** — a short encounter combining combat, platforming and echo
   use, where the boss itself manipulates your echoes.
3. **Two-echo puzzles** — using the already-implemented 12 s / 2-echo configuration.
4. **Temporal Sentinel** — the third enemy archetype, ranged.
5. **Audio pass** — the direction described in section 14.
6. **Persistence** — checkpoint and level progress to disk.
7. **Polish** — sprite animation, camera work, transitions, hit-stop, screen effects.
8. **Presentation deliverables** — exported builds and the <2 min gameplay capture.
