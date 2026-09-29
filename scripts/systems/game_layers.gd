class_name GameLayers
extends RefCounted
## Central definition of every 2D physics layer used by the game.
##
## These constants mirror the layer names declared in [code]project.godot[/code]
## ([code]layer_1[/code] = [constant WORLD], [code]layer_2[/code] = [constant PLAYER_BODY], ...).
## Scenes and code must use these constants instead of raw integers so that the
## layer assignments cannot silently drift apart.
##
## A collision "mask" answers "what do I want to detect?" and a "layer" answers
## "what am I?". Keeping both explicit is what makes the Temporal Echo able to
## trigger pressure plates without colliding with walls.

const WORLD: int = 1 << 0          ## Static level geometry.
const PLAYER_BODY: int = 1 << 1    ## The present-day player's body.
const ENEMY_BODY: int = 1 << 2     ## Enemy bodies (they collide with WORLD only).
const ECHO_BODY: int = 1 << 3      ## Temporal Echo bodies. Never collide, only detectable.
const PLAYER_HITBOX: int = 1 << 4  ## Offensive areas owned by the player.
const PLAYER_HURTBOX: int = 1 << 5 ## Defensive area owned by the player.
const ENEMY_HITBOX: int = 1 << 6   ## Offensive areas owned by enemies.
const ENEMY_HURTBOX: int = 1 << 7  ## Defensive areas owned by enemies.
const INTERACTABLE: int = 1 << 8   ## Switches, levers and other usable props.
const HAZARD: int = 1 << 9         ## Traps and environmental damage sources.

## Everything the ground/geometry layer must stop.
const SOLID_BODIES: int = PLAYER_BODY | ENEMY_BODY

## Anything an interactable pressure plate or trigger should notice.
const TRIGGER_ACTORS: int = PLAYER_BODY | ECHO_BODY

## What a player weapon swing looks for.
const PLAYER_ATTACK_TARGETS: int = ENEMY_HURTBOX

## What an enemy weapon swing looks for.
##
## Only ever a [Hurtbox]: an echo has no [Health], so it cannot be damaged. An
## enemy striking at an echo simply swings through it, which is exactly the
## behaviour "distract the guard with your past" should have.
const ENEMY_ATTACK_TARGETS: int = PLAYER_HURTBOX
