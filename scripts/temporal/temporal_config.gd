class_name TemporalConfig
extends Resource
## All tunable rules for the Temporal Echo, as a data [Resource].
##
## Nothing here is hard-coded into the systems: [TemporalManager] reads this and
## levels / upgrades simply swap the instance. This is what lets the directive's
## "8 s recording, 1 echo" starting limits later become "12 s, 2 echoes" without
## recompiling behaviour.

@export_group("Recording")
## Hard cap on how long a single recording may run, in seconds.
@export_range(1.0, 60.0, 0.5) var max_recording_duration: float = 8.0
## Recordings shorter than this are discarded — they are treated as a mis-tap.
@export_range(0.0, 3.0, 0.05) var min_recording_duration: float = 0.3

@export_group("Echoes")
## How many echoes may exist at once. The oldest is retired when exceeded.
@export_range(1, 8, 1) var max_active_echoes: int = 1
## How long an echo lives before it dissolves, in seconds. 0 means "until replaced".
@export_range(0.0, 120.0, 0.5) var echo_lifetime: float = 24.0
## Whether an echo repeats its recorded path or plays it once and then holds
## its final pose until it expires.
##
## Default is [code]false[/code] on purpose. A looping echo walks back to its
## starting point every lap, which would make a pressure plate it is standing on
## flicker on and off — unplayable. Holding the final pose is what lets
## "record yourself standing on the plate" be a real, stable solution.
@export var loop_echo: bool = false

@export_group("Temporal Energy")
@export_range(1.0, 12.0, 0.5) var energy_max: float = 3.0
@export_range(0.0, 5.0, 0.25) var energy_cost_per_echo: float = 1.0
## Energy regained per second. Must be > 0 or a player who wastes echoes soft-locks.
@export_range(0.0, 5.0, 0.05) var energy_regen_per_second: float = 0.34


## A duplicate tuned for the later "advanced" tier described in the directive.
func advanced_variant() -> TemporalConfig:
	var clone: TemporalConfig = duplicate(true) as TemporalConfig
	clone.max_recording_duration = 12.0
	clone.max_active_echoes = 2
	return clone
