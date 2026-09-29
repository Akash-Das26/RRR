extends Node
## Autoload [code]TemporalManager[/code] — the single authority on time.
##
## Flow it implements (matching the directive):
## [codeblock]
## start_recording -> capture snapshots -> stop -> create echo -> replay
##                 -> echo interacts with world -> echo expires
## [/codeblock]
##
## It is the only thing that ticks the recorder, so a recording can never be
## advanced by two systems at once. Levels never touch the recorder directly;
## they call the small public API here.

## The active rule set. Levels may swap in a tuned or advanced variant.
var config: TemporalConfig
## Current temporal energy, in [code]0..config.energy_max[/code].
var energy: float = 0.0
## The recorder for the take in progress (never null; check [member TemporalRecorder.is_recording]).
var recorder: TemporalRecorder

## The node whose transforms are recorded. Must implement
## [code]capture_temporal_state() -> Dictionary[/code].
var _source: Node = null
## Where spawned echoes are parented (the current level root).
var _echo_container: Node = null
var _active_echoes: Array[TemporalEcho] = []
var _last_energy_signal: float = -1.0


func _ready() -> void:
	config = TemporalConfig.new()
	recorder = TemporalRecorder.new(config)
	energy = config.energy_max
	EventBus.temporal_energy_changed.emit(energy, config.energy_max)
	_last_energy_signal = energy


func _physics_process(delta: float) -> void:
	_tick_recording(delta)
	_tick_energy(delta)


# --- Wiring -----------------------------------------------------------------

## Binds the recording target. Called by the player when it enters the tree.
func register_source(node: Node) -> void:
	if node != null and not node.has_method("capture_temporal_state"):
		push_error("TemporalManager.register_source: node '%s' lacks capture_temporal_state()." % node)
		return
	_source = node


## Binds where echoes live. Called by the level when it is built.
func set_echo_container(node: Node) -> void:
	_echo_container = node


func clear_source() -> void:
	_source = null


# --- Energy -----------------------------------------------------------------

func energy_ratio() -> float:
	if config.energy_max <= 0.0:
		return 0.0
	return clampf(energy / config.energy_max, 0.0, 1.0)


func reset_energy() -> void:
	energy = config.energy_max
	_emit_energy(true)


func _tick_energy(delta: float) -> void:
	if config.energy_regen_per_second <= 0.0:
		return
	var before := energy
	energy = minf(config.energy_max, energy + config.energy_regen_per_second * delta)
	if not is_equal_approx(before, energy):
		_emit_energy(is_equal_approx(energy, config.energy_max))


func _emit_energy(force: bool) -> void:
	if force or absf(energy - _last_energy_signal) >= 0.02:
		_last_energy_signal = energy
		EventBus.temporal_energy_changed.emit(energy, config.energy_max)


# --- Recording --------------------------------------------------------------

## True when a new take may begin. Checks both the state and the energy cost.
func can_start_recording() -> bool:
	if recorder.is_recording or not is_instance_valid(_source):
		return false
	return energy + 0.0001 >= config.energy_cost_per_echo


## Begins a take. Returns [code]false[/code] (with a signal) if it is not allowed.
func start_recording() -> bool:
	if not can_start_recording():
		return false
	recorder.start()
	EventBus.recording_started.emit(config.max_recording_duration)
	EventBus.recording_progress.emit(0.0, config.max_recording_duration)
	return true


## Player-initiated end of a take. Produces an echo if the take is usable.
func stop_recording() -> void:
	if not recorder.is_recording:
		return
	recorder.stop()
	_finalize_recording()


## Abandons a take without producing an echo.
func cancel_recording(reason: String = "cancelled") -> void:
	if not recorder.is_recording:
		return
	recorder.cancel()
	EventBus.recording_cancelled.emit(reason)


## Records a gameplay event on the current frame so the echo can reproduce it.
## Silently ignored when not recording, which keeps call sites branch-free.
func record_event(event_id: StringName) -> void:
	if recorder.is_recording:
		recorder.add_event(event_id)


func _tick_recording(delta: float) -> void:
	if not recorder.is_recording:
		return
	if not is_instance_valid(_source):
		cancel_recording("source_lost")
		return

	var payload: Dictionary = _source.capture_temporal_state()
	var still_recording: bool = recorder.record(
		delta,
		payload.get("position", Vector2.ZERO),
		payload.get("rotation", 0.0),
		payload.get("velocity", Vector2.ZERO),
		payload.get("state", &"idle"),
		payload.get("facing", 1)
	)
	EventBus.recording_progress.emit(recorder.duration(), config.max_recording_duration)

	if not still_recording:
		# Either the player stopped us or the duration cap fired.
		_finalize_recording()


func _finalize_recording() -> void:
	if not recorder.has_usable_data():
		recorder.cancel()
		EventBus.recording_cancelled.emit("too_short")
		return

	var produced: TemporalEcho = spawn_echo(recorder.get_snapshots())
	if produced == null:
		recorder.cancel()
		EventBus.recording_cancelled.emit("echo_failed")
		return

	energy = maxf(0.0, energy - config.energy_cost_per_echo)
	_emit_energy(true)
	recorder.cancel()


# --- Echoes -----------------------------------------------------------------

## Instantiates an echo from a snapshot array and registers it for lifecycle
## management. Charges no energy — [method _finalize_recording] owns that.
func spawn_echo(snapshots: Array[TemporalSnapshot]) -> TemporalEcho:
	if snapshots.size() < 2:
		push_warning("TemporalManager.spawn_echo: need at least 2 snapshots.")
		return null
	if _echo_container == null or not is_instance_valid(_echo_container):
		push_error("TemporalManager.spawn_echo: no echo container set. Call set_echo_container() when building the level.")
		return null

	while _active_echoes.size() >= config.max_active_echoes and not _active_echoes.is_empty():
		_retire_echo(_active_echoes[0], "replaced")

	var echo := TemporalEcho.new()
	echo.setup(snapshots, config)
	echo.playback_finished.connect(_on_echo_finished)
	echo.event_replayed.connect(_on_echo_event)
	_echo_container.add_child(echo)
	_active_echoes.append(echo)

	EventBus.echo_created.emit(echo, snapshots[-1].time)
	return echo


func _retire_echo(echo: TemporalEcho, _reason: String) -> void:
	if not is_instance_valid(echo):
		_active_echoes.erase(echo)
		return
	_active_echoes.erase(echo)
	EventBus.echo_expired.emit(echo)
	if is_instance_valid(echo):
		echo.queue_free()


func _on_echo_finished(echo: TemporalEcho) -> void:
	_active_echoes.erase(echo)
	EventBus.echo_expired.emit(echo)


func _on_echo_event(echo: TemporalEcho, event_id: StringName) -> void:
	EventBus.echo_event_replayed.emit(echo, event_id)


## Removes every echo. Called on level restart so a replay cannot leak across
## a reset and desynchronise the puzzle state.
func clear_echoes() -> void:
	for echo: TemporalEcho in _active_echoes.duplicate():
		if is_instance_valid(echo):
			echo.queue_free()
	_active_echoes.clear()


func echo_count() -> int:
	return _active_echoes.size()


func has_active_echo() -> bool:
	return not _active_echoes.is_empty()
