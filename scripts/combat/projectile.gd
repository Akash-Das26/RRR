class_name Projectile
extends Area2D
## A temporal bolt fired by ranged enemies.
##
## Implemented as an [Area2D] rather than a physics body for two reasons: it must
## pass over level geometry instead of being stopped dead by a lip in the floor,
## and it must never push the player around — only damage them.
##
## It is still stopped by *solid* geometry via [signal Area2D.body_entered], so a
## bolt cannot tunnel through a wall to reach the player behind it.

const RADIUS: float = 6.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 320.0
var damage: int = 9
var lifetime: float = 4.0

var _age: float = 0.0
var _spent: bool = false


## Must be called before the node enters the tree.
func configure(p_direction: Vector2, p_speed: float, p_damage: int, p_lifetime: float = 4.0) -> void:
	direction = p_direction.normalized()
	speed = p_speed
	damage = p_damage
	lifetime = p_lifetime


func _ready() -> void:
	collision_layer = GameLayers.HAZARD
	# Seeks the player's hurtbox, and also notices world geometry so it expires
	# on contact with a wall rather than phasing through it.
	collision_mask = GameLayers.PLAYER_HURTBOX | GameLayers.WORLD
	monitoring = true
	monitorable = false
	z_index = 12

	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	collision.shape = circle
	add_child(collision)

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_age += delta
	if _age >= lifetime:
		_despawn()
		return
	position += direction * speed * delta


func _on_area_entered(area: Area2D) -> void:
	if _spent or area is not Hurtbox:
		return
	# Only consumed if the hit actually landed; i-frames should not eat the bolt.
	if (area as Hurtbox).receive_hit(damage, 0.0, global_position):
		_despawn()


func _on_body_entered(_body: Node2D) -> void:
	_despawn()


func _despawn() -> void:
	if _spent:
		return
	_spent = true
	# Disabled immediately so a bolt queued for deletion cannot land this frame.
	set_deferred("monitoring", false)
	queue_free()


func _draw() -> void:
	# A stretched temporal shard, oriented along its flight path.
	var tail := -direction * 16.0
	draw_line(tail, direction * 5.0, Color(Palette.TEMPORAL_DEEP.r, Palette.TEMPORAL_DEEP.g, Palette.TEMPORAL_DEEP.b, 0.55), 4.0)
	draw_line(tail * 0.6, direction * 6.0, Color(Palette.TEMPORAL_GLOW.r, Palette.TEMPORAL_GLOW.g, Palette.TEMPORAL_GLOW.b, 0.85), 2.5)
	draw_circle(Vector2.ZERO, RADIUS * 1.7, Color(Palette.TEMPORAL_GLOW.r, Palette.TEMPORAL_GLOW.g, Palette.TEMPORAL_GLOW.b, 0.18))
	draw_circle(Vector2.ZERO, RADIUS, Palette.TEMPORAL_CORE)
