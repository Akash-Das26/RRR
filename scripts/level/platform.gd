class_name Platform
extends StaticBody2D
## A solid block of palace architecture.
##
## Geometry is built in code from a [Rect2] so levels stay data-driven and the
## headless test can construct a level without any art assets present. The
## speckle pattern is seeded, so a given platform always looks identical.

enum Kind {
	STONE,              ## Plain sandstone.
	LEDGE,              ## Thin lip; visually lighter so it reads as one-way-ish.
	TEMPORAL_FRACTURE,  ## Sandstone split by frozen temporal energy.
}

var size: Vector2 = Vector2(200.0, 40.0)
var kind: Kind = Kind.STONE

var _rng := RandomNumberGenerator.new()


func configure(p_size: Vector2, p_kind: Kind = Kind.STONE, seed_value: int = 1) -> void:
	size = Vector2(maxf(4.0, p_size.x), maxf(4.0, p_size.y))
	kind = p_kind
	_rng.seed = seed_value
	_build_collision()
	queue_redraw()


func _build_collision() -> void:
	collision_layer = GameLayers.WORLD
	collision_mask = 0

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	add_child(collision)


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	var base: Color = Palette.STONE_BASE if kind != Kind.LEDGE else Palette.STONE_LIGHT

	draw_rect(rect, Palette.STONE_DEEP)
	draw_rect(rect.grow(-3.0), base)

	# Sunlit top edge — reads as "this is the surface you stand on".
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4.0)), Palette.STONE_EDGE)
	# Shaded underside gives the blocks weight.
	draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - 5.0), Vector2(rect.size.x, 5.0)), Palette.STONE_SHADE)

	# Deterministic weathering speckles, scaled to the block so big slabs get
	# more detail instead of stretched noise.
	var speckles := int(clampf(size.x * size.y / 2600.0, 3.0, 26.0))
	for i: int in speckles:
		var point := Vector2(
			_rng.randf_range(rect.position.x + 5.0, rect.end.x - 5.0),
			_rng.randf_range(rect.position.y + 6.0, rect.end.y - 7.0)
		)
		var radius := _rng.randf_range(1.0, 2.6)
		draw_circle(point, radius, Palette.jitter(Palette.STONE_SHADE, _rng, 0.08))

	if kind == Kind.TEMPORAL_FRACTURE:
		_draw_fracture(rect)


## A jagged seam of temporal energy through the stone.
func _draw_fracture(rect: Rect2) -> void:
	var points := PackedVector2Array()
	var steps := 5
	var drift := 0.0
	for i: int in steps + 1:
		var t := float(i) / float(steps)
		drift += _rng.randf_range(-rect.size.y * 0.12, rect.size.y * 0.12)
		points.append(Vector2(
			rect.position.x + rect.size.x * t,
			clampf(rect.position.y + rect.size.y * 0.5 + drift, rect.position.y + 3.0, rect.end.y - 3.0)
		))
	draw_polyline(points, Palette.TEMPORAL_FADE, 2.0, true)
	draw_polyline(points, Palette.TEMPORAL_GLOW, 1.0, true)
