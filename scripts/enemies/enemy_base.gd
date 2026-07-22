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
const VISUAL_DIRECTION_DOT_THRESHOLD := 0.9995
var _last_visual_direction := Vector2.ZERO
var _cached_separation := Vector2.ZERO
var _separation_update_phase := 0
@onready var visual_root: EnemyVisual = $VisualRoot
@onready var hurtbox: EntityHurtbox = $Hurtbox

func _ready() -> void:
	add_to_group("enemy")
	hurtbox.set_collision_radius(collision_radius)
	position = IsoMath.world_to_screen(world_position)
	_last_visual_direction = visual_direction()
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
	reset_separation_cache()

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

func reset_separation_cache() -> void:
	_cached_separation = Vector2.ZERO
	var divisor := maxi(1, world_config.enemy_separation_update_divisor) if world_config != null else 1
	var instance_id := get_instance_id()
	var mixed_id := instance_id ^ (instance_id >> 16)
	_separation_update_phase = int(mixed_id % divisor)

func update_separation_cache_for_frame(physics_frame: int) -> void:
	if world_state == null or world_config == null:
		_cached_separation = Vector2.ZERO
		return
	var divisor := maxi(1, world_config.enemy_separation_update_divisor)
	if posmod(physics_frame, divisor) == _separation_update_phase:
		_cached_separation = world_state.enemy_separation(self, world_config.enemy_separation_radius)

func separation_update_phase() -> int:
	return _separation_update_phase

func cached_separation() -> Vector2:
	return _cached_separation

func _physics_process(delta: float) -> void:
	if not is_alive or player == null or world_config == null or not player.is_alive:
		return
	var had_hit_flash := hit_flash > 0.0
	hit_flash = maxf(0.0, hit_flash - delta)
	var previous_position := world_position
	tick_behavior(delta)
	if world_state != null:
		update_separation_cache_for_frame(Engine.get_physics_frames())
		world_position += _cached_separation * world_config.enemy_separation_speed * delta
		world_position = world_state.resolve_obstacle_motion(previous_position, world_position, collision_radius)
	world_position = world_position.clamp(
		Vector2.ONE * -world_config.world_limit,
		Vector2.ONE * world_config.world_limit
	)
	if world_state != null:
		world_state.update_enemy(self)
	position = IsoMath.world_to_screen(world_position)
	var next_visual_direction := visual_direction()
	if _last_visual_direction.is_zero_approx() or _last_visual_direction.dot(next_visual_direction) < VISUAL_DIRECTION_DOT_THRESHOLD:
		_last_visual_direction = next_visual_direction
		refresh_visual()
	if had_hit_flash and hit_flash <= 0.0:
		refresh_visual()
	if is_visual_animation_active():
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
	refresh_visual()
	world_position += knockback_direction.normalized() * 18.0
	if world_state != null:
		world_position = world_state.resolve_obstacle_motion(world_position - knockback_direction.normalized() * 18.0, world_position, collision_radius)
		world_state.update_enemy(self)
	if health <= 0.0:
		is_alive = false
		died.emit(self, experience_value)
		queue_free()

func damage_player(amount: float = -1.0) -> void:
	if player != null:
		player.take_damage(contact_damage if amount < 0.0 else amount)

func visual_direction() -> Vector2:
	if player == null:
		return Vector2.RIGHT
	var offset := player.world_position - world_position
	return offset.normalized() if not offset.is_zero_approx() else Vector2.RIGHT

func is_visual_animation_active() -> bool:
	return false

func refresh_visual() -> void:
	visual_root.queue_redraw()
