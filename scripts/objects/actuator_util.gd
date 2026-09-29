class_name ActuatorUtil
extends RefCounted
## Static helpers shared by every actuated object (doors, gates, platforms).
##
## GDScript has no interfaces, and a door is a [StaticBody2D] while a platform is
## an [AnimatableBody2D], so they cannot share a base class. These functions give
## them identical source-handling behaviour without duplication.


## Wires [param on_changed] to every valid source. Safe to call with empty or
## partially-invalid arrays.
static func connect_sources(sources: Array, on_changed: Callable) -> void:
	for source: Activator in sources:
		if source == null or not is_instance_valid(source):
			continue
		if not source.active_changed.is_connected(on_changed):
			source.active_changed.connect(on_changed)


## True when every source is switched on. An empty source list is treated as
## "always on" so a mechanism with no wiring still works as a plain prop.
static func all_active(sources: Array) -> bool:
	for source: Activator in sources:
		if source == null:
			continue
		if not source.is_on():
			return false
	return true


## True when at least one source is switched on.
static func any_active(sources: Array) -> bool:
	for source: Activator in sources:
		if source != null and is_instance_valid(source) and source.is_on():
			return true
	return false


## Drops freed sources. Called before evaluation so a destroyed plate cannot
## leave a door permanently stuck closed.
static func prune(sources: Array) -> Array:
	var live: Array = []
	for source: Activator in sources:
		if source != null and is_instance_valid(source):
			live.append(source)
	return live
