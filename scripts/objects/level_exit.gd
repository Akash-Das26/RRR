class_name LevelExit
extends Area2D
## The goal of a level. Entering it asks [GameManager] to advance.
##
## Guarded by a one-shot flag: without it a player resting on the goal would
## queue a level transition every physics frame.

@export var exit_size: Vector2 = Vector2(64.0, 140.0)
@export var label: String = "EXIT"

var _triggered: bool = false


func configure(p_size: Vector2 = Vector2(64.0, 140.0)) -> void:
	exit_size = p_size
	if get_child_count() == 0:
		_build()


func _ready() -> void:
	if get_child_count() == 0:
		_build()


func _build() -> void:
	collision_layer = 0
	collision_mask = GameLayers.PLAYER_BODY
	monitoring = true
	monitorable = false

	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = exit_size
	collision.shape = rectangle
	collision.position = Vector2(0, -exit_size.y * 0.5)
	add_child(collision)
	z_index = 4


func _physics_process(_delta: float) -> void:
	if _triggered:
		return
	for body: Node2D in get_overlapping_bodies():
		if body is Player:
			_triggered = true
			GameManager.complete_level()
			return


func _draw() -> void:
	var half := exit_size * 0.5
	var pulse: float = 0.5 + 0.35 * sin(Time.get_ticks_msec() * 0.0035)

	# A doorway of light: the level's temporal exit.
	draw_rect(Rect2(-half.x, -exit_size.y, exit_size.x, exit_size.y), Color(Palette.TEMPORAL_DEEP.r, Palette.TEMPORAL_DEEP.g, Palette.TEMPORAL_DEEP.b, 0.22))
	for i: int in 5:
		var t := float(i) / 4.0
		draw_rect(
			Rect2(-half.x + exit_size.x * t, -exit_size.y + 8.0, 2.0, exit_size.y - 16.0),
			Color(Palette.TEMPORAL_CORE.r, Palette.TEMPORAL_CORE.g, Palette.TEMPORAL_CORE.b, 0.10 + 0.25 * pulse)
		)
	draw_arc(Vector2(0, -half.y), half.x, 0.0, TAU, 28, Color(Palette.TEMPORAL_CORE.r, Palette.TEMPORAL_CORE.g, Palette.TEMPORAL_CORE.b, 0.7), 2.0, true)
