class_name Hitbox
extends Area2D
## The active half of a strike: enabled only during an attack's live frames.
##
## Detection uses a per-swing "already hit" set rather than [signal Area2D.area_entered]
## alone. That is deliberate: an area entered mid-swing (an enemy walking into a
## strike already in progress) still takes the hit, and one swing can never
## damage the same target twice.

var damage: int = 10
var knockback: float = 220.0

var _active: bool = false
var _already_hit: Dictionary = {}


func configure(layer_bit: int, target_mask: int, shape_size: Vector2, shape_offset: Vector2 = Vector2.ZERO) -> void:
	collision_layer = layer_bit
	collision_mask = target_mask
	monitoring = false
	monitorable = false

	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = shape_size
	collision.shape = rectangle
	collision.position = shape_offset
	add_child(collision)


## Turns the strike on or off. Each activation is a fresh swing, so the
## "already hit" set is cleared on enable.
func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	_already_hit.clear()
	set_deferred("monitoring", active)


func is_active() -> bool:
	return _active


func _physics_process(_delta: float) -> void:
	if not _active:
		return
	for area: Area2D in get_overlapping_areas():
		if area is not Hurtbox:
			continue
		if _already_hit.has(area):
			continue
		var hurtbox := area as Hurtbox
		if hurtbox.health == null or hurtbox.health.is_dead:
			continue
		_already_hit[area] = true
		hurtbox.receive_hit(damage, knockback, global_position)
