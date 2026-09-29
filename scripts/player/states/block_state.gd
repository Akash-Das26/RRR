class_name BlockState
extends PlayerState
## A raised guard: slow shuffling movement, heavily reduced damage from the
## front (see [method Player._filter_incoming_damage]).
##
## Blocking is intentionally not invulnerable — a rear attack still lands in
## full. The player's facing therefore matters, which is what keeps enemies that
## circle behind you threatening.

## Blocking movement is slower than a crouch-walk on purpose: safety should cost
## tempo, otherwise there is no reason to ever lower the guard.
const SHUFFLE_SPEED: float = 105.0


func _init() -> void:
	name = &"block"


func enter() -> void:
	player.set_blocking(true)


func exit() -> void:
	player.set_blocking(false)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(delta, SHUFFLE_SPEED)
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
	if not Input.is_action_pressed(&"block"):
		machine.transition_to(&"idle")
