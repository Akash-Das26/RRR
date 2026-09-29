class_name EnemyStats
extends Resource
## Every tunable number for one enemy archetype.
##
## Keeping stats in a [Resource] rather than in code means a new enemy variant is
## a data change, and a designer can retune a guard's aggression without reading
## the AI. [EnemyBase] supplies a sensible default so a subclass only has to
## override what makes it distinct.

@export_group("Identity")
@export var display_name: String = "Enemy"
@export var body_size: Vector2 = Vector2(20.0, 46.0)
## When false the enemy hovers and ignores gravity (used by the Shadow Echo).
@export var uses_gravity: bool = true

@export_group("Vitals")
@export var max_health: int = 60

@export_group("Movement")
@export var patrol_speed: float = 80.0
@export var chase_speed: float = 150.0
## How far from its spawn point the enemy will wander before turning back.
@export var patrol_distance: float = 120.0

@export_group("Senses")
@export var detection_radius: float = 280.0
## Enemies give up and return to patrol beyond this distance.
@export var disengage_radius: float = 420.0

@export_group("Attack")
@export var attack_range: float = 50.0
@export var attack_windup: float = 0.34
@export var attack_active: float = 0.12
@export var attack_recovery: float = 0.40
@export var attack_damage: int = 14
@export var attack_knockback: float = 250.0

@export_group("Reactions")
@export var hurt_duration: float = 0.24
@export var hurt_knockback: float = 220.0
## Seconds the corpse lingers (fading) before being removed.
@export var death_fade: float = 0.8


## Total length of one attack animation.
func attack_total_time() -> float:
	return attack_windup + attack_active + attack_recovery
