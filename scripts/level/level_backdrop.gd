class_name LevelBackdrop
extends Node2D
## The distant layer behind all level geometry.
##
## Purely decorative and drawn once (never per frame), so it costs nothing at
## runtime. Everything is generated from a seeded RNG, which keeps the skyline
## identical between runs — a backdrop that reshuffled itself every launch would
## read as a bug.

const PILLAR_COUNT: int = 22
const MOTE_COUNT: int = 90

var bounds: Rect2 = Rect2(-400.0, -1200.0, 4000.0, 2000.0)

var _rng := RandomNumberGenerator.new()


func configure(p_bounds: Rect2) -> void:
	bounds = p_bounds
	z_index = -100
	_rng.seed = 88112233
	queue_redraw()


func _draw() -> void:
	_draw_sky()
	_draw_arches()
	_draw_motes()


func _draw_sky() -> void:
	# Per-vertex colours on a quad give a vertical gradient without a shader or
	# a gradient texture resource.
	var points := PackedVector2Array([
		bounds.position,
		Vector2(bounds.end.x, bounds.position.y),
		bounds.end,
		Vector2(bounds.position.x, bounds.end.y),
	])
	var colors := PackedColorArray([
		Palette.SKY_TOP,
		Palette.SKY_TOP,
		Palette.SKY_BOTTOM,
		Palette.SKY_BOTTOM,
	])
	draw_polygon(points, colors)


func _draw_arches() -> void:
	var base_y: float = bounds.position.y + bounds.size.y * 0.82
	for i: int in PILLAR_COUNT:
		var x: float = bounds.position.x + bounds.size.x * (float(i) + 0.5) / float(PILLAR_COUNT)
		var height: float = _rng.randf_range(150.0, 420.0)
		var width: float = _rng.randf_range(26.0, 52.0)

		# Silhouette only — these are far away and must never compete with the
		# playable geometry for attention.
		var shade := Color(Palette.STONE_DEEP.r, Palette.STONE_DEEP.g, Palette.STONE_DEEP.b, 0.55)
		draw_rect(Rect2(x - width * 0.5, base_y - height, width, height), shade)
		# A soft arch cap.
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - width * 0.5, base_y - height),
			Vector2(x + width * 0.5, base_y - height),
			Vector2(x, base_y - height - width * 0.8),
		]), shade)

	# A distant horizon band grounds the composition.
	draw_rect(Rect2(bounds.position.x, base_y, bounds.size.x, bounds.end.y - base_y),
		Color(Palette.STONE_DEEP.r, Palette.STONE_DEEP.g, Palette.STONE_DEEP.b, 0.75))


func _draw_motes() -> void:
	# Suspended temporal dust: the visual language of a palace unstuck in time.
	for i: int in MOTE_COUNT:
		var x: float = bounds.position.x + _rng.randf() * bounds.size.x
		var y: float = bounds.position.y + _rng.randf() * bounds.size.y
		var radius: float = _rng.randf_range(0.7, 2.1)
		var alpha: float = _rng.randf_range(0.05, 0.20)
		draw_circle(Vector2(x, y), radius, Color(Palette.TEMPORAL_GLOW.r, Palette.TEMPORAL_GLOW.g, Palette.TEMPORAL_GLOW.b, alpha))
