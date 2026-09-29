class_name TemporalSwitch
extends Activator
## A latch that only a temporal echo can throw, and that stays thrown.
##
## This exists to create puzzles the present-day player physically cannot solve
## alone: the rune must be *held open by a memory*. Because it latches, the
## player can step away afterwards, which is what turns "reach the switch" into
## "choreograph your past to reach it for you".

var _seal_size: Vector2 = Vector2(40.0, 52.0)


func configure(p_size: Vector2) -> void:
	_seal_size = p_size
	_build()


func _ready() -> void:
	if get_child_count() == 0:
		_build()
	super()


func _build() -> void:
	collision_layer = GameLayers.INTERACTABLE
	collision_mask = GameLayers.ECHO_BODY
	monitoring = true
	monitorable = false

	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = _seal_size
	collision.shape = rectangle
	collision.position = Vector2(0, -_seal_size.y * 0.5)
	add_child(collision)


func _physics_process(_delta: float) -> void:
	if is_active:
		return
	# Latched by design: once a memory has touched the rune it stays lit.
	if get_overlapping_areas().size() > 0:
		set_active(true)
		queue_redraw()


func _draw() -> void:
	var half := _seal_size * 0.5
	var center := Vector2(0, -half.y)

	draw_rect(Rect2(-half, _seal_size), Palette.STONE_DEEP)
	draw_rect(Rect2(-half + Vector2(3.0, 3.0), _seal_size - Vector2(6.0, 6.0)), Palette.SHADOW_BODY)

	var glow: Color = Palette.TEMPORAL_CORE if is_active else Palette.SHADOW_GLOW
	var pulse: float = 1.0 if is_active else 0.5 + 0.3 * sin(Time.get_ticks_msec() * 0.004)

	draw_arc(center, half.x - 7.0, 0.0, TAU, 24, Color(glow.r, glow.g, glow.b, 0.85 * pulse), 2.0, true)
	draw_arc(center, half.x - 13.0, 0.0, TAU, 24, Color(glow.r, glow.g, glow.b, 0.45 * pulse), 1.0, true)
	if is_active:
		draw_circle(center, 6.0, Color(glow.r, glow.g, glow.b, 0.9))
