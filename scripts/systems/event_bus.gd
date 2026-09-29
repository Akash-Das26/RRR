extends Node
## Global, read-only signal hub (autoload: [code]EventBus[/code]).
##
## Systems publish here instead of holding references to each other. This keeps
## the HUD, the TemporalManager and the level scripts decoupled: the HUD never
## needs to know a [Player] exists, it only listens for [signal health_changed].
##
## Rule: this node stores no state and contains no logic beyond relaying.

# --- Player -----------------------------------------------------------------
signal health_changed(current: int, maximum: int)
signal player_damaged(amount: int, source: Node)
signal player_died
signal player_spawned(player: Node)

# --- Temporal Echo ----------------------------------------------------------
signal temporal_energy_changed(current: float, maximum: float)
signal recording_started(max_duration: float)
signal recording_progress(elapsed: float, max_duration: float)
signal recording_cancelled(reason: String)
signal echo_created(echo: Node, recorded_duration: float)
signal echo_expired(echo: Node)
signal echo_event_replayed(echo: Node, event_id: StringName)

# --- World / progression ----------------------------------------------------
signal objective_changed(text: String)
signal checkpoint_reached(checkpoint_id: StringName)
signal level_started(level_id: StringName, title: String)
signal level_completed(level_id: StringName)
signal game_paused(is_paused: bool)
