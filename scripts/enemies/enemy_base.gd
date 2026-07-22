class_name EnemyBase
extends Node2D

signal died(enemy: EnemyBase, experience_value: int)
signal projectile_requested(origin: Vector2, direction: Vector2, damage: float)
signal spell_requested(spell_kind: StringName, origin: Vector2, direction: Vector2, damage: float)

## Позиция врага в общей логической системе координат мира.
var world_position := Vector2.ZERO
## Типизированная цель гарантирует доступ к позиции, радиусу, здоровью и take_damage().
var player: PlayerHero
## Идентификатор вида врага из GameIds используется фабрикой, волнами и обработкой босса.
var enemy_kind: StringName = GameIds.ENEMY_BASE
var definition: EnemyDefinition
var world_config: WorldConfig
var world_state: WorldState
## Размер модели в VisualRoot; изменение не влияет на попадания.
var visual_radius := 24.0
## Радиус world-space Hurtbox для меча, магии и снарядов.
var collision_radius := 24.0
var max_health := 70.0
var health := 70.0
## Скорость в мировых координатах за секунду.
var move_speed := 72.0
## Базовый урон собственной атаки врага.
var contact_damage := 12.0
## Опыт, выпадающий после смерти обычного врага.
var experience_value := 18
var is_elite := false
var _elite_modifiers_applied := false
var hit_flash := 0.0
var is_alive := true
var previous_world_position := Vector2.ZERO
@onready var visual_root: EnemyVisual = $VisualRoot
@onready var hurtbox: EntityHurtbox = $Hurtbox

func _ready() -> void:
	add_to_group("enemy")
	hurtbox.set_collision_radius(collision_radius)
	position = IsoMath.world_to_screen(world_position)
	refresh_visual()

func setup(player_target: PlayerHero, spawn_position: Vector2, difficulty: float, config: WorldConfig, enemy_definition: EnemyDefinition = null, elite := false) -> void:
	# difficulty усиливает характеристики по номеру волны, но не меняет радиус модели.
	player = player_target
	world_position = spawn_position
	world_config = config
	definition = enemy_definition
	if definition != null:
		enemy_kind = definition.id
		visual_radius = definition.visual_radius
		collision_radius = definition.collision_radius
		max_health = definition.max_health
		move_speed = definition.move_speed
		contact_damage = definition.contact_damage
		experience_value = definition.experience_value
	max_health *= difficulty
	health = max_health
	move_speed *= 1.0 + (difficulty - 1.0) * 0.12
	contact_damage *= 1.0 + (difficulty - 1.0) * 0.16
	is_elite = elite and (definition == null or not definition.is_boss)
	apply_elite_modifiers()
	health = max_health

func apply_elite_modifiers() -> void:
	if not is_elite or _elite_modifiers_applied or world_config == null:
		return
	_elite_modifiers_applied = true
	max_health *= world_config.elite_health_multiplier
	contact_damage *= world_config.elite_damage_multiplier
	move_speed *= world_config.elite_speed_multiplier
	experience_value = maxi(1, roundi(experience_value * world_config.elite_experience_multiplier))
	visual_radius *= world_config.elite_visual_radius_multiplier
	collision_radius *= world_config.elite_collision_radius_multiplier

func set_world_state(state: WorldState) -> void:
	world_state = state

func _physics_process(delta: float) -> void:
	if not is_alive or player == null or world_config == null or not player.is_alive:
		return
	hit_flash = maxf(0.0, hit_flash - delta)
	var previous_position := world_position
	previous_world_position = previous_position
	tick_behavior(delta)
	if world_state != null:
		world_position += world_state.enemy_separation(self, world_config.enemy_separation_radius) * world_config.enemy_separation_speed * delta
		world_position = world_state.resolve_enemy_motion(self, previous_position, world_position, collision_radius)
	world_position = world_position.clamp(
		Vector2.ONE * -world_config.world_limit,
		Vector2.ONE * world_config.world_limit
	)
	if world_state != null:
		world_state.update_enemy(self)
	position = IsoMath.world_to_screen(world_position)
	refresh_visual()

func tick_behavior(delta: float) -> void:
	move_toward_player(delta)

func move_toward_player(delta: float, speed_multiplier: float = 1.0) -> float:
	# Метод возвращает исходную дистанцию, чтобы наследник мог сразу принять решение об атаке.
	var offset: Vector2 = player.world_position - world_position
	var distance := offset.length()
	if distance > 0.001:
		world_position += offset / distance * move_speed * speed_multiplier * delta
	return distance

func take_damage(amount: float, knockback_direction: Vector2 = Vector2.ZERO) -> void:
	if not is_alive:
		return
	health -= amount
	hit_flash = 0.15
	visual_root.play_hurt()
	visual_root.refresh_status()
	world_position += knockback_direction.normalized() * 18.0
	if world_state != null:
		world_position = world_state.resolve_obstacle_motion(world_position - knockback_direction.normalized() * 18.0, world_position, collision_radius)
		world_state.update_enemy(self)
	if health <= 0.0:
		is_alive = false
		visual_root.play_death()
		died.emit(self, experience_value)
		queue_free()

func damage_player(amount: float = -1.0) -> void:
	if player != null:
		player.take_damage(contact_damage if amount < 0.0 else amount)

func refresh_visual() -> void:
	if visual_root != null:
		visual_root.sync_from_enemy(self)
