class_name LevelBuilder
extends Node2D
## Turns a level [Dictionary] into a live scene tree.
##
## Assignment is deliberate: the level data holds only [i]what[/i] exists and
## [i]where[/i], while this class knows how to instantiate each prop type.
##
## The important sequencing detail is that every prop and enemy is created but
## [b]not parented[/b] until all wiring has been resolved. Wiring is by string id
## across props [i]and[/i] enemies (the boss listens to an arena plate), and a
## mechanism must see its complete source list the first time it runs —
## otherwise its very first frame is computed from a half-wired state.

## Prop type id -> script. Adding a prop type is one line here plus the class.
##
## These are functions rather than [code]const[/code] dictionaries because
## GDScript does not accept a class reference as a constant expression.
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
		"temporal_sentinel": TemporalSentinel,
		"time_warden": TimeWarden,
	}


## Builds the level and returns metadata the caller needs: spawn point, camera
## bounds, and any per-level Temporal Echo rule overrides.
func build(data: Dictionary) -> Dictionary:
	var bounds: Rect2 = data.get("bounds", Rect2(-400.0, -1200.0, 4000.0, 2000.0))

	var backdrop := LevelBackdrop.new()
	backdrop.name = "Backdrop"
	backdrop.configure(bounds)
	add_child(backdrop)

	_create_platforms(data.get("platforms", []))

	var registry: Dictionary = {}
	var pending: Array[Node2D] = []
	_prepare_objects(data.get("objects", []), registry, pending)
	_prepare_enemies(data.get("enemies", []), registry, pending)

	# Wiring must complete before anything enters the tree.
	_resolve_wiring(data.get("objects", []) as Array, registry)
	_resolve_wiring(data.get("enemies", []) as Array, registry)

	for node: Node2D in pending:
		add_child(node)

	return {
		"spawn": data.get("spawn", Vector2(160.0, 400.0)),
		"bounds": bounds,
		"temporal": data.get("temporal", {}),
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

func _prepare_objects(specs: Array, registry: Dictionary, pending: Array[Node2D]) -> void:
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
		_register(registry, spec, node)
		pending.append(node)


func _apply_params(node: Node2D, type_id: String, params: Dictionary) -> void:
	match type_id:
		"pressure_plate":
			var plate := node as PressurePlate
			plate.configure(params.get("size", Vector2(76.0, 14.0)))
			# Authored as a word rather than an enum index: level data should not
			# break silently when the Trigger enum gains a member.
			match String(params.get("filter", "any")):
				"echo":
					plate.trigger_filter = PressurePlate.Trigger.ECHO_ONLY
				"player":
					plate.trigger_filter = PressurePlate.Trigger.PLAYER_ONLY
				_:
					plate.trigger_filter = PressurePlate.Trigger.ANY_ACTOR
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
			var hazard_kind: Hazard.Kind = Hazard.Kind.TEMPORAL_RUPTURE if String(params.get("kind", "spikes")) == "rupture" else Hazard.Kind.SPIKES
			hazard.configure(
				params.get("size", Vector2(64.0, 30.0)),
				params.get("damage", 20),
				hazard_kind
			)
		"checkpoint":
			(node as Checkpoint).configure(String(params.get("checkpoint_id", "cp")), params.get("size", Vector2(56.0, 96.0)))
		"ladder":
			(node as Ladder).configure(params.get("size", Vector2(40.0, 150.0)))
		"level_exit":
			(node as LevelExit).configure(params.get("size", Vector2(64.0, 140.0)))
		_:
			push_warning("LevelBuilder: no parameter mapping for object type '%s'." % type_id)


# --- Enemies ----------------------------------------------------------------

func _prepare_enemies(specs: Array, registry: Dictionary, pending: Array[Node2D]) -> void:
	var types := enemy_types()
	var index := 0
	for spec: Dictionary in specs:
		var type_id := String(spec.get("type", ""))
		if not types.has(type_id):
			push_error("LevelBuilder: unknown enemy type '%s'." % type_id)
			continue

		var script: GDScript = types[type_id]
		var enemy: EnemyBase = script.new()
		enemy.name = "enemy_%s_%d" % [type_id, index]
		enemy.position = spec.get("pos", Vector2.ZERO)

		# Allow per-instance health overrides without a whole new stats resource.
		# Stats are built eagerly here because _make_default_stats() normally runs
		# in _ready(), which has not happened yet.
		if spec.has("health"):
			var stats: EnemyStats = enemy.stats if enemy.stats != null else enemy._make_default_stats()
			stats.max_health = int(spec["health"])
			enemy.stats = stats

		_register(registry, spec, enemy)
		pending.append(enemy)
		index += 1


# --- Wiring -----------------------------------------------------------------

func _register(registry: Dictionary, spec: Dictionary, node: Node2D) -> void:
	var id := String(spec.get("id", ""))
	if id.is_empty():
		return
	if registry.has(id):
		push_error("LevelBuilder: duplicate id '%s'; wiring would be ambiguous." % id)
	registry[id] = node


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
		node.call("bind_sources", sources, spec.get("require_all", true))
