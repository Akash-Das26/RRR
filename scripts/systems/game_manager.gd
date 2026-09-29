extends Node
## Autoload [code]GameManager[/code] — the shell around the game.
##
## Owns the world container, the UI layers, level load/teardown, checkpoints and
## pause. Levels themselves know nothing about progression; they only build
## geometry and props. That separation is why a level can be tested on its own.

enum State { BOOT, MENU, PLAYING, PAUSED, LEVEL_COMPLETE, DEAD }

signal state_changed(state: State)

var state: State = State.BOOT
var current_level_index: int = 0
var player: Player = null

var _world: Node2D = null
var _effects_layer: Node2D = null
var _hud_layer: CanvasLayer = null
var _menu_layer: CanvasLayer = null
var _hud: Hud = null
var _menu: MenuScreen = null

var _checkpoint_position: Vector2 = Vector2.ZERO
var _checkpoint_id: String = ""
var _level_bounds: Rect2 = Rect2(-400.0, -1200.0, 4000.0, 2000.0)
var _level_spawn: Vector2 = Vector2.ZERO
var _current_level_id: StringName = &""
var _death_timer: float = 0.0
var _pending_death_restart: bool = false


func _ready() -> void:
	# Must keep running while the tree is paused, or pause could never be undone.
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputActions.ensure_defaults()

	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	_effects_layer = Node2D.new()
	_effects_layer.name = "Echoes"
	_world.add_child(_effects_layer)

	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HudLayer"
	_hud_layer.layer = 10
	add_child(_hud_layer)

	_hud = Hud.new()
	_hud.name = "Hud"
	_hud_layer.add_child(_hud)
	_hud.hide()

	_menu_layer = CanvasLayer.new()
	_menu_layer.name = "MenuLayer"
	_menu_layer.layer = 20
	add_child(_menu_layer)

	_menu = MenuScreen.new()
	_menu.name = "Menu"
	_menu_layer.add_child(_menu)
	_menu.action_requested.connect(_on_menu_action)

	EventBus.player_died.connect(_on_player_died)
	EventBus.checkpoint_reached.connect(_on_checkpoint_reached)

	_set_state(State.MENU)
	_menu.show_title()


func _process(delta: float) -> void:
	# Falling out of the level is a death, not an endless plummet. Measured
	# against the level bounds, so every level gets it for free.
	if state == State.PLAYING and player != null and is_instance_valid(player):
		if player.global_position.y > _level_bounds.end.y + 64.0:
			player.kill()

	if not _pending_death_restart:
		return
	_death_timer -= delta
	if _death_timer <= 0.0:
		_pending_death_restart = false
		respawn_at_checkpoint()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if state == State.PLAYING:
			set_paused(true)
		elif state == State.PAUSED:
			set_paused(false)
	elif event.is_action_pressed(&"restart") and state == State.PLAYING:
		restart_level()


# --- Level lifecycle --------------------------------------------------------

func start_new_game() -> void:
	current_level_index = 0
	load_level(0)


## Loads a level by catalog index. Tears the previous level down first so no
## echo, timer or node can leak across a transition.
func load_level(index: int) -> void:
	if index < 0 or index >= LevelCatalog.count():
		push_error("GameManager.load_level: index %d is out of range (0..%d)." % [index, LevelCatalog.count() - 1])
		_menu.show_victory()
		_set_state(State.LEVEL_COMPLETE)
		return

	_teardown_level()
	get_tree().paused = false
	current_level_index = index

	var data: Dictionary = LevelCatalog.get_level(index)
	_current_level_id = StringName(data.get("id", "level_%d" % index))
	_level_bounds = data.get("bounds", _level_bounds)

	var builder := LevelBuilder.new()
	builder.name = "Level"
	_world.add_child(builder)
	var result: Dictionary = builder.build(data)

	_level_spawn = result.get("spawn", Vector2(160.0, 400.0))
	_checkpoint_position = _level_spawn
	_checkpoint_id = ""

	TemporalManager.clear_echoes()
	TemporalManager.reset_energy()
	TemporalManager.set_echo_container(builder)

	player = Player.new()
	player.name = "Player"
	builder.add_child(player)
	player.global_position = _level_spawn
	player.set_camera_limits(_level_bounds)

	_hud.bind_player(player)
	_hud.show()

	_menu.hide_all()
	_set_state(State.PLAYING)
	EventBus.level_started.emit(_current_level_id, String(data.get("title", "")))
	EventBus.objective_changed.emit(String(data.get("objective", "")))


func restart_level() -> void:
	load_level(current_level_index)


## Hard reset back to the last checkpoint (or the level start).
func respawn_at_checkpoint() -> void:
	if player == null or not is_instance_valid(player):
		restart_level()
		return
	TemporalManager.cancel_recording("respawn")
	TemporalManager.clear_echoes()
	TemporalManager.reset_energy()
	player.respawn(_checkpoint_position)
	get_tree().paused = false
	_menu.hide_all()
	_set_state(State.PLAYING)


func register_checkpoint(checkpoint_id: String, position: Vector2) -> void:
	# Checkpoints are sticky: revisiting an earlier one must not move the
	# respawn point backwards past a later one.
	if checkpoint_id == _checkpoint_id:
		return
	_checkpoint_id = checkpoint_id
	_checkpoint_position = position
	EventBus.checkpoint_reached.emit(StringName(checkpoint_id))


func complete_level() -> void:
	if state != State.PLAYING:
		return
	TemporalManager.cancel_recording("level_complete")
	TemporalManager.clear_echoes()
	_hud.hide()
	_set_state(State.LEVEL_COMPLETE)
	EventBus.level_completed.emit(_current_level_id)

	if current_level_index + 1 < LevelCatalog.count():
		_menu.show_level_complete(LevelCatalog.get_level(current_level_index + 1).get("title", ""))
	else:
		_menu.show_victory()


func return_to_menu() -> void:
	_teardown_level()
	get_tree().paused = false
	_hud.hide()
	_set_state(State.MENU)
	_menu.show_title()


func _teardown_level() -> void:
	TemporalManager.cancel_recording("teardown")
	TemporalManager.clear_echoes()
	TemporalManager.clear_source()
	TemporalManager.set_echo_container(null)
	player = null
	_checkpoint_id = ""
	if _hud != null:
		_hud.bind_player(null)
	# Freeing the level root frees every child level node with it.
	if _world != null:
		_world.queue_free()
		_world = Node2D.new()
		_world.name = "World"
		add_child(_world)
		_effects_layer = Node2D.new()
		_effects_layer.name = "Echoes"
		_world.add_child(_effects_layer)


# --- Pause ------------------------------------------------------------------

func set_paused(paused: bool) -> void:
	if paused and state != State.PLAYING:
		return
	get_tree().paused = paused
	if paused:
		_set_state(State.PAUSED)
		_menu.show_pause()
	else:
		_set_state(State.PLAYING)
		_menu.hide_all()
	EventBus.game_paused.emit(paused)


# --- Signals ----------------------------------------------------------------

func _on_player_died() -> void:
	if state != State.PLAYING:
		return
	_set_state(State.DEAD)
	TemporalManager.clear_echoes()
	# A short beat before the retry prompt, so the death reads.
	_pending_death_restart = true
	_death_timer = 1.1


func _on_checkpoint_reached(checkpoint_id: StringName) -> void:
	if _hud != null:
		_hud.flash_checkpoint("CHECKPOINT — %s" % String(checkpoint_id).to_upper())


func _on_menu_action(action: StringName) -> void:
	match action:
		&"start":
			start_new_game()
		&"resume":
			set_paused(false)
		&"restart_level":
			restart_level()
		&"restart_checkpoint":
			respawn_at_checkpoint()
		&"next_level":
			load_level(current_level_index + 1)
		&"menu":
			return_to_menu()
		&"quit":
			get_tree().quit()
		_:
			push_warning("GameManager: unhandled menu action '%s'." % action)


func _set_state(next: State) -> void:
	state = next
	state_changed.emit(state)
