class_name LandState
extends PlayerState
## A short recovery beat on touchdown.
##
## The lock is deliberately tiny (~70 ms) and jumping or attacking is still
## allowed during it. Its job is to give the landing a readable moment, not to
## take control away from the player.

const LAND_LOCK: float = 0.07


func _init() -> void:
	name = &"land"


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	# Reduced control on touchdown so a hard landing has weight.
	player.apply_horizontal(delta, player.max_run_speed * 0.55)
	player.commit_motion()

	if player.consume_jump():
		machine.transition_to(&"jump")
		return
	if player.has_buffered_attack():
		machine.transition_to(&"attack")
		return
	if not player.is_on_floor():
		machine.transition_to(&"fall")
		return
	if machine.time_in_current() >= LAND_LOCK:
		machine.transition_to(&"run" if absf(player.move_axis()) > 0.01 else &"idle")
