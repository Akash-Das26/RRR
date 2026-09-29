class_name DeadState
extends PlayerState
## Terminal state. Nothing transitions out of it; [method Player.respawn] calls
## [method PlayerStateMachine.start] to force a hard reset instead.
##
## Keeping it truly terminal means no stray transition can resurrect the player
## mid-death sequence.

const DRAG: float = 900.0


func _init() -> void:
	name = &"dead"


func enter() -> void:
	player.set_hitbox_active(false)
	player.set_blocking(false)
	player.velocity.x *= 0.35


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, DRAG * delta)
	player.commit_motion()
