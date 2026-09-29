class_name MovingPlatform
extends AnimatableBody2D
## A platform that slides along a fixed travel vector when switched on.
##
## [member AnimatableBody2D.sync_to_physics] is enabled so a player standing on
## it is carried correctly instead of sliding off — that requires the platform to
## move during the physics step, which is why travel happens in
## [method _physics_process].

@export var travel: Vector2 = Vector2(0.0, -170.0)
@export var speed: float = 70.0
@export var platform_size: Vector2 = Vector2(110.0, 22.0)
@export var require_all: bool = true
## When true the platform ping-pongs between its two ends while engaged, instead
## of travelling to the far end and stopping. Oscillation is what makes a
## platform usable as a bridge: a one-way platform strands the player at the
## far side.
@export var oscillate: bool = true

var sources: Array = []

var _origin: Vector2 = Vector2.ZERO
var _progress: float = 0.0
var _osc_phase: float = 0.0
var _on_changed := Callable()


func configure(p_size: Vector2, p_travel: Vector2, p_speed: float) -> void:
	platform_size = p_size
	travel = p_travel
	speed = p_speed
	if get_child_count() == 0:
		_build()


func _ready() -> void:
	if get_child_count() == 0:
		_build()
	_origin = position
	_on_changed = _on_state_changed
	ActuatorUtil.connect_sources(sources, _on_changed)
	# Zero-length travel would make the interpolation below divide by zero.
	if travel.length() < 0.001:
		push_warning("MovingPlatform '%s' has a zero travel vector and will never move." % name)


func _build() -> void:
	sync_to_physics = true
	collision_layer = GameLayers.WORLD
	collision_mask = 0

	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = platform_size
	collision.shape = rectangle
	add_child(collision)
	z_index = 0


func bind_sources(p_sources: Array, p_require_all: bool = true) -> void:
	sources = p_sources
	require_all = p_require_all


func _on_state_changed(_active: bool) -> void:
	sources = ActuatorUtil.prune(sources)


func is_engaged() -> bool:
	sources = ActuatorUtil.prune(sources)
	return ActuatorUtil.all_active(sources) if require_all else ActuatorUtil.any_active(sources)


func _physics_process(delta: float) -> void:
	var distance: float = travel.length()
	if distance < 0.001:
		return

	if oscillate:
		if not is_engaged():
			return
		# angular rate chosen so one full there-and-back trip takes
		# 2 * distance / speed seconds.
		_osc_phase += delta * PI * speed / distance
		_progress = 0.5 - 0.5 * cos(_osc_phase)
		position = _origin + travel * _progress
		queue_redraw()
		return

	var target: float = 1.0 if is_engaged() else 0.0
	var previous := _progress
	_progress = move_toward(_progress, target, (speed / distance) * delta)
	if is_equal_approx(previous, _progress):
		return
	# Move in physics so riders are carried. With sync_to_physics enabled,
	# assigning the transform here is what makes CharacterBody2D riders stick.
	position = _origin + travel * _progress


func _draw() -> void:
	var rect := Rect2(-platform_size * 0.5, platform_size)
	draw_rect(rect, Palette.STONE_DEEP)
	draw_rect(rect.grow(-3.0), Palette.STONE_BASE)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3.0)), Palette.TEMPORAL_GLOW if is_engaged() else Palette.STONE_EDGE)
	# Guide rail so the travel path is readable before it moves.
	draw_line(Vector2.ZERO, travel, Color(Palette.TEMPORAL_GLOW.r, Palette.TEMPORAL_GLOW.g, Palette.TEMPORAL_GLOW.b, 0.18), 1.0)
