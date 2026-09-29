class_name IdleState
extends PlayerState
## Standing still. Because it is the grounded hub state, most transitions out of
## neutral ground movement are decided here.


func _init() -> void:
	name = &"idle"


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(delta, player.max_run_speed)
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
	if Input.is_action_just_pressed(&"dodge"):
		machine.transition_to(&"dodge")
		return
	if player.current_ladder() != null and Input.is_action_pressed(&"move_up"):
		machine.transition_to(&"climb")
		return
	if Input.is_action_pressed(&"block"):
		machine.transition_to(&"block")
		return
	if Input.is_action_pressed(&"crouch"):
		machine.transition_to(&"crouch")
		return
	if absf(player.move_axis()) > 0.01:
		machine.transition_to(&"run")
