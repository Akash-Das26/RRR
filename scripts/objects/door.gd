class_name Door
extends StaticBody2D
## A barrier driven by one or more [Activator]s.
##
## Doors own no puzzle logic of their own — they are told what to listen to. The
## same class therefore serves a single-plate tutorial door and a two-plate vault
## door with no code change, just different wiring in the level data.

@export var door_size: Vector2 = Vector2(52.0, 132.0)
## When true every source must be on; when false any one source opens the door.
@export var require_all: bool = true
## Seconds the slab takes to slide open.
@export var slide_time: float = 0.35

var is_open: bool = false
var sources: Array = []

var _slide: float = 0.0   ## 0 = closed, 1 = fully open
var _on_changed := Callable()


func configure(p_size: Vector2) -> void:
	door_size = p_size
	_build()


func _ready() -> void:
	if get_child_count() == 0:
		_build()
	_on_changed = _recompute
	ActuatorUtil.connect_sources(sources, _on_changed)
	_recompute()


func _build() -> void:
	collision_layer = GameLayers.WORLD
	collision_mask = 0

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = door_size
	collision.shape = rectangle
	collision.position = Vector2(0, -door_size.y * 0.5)
	add_child(collision)
	z_index = 1


## Binds the sources this door listens to. Call before adding to the tree.
func bind_sources(p_sources: Array, p_require_all: bool = true) -> void:
	sources = p_sources
	require_all = p_require_all


## Bound directly to [signal Activator.active_changed], so it must accept the
## signal's argument. Getting this signature wrong means the door silently never
## opens — the single highest-risk wiring mistake in the puzzle system.
func _recompute(_active: bool = false) -> void:
	sources = ActuatorUtil.prune(sources)
	var should_open: bool = ActuatorUtil.all_active(sources) if require_all else ActuatorUtil.any_active(sources)
	set_open(should_open)


func set_open(open: bool) -> void:
	if is_open == open:
		return
	is_open = open
	# Physics state changes must be deferred: this can be called from inside a
	# physics callback when a plate flips.
	set_deferred("collision_layer", 0 if is_open else GameLayers.WORLD)


func _process(delta: float) -> void:
	var target: float = 1.0 if is_open else 0.0
	var previous := _slide
	if slide_time <= 0.0:
		_slide = target
	else:
		_slide = move_toward(_slide, target, delta / slide_time)
	if not is_equal_approx(previous, _slide):
		queue_redraw()


func _draw() -> void:
	var half := door_size * 0.5
	var lift: float = _slide * door_size.y * 0.92

	# Frame the door sits in.
	draw_rect(Rect2(-half.x - 6.0, -door_size.y - 6.0, door_size.x + 12.0, door_size.y), Palette.STONE_SHADE)

	# The slab rises into the lintel as it opens.
	var slab := Rect2(-half.x, -door_size.y + lift, door_size.x, door_size.y)
	draw_rect(slab, Palette.STONE_DEEP)
	draw_rect(slab.grow(-3.0), Palette.GUARD_ARMOUR)
	# Banding so vertical travel is legible.
	draw_rect(Rect2(slab.position.x, slab.position.y + slab.size.y * 0.35, slab.size.x, 6.0), Palette.GUARD_TRIM)

	if is_open:
		draw_rect(Rect2(-half.x, -door_size.y, door_size.x, 5.0), Palette.TEMPORAL_GLOW)
