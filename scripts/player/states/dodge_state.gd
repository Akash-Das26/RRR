class_name DodgeState
extends PlayerState
## A fast evasive dash with invulnerability frames.
##
## Distinct from [RollState]: the dodge can be aimed (including backwards, by
## holding away from the facing direction) and keeps the prince upright, so it
## is the reactive option. The roll is the crouched, committed option.


func _init() -> void:
	name = &"dodge"


func enter() -> void:
	# Aim the dodge with the stick/keys when held, otherwise dash forward.
	var axis := player.move_axis()
	if absf(axis) > 0.01:
		player.update_facing(1 if axis > 0.0 else -1)
	player.velocity.x = float(player.facing) * player.dodge_speed
	player.grant_invulnerability(player.dodge_duration + 0.05)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	var terminal: float = float(player.facing) * player.dodge_speed * 0.45
	player.velocity.x = move_toward(player.velocity.x, terminal, 380.0 * delta)
	player.commit_motion()

	if machine.time_in_current() >= player.dodge_duration:
		machine.transition_to(&"run" if absf(player.move_axis()) > 0.01 else &"idle")
		return
	if not player.is_on_floor() and machine.time_in_current() > 0.05:
		machine.transition_to(&"fall")
