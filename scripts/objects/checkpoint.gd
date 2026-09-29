class_name Checkpoint
extends Area2D
## Records where the player will respawn after death.
##
## Polls overlaps rather than relying on [signal Area2D.body_entered] alone: a
## player who is *already* standing in a checkpoint when a level loads (or who is
## respawned on top of one) must still register it.

@export var checkpoint_id: String = "cp_0"
@export var checkpoint_size: Vector2 = Vector2(56.0, 96.0)

var _claimed: bool = false


func configure(p_id: String, p_size: Vector2 = Vector2(56.0, 96.0)) -> void:
	checkpoint_id = p_id
	checkpoint_size = p_size
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
	rectangle.size = checkpoint_size
	collision.shape = rectangle
	collision.position = Vector2(0, -checkpoint_size.y * 0.5)
	add_child(collision)
	z_index = 3


func _physics_process(_delta: float) -> void:
	if _claimed:
		return
	for body: Node2D in get_overlapping_bodies():
		if body is Player:
			_claim(body as Player)
			return


func _claim(player: Player) -> void:
	_claimed = true
	GameManager.register_checkpoint(checkpoint_id, player.global_position)
	queue_redraw()


func _draw() -> void:
	var half := checkpoint_size * 0.5
	var glow: Color = Palette.TEMPORAL_CORE if _claimed else Palette.TEMPORAL_GLOW
	var pulse: float = 0.4 if _claimed else 0.25 + 0.15 * sin(Time.get_ticks_msec() * 0.003)

	# Braziers flanking a floor band make the checkpoint readable at a glance.
	draw_rect(Rect2(-half.x, -6.0, checkpoint_size.x, 6.0), Color(glow.r, glow.g, glow.b, 0.35 + pulse))
	for sign_x: float in [-half.x + 6.0, half.x - 6.0]:
		draw_rect(Rect2(sign_x - 3.0, -40.0, 6.0, 34.0), Palette.STONE_SHADE)
		draw_circle(Vector2(sign_x, -44.0), 6.0, Color(glow.r, glow.g, glow.b, 0.55 + pulse))
		draw_circle(Vector2(sign_x, -44.0), 12.0, Color(glow.r, glow.g, glow.b, 0.16 + pulse * 0.4))
