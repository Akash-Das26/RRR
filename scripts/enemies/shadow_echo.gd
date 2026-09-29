class_name ShadowEcho
extends EnemyBase
## A temporal aberration of the protagonist's own silhouette.
##
## Distinct role from the [PalaceGuard]: it hovers, so it ignores the level's
## vertical design and cannot be escaped by simply climbing. It is also the enemy
## that makes baiting meaningful — it acquires echoes as targets just as readily
## as it acquires the player.


func _make_default_stats() -> EnemyStats:
	var shadow := EnemyStats.new()
	shadow.display_name = "Shadow Echo"
	shadow.max_health = 40
	shadow.body_size = Vector2(24.0, 40.0)
	# Hovering: gravity is skipped entirely and it steers in both axes.
	shadow.uses_gravity = false
	shadow.patrol_speed = 55.0
	shadow.chase_speed = 128.0
	shadow.patrol_distance = 90.0
	shadow.detection_radius = 320.0
	shadow.disengage_radius = 480.0
	shadow.attack_range = 46.0
	shadow.attack_windup = 0.42
	shadow.attack_active = 0.14
	shadow.attack_recovery = 0.46
	shadow.attack_damage = 10
	shadow.attack_knockback = 200.0
	shadow.hurt_duration = 0.20
	shadow.hurt_knockback = 190.0
	shadow.death_fade = 0.7
	return shadow


func _draw_enemy(alpha: float) -> void:
	var height := stats.body_size.y
	var body: Color = Palette.UI_HEALTH if _hurt_flash > 0.0 else Palette.SHADOW_BODY
	body.a = alpha

	# Floating offset gives the aberration a drifting, unmoored read.
	var hover := sin(_anim_time * 2.6) * 3.0
	var top := -height + hover

	var pulse := 0.45 + 0.25 * sin(_anim_time * 4.0)
	draw_circle(Vector2(0, top + height * 0.5), 20.0, Color(Palette.SHADOW_GLOW.r, Palette.SHADOW_GLOW.g, Palette.SHADOW_GLOW.b, 0.12 * pulse))
	draw_circle(Vector2(0, top + height * 0.5), 12.0, Color(Palette.SHADOW_GLOW.r, Palette.SHADOW_GLOW.g, Palette.SHADOW_GLOW.b, 0.16 * pulse))

	# A tattered, hollow silhouette.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9.0, top + height),
		Vector2(9.0, top + height),
		Vector2(7.0, top),
		Vector2(-7.0, top),
	]), body)
	# Ragged hem so it never reads as a solid body.
	for i: int in 4:
		var x := -8.0 + float(i) * 5.0
		draw_line(Vector2(x, top + height), Vector2(x + sin(_anim_time * 3.0 + float(i)) * 3.0, top + height + 9.0), body)

	draw_circle(Vector2(0, top - 4.0), 7.0, Palette.SHADOW_BODY)
	# Two burning points where eyes would be.
	var eye_shift := 2.0 * float(facing)
	draw_circle(Vector2(eye_shift - 2.5, top - 4.0), 1.6, Palette.SHADOW_GLOW)
	draw_circle(Vector2(eye_shift + 2.5, top - 4.0), 1.6, Palette.SHADOW_GLOW)

	if ai_state == AIState.ATTACK:
		draw_arc(Vector2(0, top + height * 0.5), 26.0, 0.0, TAU, 20,
			Color(Palette.SHADOW_GLOW.r, Palette.SHADOW_GLOW.g, Palette.SHADOW_GLOW.b, 0.8), 2.0, true)
