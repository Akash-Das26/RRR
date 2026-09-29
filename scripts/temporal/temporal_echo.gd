class_name TemporalEcho
extends Area2D
## A genuine gameplay entity that replays a past recording.
##
## Design decision worth stating plainly: an echo does [b]not[/b] re-simulate
## physics. It reproduces the exact recorded transforms, so it walks the same
## path through the same walls at the same speed every single time. That is what
## makes "your past self opens the door for you" a solvable puzzle instead of a
## physics lottery.
##
## Because it is an [Area2D] on [constant GameLayers.ECHO_BODY] it is invisible
## to level geometry but perfectly visible to pressure plates, triggers and
## enemy detection — geometry ignores it, mechanisms do not.

## Emitted when playback ends (lifetime elapsed or the take ran out).
signal playback_finished(echo: TemporalEcho)
## Emitted for every recorded gameplay event as playback crosses it.
signal event_replayed(echo: TemporalEcho, event_id: StringName)

const BODY_HALF_WIDTH: float = 6.0
const BODY_HEIGHT: float = 18.0
const HEAD_RADIUS: float = 6.0
const TRAIL_MAX: int = 14

## Whether the take repeats. Set from [member TemporalConfig.loop_echo].
var loop: bool = true
## Seconds of life remaining budget; 0 means "live until replaced".
var lifetime: float = 24.0

var _snapshots: Array[TemporalSnapshot] = []
var _duration: float = 1.0
var _time: float = 0.0
var _life_left: float = 0.0
var _cursor: int = -1
var _loops_done: int = 0
var _facing: int = 1
var _state: StringName = &"idle"
var _fade: float = 1.0
var _finished: bool = false
var _trail: Array[Vector2] = []


## Must be called before the node enters the tree.
##
## Note the initial frame is deliberately NOT applied here. Setting
## [member Node2D.global_position] while a node is outside the tree writes its
## *local* position, so doing it early silently bakes in the container's
## transform the moment the echo is parented. It is applied in [method _ready]
## instead, once the global transform actually means something.
func setup(p_snapshots: Array[TemporalSnapshot], p_config: TemporalConfig) -> void:
	_snapshots = p_snapshots
	loop = p_config.loop_echo
	lifetime = p_config.echo_lifetime
	_duration = maxf(0.016, _snapshots[-1].time)
	_life_left = lifetime
	_time = 0.0


func _ready() -> void:
	collision_layer = GameLayers.ECHO_BODY
	collision_mask = 0
	monitoring = false   # The echo never asks what is around it...
	monitorable = true   # ...but the world is always allowed to notice it.
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = BODY_HALF_WIDTH
	capsule.height = BODY_HEIGHT + HEAD_RADIUS * 2.0
	shape.shape = capsule
	shape.position = Vector2(0, -BODY_HEIGHT * 0.5)
	add_child(shape)
	z_index = 5

	# Now that the echo is parented, global_position is meaningful. Snap to the
	# first recorded frame so it never appears briefly at the origin.
	_apply_frame(0)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _finished:
		return
	if _snapshots.size() < 2:
		_expire()
		return

	_time += delta

	if lifetime > 0.0:
		_life_left -= delta
		if _life_left <= 0.0:
			_expire()
			return
		# Dying echoes fade out over their final two seconds.
		_fade = clampf(_life_left / 2.0, 0.0, 1.0)

	var play_time: float = _time
	if loop:
		var loops_done := floori(_time / _duration)
		if loops_done != _loops_done:
			_loops_done = loops_done
			_cursor = -1   # Re-arm events for the new lap.
		play_time = fmod(_time, _duration)
	else:
		play_time = minf(_time, _duration)

	_advance_to(play_time)
	queue_redraw()


## Walks the cursor forward, firing any events crossed, then snaps to that frame.
func _advance_to(play_time: float) -> void:
	var last := _snapshots.size() - 1
	while _cursor < last and _snapshots[_cursor + 1].time <= play_time:
		_cursor += 1
		var crossed := _snapshots[_cursor]
		for event_id: String in crossed.events:
			event_replayed.emit(self, StringName(event_id))

	_apply_frame(clampi(_cursor, 0, last))


func _apply_frame(index: int) -> void:
	var snapshot: TemporalSnapshot = _snapshots[index]
	global_position = snapshot.position
	rotation = snapshot.rotation
	_facing = snapshot.facing
	_state = snapshot.animation_state

	if _trail.is_empty() or _trail[_trail.size() - 1].distance_squared_to(snapshot.position) > 4.0:
		_trail.append(snapshot.position)
		while _trail.size() > TRAIL_MAX:
			_trail.remove_at(0)


func _expire() -> void:
	if _finished:
		return
	_finished = true
	playback_finished.emit(self)
	queue_free()


## Seconds into the take that playback is currently at (for HUD / debugging).
func playback_time() -> float:
	return minf(_time, _duration)


## Progress through the take in the range 0..1.
func playback_ratio() -> float:
	if _duration <= 0.0:
		return 0.0
	return clampf(_time / _duration, 0.0, 1.0)


func _draw() -> void:
	# Motion trail — the "afterimage" half of the temporal visual language.
	var trail_count := _trail.size()
	for i: int in range(maxi(0, trail_count - 1)):
		var point := to_local(_trail[i])
		var age := float(i + 1) / float(trail_count)
		draw_circle(point + Vector2(0, -BODY_HEIGHT * 0.5), BODY_HALF_WIDTH * 0.8, Color(0.45, 0.85, 1.0, 0.16 * age * _fade))

	# Energy aura.
	draw_circle(Vector2(0, -BODY_HEIGHT * 0.5), BODY_HALF_WIDTH * 2.4, Color(0.30, 0.70, 1.0, 0.08 * _fade))
	draw_circle(Vector2(0, -BODY_HEIGHT * 0.5), BODY_HALF_WIDTH * 1.6, Color(0.55, 0.90, 1.0, 0.14 * _fade))

	# The figure itself: a hollow, translucent memory of the prince.
	var body_color := Color(0.72, 0.95, 1.0, 0.42 * _fade)
	var head_color := Color(0.85, 0.98, 1.0, 0.50 * _fade)
	var crouching: bool = _state == &"crouch" or _state == &"roll"
	if crouching:
		draw_rect(Rect2(-BODY_HALF_WIDTH, -BODY_HEIGHT * 0.5, BODY_HALF_WIDTH * 2.0, BODY_HEIGHT * 0.6), body_color)
		draw_circle(Vector2(0, -BODY_HEIGHT * 0.5), HEAD_RADIUS * 0.8, head_color)
	else:
		draw_rect(Rect2(-BODY_HALF_WIDTH, -BODY_HEIGHT, BODY_HALF_WIDTH * 2.0, BODY_HEIGHT), body_color)
		draw_circle(Vector2(0, -BODY_HEIGHT - HEAD_RADIUS * 0.6), HEAD_RADIUS, head_color)

	# Facing indicator so the player can read which way their memory is looking.
	var arm_x := 9.0 * float(_facing)
	draw_line(Vector2(0, -BODY_HEIGHT * 0.6), Vector2(arm_x, -BODY_HEIGHT * 0.2), Color(0.92, 0.99, 1.0, 0.55 * _fade), 2.0)
