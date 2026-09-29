class_name RollState
extends PlayerState
## A committed roll: fixed direction, invulnerable, no mid-roll steering.
##
## Commitment is the point. If the roll could be steered it would just be "run
## with i-frames"; locking the direction makes it a decision with a cost.


func _init() -> void:
	name = &"roll"


func enter() -> void:
	player.velocity.x = float(player.facing) * player.roll_speed
	player.grant_invulnerability(player.roll_duration + 0.05)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	# Bleed a little speed so the roll ends in a natural stop rather than
	# snapping back to walking speed on the final frame.
	var terminal: float = float(player.facing) * player.roll_speed * 0.55
	player.velocity.x = move_toward(player.velocity.x, terminal, 260.0 * delta)
	player.commit_motion()

	if machine.time_in_current() >= player.roll_duration:
		machine.transition_to(&"run" if absf(player.move_axis()) > 0.01 else &"idle")
		return
	if not player.is_on_floor() and machine.time_in_current() > 0.06:
		machine.transition_to(&"fall")
