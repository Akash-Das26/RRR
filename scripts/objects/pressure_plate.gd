class_name PressurePlate
extends Activator
## A floor slab that switches on while something stands on it.
##
## The plate is blind to *which* body is standing on it beyond the filter below,
## which is exactly what makes the signature puzzle work: the present-day player
## and a recorded echo are interchangeable weights.

enum Trigger {
	ANY_ACTOR,   ## Player or echo.
	ECHO_ONLY,   ## Only a memory can hold it down.
	PLAYER_ONLY, ## Only the living prince counts.
}

const PRESS_DEPTH: float = 4.0

@export var plate_size: Vector2 = Vector2(76.0, 14.0)
@export var trigger_filter: Trigger = Trigger.ANY_ACTOR
## Seconds the plate stays pressed after the last weight leaves. 0 = instant.
@export var release_delay: float = 0.0

var _press: float = 0.0
var _release_timer: float = 0.0


func configure(p_size: Vector2) -> void:
	plate_size = p_size
	_build()


func _ready() -> void:
	if get_child_count() == 0:
		_build()
	super()


func _build() -> void:
	collision_layer = 0
	collision_mask = GameLayers.TRIGGER_ACTORS
	monitoring = true
	monitorable = false

	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(plate_size.x, plate_size.y + 12.0)
	collision.shape = rectangle
	collision.position = Vector2(0, -plate_size.y * 0.5)
	add_child(collision)
	z_index = -1


func _physics_process(delta: float) -> void:
	var weight := _detect_weight()

	if weight > 0:
		_release_timer = release_delay
		set_active(true)
	elif is_active:
		_release_timer = maxf(0.0, _release_timer - delta)
		if _release_timer <= 0.0:
			set_active(false)

	# Animate the slab so the player can read the state at a glance.
	var target: float = PRESS_DEPTH if is_active else 0.0
	var previous := _press
	_press = move_toward(_press, target, 40.0 * delta)
	if not is_equal_approx(previous, _press):
		queue_redraw()


## Number of qualifying actors currently on the plate.
func _detect_weight() -> int:
	var count := 0
	if trigger_filter != Trigger.ECHO_ONLY:
		count += get_overlapping_bodies().size()
	if trigger_filter != Trigger.PLAYER_ONLY:
		for area: Area2D in get_overlapping_areas():
			if area is TemporalEcho:
				count += 1
	return count


func _draw() -> void:
	var width := plate_size.x
	var height := plate_size.y
	var top := -height + _press

	# Recessed socket the slab sits in.
	draw_rect(Rect2(-width * 0.5, -height, width, height), Palette.STONE_DEEP)
	# The slab itself.
	draw_rect(Rect2(-width * 0.5, top, width, height), Palette.STONE_SHADE)
	draw_rect(Rect2(-width * 0.5, top, width, 3.0), Palette.STONE_LIGHT)

	if is_active:
		var glow := Palette.TEMPORAL_GLOW if trigger_filter != Trigger.PLAYER_ONLY else Palette.STONE_EDGE
		draw_rect(Rect2(-width * 0.5 + 4.0, top + 4.0, width - 8.0, 3.0), glow)
		draw_circle(Vector2(0, top - 4.0), 5.0, Color(glow.r, glow.g, glow.b, 0.22))


func describe() -> String:
	return "PressurePlate(%s, active=%s)" % [Trigger.keys()[trigger_filter], is_active]
