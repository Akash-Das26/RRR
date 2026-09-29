class_name Hud
extends Control
## The in-game heads-up display.
##
## Reads exclusively from [EventBus] and never queries gameplay nodes, so the HUD
## cannot accidentally become a dependency of the systems it reports on. The one
## exception is [method bind_player], used only to render the player-bound
## recording meter position; it is cleared on teardown.

const BAR_WIDTH: float = 246.0
const BAR_HEIGHT: float = 20.0
const NOTICE_DURATION: float = 2.2

var _health_fill: ColorRect
var _health_label: Label
var _energy_fill: ColorRect
var _energy_label: Label
var _objective_label: Label
var _record_track: ColorRect
var _record_fill: ColorRect
var _record_label: Label
var _echo_label: Label
var _notice: Label
var _notice_left: float = 0.0
var _echo_count: int = 0
var _player: Player = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

	EventBus.health_changed.connect(_on_health_changed)
	EventBus.temporal_energy_changed.connect(_on_energy_changed)
	EventBus.objective_changed.connect(_on_objective_changed)
	EventBus.recording_started.connect(_on_recording_started)
	EventBus.recording_progress.connect(_on_recording_progress)
	EventBus.recording_cancelled.connect(_on_recording_cancelled)
	EventBus.echo_created.connect(_on_echo_created)
	EventBus.echo_expired.connect(_on_echo_expired)

	_set_record_visible(false)


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left = maxf(0.0, _notice_left - delta)
		_notice.modulate.a = clampf(_notice_left / NOTICE_DURATION, 0.0, 1.0)


func bind_player(player: Player) -> void:
	_player = player


# --- Construction -----------------------------------------------------------

func _build() -> void:
	_health_label = _make_label(Vector2(28.0, 20.0), "HP", Palette.UI_DIM, 14)
	_make_panel(Vector2(28.0, 40.0), Vector2(BAR_WIDTH, BAR_HEIGHT), Palette.UI_PANEL)
	_health_fill = _make_fill(Vector2(28.0, 40.0), Vector2(BAR_WIDTH, BAR_HEIGHT), Palette.UI_HEALTH)

	_energy_label = _make_label(Vector2(0.0, 20.0), "TEMPORAL ENERGY", Palette.UI_DIM, 14)
	_energy_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_energy_label.position = Vector2(-28.0 - BAR_WIDTH, 20.0)
	_make_panel(Vector2(-28.0 - BAR_WIDTH, 40.0), Vector2(BAR_WIDTH, BAR_HEIGHT), Palette.UI_PANEL, true)
	_energy_fill = _make_fill(Vector2(-28.0 - BAR_WIDTH, 40.0), Vector2(BAR_WIDTH, BAR_HEIGHT), Palette.UI_ACCENT, true)

	_objective_label = _make_label(Vector2(0.0, 88.0), "", Palette.UI_TEXT, 18)
	_objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.custom_minimum_size = Vector2(900.0, 0.0)
	_objective_label.position = Vector2(-450.0, 88.0)

	_echo_label = _make_label(Vector2(28.0, 70.0), "", Palette.UI_ACCENT, 14)

	# Recording meter sits low-centre so it does not fight the health bar.
	_record_track = _make_panel(Vector2(-160.0, -60.0), Vector2(320.0, 14.0), Palette.UI_PANEL, false, true)
	_record_fill = _make_fill(Vector2(-160.0, -60.0), Vector2(320.0, 14.0), Palette.TEMPORAL_GLOW, false, true)
	_record_label = _make_label(Vector2(-160.0, -84.0), "RECORDING", Palette.TEMPORAL_CORE, 15, true)

	_notice = _make_label(Vector2(0.0, -150.0), "", Palette.UI_WARN, 20, true)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.custom_minimum_size = Vector2(900.0, 0.0)
	_notice.position = Vector2(-450.0, -150.0)
	_notice.modulate.a = 0.0


func _make_label(at: Vector2, text: String, color: Color, size: int, centered_bottom: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not centered_bottom:
		label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(label)
	return label


func _make_panel(at: Vector2, size: Vector2, color: Color, right_anchored: bool = false, bottom_anchored: bool = false) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.size = size
	rect.position = at
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if right_anchored:
		rect.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	if bottom_anchored:
		rect.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	add_child(rect)
	return rect


func _make_fill(at: Vector2, size: Vector2, color: Color, right_anchored: bool = false, bottom_anchored: bool = false) -> ColorRect:
	var rect := _make_panel(at, size, color, right_anchored, bottom_anchored)
	# Inset by one pixel so the panel behind reads as a frame.
	rect.position = at + Vector2(1.0, 1.0)
	rect.size = size - Vector2(2.0, 2.0)
	return rect


# --- Events -----------------------------------------------------------------

func _on_health_changed(current: int, maximum: int) -> void:
	var ratio: float = 0.0 if maximum <= 0 else clampf(float(current) / float(maximum), 0.0, 1.0)
	_health_fill.size = Vector2(maxf(0.0, (BAR_WIDTH - 2.0) * ratio), BAR_HEIGHT - 2.0)
	_health_fill.color = Palette.UI_HEALTH if ratio > 0.3 else Palette.UI_WARN
	_health_label.text = "HP  %d / %d" % [current, maximum]


func _on_energy_changed(current: float, maximum: float) -> void:
	var ratio: float = 0.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)
	_energy_fill.size = Vector2(maxf(0.0, (BAR_WIDTH - 2.0) * ratio), BAR_HEIGHT - 2.0)
	_energy_label.text = "TEMPORAL ENERGY  %d / %d" % [roundi(current), roundi(maximum)]


func _on_objective_changed(text: String) -> void:
	_objective_label.text = text
	if not text.is_empty():
		flash_notice(text, 2.8)


func _on_recording_started(max_duration: float) -> void:
	_set_record_visible(true)
	_record_label.text = "RECORDING  —  press Q to place the echo   (%.0fs max)" % max_duration
	_record_fill.size = Vector2(0.0, _record_fill.size.y)


func _on_recording_progress(elapsed: float, max_duration: float) -> void:
	if not _record_track.visible:
		return
	var ratio: float = 0.0 if max_duration <= 0.0 else clampf(elapsed / max_duration, 0.0, 1.0)
	_record_fill.size = Vector2(maxf(0.0, 318.0 * ratio), _record_fill.size.y)
	# Turns red as the cap approaches so a lost take is never a surprise.
	_record_fill.color = Palette.UI_WARN if ratio > 0.85 else Palette.TEMPORAL_GLOW


func _on_recording_cancelled(reason: String) -> void:
	_set_record_visible(false)
	if reason == "too_short":
		flash_notice("Recording too short — hold the moment longer.", 1.8)


func _on_echo_created(_echo: Node, recorded_duration: float) -> void:
	_set_record_visible(false)
	_echo_count += 1
	_refresh_echo_label()
	flash_notice("ECHO RELEASED  (%.1fs of memory)" % recorded_duration, 1.6)


func _on_echo_expired(_echo: Node) -> void:
	# Tracked locally so the HUD stays event-driven instead of polling the
	# manager every frame.
	_echo_count = maxi(0, _echo_count - 1)
	_refresh_echo_label()


func _refresh_echo_label() -> void:
	_echo_label.text = "" if _echo_count <= 0 else "ECHOES ACTIVE  %d" % _echo_count


func _set_record_visible(visible_now: bool) -> void:
	_record_track.visible = visible_now
	_record_fill.visible = visible_now
	_record_label.visible = visible_now


func flash_notice(text: String, duration: float = NOTICE_DURATION) -> void:
	_notice.text = text
	_notice.modulate.a = 1.0
	_notice_left = duration


func flash_checkpoint(text: String) -> void:
	flash_notice(text, 2.0)
