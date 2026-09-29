class_name TemporalRecorder
extends RefCounted
## Samples a moving source once per physics frame into a bounded buffer.
##
## The recorder is deliberately dumb: it stores what it is handed. It contains
## no knowledge of the player, which is why it can be unit-tested by feeding it
## synthetic frames (see [code]tests/test_main.gd[/code]).
##
## Capacity is bounded by [code]max_recording_duration * physics_ticks_per_second[/code]
## because [method record] hard-stops the moment the cap is reached. There is no
## unbounded append path.

var _config: TemporalConfig
var _snapshots: Array[TemporalSnapshot] = []
var _elapsed: float = 0.0

## True between [method start] and whichever of [method stop] / the duration cap
## fires first.
var is_recording: bool = false


func _init(config: TemporalConfig) -> void:
	assert(config != null, "TemporalRecorder requires a TemporalConfig.")
	_config = config


func start() -> void:
	_snapshots.clear()
	_elapsed = 0.0
	is_recording = true


## Abandons the take in progress; nothing is produced.
func cancel() -> void:
	is_recording = false
	_snapshots.clear()
	_elapsed = 0.0


## Ends the take, keeping whatever was captured.
func stop() -> void:
	is_recording = false


## Appends one frame. Returns [code]false[/code] once recording has ended, either
## because the caller stopped it or because the duration cap was reached.
func record(
	delta: float,
	position: Vector2,
	rotation: float,
	velocity: Vector2,
	state: StringName,
	facing: int
) -> bool:
	if not is_recording:
		return false

	# Clamp the step so a pathological frame time cannot blow past the cap and
	# leave a truncated, non-uniform tail in the timeline.
	var step: float = maxf(delta, 0.0)
	_elapsed += step

	_snapshots.append(TemporalSnapshot.create(_elapsed, position, rotation, velocity, state, facing))

	if _elapsed >= _config.max_recording_duration:
		is_recording = false
		return false
	return true


## Attaches a gameplay event id to the frame that was just recorded.
## Events are what let an echo operate a lever, not just stand on a plate.
func add_event(event_id: StringName) -> void:
	if _snapshots.is_empty():
		push_warning("TemporalRecorder.add_event ignored: no frame has been recorded yet.")
		return
	_snapshots[_snapshots.size() - 1].events.append(String(event_id))


func get_snapshots() -> Array[TemporalSnapshot]:
	return _snapshots


## Length of the take in seconds.
func duration() -> float:
	return _elapsed


func frame_count() -> int:
	return _snapshots.size()


## Whether the take is long enough and has enough frames to make a useful echo.
func has_usable_data() -> bool:
	return _elapsed >= _config.min_recording_duration and _snapshots.size() >= 2


## Remaining recording budget in the range 0..1, for the HUD meter.
func budget_ratio() -> float:
	if _config.max_recording_duration <= 0.0:
		return 0.0
	return clampf(_elapsed / _config.max_recording_duration, 0.0, 1.0)
