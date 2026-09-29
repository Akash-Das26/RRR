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
## How far ahead of the body the ledge probe looks.
const LEDGE_PROBE_OFFSET: float = 12.0
## How far ahead of the body the wall probe reaches.
const WALL_PROBE_LENGTH: float = 22.0
## How far in front of the body the weapon hitbox sits.
##
## This MUST stay well inside [member EnemyStats.attack_range], otherwise the
## enemy commits to an attack it physically cannot land — it stops at range,
## swings at empty air, and the player never has to respect it.
const WEAPON_REACH: float = 26.0

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
## Guards against a ranged attack firing more than once per wind-up cycle.
var _attack_fired: bool = false
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
	# Aim the probes and the weapon before the first state runs. Skipping this
	# leaves the wall probe as a zero-length ray and the weapon hitbox sitting on
	# the enemy's own chest until something happens to change its facing.
	_update_probes()
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
	_attack_fired = false
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

	if stats.ranged:
		_chase_ranged(delta, target, distance)
		return

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


## Stand-off behaviour for ranged enemies: close in when far, retreat when
## crowded, and hold position inside the firing band.
##
## The enemy steers toward a point offset from the target rather than toward the
## target itself, which is what produces "keeps its distance" instead of
## "walks into melee and shoots from point blank".
func _chase_ranged(delta: float, target: Node2D, distance: float) -> void:
	# In the firing envelope: shoot. An enemy configured not to retreat keeps
	# firing even at point-blank range instead of endlessly backing away.
	if distance <= stats.attack_range:
		var comfortable: bool = distance >= stats.preferred_range * 0.55
		if comfortable or not stats.retreat_when_crowded:
			_enter(AIState.ATTACK)
			return

	# Aim for a spot `preferred_range` in front of the target, `hover_offset` above
	# its feet.
	var desired: Vector2 = target.global_position - Vector2(float(facing) * stats.preferred_range, stats.hover_offset)

	if stats.uses_gravity:
		# Gravity owns the vertical axis; only steer horizontally or the two
		# would fight each other and the enemy would judder in place.
		var dx: float = desired.x - global_position.x
		if absf(dx) > 10.0:
			velocity.x = move_toward(velocity.x, signf(dx) * stats.chase_speed, 800.0 * delta)
		else:
			_decelerate(delta, 1400.0)
	else:
		var to_desired: Vector2 = desired - global_position
		if to_desired.length() > 10.0:
			velocity = velocity.move_toward(to_desired.normalized() * stats.chase_speed, 800.0 * delta)
		else:
			_decelerate(delta, 1400.0)

	move_and_slide()


func _state_attack(delta: float) -> void:
	_apply_gravity(delta)
	_decelerate(delta, 1600.0)

	if _target != null and is_instance_valid(_target):
		_face_target()

	var windup := stats.attack_windup
	var active := stats.attack_active
	var in_window: bool = _state_time >= windup and _state_time < windup + active

	if stats.ranged:
		# A ranged attack resolves once, at the start of the active window. It
		# must NOT leave a damaging volume in the world the way a melee swing
		# does, or the enemy would deal damage for the whole window at any range.
		attack_hitbox.set_active(false)
		if in_window and not _attack_fired:
			_attack_fired = true
			_fire_attack()
	else:
		attack_hitbox.set_active(in_window)

	move_and_slide()

	if _state_time >= stats.attack_total_time():
		attack_hitbox.set_active(false)
		_enter(AIState.CHASE)


## Fires the enemy's attack.
##
## Melee enemies do nothing here — their damage comes from the hitbox during the
## active window. Ranged enemies override this.
func _fire_attack() -> void:
	pass


## Spawns a volley of [Projectile]s along [param direction].
##
## Bolts are parented to the level rather than to the enemy, so a bolt already in
## flight is not deleted the moment its firer dies.
func spawn_volley(direction: Vector2, count: int = -1, spread: float = -1.0) -> void:
	var shots: int = count if count > 0 else maxi(1, stats.volley_count)
	var arc: float = spread if spread >= 0.0 else stats.volley_spread
	var parent := get_parent()
	if parent == null:
		push_error("EnemyBase.spawn_volley: '%s' has no parent to attach projectiles to." % name)
		return

	for i: int in shots:
		var offset: float = 0.0
		if shots > 1:
			offset = lerpf(-arc * 0.5, arc * 0.5, float(i) / float(shots - 1))
		var bolt := Projectile.new()
		bolt.configure(direction.rotated(offset), stats.projectile_speed, stats.projectile_damage, stats.projectile_lifetime)
		parent.add_child(bolt)
		bolt.global_position = global_position + Vector2(0.0, -stats.body_size.y * 0.55)


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


## Re-aims the ledge probe, the wall probe and the weapon hitbox for the current
## facing. Called once at spawn and again every time facing changes.
func _update_probes() -> void:
	_ledge_probe.position.x = float(facing) * LEDGE_PROBE_OFFSET
	_wall_probe.target_position = Vector2(float(facing) * WALL_PROBE_LENGTH, 0.0)
	if attack_hitbox != null:
		attack_hitbox.position = Vector2(float(facing) * WEAPON_REACH, 0.0)


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

	if stats.stagger_immune:
		# Large enemies keep their attack rhythm. Without this a fast attacker
		# can cancel every wind-up and stun-lock them indefinitely.
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
