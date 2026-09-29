class_name Ladder
extends Area2D
## A climbable volume (rope, stair shaft, collapsed pillar).
##
## The player finds these through its interact detector and checks the
## [member is_climbable] flag, so any future climbable prop only has to expose
## the same property to work with [ClimbState].

## Read by [method Player.current_ladder]. Do not rename without updating it.
var is_climbable: bool = true

@export var ladder_size: Vector2 = Vector2(40.0, 150.0) ## Size of the climb volume.


func configure(p_size: Vector2) -> void:
	ladder_size = p_size
	if get_child_count() == 0:
		_build()


func _ready() -> void:
	if get_child_count() == 0:
		_build()


func _build() -> void:
	collision_layer = GameLayers.INTERACTABLE
	collision_mask = 0
	monitoring = false
	monitorable = true

	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = ladder_size
	collision.shape = rectangle
	collision.position = Vector2(0, -ladder_size.y * 0.5)
	add_child(collision)
	z_index = 1


func _draw() -> void:
	var half := ladder_size * 0.5
	draw_rect(Rect2(-half.x, -ladder_size.y, ladder_size.x, ladder_size.y), Color(Palette.STONE_DEEP.r, Palette.STONE_DEEP.g, Palette.STONE_DEEP.b, 0.55))
	for rail_x: float in [-half.x + 5.0, half.x - 5.0]:
		draw_line(Vector2(rail_x, 0), Vector2(rail_x, -ladder_size.y), Palette.STONE_LIGHT, 3.0)
	var rungs := int(maxf(2.0, floor(ladder_size.y / 18.0)))
	for i: int in rungs:
		var y := -ladder_size.y + 12.0 + float(i) * 18.0
		if y < -6.0:
			draw_line(Vector2(-half.x + 5.0, y), Vector2(half.x - 5.0, y), Palette.STONE_BASE, 2.0)
