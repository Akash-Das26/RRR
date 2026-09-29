class_name Activator
extends Area2D
## Base class for a mechanism that reports an on/off state.
##
## Pressure plates, levers and temporal switches all extend this, and doors,
## platforms and gates all listen to it. That one shared contract is what keeps
## puzzle wiring data-driven instead of a pile of bespoke per-room scripts:
## a level only has to say "door B listens to plate A".

## Emitted whenever the on/off state actually changes (never on redundant sets).
signal active_changed(active: bool)

## Whether the mechanism begins the level already switched on.
@export var starts_active: bool = false

var is_active: bool = false


func _ready() -> void:
	is_active = starts_active
	if is_active:
		active_changed.emit(true)


## Turns the mechanism on or off. Idempotent: setting the current value is a
## no-op and emits nothing, so listeners never receive duplicate events.
func set_active(value: bool) -> void:
	if is_active == value:
		return
	is_active = value
	active_changed.emit(is_active)


func is_on() -> bool:
	return is_active
