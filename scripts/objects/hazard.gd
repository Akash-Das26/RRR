class_name Hazard
extends Area2D
## Environmental damage.
##
## Damage is dealt by hitting the player's [Hurtbox] rather than by touching the
## player body directly, so the normal i-frame rules apply automatically: a
## player standing in spikes takes repeated hits at the standard cadence instead
## of being deleted in a single frame.

enum Kind {
	SPIKES,           ## Sandstone spikes.
	TEMPORAL_RUPTURE, ## A tear in time along the architecture.
}

@export var damage: int = 20
@export var hazard_size: Vector2 = Vector2(64.0, 30.0)
@export var kind: Kind = Kind.SPIKES


func configure(p_size: Vector2, p_damage: int, p_kind: Kind = Kind.SPIKES) -> void:
	hazard_size = p_size
	damage = p_damage
	kind = p_kind
	if get_child_count() == 0:
		_build()


func _ready() -> void:
	if get_child_count() == 0:
		_build()


func _build() -> void:
	collision_layer = GameLayers.HAZARD
	collision_mask = GameLayers.PLAYER_HURTBOX
	monitoring = true
	monitorable = false

	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = hazard_size
	collision.shape = rectangle
	collision.position = Vector2(0, -hazard_size.y * 0.5)
	add_child(collision)
	z_index = 2


func _physics_process(_delta: float) -> void:
	# Hurtboxes are monitorable but not monitoring, so the hazard is the only
	# side that needs to poll.
	for area: Area2D in get_overlapping_areas():
		if area is Hurtbox:
			(area as Hurtbox).receive_hit(damage, 0.0, global_position)


func _draw() -> void:
	var half := hazard_size * 0.5
	var base_y := 0.0

	match kind:
		Kind.SPIKES:
			var spikes := int(maxf(3.0, hazard_size.x / 14.0))
			var spacing := hazard_size.x / float(spikes)
			for i: int in spikes:
				var x := -half.x + spacing * (float(i) + 0.5)
				var tip := Vector2(x, base_y - hazard_size.y)
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - spacing * 0.45, base_y),
					Vector2(x + spacing * 0.45, base_y),
					tip,
				]), Palette.STONE_EDGE)
				draw_line(Vector2(x, base_y), tip, Palette.BLADE, 1.0)
			draw_rect(Rect2(-half.x, base_y - 4.0, hazard_size.x, 4.0), Palette.STONE_SHADE)
		Kind.TEMPORAL_RUPTURE:
			var pulse: float = 0.55 + 0.35 * sin(Time.get_ticks_msec() * 0.005)
			draw_rect(Rect2(-half.x, base_y - hazard_size.y, hazard_size.x, hazard_size.y),
				Color(Palette.TEMPORAL_DEEP.r, Palette.TEMPORAL_DEEP.g, Palette.TEMPORAL_DEEP.b, 0.35 * pulse))
			for i: int in 4:
				var x := -half.x + hazard_size.x * (float(i) + 0.5) / 4.0
				draw_line(Vector2(x, base_y), Vector2(x + 5.0, base_y - hazard_size.y),
					Color(Palette.TEMPORAL_CORE.r, Palette.TEMPORAL_CORE.g, Palette.TEMPORAL_CORE.b, pulse), 1.5)
