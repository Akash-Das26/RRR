class_name InputActions
extends RefCounted
## Registers every gameplay action in [InputMap] at runtime.
##
## Why runtime instead of [code]project.godot[/code]: the bindings then live in
## exactly one auditable, diffable table and cannot be corrupted by a hand-edited
## config file. [method ensure_defaults] is idempotent, so it is safe to call on
## every boot and it will never clobber a binding a developer added by hand.
##
## Keyboard only. The directive targets desktop first, and gamepad support is a
## later phase; adding it here means editing one dictionary.

## action name -> array of physical key scancodes.
const DEFAULTS: Dictionary = {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"move_up": [KEY_W, KEY_UP],
	&"crouch": [KEY_S, KEY_DOWN],
	&"jump": [KEY_SPACE],
	&"interact": [KEY_E],
	&"light_attack": [KEY_J],
	&"heavy_attack": [KEY_K],
	&"block": [KEY_L],
	&"dodge": [KEY_SHIFT],
	&"temporal_record": [KEY_Q],
	&"pause": [KEY_ESCAPE],
	&"restart": [KEY_R],
}

## Deadzone is only meaningful for analogue input; keys are always 0 or 1.
const DEADZONE: float = 0.2


## Creates any missing action and key binding. Returns the number of actions
## that were newly created (useful for tests and for boot logging).
static func ensure_defaults() -> int:
	var created := 0
	for action: StringName in DEFAULTS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
			created += 1
		for scancode: int in DEFAULTS[action]:
			if not _has_physical_key(action, scancode):
				var event := InputEventKey.new()
				event.physical_keycode = scancode
				InputMap.action_add_event(action, event)
	return created


static func _has_physical_key(action: StringName, scancode: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == scancode:
			return true
	return false
