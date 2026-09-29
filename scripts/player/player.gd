class_name Player
extends CharacterBody2D
## The playable prince.
##
## Responsibilities are split deliberately:
## [br]• [b]this script[/b] owns motion maths, input buffering and combat wiring
## [br]• [PlayerStateMachine] decides [i]which behaviour[/i] is running
## [br]• each [PlayerState] describes one behaviour
##
## Game feel lives here as data, not as magic numbers sprinkled through states:
## acceleration/friction curves, coyote time, jump buffering and jump cutting are
## all exported so they can be tuned without touching logic.

## Attack kinds consumed by [method consume_attack].
const ATTACK_LIGHT: int = 0
const ATTACK_HEAVY: int = 1

signal died
signal respawned

@export_group("Movement")
@export var max_run_speed: float = 250.0
@export var ground_acceleration: float = 2400.0
@export var ground_friction: float = 3000.0
@export var air_acceleration: float = 1500.0
@export var air_friction: float = 700.0
@export var gravity: float = 1650.0
@export var max_fall_speed: float = 940.0
@export var jump_velocity: float = -530.0
## Releasing jump early multiplies upward velocity by this, giving variable jump height.
@export_range(0.1, 1.0, 0.02) var jump_cut_multiplier: float = 0.42
## Grace period after walking off a ledge during which a jump still works.
@export var coyote_time: float = 0.10
## Window during which a too-early jump press is remembered.
@export var jump_buffer_time: float = 0.12
@export var crouch_speed: float = 85.0
@export var roll_speed: float = 400.0
@export var roll_duration: float = 0.34
@export var ladder_speed: float = 120.0

@export_group("Combat")
@export var light_attack_damage: int = 12
@export var heavy_attack_damage: int = 22
@export var dodge_speed: float = 410.0
@export var dodge_duration: float = 0.26
## Damage retained when a block successfully catches an attack from the front.
@export_range(0.0, 1.0, 0.05) var block_damage_multiplier: float = 0.25
@export var hurt_knockback: float = 250.0

# --- Nodes ------------------------------------------------------------------
var health: Health
var hurtbox: Hurtbox
var attack_hitbox: Hitbox
var interact_detector: Area2D
var camera: Camera2D
var state_machine: PlayerStateMachine

# --- Runtime ----------------------------------------------------------------
var facing: int = 1
## Cleared during death and scripted sequences to freeze player intent.
var can_control: bool = true
## Mirrors the active state name; recorded into snapshots for echo visuals.
var visual_state: StringName = &"idle"

var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _attack_buffer: int = -1
var _blocking: bool = false
var _flash: float = 0.0
var _anim_time: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	collision_layer = GameLayers.PLAYER_BODY
	collision_mask = GameLayers.WORLD
	_rng.seed = 20260929

	_build_body()
	_build_components()
	_build_state_machine()

	health.died.connect(_on_died)

	TemporalManager.register_source(self)
	EventBus.player_spawned.emit(self)
	EventBus.health_changed.emit(health.current, health.max_health)

	state_machine.start(&"fall")


func _process(delta: float) -> void:
	_anim_time += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	state_machine.physics_update(delta)
	visual_state = state_machine.state_name()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"jump"):
		# Buffer the press instead of jumping immediately: this is what makes
		# landing-then-jumping feel instant rather than dropped.
		_jump_buffer_left = jump_buffer_time
	elif event.is_action_released(&"jump"):
		if velocity.y < 0.0:
			velocity.y *= jump_cut_multiplier
	elif event.is_action_pressed(&"light_attack"):
		_attack_buffer = ATTACK_LIGHT
	elif event.is_action_pressed(&"heavy_attack"):
		_attack_buffer = ATTACK_HEAVY
	elif event.is_action_pressed(&"interact"):
		_try_interact()
	elif event.is_action_pressed(&"temporal_record"):
		_toggle_recording()

	if can_control:
		state_machine.handle_input(event)


# --- Construction -----------------------------------------------------------

func _build_body() -> void:
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var capsule := CapsuleShape2D.new()
	capsule.radius = 9.0
	capsule.height = 42.0
	collision.shape = capsule
	collision.position = Vector2(0, -21)
	add_child(collision)
	z_index = 10


func _build_components() -> void:
	health = Health.new()
	health.name = "Health"
	health.max_health = 100
	health.invulnerability_time = 0.7
	health.changed.connect(_on_health_changed)
	add_child(health)

	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.damage_filter = _filter_incoming_damage
	hurtbox.hit_taken.connect(_on_hit_taken)
	add_child(hurtbox)
	hurtbox.configure(health, GameLayers.PLAYER_HURTBOX, Vector2(24.0, 48.0), Vector2(0, -24))

	attack_hitbox = Hitbox.new()
	attack_hitbox.name = "AttackHitbox"
	add_child(attack_hitbox)
	attack_hitbox.configure(GameLayers.PLAYER_HITBOX, GameLayers.PLAYER_ATTACK_TARGETS, Vector2(46.0, 34.0), Vector2.ZERO)
	_update_hitbox_placement()

	interact_detector = Area2D.new()
	interact_detector.name = "InteractDetector"
	interact_detector.collision_layer = 0
	interact_detector.collision_mask = GameLayers.INTERACTABLE
	var interact_shape := CollisionShape2D.new()
	var interact_rect := RectangleShape2D.new()
	interact_rect.size = Vector2(52.0, 56.0)
	interact_shape.shape = interact_rect
	interact_shape.position = Vector2(0, -28)
	interact_detector.add_child(interact_shape)
	add_child(interact_detector)

	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)
	camera.make_current()


func _build_state_machine() -> void:
	state_machine = PlayerStateMachine.new(self)
	# Attached as a child so it is freed with the player, which is what keeps the
	# machine <-> state references from forming an uncollectable cycle.
	state_machine.name = "StateMachine"
	add_child(state_machine)
	state_machine.add_state(IdleState.new())
	state_machine.add_state(RunState.new())
	state_machine.add_state(JumpState.new())
	state_machine.add_state(FallState.new())
	state_machine.add_state(LandState.new())
	state_machine.add_state(CrouchState.new())
	state_machine.add_state(RollState.new())
	state_machine.add_state(ClimbState.new())
	state_machine.add_state(AttackState.new())
	state_machine.add_state(BlockState.new())
	state_machine.add_state(DodgeState.new())
	state_machine.add_state(HurtState.new())
	state_machine.add_state(DeadState.new())


# --- Timers -----------------------------------------------------------------

func _tick_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_left = coyote_time
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)
	_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)


# --- Motion helpers (used by states) ---------------------------------------

## Horizontal input as -1, 0 or 1.
func move_axis() -> float:
	if not can_control:
		return 0.0
	return Input.get_axis(&"move_left", &"move_right")


func apply_gravity(delta: float, scale: float = 1.0) -> void:
	if is_on_floor() and velocity.y >= 0.0:
		# Small downward bias keeps the body glued to slopes and moving floors.
		velocity.y = 40.0
		return
	velocity.y = minf(velocity.y + gravity * scale * delta, max_fall_speed)


## Accelerates toward [param target_speed] in the input direction, or brakes
## toward rest when there is no input. Separate ground/air rates are what make
## airborne control feel weighty without making the ground feel slippery.
func apply_horizontal(delta: float, target_speed: float, accel_override: float = -1.0) -> void:
	var axis := move_axis()
	var on_floor := is_on_floor()
	var accel := accel_override if accel_override > 0.0 else (ground_acceleration if on_floor else air_acceleration)
	var brake := ground_friction if on_floor else air_friction

	if absf(axis) > 0.01:
		velocity.x = move_toward(velocity.x, axis * target_speed, accel * delta)
		update_facing(1 if axis > 0.0 else -1)
	else:
		velocity.x = move_toward(velocity.x, 0.0, brake * delta)


func update_facing(direction: int) -> void:
	if direction == 0 or direction == facing:
		return
	facing = direction
	_update_hitbox_placement()


func _update_hitbox_placement() -> void:
	if attack_hitbox != null:
		attack_hitbox.position = Vector2(28.0 * float(facing), -24.0)


func commit_motion() -> void:
	move_and_slide()


## True exactly once per successful jump request (buffered press + coyote grace).
func consume_jump() -> bool:
	if _jump_buffer_left <= 0.0:
		return false
	if not is_on_floor() and _coyote_left <= 0.0:
		return false
	_jump_buffer_left = 0.0
	_coyote_left = 0.0
	return true


func do_jump() -> void:
	velocity.y = jump_velocity


## Whether an attack press is waiting to be claimed. States use this to decide
## transitions without consuming the request, so the buffer survives until the
## attack actually starts.
func has_buffered_attack() -> bool:
	return _attack_buffer >= 0


## Returns [constant ATTACK_LIGHT], [constant ATTACK_HEAVY] or -1 when no attack
## is buffered.
func consume_attack() -> int:
	var buffered := _attack_buffer
	_attack_buffer = -1
	return buffered


func set_hitbox_active(active: bool) -> void:
	attack_hitbox.set_active(active)


func set_hitbox_damage(amount: int) -> void:
	attack_hitbox.damage = amount


func set_hitbox_knockback(amount: float) -> void:
	attack_hitbox.knockback = amount


func set_blocking(blocking: bool) -> void:
	_blocking = blocking


func is_blocking() -> bool:
	return _blocking


func apply_self_knockback(from_position: Vector2, force: float) -> void:
	var direction := signf(global_position.x - from_position.x)
	if is_zero_approx(direction):
		direction = float(-facing)
	velocity.x = direction * force
	velocity.y = minf(velocity.y, -force * 0.45)


## Grants dodge i-frames.
func grant_invulnerability(seconds: float) -> void:
	health.grant_invulnerability(seconds)


# --- Combat -----------------------------------------------------------------

func _filter_incoming_damage(amount: int, source_position: Vector2) -> int:
	if not _blocking:
		return amount
	var delta_x := source_position.x - global_position.x
	var from_front: bool = is_zero_approx(delta_x) or signf(delta_x) == float(facing)
	if not from_front:
		return amount
	_flash = 0.15
	return maxi(1, int(round(float(amount) * block_damage_multiplier)))


func _on_hit_taken(_amount: int, source_position: Vector2) -> void:
	_flash = 0.22
	if health.is_dead:
		return
	state_machine.transition_to(&"hurt")
	apply_self_knockback(source_position, hurt_knockback)


func _on_health_changed(current: int, maximum: int) -> void:
	EventBus.health_changed.emit(current, maximum)


## Outright death, ignoring i-frames. Used when the player falls out of the
## level bounds.
func kill() -> void:
	if health.is_dead:
		return
	health.kill()


func _on_died() -> void:
	can_control = false
	set_hitbox_active(false)
	TemporalManager.cancel_recording("player_died")
	died.emit()
	EventBus.player_damaged.emit(0, self)
	EventBus.player_died.emit()
	state_machine.transition_to(&"dead")


## Full restore at a checkpoint.
func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	facing = 1
	can_control = true
	_blocking = false
	_attack_buffer = -1
	_jump_buffer_left = 0.0
	_flash = 0.0
	health.reset()
	set_hitbox_active(false)
	state_machine.start(&"fall")
	respawned.emit()


func set_camera_limits(area: Rect2) -> void:
	if camera == null:
		return
	camera.limit_left = int(area.position.x)
	camera.limit_top = int(area.position.y)
	camera.limit_right = int(area.end.x)
	camera.limit_bottom = int(area.end.y)


# --- Interaction & temporal -------------------------------------------------

func _try_interact() -> void:
	if not can_control:
		return
	for area: Area2D in interact_detector.get_overlapping_areas():
		if area.has_method("interact") and bool(area.interact(self)):
			# Recorded so the resulting echo performs the same action.
			TemporalManager.record_event(&"interact")
			return


## The closest climbable volume the player is standing in, or null.
func current_ladder() -> Node:
	for area: Area2D in interact_detector.get_overlapping_areas():
		if area.get(&"is_climbable") == true:
			return area
	return null


func _toggle_recording() -> void:
	if not can_control:
		return
	if TemporalManager.recorder.is_recording:
		TemporalManager.stop_recording()
	else:
		TemporalManager.start_recording()


## Contract consumed by [code]TemporalManager[/code].
func capture_temporal_state() -> Dictionary:
	return {
		"position": global_position,
		"rotation": rotation,
		"velocity": velocity,
		"state": visual_state,
		"facing": facing,
	}


func is_recording() -> bool:
	return TemporalManager.recorder.is_recording


# --- Rendering --------------------------------------------------------------

func _draw() -> void:
	var recording: bool = is_recording()
	var alpha := 1.0
	if health.is_invulnerable() and _flash <= 0.0:
		# Standard i-frame blink so the player can read that they are safe.
		alpha = 0.55 + 0.45 * sin(_anim_time * 40.0)
	var hit_tint := _flash > 0.0

	var tunic := Palette.PRINCE_TUNIC if not hit_tint else Palette.UI_HEALTH
	var skin := Palette.PRINCE_SKIN
	if alpha < 1.0:
		tunic.a = alpha
		skin.a = alpha

	var state := state_machine.state_name()
	var crouching: bool = state == &"crouch" or state == &"roll"
	var torso_height := 20.0 if not crouching else 12.0
	var torso_top := -torso_height - 6.0

	# Temporal recording aura.
	if recording:
		draw_circle(Vector2(0, -22), 30.0, Color(Palette.TEMPORAL_GLOW.r, Palette.TEMPORAL_GLOW.g, Palette.TEMPORAL_GLOW.b, 0.14 + 0.06 * sin(_anim_time * 9.0)))
		draw_arc(Vector2(0, -22), 30.0, -PI * 0.5, PI * 1.5, 32, Palette.TEMPORAL_GLOW, 1.5, true)

	# Legs - a simple two-segment walk cycle driven by horizontal speed.
	var speed_ratio: float = clampf(absf(velocity.x) / maxf(1.0, max_run_speed), 0.0, 1.0)
	var stride := sin(_anim_time * 14.0) * 7.0 * speed_ratio
	if state == &"roll":
		draw_arc(Vector2(0, -10), 11.0, 0.0, TAU, 16, tunic, 4.0, true)
	else:
		draw_line(Vector2(0, -torso_height), Vector2(stride, 0), Palette.STONE_DEEP, 4.0)
		draw_line(Vector2(0, -torso_height), Vector2(-stride, 0), Palette.STONE_DEEP, 4.0)

	# Torso + sash.
	var torso := PackedVector2Array([
		Vector2(-7, -torso_height),
		Vector2(7, -torso_height),
		Vector2(5, torso_top),
		Vector2(-5, torso_top),
	])
	draw_colored_polygon(torso, tunic)
	draw_line(Vector2(-7, -torso_height * 0.6), Vector2(7, -torso_height * 0.75), Palette.PRINCE_SASH, 3.0)

	# Head.
	draw_circle(Vector2(0, torso_top - 5.0), 6.0, skin)

	# Arms and blade depend on what the prince is doing.
	match state:
		&"attack":
			var reach := 26.0 * float(facing)
			draw_line(Vector2(0, torso_top + 6.0), Vector2(reach, torso_top + 2.0), skin, 3.5)
			draw_line(Vector2(reach, torso_top + 2.0), Vector2(reach + 16.0 * float(facing), torso_top - 6.0), Palette.BLADE, 2.5)
		&"block":
			draw_line(Vector2(0, torso_top + 6.0), Vector2(12.0 * float(facing), torso_top + 2.0), skin, 3.5)
			draw_line(Vector2(12.0 * float(facing), torso_top - 8.0), Vector2(12.0 * float(facing), torso_top + 12.0), Palette.BLADE, 3.0)
		&"climb":
			draw_line(Vector2(0, torso_top + 6.0), Vector2(-6.0, torso_top - 8.0), skin, 3.5)
			draw_line(Vector2(0, torso_top + 6.0), Vector2(6.0, torso_top - 12.0), skin, 3.5)
		_:
			draw_line(Vector2(0, torso_top + 6.0), Vector2(9.0 * float(facing), torso_top + 12.0), skin, 3.5)
			draw_line(Vector2(9.0 * float(facing), torso_top + 12.0), Vector2(14.0 * float(facing), torso_top + 20.0), Palette.BLADE, 2.0)
