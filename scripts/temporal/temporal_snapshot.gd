class_name TemporalSnapshot
extends RefCounted
## One sampled physics frame of a recording.
##
## Every field the replay needs is captured here so an echo never has to
## re-simulate physics — it reproduces the exact transform that was recorded,
## which is what makes playback deterministic by construction.

## Seconds since the recording started. Strictly increasing.
var time: float = 0.0
var position: Vector2 = Vector2.ZERO
var rotation: float = 0.0
var velocity: Vector2 = Vector2.ZERO
## Name of the player state machine state (used for echo visuals + debugging).
var animation_state: StringName = &"idle"
## -1 or 1. Echo silhouettes mirror the direction the player was facing.
var facing: int = 1
## Gameplay events fired on this exact frame (see [method TemporalRecorder.add_event]).
var events: PackedStringArray = PackedStringArray()


static func create(
	p_time: float,
	p_position: Vector2,
	p_rotation: float,
	p_velocity: Vector2,
	p_state: StringName,
	p_facing: int
) -> TemporalSnapshot:
	var snapshot := TemporalSnapshot.new()
	snapshot.time = p_time
	snapshot.position = p_position
	snapshot.rotation = p_rotation
	snapshot.velocity = p_velocity
	snapshot.animation_state = p_state
	snapshot.facing = p_facing
	return snapshot


func has_events() -> bool:
	return not events.is_empty()
