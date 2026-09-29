class_name FallState
extends PlayerState
## Airborne descent.
##
## This is where coyote time pays off: [method Player.consume_jump] still accepts
## a jump for a few frames after walking off a ledge, so a late press is honoured
## instead of ignored.


func _init() -> void:
	name = &"fall"


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(delta, player.max_run_speed)
	player.commit_motion()

	if player.is_on_floor():
		machine.transition_to(&"land")
		return
	if player.consume_jump():
		machine.transition_to(&"jump")
		return
	if player.has_buffered_attack():
		machine.transition_to(&"attack")
		return
	var ladder := player.current_ladder()
	if ladder != null and (Input.is_action_pressed(&"move_up") or Input.is_action_pressed(&"crouch")):
		machine.transition_to(&"climb")
