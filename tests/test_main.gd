extends Node
## Headless verification harness.
##
## Run with:
## [codeblock]
## ./.tools/godot --headless --path . res://tests/test_main.tscn
## [/codeblock]
## Exits with status 1 if any assertion fails, so it is usable as a CI gate.
##
## These are integration tests, not unit tests: they instantiate the real
## [TemporalEcho], the real [PressurePlate] and the real level data, because the
## thing most worth proving is that a recorded memory actually drives the world.

var _passed: int = 0
var _failed: int = 0
var _sandbox: Node2D = null


func _ready() -> void:
	_sandbox = Node2D.new()
	_sandbox.name = "TestSandbox"
	add_child(_sandbox)

	await get_tree().physics_frame

	_section("Input map")
	_test_input_map()

	_section("Health component")
	_test_health()

	_section("Temporal recorder")
	_test_recorder()

	_section("Level data")
	_test_level_data()

	_section("Puzzle wiring")
	_test_puzzle_wiring()

	_section("Advanced levels")
	_test_advanced_levels()

	_section("Temporal rule overrides")
	_test_temporal_overrides()

	_section("Boss encounter")
	_test_boss()

	_section("Enemy statistics")
	_test_enemy_stats()

	_section("Player state machine")
	await _test_player_states()

	_section("Temporal echo playback")
	await _test_echo_replay()

	_finish()


# --- Harness ----------------------------------------------------------------

func _section(label: String) -> void:
	print("")
	print("== %s ==" % label)


func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s" % label)


func _wait_physics(frames: int) -> void:
	for _i: int in frames:
		await get_tree().physics_frame


func _finish() -> void:
	print("")
	print("-----------------------------------------")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("-----------------------------------------")
	get_tree().quit(1 if _failed > 0 else 0)


# --- Tests ------------------------------------------------------------------

func _test_input_map() -> void:
	var missing: Array[String] = []
	for action: StringName in InputActions.DEFAULTS:
		if not InputMap.has_action(action):
			missing.append(String(action))
	check(missing.is_empty(), "every declared action exists in the InputMap (%s)" % ("ok" if missing.is_empty() else str(missing)))

	var jump_events := InputMap.action_get_events(&"jump")
	check(jump_events.size() > 0, "'jump' has at least one bound key")

	# Re-running setup must be a no-op, not a duplicate-binding bug.
	var before := InputMap.action_get_events(&"jump").size()
	InputActions.ensure_defaults()
	check(InputMap.action_get_events(&"jump").size() == before, "ensure_defaults is idempotent")


func _test_health() -> void:
	var health := Health.new()
	health.max_health = 100
	health.invulnerability_time = 0.5
	_sandbox.add_child(health)
	health.reset()

	check(health.current == 100, "initialises to max health")

	check(health.take_damage(30), "damage lands when vulnerable")
	check(health.current == 70, "health decreases by the damage amount")
	check(not health.take_damage(30), "a second hit inside the i-frame window is refused")
	check(health.current == 70, "i-frames leave health unchanged")

	health.grant_invulnerability(0.0)
	health.heal(10)
	check(health.current == 80, "heal restores health")

	health.kill()
	check(health.is_dead and health.current == 0, "kill() forces death past i-frames")

	health.queue_free()


func _test_recorder() -> void:
	var config := TemporalConfig.new()
	config.max_recording_duration = 0.1
	config.min_recording_duration = 0.05
	var recorder := TemporalRecorder.new(config)
	recorder.start()
	check(recorder.is_recording, "recorder reports recording after start()")

	# Feed synthetic frames: the recorder must never exceed its duration budget.
	var frames := 0
	while recorder.is_recording and frames < 500:
		recorder.record(1.0 / 60.0, Vector2(float(frames), 0.0), 0.0, Vector2.ZERO, &"run", 1)
		frames += 1

	check(frames <= 8, "recording hard-stops at the duration cap (took %d frames)" % frames)
	check(not recorder.is_recording, "recorder reports stopped")
	check(recorder.has_usable_data(), "a 0.1s take is usable given a 0.05s minimum")
	check(recorder.duration() <= config.max_recording_duration + 0.02, "recorded duration respects the cap")

	# Events attach to the newest frame, which is what the echo replays.
	recorder.add_event(&"interact")
	check(recorder.get_snapshots()[-1].has_events(), "add_event attaches to the latest frame")

	# Too-short takes must be rejected, not silently used.
	config.min_recording_duration = 5.0
	check(not recorder.has_usable_data(), "a take shorter than the minimum is unusable")


func _test_level_data() -> void:
	check(LevelCatalog.count() == 5, "catalog exposes all five levels (found %d)" % LevelCatalog.count())

	for index: int in LevelCatalog.count():
		var data := LevelCatalog.get_level(index)
		check(not data.is_empty(), "level %d has data" % index)
		check(data.has("spawn") and data.has("bounds") and data.has("platforms"), "level %d has spawn/bounds/platforms" % index)
		check(data["platforms"].size() > 0, "level %d has at least one platform" % index)

		# Wiring references span props AND enemies (the boss listens to a plate),
		# so both groups have to be pooled before checking. A dangling reference
		# ships a mechanism that can never be operated.
		var ids := {}
		for group: String in ["objects", "enemies"]:
			for spec: Dictionary in data.get(group, []):
				var spec_id := String(spec.get("id", ""))
				if not spec_id.is_empty():
					ids[spec_id] = true

		var dangling: Array[String] = []
		for group: String in ["objects", "enemies"]:
			for spec: Dictionary in data.get(group, []):
				for source_id: String in spec.get("listens_to", []):
					if not ids.has(source_id):
						dangling.append("%s -> %s" % [spec.get("id", "?"), source_id])
		check(dangling.is_empty(), "level %d has no dangling listens_to references (%s)" % [index, "ok" if dangling.is_empty() else str(dangling)])

		# Every wired target must actually accept wiring.
		var unwireable: Array[String] = []
		for group: String in ["objects", "enemies"]:
			for spec: Dictionary in data.get(group, []):
				if spec.get("listens_to", []).is_empty():
					continue
				var type_id := String(spec.get("type", ""))
				var registry: Dictionary = LevelBuilder.enemy_types() if group == "enemies" else LevelBuilder.object_types()
				if not registry.has(type_id):
					unwireable.append(type_id)
					continue
				var probe: Node = (registry[type_id] as GDScript).new()
				if not probe.has_method("bind_sources"):
					unwireable.append(type_id)
				probe.free()
		check(unwireable.is_empty(), "level %d wiring targets all support bind_sources (%s)" % [index, "ok" if unwireable.is_empty() else str(unwireable)])


func _test_puzzle_wiring() -> void:
	var builder := LevelBuilder.new()
	_sandbox.add_child(builder)
	builder.build(LevelCatalog.get_level(1))

	var plate := builder.get_node_or_null("pressure_plate_plate_near") as PressurePlate
	var door_near := builder.get_node_or_null("door_door_near") as Door
	var rune := builder.get_node_or_null("temporal_switch_rune_hall") as TemporalSwitch
	var door_far := builder.get_node_or_null("door_door_far") as Door
	var bridge := builder.get_node_or_null("moving_platform_bridge") as MovingPlatform

	check(plate != null, "near pressure plate was built")
	check(door_near != null, "near door was built")
	check(rune != null, "temporal rune was built")
	check(door_far != null, "far door was built")
	check(bridge != null, "bridge platform was built")

	if plate == null or door_near == null or rune == null or door_far == null:
		builder.queue_free()
		return

	check(not door_near.is_open, "near door starts closed")
	plate.set_active(true)
	check(door_near.is_open, "holding the plate opens the door it is wired to")
	plate.set_active(false)
	check(not door_near.is_open, "releasing the plate closes that door again")

	check(not rune.is_on(), "rune starts unlit")
	check(not door_far.is_open, "far door starts closed")
	rune.set_active(true)
	check(door_far.is_open, "the rune opens the far door")
	check(bridge.is_engaged(), "the same rune engages the bridge platform")

	builder.queue_free()


func _test_player_states() -> void:
	var player := Player.new()
	_sandbox.add_child(player)

	check(player.state_machine.states.size() == 13, "all 13 states are registered (found %d)" % player.state_machine.states.size())

	# An unknown state must be rejected without corrupting the machine.
	# The engine ERROR logged on the next line is INTENTIONAL: it is the rejection
	# path being exercised. The accompanying assertion is the real check.
	var before := player.state_machine.state_name()
	player.state_machine.transition_to(&"does_not_exist")
	check(player.state_machine.state_name() == before, "transition to an unknown state is ignored")

	# Transitions are deferred by design, so the change must NOT be visible on the
	# same frame, and must be in place on the next one. Dead is terminal, which
	# makes it stable enough to assert against.
	player.state_machine.transition_to(&"dead")
	check(player.state_machine.state_name() != &"dead", "transition is deferred, not applied mid-frame")
	await _wait_physics(2)
	check(player.state_machine.state_name() == &"dead", "deferred transition lands on the next physics step")

	player.queue_free()


func _test_echo_replay() -> void:
	var container := Node2D.new()
	_sandbox.add_child(container)
	var plate := PressurePlate.new()
	plate.configure(Vector2(90.0, 14.0))
	container.add_child(plate)

	# A synthetic take that walks right and stops standing on the plate.
	# Deliberately offsets the path so the end pose is nowhere near the origin:
	# that way "the echo held its final pose" cannot pass by accident.
	var snapshots: Array[TemporalSnapshot] = []
	var frame_count := 24
	for i: int in frame_count:
		snapshots.append(TemporalSnapshot.create(
			float(i + 1) / 60.0,
			Vector2(-230.0 + float(i) * 10.0, -14.0),
			0.0,
			Vector2(60.0, 0.0),
			&"run",
			1
		))
	var final_position: Vector2 = snapshots[-1].position

	var config := TemporalConfig.new()
	config.loop_echo = false
	config.echo_lifetime = 10.0
	TemporalManager.config = config
	TemporalManager.set_echo_container(container)

	var echo := TemporalManager.spawn_echo(snapshots)
	check(echo != null, "spawn_echo returns an echo")
	check(TemporalManager.echo_count() == 1, "the echo is registered as active")
	if echo == null:
		container.queue_free()
		return

	# The echo spawns on its first frame, not at the world origin.
	check(echo.global_position.is_equal_approx(snapshots[0].position), "echo starts at the first recorded frame")

	# Let playback run past the end of the take.
	await _wait_physics(frame_count + 12)

	check(echo.global_position.distance_to(final_position) < 1.0,
		"echo holds its final recorded pose after playback ends (at %s, expected %s)" % [echo.global_position, final_position])

	# The whole point: the memory is a physical weight on the plate.
	check(plate.is_active, "an echo standing on a pressure plate activates it")

	# Determinism: a second echo from the same take follows the same path.
	var second := TemporalManager.spawn_echo(snapshots)
	check(second != null, "a second echo can be spawned")
	if second != null:
		check(second.global_position.is_equal_approx(snapshots[0].position),
			"replaying the same take starts from the same position (deterministic)")

	# Capacity is enforced, not advisory.
	await _wait_physics(2)
	check(TemporalManager.echo_count() <= config.max_active_echoes,
		"active echo count respects max_active_echoes (%d <= %d)" % [TemporalManager.echo_count(), config.max_active_echoes])

	TemporalManager.clear_echoes()
	await _wait_physics(2)
	check(TemporalManager.echo_count() == 0, "clear_echoes removes every echo")

	container.queue_free()


## Level 4 is the directive's advanced tier: three sources must be live at once.
func _test_advanced_levels() -> void:
	var builder := LevelBuilder.new()
	_sandbox.add_child(builder)
	builder.build(LevelCatalog.get_level(3))

	var plate_a := builder.get_node_or_null("pressure_plate_sanctum_plate_a") as PressurePlate
	var plate_b := builder.get_node_or_null("pressure_plate_sanctum_plate_b") as PressurePlate
	var rune := builder.get_node_or_null("temporal_switch_sanctum_rune") as TemporalSwitch
	var door := builder.get_node_or_null("door_sanctum_door") as Door
	var bridge := builder.get_node_or_null("moving_platform_sanctum_bridge") as MovingPlatform
	var sentinel := builder.get_node_or_null("enemy_temporal_sentinel_1")

	check(plate_a != null and plate_b != null, "both sanctum plates were built")
	check(rune != null, "the sanctum rune was built")
	check(door != null, "the three-source sanctum door was built")
	check(bridge != null, "the sanctum bridge was built")
	check(sentinel != null, "the Temporal Sentinel was built")

	if door == null or plate_a == null or plate_b == null or rune == null:
		builder.queue_free()
		return

	check(not door.is_open, "the sanctum door starts closed")
	plate_a.set_active(true)
	check(not door.is_open, "one of three sources is not enough")
	plate_b.set_active(true)
	check(not door.is_open, "two of three sources is still not enough")
	rune.set_active(true)
	check(door.is_open, "all three sources finally open the door")
	plate_b.set_active(false)
	check(not door.is_open, "losing any single source closes it again")

	builder.queue_free()


## A level may raise the recording window and the echo cap. The stock rules must
## come back afterwards, or the sanctum's upgrade would leak into the boss.
func _test_temporal_overrides() -> void:
	var overrides: Dictionary = LevelCatalog.get_level(3).get("temporal", {})
	check(overrides.get("max_active_echoes", 0) == 2, "level 4 requests the two-echo tier")
	check(overrides.get("max_recording_duration", 0.0) == 12.0, "level 4 requests the 12 s recording window")
	check(LevelCatalog.get_level(0).get("temporal", {}).is_empty(), "level 1 requests no overrides")

	TemporalManager.configure_for_level(overrides)
	check(TemporalManager.config.max_active_echoes == 2, "the override raises the echo cap")
	check(TemporalManager.config.max_recording_duration == 12.0, "the override raises the recording window")

	TemporalManager.configure_for_level({})
	check(TemporalManager.config.max_active_echoes == 1, "stock echo cap is restored afterwards")
	check(TemporalManager.config.max_recording_duration == 8.0, "stock recording window is restored afterwards")


## The Warden is the only enemy designed around the echo mechanic: its shield is
## down only while an arena plate is held, and a shielded hit is nullified.
func _test_boss() -> void:
	var builder := LevelBuilder.new()
	_sandbox.add_child(builder)
	builder.build(LevelCatalog.get_level(4))

	var boss := builder.get_node_or_null("enemy_time_warden_0") as TimeWarden
	var plate := builder.get_node_or_null("pressure_plate_warden_plate") as PressurePlate

	check(boss != null, "the Time Warden was built")
	check(plate != null, "the arena plate was built")
	if boss == null or plate == null:
		builder.queue_free()
		return

	check(boss.stats.stagger_immune, "the Warden never staggers, so it cannot be stun-locked")
	# A hovering boss would drift above the player's swing arc and be unkillable.
	check(boss.stats.uses_gravity, "the Warden stays grounded, inside melee reach")
	check(boss.is_shielded(), "the Warden starts shielded")

	var before := boss.health.current
	check(not boss.hurtbox.receive_hit(50, 0.0, Vector2.ZERO), "a hit on the shielded Warden is refused")
	check(boss.health.current == before, "the shielded Warden takes no damage at all")

	plate.set_active(true)
	check(not boss.is_shielded(), "holding the arena plate drops the shield")
	check(boss.hurtbox.receive_hit(50, 0.0, Vector2.ZERO), "a hit lands once the shield is down")
	check(boss.health.current < before, "the unshielded Warden takes damage")

	# Phase thresholds are data; drive them directly rather than grinding 320 HP.
	boss.health.current = 150
	boss.health.changed.emit(150, boss.health.max_health)
	check(boss.phase == TimeWarden.Phase.TWO, "falling below 60% health advances to phase two")
	boss.health.current = 40
	boss.health.changed.emit(40, boss.health.max_health)
	check(boss.phase == TimeWarden.Phase.THREE, "falling below 25% health advances to phase three")
	check(boss.stats.volley_count == 5, "phase three widens the volley")

	plate.set_active(false)
	check(boss.is_shielded(), "releasing the plate restores the shield")

	builder.queue_free()


## Guards the defect where an enemy's weapon hitbox sat on its own chest instead
## of in front of it: every melee archetype must reach at least as far as it
## commits to attacking, or it swings at air forever.
func _test_enemy_stats() -> void:
	var archetypes := LevelBuilder.enemy_types()
	check(archetypes.size() >= 4, "four enemy archetypes are registered (found %d)" % archetypes.size())

	for type_id: String in archetypes:
		var enemy: EnemyBase = (archetypes[type_id] as GDScript).new()
		var stats: EnemyStats = enemy._make_default_stats()
		check(stats.max_health > 0, "%s has a positive health pool" % type_id)
		check(stats.detection_radius > 0.0, "%s can detect the player" % type_id)
		check(stats.disengage_radius >= stats.detection_radius,
			"%s never disengages before it detects" % type_id)

		if stats.ranged:
			check(stats.preferred_range < stats.attack_range,
				"%s holds station inside its firing envelope (%.0f < %.0f)" % [type_id, stats.preferred_range, stats.attack_range])
		else:
			check(EnemyBase.WEAPON_REACH < stats.attack_range,
				"%s weapon reach (%.0f) is inside its attack range (%.0f)" % [type_id, EnemyBase.WEAPON_REACH, stats.attack_range])

		enemy.free()
