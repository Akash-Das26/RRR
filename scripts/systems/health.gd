class_name Health
extends Node
## A drop-in health pool. Attach as a child of anything that can be hurt.
##
## Owning a component instead of extending a base class means the player, every
## enemy and any destructible prop share one damage model, and a new enemy gets
## correct damage/i-frames without writing combat code.

signal changed(current: int, maximum: int)
signal damaged(amount: int, current: int)
signal healed(amount: int, current: int)
signal died

@export var max_health: int = 100
## Seconds of immunity after taking a hit. Keeps a single swing from landing
## twice and stops contact damage from shredding the player.
@export_range(0.0, 3.0, 0.05) var invulnerability_time: float = 0.6

var current: int = 0
var is_dead: bool = false

var _invulnerable_left: float = 0.0


func _ready() -> void:
	current = max_health
	changed.emit(current, max_health)


func _process(delta: float) -> void:
	# _process is enough: nothing reads invulnerability from physics.
	if _invulnerable_left > 0.0:
		_invulnerable_left = maxf(0.0, _invulnerable_left - delta)


## Applies damage. Returns [code]true[/code] if the hit actually landed, so the
## attacker can decide whether to play a hit effect.
func take_damage(amount: int, _source: Node = null) -> bool:
	if is_dead or amount <= 0 or is_invulnerable():
		return false

	current = maxi(0, current - amount)
	_invulnerable_left = invulnerability_time
	damaged.emit(amount, current)
	changed.emit(current, max_health)

	if current == 0:
		is_dead = true
		died.emit()
	return true


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	var before := current
	current = mini(max_health, current + amount)
	if current != before:
		healed.emit(current - before, current)
		changed.emit(current, max_health)


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


## Forces death regardless of i-frames. Used for pits and scripted deaths,
## where "the player was mid-dodge" must not save them.
func kill() -> void:
	if is_dead:
		return
	current = 0
	is_dead = true
	_invulnerable_left = 0.0
	changed.emit(current, max_health)
	died.emit()


## Grants temporary immunity on top of any already running window.
## Used by dodge rolls and scripted sequences.
func grant_invulnerability(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)


func health_ratio() -> float:
	if max_health <= 0:
		return 0.0
	return float(current) / float(max_health)


## Full reset, used on checkpoint respawn and level reload.
func reset() -> void:
	is_dead = false
	_invulnerable_left = 0.0
	current = max_health
	changed.emit(current, max_health)
