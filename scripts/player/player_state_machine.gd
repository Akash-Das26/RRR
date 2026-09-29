class_name PlayerStateMachine
extends Node
## Runs the player's states and mediates every transition.
##
## This is a [Node] rather than a [RefCounted] for a concrete reason: the machine
## holds the states and every state holds a reference back to the machine. As
## [RefCounted] objects that is an uncollectable reference cycle and all thirteen
## states leak on every level load. Being a [Node] makes the machine
## manually-managed and therefore cycle-free — attach it as a child of the
## player so it is freed with its owner.
##
## Transitions are [b]deferred[/b]: [method transition_to] records the request and
## the machine applies it after the current state's update returns. This is the
## single most important design choice here — it makes it impossible for a state
## to change the active state while its own code is still executing, which is the
## usual source of one-frame glitches and double-entered states.

## Guards against two states instantly redirecting to each other forever.
const MAX_ENTER_CHAIN: int = 8

var player: Player = null
var states: Dictionary = {}

var current: PlayerState = null
var current_name: StringName = &""
var previous_name: StringName = &""
var time_in_state: float = 0.0

var _pending_name: StringName = &""


func _init(p_player: Player) -> void:
	player = p_player


## Registers a state. Call for every state before [method start].
func add_state(state: PlayerState) -> void:
	if state == null:
		push_error("PlayerStateMachine.add_state: null state passed.")
		return
	if states.has(state.name):
		push_error("PlayerStateMachine.add_state: duplicate state '%s'." % state.name)
		return
	state.player = player
	state.machine = self
	states[state.name] = state


func start(initial_name: StringName) -> void:
	_enter(initial_name)


## Requests a transition. Ignored if the target is already active or unknown.
func transition_to(state_name: StringName) -> void:
	if state_name == current_name:
		return
	if not states.has(state_name):
		push_error("PlayerStateMachine.transition_to: unknown state '%s'." % state_name)
		return
	_pending_name = state_name


func physics_update(delta: float) -> void:
	time_in_state += delta
	if current != null:
		current.physics_update(delta)
	_apply_pending()


func handle_input(event: InputEvent) -> void:
	if current != null:
		current.handle_input(event)


func state_name() -> StringName:
	return current_name


func time_in_current() -> float:
	return time_in_state


func _apply_pending() -> void:
	if _pending_name == &"" or _pending_name == current_name:
		_pending_name = &""
		return
	var target := _pending_name
	_pending_name = &""
	_enter(target)


func _enter(state_name: StringName, depth: int = 0) -> void:
	if depth > MAX_ENTER_CHAIN:
		push_error("PlayerStateMachine: enter chain exceeded %d states; check for a transition cycle." % MAX_ENTER_CHAIN)
		return

	if current != null:
		current.exit()

	previous_name = current_name
	current_name = state_name
	current = states[state_name]
	time_in_state = 0.0
	current.enter()

	# A state may redirect the instant it is entered (e.g. Land -> Run).
	# Chain immediately so the player never spends a frame in a stale state.
	if _pending_name != &"" and _pending_name != current_name:
		var next := _pending_name
		_pending_name = &""
		_enter(next, depth + 1)
