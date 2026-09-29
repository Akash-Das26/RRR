# PRESENTATION — 9 SLIDES
## Prince of Persia: Echoes of Time

*RRR — Rewind. Reimagine. Reconnect.*

Slide count is **9**, inside the 10-slide limit. Each slide lists its on-screen copy
and the speaker notes for it.

> **Standing rule:** every claim on these slides must correspond to something that
> actually runs in the build. Nothing here is aspirational. The status of each
> deliverable is tracked in [`QA_REPORT.md`](QA_REPORT.md).

---

## SLIDE 1 — Title

**On screen**

> # PRINCE OF PERSIA: ECHOES OF TIME
>
> ### *Master your past to survive your present.*
>
> **Team:** [fill in]
> **Event:** RRR — Rewind. Reimagine. Reconnect.
> **Original inspiration:** Prince of Persia (1989)

**Speaker notes**

Open with the hook, not the backstory. One sentence: *"You play a man who can make
his own recent past real — and solve problems with a version of himself that he
choreographed thirty seconds ago."* Then stop talking and let slide 5 do its work.

---

## SLIDE 2 — Original inspiration

**On screen**

> ### PRINCE OF PERSIA (1989)
> Brøderbund · designed by Jordan Mechner
>
> What inspired us — **and what we did not take:**
>
> - ✔ Side-scrolling palace traversal
> - ✔ Precision platforming, lethal traps
> - ✔ Sword combat, hostile ancient architecture
> - ✘ No sprite, map, sound, UI or character from the original
>
> *The connection is design. Everything else is new.*

**Speaker notes**

Be direct about this early — it is the question judges are already asking. The
inspiration is chosen for its *systems*, which are ideas, not assets. Explicitly state
that no original asset is present and point at the asset licence record.

---

## SLIDE 3 — The reimagination

**On screen**

> ### TIME AS PRESSURE → TIME AS A TOOL
>
> | | 1989 | Echoes of Time |
> |---|---|---|
> | Central system | A one-hour countdown | **Temporal Echo replay** |
> | Combat | Turn-based duels | Real-time three-beat combat |
> | Structure | One continuous dungeon | Levels, each built on one idea |
> | Player fantasy | *Escape* | *Cooperate with yourself* |
>
> ### We kept the DNA. We rebuilt the brain.

**Speaker notes**

The one-line version: *the original made time a deadline; we made it a resource you
author.* Everything else in the reimagining follows from that single change.

---

## SLIDE 4 — Core gameplay loop

**On screen**

> ```
> EXPLORE → OBSERVE → PLATFORM → FIGHT OR AVOID
>    → DISCOVER PUZZLE
>    → ● RECORD YOURSELF ●
>    → RELEASE THE ECHO
>    → SOLVE IT WITH YOUR OWN PAST
>    → PROGRESS
> ```
>
> *The highlighted step is the only one no other game asks of you.*

**Speaker notes**

Walk the loop once, quickly, then land on the middle. The rest of the loop is familiar
platformer grammar — deliberately so. The player already knows how to jump and fight;
the game only has to teach one new idea.

---

## SLIDE 5 — The Temporal Echo *(the important slide)*

**On screen**

> ### ONE RECORDING. TWO JOBS. NO PLAYER CAN DO IT ALONE.
>
> ```
>  press Q ──▶ record    (position, velocity, state, events, 8s cap)
>  press Q ──▶ release   (a real entity, not an afterimage)
>
>     ┌─ the echo replays your exact path, every time ─┐
>     │  trips pressure plates · throws levers         │
>     │  pulls enemy aggro · holds its final pose      │
>     └────────────────────────────────────────────────┘
> ```
>
> **"What if your past could fight beside you?"**

**Speaker notes**

This is the thesis. Emphasise three things a judge cannot see from a screenshot:

1. **It is real** — not a visual clone. Deterministic replay of recorded transforms,
   with its own collision volume that plates and enemies can see.
2. **It holds its final pose** — which is what makes *"stand on the plate and leave a
   memory there"* a stable solution rather than a lucky one.
3. **It is limited** — costs energy, one echo at a time. The player cannot spam out of
   a puzzle.

Then give the concrete example from Level 2: one recording must pass through an
echo-only rune *and* finish on a pressure plate, opening two different doors at once.

---

## SLIDE 6 — Level and puzzle design

**On screen**

> ### TAUGHT, NOT TOLD
>
> **Level 1 — The Collapsing Gate**
> gaps → spikes → lever → **the plate you cannot outrun**
> *the game makes the echo an obvious necessity, with no tutorial text*
>
> **Level 2 — Hall of Echoes**
> one recording, two mechanisms
> *echo-only rune* + *pressure plate* → two doors, one memory
>
> Every level: **introduce → practice → combine → challenge → payoff**
> No puzzle is solvable without understanding the mechanic.

**Speaker notes**

The teaching method is the design point. Level 1 does not explain the echo; it places
a plate and a door far enough apart that outrunning it is impossible, and lets the
player conclude the answer themselves. Level 2 then demands the player author a route
that serves two mechanisms — the moment they realise *one* recording can do both is
the moment the game has taught itself.

---

## SLIDE 7 — Combat and progression

**On screen**

> ### COMBAT THAT PUNISHES POSITIONING
>
> Light 0.09s → 0.11s → 0.13s · Heavy 0.20s → 0.15s → 0.22s
> Block (frontal, 25% damage) · Dodge & Roll (invulnerable, committed)
>
> **Two archetypes**
> - **Palace Guard** — teaches the rules honestly; stops at ledges
> - **Shadow Echo** — hovers; punishes relying on the floor
>
> Both can be **baited by an echo** — your past is a decoy
>
> ### Same skill as the puzzles: read the room, then plan.

**Speaker notes**

Combat exists to reinforce the puzzle skill, not to compete with it. Wind-ups are long
enough to react to, so damage taken is a positioning error. And because enemies target
echoes, the temporal mechanic feeds back into combat — bait a guard with a memory and
reposition.

---

## SLIDE 8 — Technology and implementation

**On screen**

> ### GODOT 4.7 · GDSCRIPT · ZERO DEPENDENCIES
>
> ```
> PlayerStateMachine   13 states, deferred transitions
> TemporalManager      recorder · snapshots · echo lifecycle · energy
> EnemyBase FSM        IDLE→PATROL→ALERT→CHASE→ATTACK→HURT→DEAD
> Activator pattern    plates / levers / runes → doors / gates / platforms
> LevelBuilder         levels are DATA; the builder is CODE
> ```
>
> ### VERIFIED, NOT ASSUMED
> `./verify.sh` → import · boot every level · **50 assertions**
>
> *Caught a game-breaking defect (doors never opened) and a memory leak
> (13 states per level load) before either could ship.*

**Speaker notes**

Keep this tight, but do not skip the verification gate — it is a genuine differentiator
and it is the honest answer to *"how do you know it works?"* Mention one bug
specifically: the door wiring defect produced a game that booted perfectly, looked
correct, and was impossible to finish. Only executing the wiring found it.

Mention the architecture principle: puzzles are **wired, not scripted** — a level says
`"listens_to": ["plate_near"]` and nothing else, so a new puzzle is data, not code.

---

## SLIDE 9 — Gameplay and conclusion

**On screen**

> ### [GAMEPLAY — live demo or the <2 min capture]
>
> Movement → spikes → lever → **first echo** → **the two-job recording** → combat
>
> ---
>
> **Repo:** github.com/officialarghya29/RRR
> **Run it:** open `project.godot` in Godot 4.7
> **Verify it:** `./verify.sh`
>
> ### Connect to the original, and it will teach you something it never could.
>
> ## THANK YOU

**Speaker notes**

Close on the thesis, not on a feature list: the game is recognisably Prince of Persia
in your hands within seconds, and within a minute it is asking you to do something the
1989 game never could. Then invite them to open the repo and run `verify.sh` — the
claim is checkable.

---

## Appendix — likely judge questions

**"Isn't this just a re-skin?"**
No. The original's central system was a countdown; this one is a replayable, physical
recording. That change rewrites the core loop, the puzzle grammar and the level design
method, and the slide 3 table shows the rest.

**"Did you copy any assets?"**
No. There are no image, audio or font files in the project at all — every visual is
drawn procedurally at runtime from one palette file. `docs/ASSET_LICENSES.md` has a
one-command audit to prove it.

**"How do you know the echo system actually works?"**
It is covered by nine assertions: spawn position, deterministic replay, final-pose
hold, plate activation, capacity enforcement and cleanup. Level 2's puzzle depends on
all of it.

**"What isn't finished?"**
Stated plainly in the README: no audio yet, two of four levels built, no boss, no
exported binary and no gameplay video. Three enemy archetypes were planned, two are
done.

**"What would you do next?"**
Playtest with a display to tune movement feel — it is the one thing automated tests
cannot verify — then audio, then Levels 3–4 and the Time Warden boss.
