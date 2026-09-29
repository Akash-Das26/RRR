class_name AttackState
extends PlayerState
## Light and heavy strikes, modelled as three timed phases.
##
## Splitting windup / active / recovery is not decoration: the [Hitbox] is only
## enabled during the active window, so an enemy cannot be hit by a swing that
## has not visually happened yet, and combat keeps a readable rhythm.

const LIGHT_WINDUP: float = 0.09
const LIGHT_ACTIVE: float = 0.11
const LIGHT_RECOVERY: float = 0.13
const LIGHT_STEP: float = 95.0

const HEAVY_WINDUP: float = 0.20
const HEAVY_ACTIVE: float = 0.15
const HEAVY_RECOVERY: float = 0.22
const HEAVY_STEP: float = 160.0
const HEAVY_KNOCKBACK: float = 340.0
const LIGHT_KNOCKBACK: float = 200.0

var _heavy: bool = false
var _windup: float = 0.0
var _active: float = 0.0
var _recovery: float = 0.0
var _step: float = 0.0


func _init() -> void:
	name = &"attack"


func enter() -> void:
	_heavy = player.consume_attack() == Player.ATTACK_HEAVY
	if _heavy:
		_windup = HEAVY_WINDUP
		_active = HEAVY_ACTIVE
		_recovery = HEAVY_RECOVERY
		_step = HEAVY_STEP
		player.set_hitbox_damage(player.heavy_attack_damage)
		player.set_hitbox_knockback(HEAVY_KNOCKBACK)
	else:
		_windup = LIGHT_WINDUP
		_active = LIGHT_ACTIVE
		_recovery = LIGHT_RECOVERY
		_step = LIGHT_STEP
		player.set_hitbox_damage(player.light_attack_damage)
		player.set_hitbox_knockback(LIGHT_KNOCKBACK)
	player.set_hitbox_active(false)


func exit() -> void:
	player.set_hitbox_active(false)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)

	var elapsed := machine.time_in_current()
	# A short forward lunge commits the strike without handing back full control.
	var lunge: float = _step if elapsed < _windup + _active * 0.5 else 0.0
	player.velocity.x = move_toward(player.velocity.x, float(player.facing) * lunge, 1000.0 * delta)
	player.commit_motion()

	var in_active_window: bool = elapsed >= _windup and elapsed < _windup + _active
	player.set_hitbox_active(in_active_window)

	if elapsed >= _windup + _active + _recovery:
		player.set_hitbox_active(false)
		if not player.is_on_floor():
			machine.transition_to(&"fall")
		else:
			machine.transition_to(&"run" if absf(player.move_axis()) > 0.01 else &"idle")


func is_heavy() -> bool:
	return _heavy
