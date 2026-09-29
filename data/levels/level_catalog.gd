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
## Level 1 teaches movement, hazards, interaction and the first echo, and is
## deliberately free of combat (that is introduced in Level 2), following the
## directive's introduce → practice → combine → challenge ordering.
## Level 2 is the game's thesis: one recorded memory must do two jobs at once.

const LEVEL_ONE_SPAWN := Vector2(100.0, 470.0)
const LEVEL_TWO_SPAWN := Vector2(60.0, 470.0)


static func count() -> int:
	return 2


static func get_level(index: int) -> Dictionary:
	match index:
		0:
			return _level_one()
		1:
			return _level_two()
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
			{"rect": Rect2(1180.0, 420.0, 150.0, 30.0), "kind": "fracture"},  # decorative fracture ledge
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
