class_name PalaceGuard
extends EnemyBase
## The palace's living garrison: a grounded, melee, deliberately readable enemy.
##
## It exists to teach the combat rules honestly. Its windup is long enough to
## react to, it stops at ledges instead of suiciding, and it gives up if you run
## far enough — an enemy a player can learn is more useful than a clever one.


func _make_default_stats() -> EnemyStats:
	var guard := EnemyStats.new()
	guard.display_name = "Palace Guard"
	guard.max_health = 60
	guard.body_size = Vector2(22.0, 46.0)
	guard.uses_gravity = true
	guard.patrol_speed = 78.0
	guard.chase_speed = 152.0
	guard.patrol_distance = 130.0
	guard.detection_radius = 280.0
	guard.disengage_radius = 430.0
	guard.attack_range = 52.0
	guard.attack_windup = 0.36
	guard.attack_active = 0.12
	guard.attack_recovery = 0.42
	guard.attack_damage = 14
	guard.attack_knockback = 260.0
	guard.hurt_duration = 0.24
	guard.hurt_knockback = 220.0
	guard.death_fade = 0.8
	return guard


func _draw_enemy(alpha: float) -> void:
	var height := stats.body_size.y
	var tint: Color = Palette.UI_HEALTH if _hurt_flash > 0.0 else Palette.GUARD_ARMOUR
	tint.a = alpha

	# Legs.
	var stride := sin(_anim_time * 10.0) * 5.0 * clampf(absf(velocity.x) / maxf(1.0, stats.chase_speed), 0.0, 1.0)
	draw_line(Vector2(0, -height * 0.45), Vector2(stride, 0), Palette.STONE_DEEP, 4.0)
	draw_line(Vector2(0, -height * 0.45), Vector2(-stride, 0), Palette.STONE_DEEP, 4.0)

	# Torso and armour trim.
	draw_rect(Rect2(-9.0, -height, 18.0, height * 0.6), tint)
	draw_rect(Rect2(-9.0, -height * 0.72, 18.0, 4.0), Palette.GUARD_TRIM)
	draw_circle(Vector2(0, -height - 3.0), 7.0, tint)

	# Helmet crest reads as a guard even at a glance.
	draw_rect(Rect2(-2.0, -height - 13.0, 4.0, 6.0), Palette.GUARD_TRIM)

	# Weapon: a scimitar held toward the facing direction.
	var swing: float = 0.0
	if ai_state == AIState.ATTACK:
		swing = -0.9 + 1.8 * clampf(_state_time / maxf(0.01, stats.attack_total_time()), 0.0, 1.0)
	var grip := Vector2(10.0 * float(facing), -height * 0.7)
	var tip := grip + Vector2(cos(swing) * float(facing), sin(swing) * 0.7) * 30.0
	draw_line(grip, tip, Palette.BLADE, 2.5)
	draw_line(grip, grip + (tip - grip).normalized() * 6.0, Palette.STONE_SHADE, 4.0)
