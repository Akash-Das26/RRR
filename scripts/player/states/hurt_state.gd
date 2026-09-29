class_name HurtState
extends PlayerState
## Brief stagger after a hit lands.
##
## Control is suspended only for the duration of the stagger — long enough that
## damage feels consequential, short enough that the player is never left
## watching the game play itself.

const HURT_TIME: float = 0.26
## How quickly horizontal knockback decays during the stagger.
const DRAG: float = 1250.0


func _init() -> void:
	name = &"hurt"


func enter() -> void:
	# Cancel any swing in progress: being hit should interrupt an attack.
	player.set_hitbox_active(false)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, DRAG * delta)
	player.commit_motion()

	if machine.time_in_current() < HURT_TIME:
		return
	if not player.is_on_floor():
		machine.transition_to(&"fall")
	else:
		machine.transition_to(&"idle")
