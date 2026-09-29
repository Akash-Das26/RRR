class_name LevelCatalog
extends RefCounted
## The level list, as pure data.
##
## Each entry describes [i]what[/i] exists and [i]where[/i]; [LevelBuilder] knows
## how to instantiate it. Puzzle wiring uses string ids, so a door simply says
## which mechanisms it listens to and no puzzle needs bespoke code.
##
## Coordinates: the world is Y-down. A platform's rect is its top-left corner
## plus size, so a floor whose surface is at y = 560 is authored as
## Rect2(x, 560, width, depth). Props are positioned by their own origin.
##
## Difficulty curve deliberately follows introduce → practice → combine →
## challenge → payoff:
##   1. Collapsing Gate  — movement, hazards, interaction, the first echo.
##                                                              (no combat)
##   2. Hall of Echoes   — one recording must satisfy two mechanisms.
##   3. Broken Courtyard — combat, hazards and an echo puzzle combined.
##   4. Clockwork Sanctum— TWO echoes required (12 s / 2 echoes tier).
##   5. The Time Warden  — boss whose shield only opens for a memory.

const LEVEL_ONE_SPAWN := Vector2(100.0, 470.0)
const LEVEL_TWO_SPAWN := Vector2(60.0, 470.0)
const LEVEL_THREE_SPAWN := Vector2(0.0, 480.0)
const LEVEL_FOUR_SPAWN := Vector2(0.0, 480.0)
const LEVEL_FIVE_SPAWN := Vector2(160.0, 470.0)


static func count() -> int:
	return 5


static func get_level(index: int) -> Dictionary:
	match index:
		0:
			return _level_one()
		1:
			return _level_two()
		2:
			return _level_three()
		3:
			return _level_four()
		4:
			return _level_five()
		_:
			push_error("LevelCatalog.get_level: no level at index %d." % index)
			return {}


# =============================================================================
# LEVEL 1 — THE COLLAPSING GATE
# =============================================================================
# Beats, in order:
#   1. Move and jump across two gaps.
#   2. Jump the spike run.
#   3. Pull a latched lever to raise a gate  (interaction).
#   4. Stand on a plate, record, release the echo to hold the plate while you
#      walk through the second gate  (first Temporal Echo).
static func _level_one() -> Dictionary:
	return {
		"id": &"level_01",
		"title": "The Collapsing Gate",
		"objective": "Reach the Hall of Echoes.",
		"spawn": LEVEL_ONE_SPAWN,
		"bounds": Rect2(-200.0, -700.0, 3200.0, 1700.0),
		"platforms": [
			{"rect": Rect2(-120.0, 560.0, 680.0, 340.0)},                 # Ground A
			{"rect": Rect2(700.0, 520.0, 280.0, 380.0)},                  # Ground B (step up)
			{"rect": Rect2(1120.0, 560.0, 700.0, 340.0)},                 # Ground C
			{"rect": Rect2(1860.0, 560.0, 700.0, 340.0)},                 # Ground D (the hall gate)
			# A decorative fracture ledge was removed here: at 140 px above Ground C
			# it was outside the 99 px jump arc, so it read as a platform the player
			# could reach but never could. Unreachable solid geometry is a trap.
		],
		"objects": [
			{"type": "checkpoint", "id": "cp_gate", "pos": Vector2(1160.0, 560.0),
				"params": {"checkpoint_id": "gate", "size": Vector2(56.0, 96.0)}},

			# Beat 2: a hazard run the player must jump.
			{"type": "hazard", "id": "spikes_gate", "pos": Vector2(1300.0, 560.0),
				"params": {"size": Vector2(100.0, 30.0), "damage": 22}},

			# Beat 3: a latched lever permanently raises gate one.
			{"type": "lever", "id": "lever_gate", "pos": Vector2(1580.0, 560.0),
				"params": {"latched": true}},
			{"type": "door", "id": "door_gate", "pos": Vector2(1780.0, 560.0),
				"params": {"size": Vector2(56.0, 155.0)},
				"listens_to": ["lever_gate"]},

			{"type": "checkpoint", "id": "cp_hall", "pos": Vector2(1900.0, 560.0),
				"params": {"checkpoint_id": "hall_gate", "size": Vector2(56.0, 96.0)}},

			# Beat 4: the plate releases the instant the player steps off it, so
			# the only way through the far gate is to leave a memory on it.
			{"type": "pressure_plate", "id": "plate_memory", "pos": Vector2(2020.0, 560.0),
				"params": {"size": Vector2(90.0, 14.0)}},
			{"type": "door", "id": "door_memory", "pos": Vector2(2320.0, 560.0),
				"params": {"size": Vector2(56.0, 155.0)},
				"listens_to": ["plate_memory"]},

			{"type": "level_exit", "id": "exit_01", "pos": Vector2(2480.0, 560.0),
				"params": {"size": Vector2(70.0, 150.0)}},
		],
		"enemies": [],
	}


# =============================================================================
# LEVEL 2 — HALL OF ECHOES
# =============================================================================
# The thesis level. One recording must do two jobs:
#   • pass through the temporal switch (echo-only, latched) — which opens the far
#     gate AND starts the bridge platform oscillating, and
#   • finish by standing on the pressure plate, which opens the near gate.
# Neither the player nor a single-purpose recording can solve it alone.
static func _level_two() -> Dictionary:
	return {
		"id": &"level_02",
		"title": "Hall of Echoes",
		"objective": "One memory, two mechanisms. Chain your past to cross.",
		"spawn": LEVEL_TWO_SPAWN,
		"bounds": Rect2(-200.0, -700.0, 3000.0, 1700.0),
		"platforms": [
			{"rect": Rect2(-100.0, 560.0, 1000.0, 340.0)},   # Hall floor
			{"rect": Rect2(1240.0, 520.0, 460.0, 380.0)},    # Far platform
			# The gap between them is a genuine pit: nothing is authored beneath it,
			# so a missed jump falls past the level bounds and kills the player.
		],
		"objects": [
			{"type": "checkpoint", "id": "cp_hall_entry", "pos": Vector2(80.0, 560.0),
				"params": {"checkpoint_id": "hall_entrance", "size": Vector2(56.0, 96.0)}},

			# Job 1 for the memory: hold this plate to raise the near gate.
			{"type": "pressure_plate", "id": "plate_near", "pos": Vector2(180.0, 560.0),
				"params": {"size": Vector2(90.0, 14.0)}},
			{"type": "door", "id": "door_near", "pos": Vector2(640.0, 560.0),
				"params": {"size": Vector2(56.0, 155.0)},
				"listens_to": ["plate_near"]},

			# Job 2: the rune can only be thrown by an echo, and it latches.
			{"type": "temporal_switch", "id": "rune_hall", "pos": Vector2(380.0, 560.0),
				"params": {"size": Vector2(44.0, 56.0)}},

			# One latched rune drives two mechanisms at once.
			{"type": "moving_platform", "id": "bridge", "pos": Vector2(980.0, 545.0),
				"params": {"size": Vector2(130.0, 22.0), "travel": Vector2(240.0, 0.0), "speed": 85.0, "oscillate": true},
				"listens_to": ["rune_hall"]},
			{"type": "door", "id": "door_far", "pos": Vector2(1520.0, 520.0),
				"params": {"size": Vector2(56.0, 155.0)},
				"listens_to": ["rune_hall"]},

			{"type": "checkpoint", "id": "cp_hall_inner", "pos": Vector2(1300.0, 520.0),
				"params": {"checkpoint_id": "hall_inner", "size": Vector2(56.0, 96.0)}},

			{"type": "level_exit", "id": "exit_02", "pos": Vector2(1640.0, 520.0),
				"params": {"size": Vector2(70.0, 150.0)}},
		],
		"enemies": [
			{"type": "palace_guard", "pos": Vector2(790.0, 560.0)},
			{"type": "shadow_echo", "pos": Vector2(1420.0, 430.0)},
		],
	}


# =============================================================================
# LEVEL 3 — THE BROKEN COURTYARD
# =============================================================================
# Combine everything so far. The courtyard is a combat gauntlet with hazards and
# a three-enemy mix, and it still ends on an echo lock: the plate that raises the
# final door is on the far side of a lethal rupture, so it can only be held by a
# memory left behind on the way through.
static func _level_three() -> Dictionary:
	return {
		"id": &"level_03",
		"title": "The Broken Courtyard",
		"objective": "Fight through, then leave a memory to hold the last gate.",
		"spawn": LEVEL_THREE_SPAWN,
		"bounds": Rect2(-200.0, -700.0, 2800.0, 1800.0),
		"platforms": [
			{"rect": Rect2(-100.0, 560.0, 700.0, 340.0)},   # Ground A
			{"rect": Rect2(740.0, 520.0, 340.0, 380.0)},    # Ground B (raised, contested)
			{"rect": Rect2(1220.0, 560.0, 340.0, 340.0)},   # Ground C (the plate ledge)
			{"rect": Rect2(1660.0, 500.0, 560.0, 400.0)},   # Ground D (the gate)
			# Broken arch. 70 px above Ground B, which puts its leading edge inside the
			# ~43-144 px landing window for that height — reachable from a normal run-up
			# rather than only from a perfect approach.
			{"rect": Rect2(860.0, 450.0, 120.0, 26.0), "kind": "fracture"},
		],
		"objects": [
			{"type": "checkpoint", "id": "cp_courtyard", "pos": Vector2(80.0, 560.0),
				"params": {"checkpoint_id": "courtyard", "size": Vector2(56.0, 96.0)}},

			{"type": "hazard", "id": "spikes_courtyard", "pos": Vector2(320.0, 560.0),
				"params": {"size": Vector2(90.0, 30.0), "damage": 22}},

			{"type": "checkpoint", "id": "cp_courtyard_ledge", "pos": Vector2(1250.0, 560.0),
				"params": {"checkpoint_id": "courtyard_ledge", "size": Vector2(56.0, 96.0)}},

			# The echo lock: plate on C, gate on D, separated by a temporal rupture.
			{"type": "pressure_plate", "id": "courtyard_plate", "pos": Vector2(1400.0, 560.0),
				"params": {"size": Vector2(90.0, 14.0)}},
			{"type": "hazard", "id": "rupture_courtyard", "pos": Vector2(1610.0, 780.0),
				"params": {"size": Vector2(140.0, 40.0), "damage": 30, "kind": "rupture"}},
			{"type": "door", "id": "courtyard_door", "pos": Vector2(1760.0, 500.0),
				"params": {"size": Vector2(56.0, 155.0)},
				"listens_to": ["courtyard_plate"]},

			{"type": "level_exit", "id": "exit_03", "pos": Vector2(2060.0, 500.0),
				"params": {"size": Vector2(70.0, 150.0)}},
		],
		"enemies": [
			{"type": "palace_guard", "pos": Vector2(500.0, 560.0)},
			{"type": "palace_guard", "pos": Vector2(960.0, 520.0)},
			{"type": "shadow_echo", "pos": Vector2(880.0, 300.0)},
			{"type": "temporal_sentinel", "pos": Vector2(1380.0, 360.0)},
		],
	}


# =============================================================================
# LEVEL 4 — CLOCKWORK SANCTUM
# =============================================================================
# The directive's "advanced tier": the Temporal Echo rules are upgraded to a 12 s
# recording window and TWO simultaneous echoes, and the level is built so both
# are genuinely required.
#
#   • the rune latches and starts the bridge  (one memory must walk through it)
#   • plate A must be held continuously, far from plate B
#   • plate B must be held continuously, far from plate A
#   • the sanctum door needs all three at once
#
# Two echoes can cover plates A and B; the rune is on the recording route that
# reaches plate A. With one echo the level is impossible — which is the point.
static func _level_four() -> Dictionary:
	return {
		"id": &"level_04",
		"title": "Clockwork Sanctum",
		"objective": "Two memories. Three mechanisms. One window.",
		"spawn": LEVEL_FOUR_SPAWN,
		"bounds": Rect2(-200.0, -700.0, 2400.0, 1800.0),
		"temporal": {
			"max_recording_duration": 12.0,
			"max_active_echoes": 2,
			"energy_max": 4.0,
			"echo_lifetime": 45.0,
		},
		"platforms": [
			{"rect": Rect2(-100.0, 560.0, 640.0, 340.0)},   # Ground A — rune + plate A
			{"rect": Rect2(700.0, 520.0, 560.0, 380.0)},    # Ground B — plate B
			{"rect": Rect2(1400.0, 560.0, 560.0, 340.0)},   # Ground C — the sanctum door
		],
		"objects": [
			{"type": "checkpoint", "id": "cp_sanctum", "pos": Vector2(70.0, 560.0),
				"params": {"checkpoint_id": "sanctum_entry", "size": Vector2(56.0, 96.0)}},

			# Echo job 1: held continuously.
			{"type": "pressure_plate", "id": "sanctum_plate_a", "pos": Vector2(200.0, 560.0),
				"params": {"size": Vector2(90.0, 14.0)}},
			# Echo job 2: latched on the way past, then forgotten about.
			{"type": "temporal_switch", "id": "sanctum_rune", "pos": Vector2(380.0, 560.0),
				"params": {"size": Vector2(44.0, 56.0)}},

			{"type": "moving_platform", "id": "sanctum_bridge", "pos": Vector2(620.0, 545.0),
				"params": {"size": Vector2(130.0, 22.0), "travel": Vector2(200.0, 0.0), "speed": 80.0, "oscillate": true},
				"listens_to": ["sanctum_rune"]},

			{"type": "checkpoint", "id": "cp_sanctum_mid", "pos": Vector2(760.0, 520.0),
				"params": {"checkpoint_id": "sanctum_mid", "size": Vector2(56.0, 96.0)}},
			# Echo job 3: held continuously, a long way from plate A.
			{"type": "pressure_plate", "id": "sanctum_plate_b", "pos": Vector2(900.0, 520.0),
				"params": {"size": Vector2(90.0, 14.0)}},

			# All three at once.
			{"type": "door", "id": "sanctum_door", "pos": Vector2(1500.0, 560.0),
				"params": {"size": Vector2(56.0, 155.0)},
				"listens_to": ["sanctum_plate_a", "sanctum_plate_b", "sanctum_rune"],
				"require_all": true},

			{"type": "level_exit", "id": "exit_04", "pos": Vector2(1820.0, 560.0),
				"params": {"size": Vector2(70.0, 150.0)}},
		],
		"enemies": [
			{"type": "palace_guard", "pos": Vector2(460.0, 560.0)},
			{"type": "temporal_sentinel", "pos": Vector2(1180.0, 400.0)},
			{"type": "shadow_echo", "pos": Vector2(980.0, 360.0)},
		],
	}


# =============================================================================
# LEVEL 5 — THE TIME WARDEN
# =============================================================================
# Final encounter. The arena plate sits far outside the Warden's firing envelope,
# and the Warden is permanently shielded while it is not held:
#
#   • stand on the plate yourself  → safe, but you cannot reach the Warden
#   • fight the Warden yourself    → the shield nullifies every hit
#
# The only answer is to leave a memory holding the plate and fight alongside it.
# When the echo expires the shield returns, so the player has to author a new
# memory under fire. The fight is the mechanic.
static func _level_five() -> Dictionary:
	return {
		"id": &"level_05",
		"title": "The Time Warden",
		"objective": "Its shield answers only to your past. Record, release, strike.",
		"spawn": LEVEL_FIVE_SPAWN,
		"bounds": Rect2(-350.0, -700.0, 2500.0, 1800.0),
		"platforms": [
			{"rect": Rect2(-300.0, 560.0, 2400.0, 500.0)},   # Arena floor
			{"rect": Rect2(600.0, 480.0, 90.0, 24.0)},       # cover slab
			{"rect": Rect2(1500.0, 470.0, 90.0, 24.0)},      # cover slab
			{"rect": Rect2(-300.0, 200.0, 40.0, 400.0)},     # arena wall (left)
			{"rect": Rect2(2060.0, 200.0, 40.0, 400.0)},     # arena wall (right)
		],
		"objects": [
			{"type": "checkpoint", "id": "cp_warden", "pos": Vector2(230.0, 560.0),
				"params": {"checkpoint_id": "warden_entry", "size": Vector2(56.0, 96.0)}},

			# The first echo lock placed on the critical path of a boss fight.
			{"type": "pressure_plate", "id": "warden_plate", "pos": Vector2(90.0, 560.0),
				"params": {"size": Vector2(100.0, 14.0)}},

			# Deliberately NO level_exit here. [method TimeWarden._declare_victory]
			# is the only thing that completes this level, so walking to a doorway
			# can never skip the fight.
		],
		"enemies": [
			{"type": "time_warden", "id": "warden", "pos": Vector2(1200.0, 560.0),
				"listens_to": ["warden_plate"], "require_all": true},
		],
	}
