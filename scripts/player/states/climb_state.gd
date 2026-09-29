class_name ClimbState
extends PlayerState
## Vertical traversal on a climbable volume (see [code]Ladder[/code]).
##
## Gravity is skipped entirely here, which is why climbing has to be its own
## state rather than a flag on [FallState].

## Horizontal nudge allowed while on a ladder, for lining up a dismount.
const NUDGE_SPEED: float = 70.0
## Outward push when hopping off a ladder with jump.
const HOP_OFF_SPEED: float = 180.0


func _init() -> void:
	name = &"climb"


func enter() -> void:
	player.velocity = Vector2.ZERO


func physics_update(delta: float) -> void:
	var ladder := player.current_ladder()
	if ladder == null:
		machine.transition_to(&"fall")
		return

	if player.consume_jump():
		player.velocity.x = float(-player.facing) * HOP_OFF_SPEED
		player.velocity.y = player.jump_velocity * 0.8
		machine.transition_to(&"jump")
		return

	var horizontal := player.move_axis()
	var vertical := Input.get_axis(&"move_up", &"crouch")
	player.velocity.x = horizontal * NUDGE_SPEED
	player.velocity.y = vertical * player.ladder_speed
	if absf(horizontal) > 0.01:
		player.update_facing(1 if horizontal > 0.0 else -1)

	player.commit_motion()

	# Stepping off at the bottom.
	if player.is_on_floor() and vertical > 0.0 and machine.time_in_current() > 0.15:
		machine.transition_to(&"idle")
		return
	if player.has_buffered_attack():
		machine.transition_to(&"attack")
