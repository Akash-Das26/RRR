class_name TemporalSentinel
extends EnemyBase
## A floating ranged construct.
##
## Distinct role from the other two archetypes. The [PalaceGuard] teaches melee
## spacing, the [ShadowEcho] punishes standing still, and the Sentinel punishes
## fighting in the open: it hovers out of sword reach, retreats when crowded, and
## forces the player to use cover or close the gap deliberately.
##
## It is built entirely from the base FSM plus [method EnemyBase._fire_attack];
## no new AI states were needed, which is the payoff of the ranged path added to
## [EnemyStats].


func _make_default_stats() -> EnemyStats:
	var sentinel := EnemyStats.new()
	sentinel.display_name = "Temporal Sentinel"
	sentinel.max_health = 35
	sentinel.body_size = Vector2(30.0, 34.0)
	# Hovers: ignores gravity so level verticality cannot strand it.
	sentinel.uses_gravity = false
	sentinel.patrol_speed = 48.0
	sentinel.chase_speed = 125.0
	sentinel.patrol_distance = 80.0
	sentinel.detection_radius = 470.0
	sentinel.disengage_radius = 660.0
	# Fires from well outside melee reach.
	sentinel.attack_range = 350.0
	sentinel.preferred_range = 255.0
	# Long wind-up: the player is meant to read the charging glow and reposition.
	sentinel.attack_windup = 0.60
	sentinel.attack_active = 0.10
	sentinel.attack_recovery = 0.62
	sentinel.ranged = true
	sentinel.projectile_speed = 340.0
	sentinel.projectile_damage = 9
	sentinel.projectile_lifetime = 4.0
	sentinel.volley_count = 1
	sentinel.volley_spread = 0.0
	sentinel.hurt_duration = 0.20
	sentinel.hurt_knockback = 110.0
	sentinel.death_fade = 0.6
	return sentinel


## Single aimed bolt. The base class handles the wind-up timing.
func _fire_attack() -> void:
	var target := _valid_target()
	if target == null:
		return
	var aim: Vector2 = (target.global_position + Vector2(0.0, -target_height_offset(target)) - global_position).normalized()
	spawn_volley(aim)


## Aims at the target's centre rather than its feet, which is where the
## [Hurtbox] actually is.
func target_height_offset(target: Node2D) -> float:
	if target is Player:
		return 24.0
	return 12.0


func _draw_enemy(alpha: float) -> void:
	var body: Color = Palette.UI_HEALTH if _hurt_flash > 0.0 else Palette.SHADOW_BODY
	body.a = alpha
	var size := stats.body_size
	var half := size * 0.5

	# Hover bob.
	var bob := sin(_anim_time * 2.2 + global_position.x * 0.01) * 3.0
	var centre := Vector2(0.0, -half.y + bob)

	var charging: bool = ai_state == AIState.ATTACK and _state_time < stats.attack_windup
	var glow: Color = Palette.UI_WARN if charging else Palette.SHADOW_GLOW

	draw_circle(centre, half.x * 1.9, Color(glow.r, glow.g, glow.b, 0.10))
	draw_circle(centre, half.x * 1.25, Color(glow.r, glow.g, glow.b, 0.16))

	# Rotating outer ring reads as "mechanism", not "creature".
	var ring_angle := _anim_time * (3.4 if charging else 1.1)
	for i: int in 3:
		var a := ring_angle + TAU * float(i) / 3.0
		draw_arc(centre, half.x + 6.0, a, a + 1.5, 10, Color(glow.r, glow.g, glow.b, 0.75 * alpha), 2.0, true)

	# Faceted core.
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(0.0, -half.y),
		centre + Vector2(half.x, 0.0),
		centre + Vector2(0.0, half.y),
		centre + Vector2(-half.x, 0.0),
	]), body)

	# The eye, which brightens as it charges.
	var eye_radius: float = 5.0 + (4.0 * clampf(_state_time / maxf(0.01, stats.attack_windup), 0.0, 1.0) if charging else 0.0)
	draw_circle(centre, eye_radius, Color(glow.r, glow.g, glow.b, 0.9 * alpha))
	draw_circle(centre, eye_radius * 0.45, Palette.TEMPORAL_CORE)
