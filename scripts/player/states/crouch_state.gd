class_name CrouchState
extends PlayerState
## Low, slow movement. Also the deliberate input for climbing down a ladder.


func _init() -> void:
	name = &"crouch"


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(delta, player.crouch_speed)
	player.commit_motion()

	if not player.is_on_floor():
		machine.transition_to(&"fall")
		return
	if player.consume_jump():
		machine.transition_to(&"jump")
		return
	if player.has_buffered_attack():
		machine.transition_to(&"attack")
		return
	# Crouched + dodge is the roll: the committed, low-profile evade.
	if Input.is_action_just_pressed(&"dodge"):
		machine.transition_to(&"roll")
		return
	var ladder := player.current_ladder()
	if ladder != null and absf(Input.get_axis(&"move_up", &"crouch")) > 0.01:
		machine.transition_to(&"climb")
		return
	if not Input.is_action_pressed(&"crouch"):
		machine.transition_to(&"idle")
