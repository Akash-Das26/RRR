class_name JumpState
extends PlayerState
## The rising half of a jump. Falling is a separate state so each can be tuned
## independently (asymmetric gravity is a core part of platformer feel).


func _init() -> void:
	name = &"jump"


func enter() -> void:
	player.do_jump()


func physics_update(delta: float) -> void:
	# Slightly reduced gravity while ascending and holding jump: a floatier rise
	# than fall, which reads as deliberate rather than mushy.
	var rising: bool = player.velocity.y < 0.0
	player.apply_gravity(delta, 0.86 if rising else 1.0)
	player.apply_horizontal(delta, player.max_run_speed)
	player.commit_motion()

	if player.has_buffered_attack():
		machine.transition_to(&"attack")
		return
	if player.velocity.y >= 0.0:
		machine.transition_to(&"fall")
