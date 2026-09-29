class_name Hurtbox
extends Area2D
## The passive half of a strike: an area other things can hit.
##
## A hurtbox never seeks anything out ([code]monitoring = false[/code]); it is
## purely [code]monitorable[/code] so an attacker's [Hitbox] can find it. This
## one-way relationship is what stops both sides of a fight from detecting each
## other and double-resolving the same swing.

## Emitted only when the hit actually landed (i-frames respected).
signal hit_taken(amount: int, source_position: Vector2)

var health: Health = null

## Optional damage modulator, used for directional blocking.
## Expected signature: [code]func(amount: int, source_position: Vector2) -> int[/code].
## Return a scaled amount, or 0 to nullify the hit entirely.
var damage_filter: Callable = Callable()


## Wires the receiver up. [param layer_bit] must be one of the
## [code]*_HURTBOX[/code] constants in [GameLayers].
func configure(p_health: Health, layer_bit: int, shape_size: Vector2, shape_offset: Vector2 = Vector2.ZERO) -> void:
	health = p_health
	collision_layer = layer_bit
	collision_mask = 0
	monitoring = false
	monitorable = true

	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = shape_size
	collision.shape = rectangle
	collision.position = shape_offset
	add_child(collision)


## Called by an attacker's hitbox. Returns whether the damage connected.
func receive_hit(amount: int, _knockback: float, source_position: Vector2) -> bool:
	if health == null:
		push_warning("Hurtbox %s received a hit but has no Health configured." % name)
		return false

	var final_amount := amount
	if damage_filter.is_valid():
		final_amount = int(damage_filter.call(amount, source_position))
	if final_amount <= 0:
		return false

	if not health.take_damage(final_amount, self):
		return false
	hit_taken.emit(final_amount, source_position)
	return true
