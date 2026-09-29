class_name TimeWarden
extends EnemyBase
## Final boss — the only enemy whose fight is designed around the echo mechanic.
##
## The Warden is permanently shielded: every hit is nullified and it does not
## stagger, so it cannot be worn down by attrition. Its shield drops only while an
## arena [PressurePlate] is being held.
##
## That plate is deliberately placed far outside the Warden's firing envelope, so
## the two obvious options both fail:
## [br]• stand on the plate yourself — you are safe but cannot attack;
## [br]• fight it yourself — the shield nullifies everything.
##
## The only solution is to record an echo that stands on the plate and then fight
## alongside your own past. The boss fight is the mechanic, stated as a combat
## encounter. If the echo expires mid-fight the shield returns, and the player
## must author a new memory under pressure.

enum Phase { ONE, TWO, THREE }

signal shield_changed(shielded: bool)

@export var is_final_boss: bool = true

## Health ratio thresholds that trigger the next phase.
const PHASE_TWO_AT: float = 0.60
const PHASE_THREE_AT: float = 0.25
## Extra time the victory beat waits before the level is declared complete.
const VICTORY_DELAY: float = 1.8

var phase: Phase = Phase.ONE

var _arena_sources: Array = []
var _shielded: bool = true


func _make_default_stats() -> EnemyStats:
	var warden := EnemyStats.new()
	warden.display_name = "The Time Warden"
	warden.max_health = 320
	warden.body_size = Vector2(64.0, 82.0)
	# Grounded rather than hovering. The Warden is big enough to be imposing
	# without floating, and a grounded boss stays inside the player's melee reach
	# — a hovering one drifts above the swing arc and cannot be hit at all.
	warden.uses_gravity = true
	warden.hover_offset = 0.0
	# Holds its ground under pressure. A boss that backs away from the player's
	# sword is not evasive, it is invulnerable in practice.
	warden.retreat_when_crowded = false
	# Never staggers: a damage race must not be possible.
	warden.stagger_immune = true
	warden.patrol_speed = 40.0
	warden.chase_speed = 105.0
	warden.patrol_distance = 120.0
	warden.detection_radius = 950.0
	warden.disengage_radius = 2200.0
	warden.attack_range = 430.0
	warden.preferred_range = 330.0
	warden.attack_windup = 0.70
	warden.attack_active = 0.12
	warden.attack_recovery = 0.85
	warden.ranged = true
	warden.projectile_speed = 330.0
	warden.projectile_damage = 12
	warden.projectile_lifetime = 5.0
	warden.volley_count = 3
	warden.volley_spread = 0.55
	warden.hurt_duration = 0.0
	warden.hurt_knockback = 0.0
	warden.death_fade = 2.2
	return warden


func _ready() -> void:
	super()
	# Filter damage at the hurtbox so a shielded hit never even reaches Health.
	hurtbox.damage_filter = _filter_incoming_damage
	ActuatorUtil.connect_sources(_arena_sources, _on_arena_changed)
	health.changed.connect(_on_health_changed)
	_recompute_shield()
	EventBus.boss_engaged.emit(stats.display_name, health.current, health.max_health)


## Wired by the level builder exactly like a door or a platform.
func bind_sources(p_sources: Array, _require_all: bool = true) -> void:
	_arena_sources = p_sources


func _on_arena_changed(_active: bool) -> void:
	_recompute_shield()


func _on_health_changed(current: int, maximum: int) -> void:
	EventBus.boss_health_changed.emit(current, maximum)
	_update_phase()


# --- Shield -----------------------------------------------------------------

## The shield is up unless every arena source is held.
func _recompute_shield() -> void:
	var held: bool = ActuatorUtil.all_active(_arena_sources)
	_set_shielded(not held)


func _set_shielded(shielded: bool) -> void:
	if _shielded == shielded:
		return
	_shielded = shielded
	shield_changed.emit(_shielded)
	queue_redraw()


func is_shielded() -> bool:
	return _shielded


## Bound to the hurtbox: returning 0 nullifies the hit outright, which is
## stronger than merely reducing damage — a shielded Warden takes nothing at all.
func _filter_incoming_damage(amount: int, _source_position: Vector2) -> int:
	if _shielded:
		return 0
	return amount


# --- Phases -----------------------------------------------------------------

func _update_phase() -> void:
	var ratio := health.health_ratio()
	var next := Phase.ONE
	if ratio <= PHASE_THREE_AT:
		next = Phase.THREE
	elif ratio <= PHASE_TWO_AT:
		next = Phase.TWO
	if next == phase:
		return
	phase = next
	_apply_phase_tuning()
	queue_redraw()


## Each phase tightens the Warden's rhythm rather than granting it new
## mechanics: fewer safe frames, wider volleys, less patience.
func _apply_phase_tuning() -> void:
	match phase:
		Phase.ONE:
			stats.attack_windup = 0.70
			stats.attack_recovery = 0.85
			stats.volley_count = 3
			stats.volley_spread = 0.55
			stats.chase_speed = 105.0
		Phase.TWO:
			stats.attack_windup = 0.52
			stats.attack_recovery = 0.66
			stats.volley_count = 4
			stats.volley_spread = 0.85
			stats.chase_speed = 140.0
		Phase.THREE:
			stats.attack_windup = 0.38
			stats.attack_recovery = 0.46
			stats.volley_count = 5
			stats.volley_spread = 1.15
			stats.chase_speed = 175.0


# --- Attack -----------------------------------------------------------------

## Phase-scaled volley aimed at the player's centre of mass.
func _fire_attack() -> void:
	var target := _valid_target()
	if target == null:
		return
	var aim_point: Vector2 = target.global_position + Vector2(0.0, -24.0)
	var direction: Vector2 = (aim_point - global_position).normalized()
	spawn_volley(direction)


func _on_died() -> void:
	super()
	EventBus.boss_defeated.emit()
	if is_final_boss:
		# Let the death read before the victory screen takes over.
		get_tree().create_timer(VICTORY_DELAY).timeout.connect(_declare_victory)


func _declare_victory() -> void:
	GameManager.complete_level()


# --- Rendering --------------------------------------------------------------

## Phase colour, resolved without allocating an array on every drawn frame.
func _phase_tint() -> Color:
	match phase:
		Phase.TWO:
			return Palette.UI_WARN
		Phase.THREE:
			return Palette.UI_HEALTH
		_:
			return Palette.TEMPORAL_GLOW


func _draw_enemy(alpha: float) -> void:
	var size := stats.body_size
	var half := size * 0.5
	var bob := sin(_anim_time * 1.5) * 4.0
	var centre := Vector2(0.0, -half.y + bob)

	var phase_tint := _phase_tint()
	var hurt: bool = _hurt_flash > 0.0
	var body: Color = Palette.UI_HEALTH if hurt else Palette.SHADOW_BODY
	body.a = alpha

	# Aura, brighter and faster the later the phase.
	draw_circle(centre, half.x * 1.9, Color(phase_tint.r, phase_tint.g, phase_tint.b, 0.08 * alpha))
	draw_circle(centre, half.x * 1.3, Color(phase_tint.r, phase_tint.g, phase_tint.b, 0.13 * alpha))

	# Cloak: a heavy trapezoid, wider at the hem.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half.x * 0.55, -size.y + bob),
		Vector2(half.x * 0.55, -size.y + bob),
		Vector2(half.x, bob),
		Vector2(-half.x, bob),
	]), body)

	# Banded trim so phase changes are readable.
	for i: int in 3:
		var y := bob - size.y * (0.22 + 0.24 * float(i))
		draw_line(Vector2(-half.x * 0.85, y), Vector2(half.x * 0.85, y), Color(phase_tint.r, phase_tint.g, phase_tint.b, 0.55 * alpha), 2.0)

	# Core: the thing the shield is protecting.
	var core_pulse: float = 0.75 + 0.25 * sin(_anim_time * 4.0)
	draw_circle(centre, 12.0, Color(phase_tint.r, phase_tint.g, phase_tint.b, 0.85 * core_pulse * alpha))
	draw_circle(centre, 6.0, Palette.TEMPORAL_CORE)

	# Hood and crown.
	draw_circle(Vector2(0.0, -size.y + bob - 6.0), 15.0, body)
	draw_arc(Vector2(0.0, -size.y + bob - 6.0), 19.0, PI, TAU, 14, Color(phase_tint.r, phase_tint.g, phase_tint.b, 0.8 * alpha), 2.5, true)
	for i: int in 3:
		var spike_x := -12.0 + 12.0 * float(i)
		draw_line(Vector2(spike_x, -size.y + bob - 22.0), Vector2(spike_x, -size.y + bob - 32.0), Color(phase_tint.r, phase_tint.g, phase_tint.b, 0.9 * alpha), 2.0)

	if _shielded:
		_draw_shield(centre)


## The shield is drawn as two counter-rotating rings. It must be unmistakable:
## the player has to understand instantly that hitting it is pointless.
func _draw_shield(centre: Vector2) -> void:
	var radius: float = 62.0
	var spin := _anim_time * 0.9
	for ring: int in 2:
		var offset := spin * (1.0 if ring == 0 else -1.4)
		for i: int in 5:
			var a := offset + TAU * float(i) / 5.0
			draw_arc(centre, radius - float(ring) * 7.0, a, a + 0.8, 8,
				Color(Palette.TEMPORAL_CORE.r, Palette.TEMPORAL_CORE.g, Palette.TEMPORAL_CORE.b, 0.75), 2.0, true)
	draw_circle(centre, radius + 6.0, Color(Palette.TEMPORAL_GLOW.r, Palette.TEMPORAL_GLOW.g, Palette.TEMPORAL_GLOW.b, 0.05))
