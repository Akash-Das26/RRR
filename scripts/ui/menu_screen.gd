class_name MenuScreen
extends Control
## One screen that serves the title, pause, level-complete and victory states.
##
## Rather than four near-identical scenes, each state is just a title, a body
## line and a list of buttons. Buttons are rebuilt per state, so there is no way
## for a stale button from a previous screen to remain clickable.

## Emitted with one of the action ids that [GameManager] handles.
signal action_requested(action: StringName)

const PANEL_SIZE: Vector2 = Vector2(560.0, 420.0)

var _panel: ColorRect
var _title: Label
var _body: Label
var _buttons: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	hide_all()


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.015, 0.04, 0.82)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	_panel = ColorRect.new()
	_panel.color = Palette.UI_PANEL
	_panel.size = PANEL_SIZE
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = -PANEL_SIZE * 0.5
	add_child(_panel)

	_title = Label.new()
	_title.position = Vector2(36.0, 40.0)
	_title.custom_minimum_size = Vector2(PANEL_SIZE.x - 72.0, 0.0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Palette.TEMPORAL_CORE)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_title)

	_body = Label.new()
	_body.position = Vector2(36.0, 150.0)
	_body.custom_minimum_size = Vector2(PANEL_SIZE.x - 72.0, 0.0)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_font_size_override("font_size", 17)
	_body.add_theme_color_override("font_color", Palette.UI_DIM)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_body)

	_buttons = VBoxContainer.new()
	_buttons.position = Vector2(150.0, 250.0)
	_buttons.custom_minimum_size = Vector2(PANEL_SIZE.x - 300.0, 0.0)
	_buttons.add_theme_constant_override("separation", 10)
	_panel.add_child(_buttons)


# --- Public screens ---------------------------------------------------------

func show_title() -> void:
	show_all()
	_title.text = "PRINCE OF PERSIA\nECHOES OF TIME"
	_body.text = "\"Master your past to survive your present.\"\n\n[WASD / Arrows] move    [Space] jump    [J] light    [K] heavy\n[L] block   [Shift] dodge   [E] interact   [Q] record / release echo\n\nRRR — Rewind. Reimagine. Reconnect."
	_set_buttons([
		["Begin the descent", &"start"],
		["Quit", &"quit"],
	])


func show_pause() -> void:
	show_all()
	_title.text = "PAUSED"
	_body.text = "The palace waits between moments."
	_set_buttons([
		["Resume", &"resume"],
		["Restart checkpoint", &"restart_checkpoint"],
		["Restart level", &"restart_level"],
		["Abandon to menu", &"menu"],
	])


func show_level_complete(next_title: String) -> void:
	show_all()
	_title.text = "THE MOMENT HOLDS"
	_body.text = "Level cleared.\nNext: %s" % next_title
	_set_buttons([
		["Continue", &"next_level"],
		["Replay this level", &"restart_level"],
		["Abandon to menu", &"menu"],
	])


func show_victory() -> void:
	show_all()
	_title.text = "THE PALACE REMEMBERS"
	_body.text = "You mastered your past and survived your present.\n\nThank you for playing Echoes of Time."
	_set_buttons([
		["Play again", &"start"],
		["Quit", &"quit"],
	])


func show_all() -> void:
	visible = true


func hide_all() -> void:
	visible = false


# --- Internals --------------------------------------------------------------

func _set_buttons(entries: Array) -> void:
	for child: Node in _buttons.get_children():
		child.queue_free()
	for entry: Array in entries:
		var button := Button.new()
		button.text = String(entry[0])
		button.add_theme_font_size_override("font_size", 17)
		var action := StringName(entry[1])
		button.pressed.connect(func() -> void: action_requested.emit(action))
		_buttons.add_child(button)

	# Focus the first button so the menu is keyboard-navigable immediately.
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus()
