class_name Lever
extends Activator
## A handle the player can throw — and that an echo can throw for them.
##
## The echo path is the interesting one: when the player pulls a lever while
## recording, [code]TemporalManager.record_event(&"interact")[/code] stamps that
## frame. During playback the echo re-emits it, the lever checks that the echo is
## physically inside its volume, and the lever throws itself. This is why echoes
## are real gameplay entities rather than decorative ghosts.

## When true the lever stays on once thrown and cannot be reset by hand.
@export var latched: bool = false
## Stops a single input/pass from registering twice.
@export var cooldown: float = 0.25

var _cooldown_left: float = 0.0


func _ready() -> void:
	if get_child_count() == 0:
		_build()
	EventBus.echo_event_replayed.connect(_on_echo_event)
	super()


func _build() -> void:
	collision_layer = GameLayers.INTERACTABLE
	# Watches for echoes inside its volume so replayed interactions can be
	# attributed to the right lever.
	collision_mask = GameLayers.ECHO_BODY
	monitoring = true
	monitorable = true

	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(46.0, 54.0)
	collision.shape = rectangle
	collision.position = Vector2(0, -27)
	add_child(collision)


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)


## Called by the player's interact detector. Returns whether the input was used.
func interact(_by: Node) -> bool:
	if _cooldown_left > 0.0:
		return false
	if latched and is_active:
		return false
	_toggle()
	_cooldown_left = cooldown
	return true


func _toggle() -> void:
	set_active(not is_active)
	queue_redraw()


func _on_echo_event(echo: Node, event_id: StringName) -> void:
	if event_id != &"interact" or _cooldown_left > 0.0:
		return
	if latched and is_active:
		return
	if not _echo_inside(echo):
		return
	_toggle()
	_cooldown_left = cooldown


func _echo_inside(echo: Node) -> bool:
	for area: Area2D in get_overlapping_areas():
		if area == echo:
			return true
	return false


func _draw() -> void:
	# Wall plate.
	draw_rect(Rect2(-14, -46, 28, 46), Palette.STONE_SHADE)
	draw_rect(Rect2(-14, -46, 28, 4), Palette.STONE_LIGHT)

	# Handle pivots between 35 degrees up and 35 degrees down.
	var angle := deg_to_rad(-35.0 if is_active else 35.0)
	var pivot := Vector2(0, -22)
	var tip := pivot + Vector2(cos(angle - PI * 0.5), sin(angle - PI * 0.5)) * 26.0
	draw_line(pivot, tip, Palette.STONE_EDGE, 5.0)
	draw_circle(pivot, 4.0, Palette.STONE_DEEP)
	draw_circle(tip, 4.0, Palette.TEMPORAL_GLOW if is_active else Palette.GUARD_TRIM)
