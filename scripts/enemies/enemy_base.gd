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
var world_config: WorldConfig
## Радиус тела для попаданий мечом и магией.
var hit_radius := 24.0
var max_health := 70.0
var health := 70.0
## Скорость в мировых координатах за секунду.
var move_speed := 72.0
## Базовый урон собственной атаки врага.
var contact_damage := 12.0
## Опыт, выпадающий после смерти обычного врага.
var experience_value := 18
var hit_flash := 0.0
var is_alive := true

func _ready() -> void:
	add_to_group("enemy")
	position = IsoMath.world_to_screen(world_position)
	queue_redraw()

func setup(player_target: PlayerHero, spawn_position: Vector2, difficulty: float, config: WorldConfig) -> void:
	# difficulty усиливает характеристики по номеру волны, но не меняет радиус модели.
	player = player_target
	world_position = spawn_position
	world_config = config
	max_health *= difficulty
	health = max_health
	move_speed *= 1.0 + (difficulty - 1.0) * 0.12
	contact_damage *= 1.0 + (difficulty - 1.0) * 0.16

func _process(delta: float) -> void:
	if not is_alive or player == null or world_config == null or not player.is_alive:
		return
	hit_flash = maxf(0.0, hit_flash - delta)
	tick_behavior(delta)
	world_position = world_position.clamp(
		Vector2.ONE * -world_config.world_limit,
		Vector2.ONE * world_config.world_limit
	)
	position = IsoMath.world_to_screen(world_position)
	queue_redraw()

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
	world_position += knockback_direction.normalized() * 18.0
	if health <= 0.0:
		is_alive = false
		died.emit(self, experience_value)
		queue_free()

func damage_player(amount: float = -1.0) -> void:
	if player != null:
		player.take_damage(contact_damage if amount < 0.0 else amount)

func health_color(base_color: Color) -> Color:
	return Color("d4c4a4") if hit_flash > 0.0 else base_color

func draw_health_bar(width: float) -> void:
	if health >= max_health:
		return
	var ratio := clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(-width * 0.5, -hit_radius - 17.0, width, 4.0), Color(0.05, 0.03, 0.025, 0.8))
	draw_rect(Rect2(-width * 0.5, -hit_radius - 17.0, width * ratio, 4.0), Color("af3029"))
