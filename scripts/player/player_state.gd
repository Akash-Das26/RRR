class_name PlayerState
extends RefCounted
## Base class for a single player state.
##
## A state owns exactly one behaviour and is intentionally tiny. Shared motion
## maths lives on [Player] ([method Player.apply_gravity],
## [method Player.apply_horizontal], ...), so states describe [i]what happens[/i],
## not how gravity works.
##
## Contract for subclasses:
## [br]• call [code]super()[/code] in [method _init] if you define one
## [br]• request a change with [method PlayerStateMachine.transition_to] and
##   [b]return immediately[/b] — the machine applies it after the frame
## [br]• end [method physics_update] with [method Player.commit_motion]

## Machine-readable id. Must be unique per state; assigned in [method _init].
var name: StringName = &"unnamed"
var player: Player = null
var machine: PlayerStateMachine = null


## Called once when the state becomes active.
func enter() -> void:
	pass


## Called once when the state is replaced.
func exit() -> void:
	pass


## Fixed-step update. Use this for all movement and most logic.
func physics_update(_delta: float) -> void:
	pass


## Raw input forwarded from [method Node._unhandled_input].
func handle_input(_event: InputEvent) -> void:
	pass
