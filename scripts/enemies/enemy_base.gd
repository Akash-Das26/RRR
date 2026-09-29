class_name EnemyBase
extends CharacterBody2D
## Shared enemy body and AI finite state machine.
##
## The FSM is intentionally explicit (a [code]match[/code] over one enum) rather
## than emergent: the directive asks for AI that is "reliable and predictable",
## and a player learning a room needs enemies to behave the same way twice.
## Every number comes from [EnemyStats].

enum AIState { IDLE, PATROL, ALERT, CHASE, ATTACK, HURT, DEAD }

## How long the enemy pauses and telegraphs before committing to a chase.
const ALERT_DURATION: float = 0.35
## Ledge/wall probes are kept short so enemies stop at edges rather than walking off.
const LEDGE_PROBE_DEPTH: float = 34.0

@export var stats: EnemyStats

var health: Health
var hurtbox: Hurtbox
var attack_hitbox: Hitbox
var detection_area: Area2D

var ai_state: AIState = AIState.IDLE
var facing: int = -1

var _origin: Vector2 = Vector2.ZERO
var _state_time: float = 0.0
var _target: Node2D = null
var _anim_time: float = 0.0
var _hurt_flash: float = 0.0
var _death_fade: float = 1.0
var _ledge_probe: RayCast2D
var _wall_probe: RayCast2D


## Subclasses override this to declare their archetype's numbers.
func _make_default_stats() -> EnemyStats:
	return EnemyStats.new()


func _ready() -> void:
	if stats == null:
		stats = _make_default_stats()

	_origin = global_position
	collision_layer = GameLayers.ENEMY_BODY
	collision_mask = GameLayers.WORLD
	z_index = 8

	_build_body()
	_build_components()
	_enter(AIState.PATROL)


func _process(delta: float) -> void:
	_anim_time += delta
	if _hurt_flash > 0.0:
		_hurt_flash = maxf(0.0, _hurt_flash - delta)
	if ai_state == AIState.DEAD:
		_death_fade = maxf(0.0, _death_fade - delta / maxf(0.05, stats.death_fade))
	queue_redraw()


func _physics_process(delta: float) -> void:
	_state_time += delta
	match ai_state:
		AIState.IDLE:
			_state_idle(delta)
		AIState.PATROL:
			_state_patrol(delta)
		AIState.ALERT:
			_state_alert(delta)
		AIState.CHASE:
			_state_chase(delta)
		AIState.ATTACK:
			_state_attack(delta)
		AIState.HURT:
			_state_hurt(delta)
		AIState.DEAD:
			_state_dead(delta)


# --- Construction -----------------------------------------------------------

func _build_body() -> void:
	var collision := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = stats.body_size.x * 0.5
	capsule.height = stats.body_size.y
	collision.shape = capsule
	collision.position = Vector2(0, -stats.body_size.y * 0.5)
	add_child(collision)

	_ledge_probe = RayCast2D.new()
	_ledge_probe.target_position = Vector2(0, LEDGE_PROBE_DEPTH)
	_ledge_probe.position = Vector2(0, -4)
	_ledge_probe.collision_mask = GameLayers.WORLD
	add_child(_ledge_probe)

	_wall_probe = RayCast2D.new()
	_wall_probe.position = Vector2(0, -stats.body_size.y * 0.5)
	_wall_probe.collision_mask = GameLayers.WORLD
	add_child(_wall_probe)


func _build_components() -> void:
	health = Health.new()
	health.name = "Health"
	health.max_health = stats.max_health
	health.invulnerability_time = 0.35
	add_child(health)
	health.died.connect(_on_died)

	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	add_child(hurtbox)
	hurtbox.configure(health, GameLayers.ENEMY_HURTBOX, stats.body_size + Vector2(4.0, 6.0), Vector2(0, -stats.body_size.y * 0.5))
	hurtbox.hit_taken.connect(_on_hit_taken)

	attack_hitbox = Hitbox.new()
	attack_hitbox.name = "AttackHitbox"
	attack_hitbox.damage = stats.attack_damage
	attack_hitbox.knockback = stats.attack_knockback
	add_child(attack_hitbox)
	attack_hitbox.configure(GameLayers.ENEMY_HITBOX, GameLayers.ENEMY_ATTACK_TARGETS, Vector2(46.0, stats.body_size.y * 0.9))

	detection_area = Area2D.new()
	detection_area.name = "DetectionArea"
	detection_area.collision_layer = 0
	# Notices the living prince and his echoes alike: an echo can pull aggro.
	detection_area.collision_mask = GameLayers.PLAYER_BODY | GameLayers.ECHO_BODY
	var sense_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = stats.detection_radius
	sense_shape.shape = circle
	detection_area.add_child(sense_shape)
	add_child(detection_area)


# --- State machine ----------------------------------------------------------

func _enter(next: AIState) -> void:
	ai_state = next
	_state_time = 0.0
	attack_hitbox.set_active(false)

	match ai_state:
		AIState.ALERT:
			velocity.x = 0.0
		AIState.DEAD:
			velocity = Vector2.ZERO
			set_deferred("collision_layer", 0)
			set_deferred("collision_mask", 0)
			detection_area.set_deferred("monitoring", false)
			attack_hitbox.set_deferred("monitoring", false)


func _state_idle(delta: float) -> void:
	_apply_gravity(delta)
	_decelerate(delta, 900.0)
	move_and_slide()
	_acquire_or_keep(AIState.PATROL)


func _state_patrol(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, float(facing) * stats.patrol_speed, 900.0 * delta)
	_update_probes()
	move_and_slide()

	# Turn at walls, at ledges, or once we have wandered too far from home.
	if is_on_floor() and not _ledge_probe.is_colliding():
		_flip()
	elif _wall_probe.is_colliding():
		_flip()
	elif absf(global_position.x - _origin.x) > stats.patrol_distance:
		_flip()

	_acquire_or_keep(AIState.PATROL)


func _state_alert(delta: float) -> void:
	_apply_gravity(delta)
	_decelerate(delta, 1400.0)
	move_and_slide()
	if _target == null or not is_instance_valid(_target):
		_enter(AIState.PATROL)
		return
	_face_target()
	if _state_time >= ALERT_DURATION:
		_enter(AIState.CHASE)


func _state_chase(delta: float) -> void:
	_apply_gravity(delta)
	var target := _valid_target()
	if target == null:
		_enter(AIState.PATROL)
		return

	_face_target()
	var distance := global_position.distance_to(target.global_position)
	if distance <= stats.attack_range:
		_enter(AIState.ATTACK)
		return

	if stats.uses_gravity:
		# Grounded enemies hold their ground rather than leaping into pits.
		if is_on_floor() and not _ledge_probe.is_colliding() and distance < 40.0:
			_decelerate(delta, 1400.0)
		else:
			velocity.x = move_toward(velocity.x, float(facing) * stats.chase_speed, 1200.0 * delta)
	else:
		# Hovering enemies steer in both axes.
		var direction := (target.global_position - global_position).normalized()
		velocity = velocity.move_toward(direction * stats.chase_speed, 900.0 * delta)

	move_and_slide()


func _state_attack(delta: float) -> void:
	_apply_gravity(delta)
	_decelerate(delta, 1600.0)

	if _target != null and is_instance_valid(_target):
		_face_target()

	var windup := stats.attack_windup
	var active := stats.attack_active
	var in_window: bool = _state_time >= windup and _state_time < windup + active
	attack_hitbox.set_active(in_window)

	move_and_slide()

	if _state_time >= stats.attack_total_time():
		attack_hitbox.set_active(false)
		_enter(AIState.CHASE)


func _state_hurt(delta: float) -> void:
	_apply_gravity(delta)
	_decelerate(delta, 700.0)
	move_and_slide()
	if _state_time >= stats.hurt_duration:
		_enter(AIState.CHASE if _valid_target() != null else AIState.PATROL)


func _state_dead(delta: float) -> void:
	_apply_gravity(delta)
	_decelerate(delta, 600.0)
	move_and_slide()
	# queue_free() is called once by _on_died; this state only lets the body settle.


# --- Helpers ----------------------------------------------------------------

func _apply_gravity(delta: float) -> void:
	if not stats.uses_gravity:
		return
	if is_on_floor() and velocity.y >= 0.0:
		velocity.y = 30.0
		return
	velocity.y = minf(velocity.y + 1650.0 * delta, 940.0)


func _decelerate(delta: float, rate: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, rate * delta)


func _update_probes() -> void:
	_ledge_probe.position.x = float(facing) * 12.0
	_wall_probe.target_position = Vector2(float(facing) * 22.0, 0)


func _flip() -> void:
	facing = -facing
	_update_probes()


func _face_target() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var delta_x := _target.global_position.x - global_position.x
	if absf(delta_x) > 4.0:
		facing = 1 if delta_x > 0.0 else -1
		_update_probes()


## Nearest valid thing worth chasing: the player, or an echo used as bait.
func _valid_target() -> Node2D:
	if _target != null and is_instance_valid(_target):
		if global_position.distance_to(_target.global_position) > stats.disengage_radius:
			_target = null
		else:
			return _target

	var best: Node2D = null
	var best_distance := INF
	for body: Node2D in detection_area.get_overlapping_bodies():
		if body is Player:
			var d := global_position.distance_squared_to(body.global_position)
			if d < best_distance:
				best = body
				best_distance = d
	for area: Area2D in detection_area.get_overlapping_areas():
		if area is TemporalEcho:
			var d := global_position.distance_squared_to(area.global_position)
			if d < best_distance:
				best = area
				best_distance = d
	_target = best
	return _target


func _acquire_or_keep(fallback: AIState) -> void:
	if _valid_target() != null:
		_enter(AIState.ALERT)
	else:
		if ai_state != fallback:
			_enter(fallback)


# --- Reactions --------------------------------------------------------------

func _on_hit_taken(amount: int, source_position: Vector2) -> void:
	_hurt_flash = 0.18
	if health.is_dead:
		return
	var direction := signf(global_position.x - source_position.x)
	velocity.x = (direction if not is_zero_approx(direction) else float(-facing)) * stats.hurt_knockback
	velocity.y = -stats.hurt_knockback * 0.25
	_enter(AIState.HURT)
	# Drop any stale target so the next acquisition re-reads the detection area;
	# the attacker will be found on the following frame if it is still in range.
	_target = null


func _on_died() -> void:
	_enter(AIState.DEAD)
	move_and_slide()
	# The corpse stays visible long enough to read the kill, then removes itself.
	get_tree().create_timer(maxf(0.05, stats.death_fade)).timeout.connect(queue_free)


# --- Rendering --------------------------------------------------------------

func _draw() -> void:
	var alpha: float = _death_fade
	if _hurt_flash > 0.0:
		alpha = minf(1.0, alpha)
	_draw_enemy(alpha)

	if ai_state == AIState.ALERT and alpha > 0.5:
		var bob: float = -46.0 + sin(_anim_time * 12.0) * 2.0
		draw_rect(Rect2(-2.0, bob, 4.0, 12.0), Palette.UI_WARN)
		draw_circle(Vector2(0, bob + 16.0), 2.5, Palette.UI_WARN)


## Subclasses draw their silhouette here. [param alpha] fades to 0 on death.
func _draw_enemy(_alpha: float) -> void:
	pass
