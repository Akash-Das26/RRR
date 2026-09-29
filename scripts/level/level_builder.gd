class_name LevelBuilder
extends Node2D
## Turns a level [Dictionary] into a live scene tree.
##
## Assignment is deliberate: the level data holds only [i]what[/i] exists and
## [i]where[/i], while this class knows how to instantiate each prop type. Puzzle
## wiring is resolved by string id before any node enters the tree, so every
## [code]_ready[/code] sees its final source list and no mechanism can boot
## half-wired.

## Prop type id -> script. Adding a prop type is one line here plus the class.
##
## These are functions rather than [code]const[/code] dictionaries because
## GDScript does not accept a class reference as a constant expression. Building
## the small dictionary once per level build costs nothing measurable.
static func object_types() -> Dictionary:
	return {
		"pressure_plate": PressurePlate,
		"lever": Lever,
		"temporal_switch": TemporalSwitch,
		"door": Door,
		"timed_gate": TimedGate,
		"moving_platform": MovingPlatform,
		"hazard": Hazard,
		"checkpoint": Checkpoint,
		"ladder": Ladder,
		"level_exit": LevelExit,
	}


static func enemy_types() -> Dictionary:
	return {
		"palace_guard": PalaceGuard,
		"shadow_echo": ShadowEcho,
	}


## Builds the level and returns metadata the caller needs: the spawn point and
## the camera bounds.
func build(data: Dictionary) -> Dictionary:
	var bounds: Rect2 = data.get("bounds", Rect2(-400.0, -1200.0, 4000.0, 2000.0))

	var backdrop := LevelBackdrop.new()
	backdrop.name = "Backdrop"
	backdrop.configure(bounds)
	add_child(backdrop)

	_create_platforms(data.get("platforms", []))
	var registry := _create_objects(data.get("objects", []))
	_create_enemies(data.get("enemies", []))

	return {
		"spawn": data.get("spawn", Vector2(160.0, 400.0)),
		"bounds": bounds,
	}


# --- Geometry ---------------------------------------------------------------

func _create_platforms(specs: Array) -> void:
	var index := 0
	for spec: Dictionary in specs:
		var rect: Rect2 = spec.get("rect", Rect2())
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			push_error("LevelBuilder: platform %d has a degenerate rect %s." % [index, rect])
			continue
		var platform := Platform.new()
		platform.name = "Platform%d" % index
		# Level data describes platforms by their rect; Platform centres on origin.
		platform.position = rect.position + rect.size * 0.5
		platform.configure(rect.size, _platform_kind(String(spec.get("kind", "stone"))), 1000 + index)
		add_child(platform)
		index += 1


func _platform_kind(name: String) -> Platform.Kind:
	match name:
		"ledge":
			return Platform.Kind.LEDGE
		"fracture":
			return Platform.Kind.TEMPORAL_FRACTURE
		_:
			return Platform.Kind.STONE


# --- Props ------------------------------------------------------------------

func _create_objects(specs: Array) -> Dictionary:
	var registry: Dictionary = {}
	var created: Array = []
	var types := object_types()

	for spec: Dictionary in specs:
		var type_id := String(spec.get("type", ""))
		if not types.has(type_id):
			push_error("LevelBuilder: unknown object type '%s'." % type_id)
			continue

		var script: GDScript = types[type_id]
		var node: Node2D = script.new()
		node.name = "%s_%s" % [type_id, spec.get("id", registry.size())]
		node.position = spec.get("pos", Vector2.ZERO)
		_apply_params(node, type_id, spec.get("params", {}))

		var id := String(spec.get("id", ""))
		if not id.is_empty():
			if registry.has(id):
				push_error("LevelBuilder: duplicate object id '%s'." % id)
			registry[id] = node

		created.append({"node": node, "spec": spec})

	# Wiring happens before anything enters the tree so _ready() sees final state.
	_resolve_wiring(specs, registry)
	for entry: Dictionary in created:
		add_child(entry["node"])

	return registry


func _apply_params(node: Node2D, type_id: String, params: Dictionary) -> void:
	match type_id:
		"pressure_plate":
			var plate := node as PressurePlate
			plate.configure(params.get("size", Vector2(76.0, 14.0)))
			plate.trigger_filter = params.get("trigger_filter", PressurePlate.Trigger.ANY_ACTOR)
			plate.release_delay = params.get("release_delay", 0.0)
		"temporal_switch":
			(node as TemporalSwitch).configure(params.get("size", Vector2(40.0, 52.0)))
		"lever":
			var lever := node as Lever
			lever.latched = params.get("latched", false)
		"door":
			(node as Door).configure(params.get("size", Vector2(52.0, 132.0)))
		"timed_gate":
			var gate := node as TimedGate
			gate.configure(params.get("size", Vector2(52.0, 132.0)))
			gate.open_time = params.get("open_time", 4.0)
		"moving_platform":
			var platform := node as MovingPlatform
			platform.configure(
				params.get("size", Vector2(110.0, 22.0)),
				params.get("travel", Vector2(0.0, -170.0)),
				params.get("speed", 70.0)
			)
			platform.oscillate = params.get("oscillate", true)
		"hazard":
			var hazard := node as Hazard
			hazard.configure(
				params.get("size", Vector2(64.0, 30.0)),
				params.get("damage", 20),
				params.get("kind", Hazard.Kind.SPIKES)
			)
		"checkpoint":
			(node as Checkpoint).configure(String(params.get("checkpoint_id", "cp")), params.get("size", Vector2(56.0, 96.0)))
		"ladder":
			(node as Ladder).configure(params.get("size", Vector2(40.0, 150.0)))
		"level_exit":
			(node as LevelExit).configure(params.get("size", Vector2(64.0, 140.0)))
		_:
			push_warning("LevelBuilder: no parameter mapping for object type '%s'." % type_id)


func _resolve_wiring(specs: Array, registry: Dictionary) -> void:
	for spec: Dictionary in specs:
		var id := String(spec.get("id", ""))
		var source_ids: Array = spec.get("listens_to", [])
		if source_ids.is_empty():
			continue
		var node: Node = registry.get(id)
		if node == null:
			push_error("LevelBuilder: '%s' has wiring but was never created." % id)
			continue
		if not node.has_method("bind_sources"):
			push_error("LevelBuilder: '%s' (%s) cannot listen to sources." % [id, node.get_class()])
			continue

		var sources: Array = []
		for source_id: String in source_ids:
			var source: Node = registry.get(source_id)
			if source == null:
				push_error("LevelBuilder: '%s' listens to unknown id '%s'." % [id, source_id])
				continue
			sources.append(source)
		node.bind_sources(sources, spec.get("require_all", true))


# --- Enemies ----------------------------------------------------------------

func _create_enemies(specs: Array) -> void:
	var index := 0
	var types := enemy_types()
	for spec: Dictionary in specs:
		var type_id := String(spec.get("type", ""))
		if not types.has(type_id):
			push_error("LevelBuilder: unknown enemy type '%s'." % type_id)
			continue
		var script: GDScript = types[type_id]
		var enemy: EnemyBase = script.new()
		enemy.name = "Enemy_%s_%d" % [type_id, index]
		enemy.position = spec.get("pos", Vector2.ZERO)
		if spec.has("health"):
			var stats := enemy.stats if enemy.stats != null else enemy._make_default_stats()
			stats.max_health = int(spec["health"])
			enemy.stats = stats
		add_child(enemy)
		index += 1
