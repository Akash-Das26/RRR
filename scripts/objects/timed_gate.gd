class_name TimedGate
extends Door
## A door that opens for a fixed window and then closes itself.
##
## The timer is what creates the "run the route before it shuts" beats. Note it
## deliberately does [b]not[/b] close the moment a plate is released — that would
## make it an ordinary door; the whole point is that it owes you a head start.

@export var open_time: float = 4.0

var _remaining: float = 0.0


## Overrides [method Door._recompute]; the signature must keep the optional
## signal argument so it can be bound to [signal Activator.active_changed].
func _recompute(_active: bool = false) -> void:
	sources = ActuatorUtil.prune(sources)
	var triggered: bool = ActuatorUtil.all_active(sources) if require_all else ActuatorUtil.any_active(sources)
	if not triggered:
		return
	# Retriggering refreshes the window rather than stacking timers.
	_remaining = open_time
	set_open(true)


func _process(delta: float) -> void:
	super(delta)
	if not is_open:
		return
	_remaining -= delta
	if _remaining <= 0.0:
		_remaining = 0.0
		set_open(false)
