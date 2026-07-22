class_name PlayerMagicProjectile
extends Node2D

var spell_kind: StringName = GameIds.SPELL_LIGHTNING
var spell_level := 1
var world_position := Vector2.ZERO
var velocity := Vector2.ZERO
var damage := 30.0
## Размер визуального эффекта; не используется логикой попадания.
var visual_radius := 13.0
## World-space радиус прямого столкновения; AoE фаербола рассчитывается отдельно.
var collision_radius := 13.0
## Защита от бесконечно летящих снарядов за пределами видимой области.
var lifetime := 4.5
var age := 0.0
var world_state: WorldState
var definition: SpellDefinition
var _enemy_query_buffer: Array[EnemyBase] = []

func setup(spell_definition: SpellDefinition, origin: Vector2, direction: Vector2, projectile_damage: float, level: int, state: WorldState) -> void:
	definition = spell_definition
	spell_kind = definition.id
	spell_level = level
	world_position = origin
	damage = projectile_damage
	world_state = state
	var level_offset := float(level - 1)
	velocity = direction.normalized() * (definition.base_speed + level_offset * definition.speed_per_level)
	visual_radius = definition.visual_radius + level_offset * definition.radius_per_level
	collision_radius = definition.collision_radius + level_offset * definition.radius_per_level
	lifetime = definition.lifetime

func _ready() -> void:
	add_to_group("player_magic_projectile")
	position = IsoMath.world_to_screen(world_position)
	queue_redraw()

func _physics_process(delta: float) -> void:
	age += delta
	lifetime -= delta
	var previous_position := world_position
	var next_position := world_position + velocity * delta
	world_position = next_position
	position = IsoMath.world_to_screen(world_position)
	if lifetime <= 0.0:
		queue_free()
		return
	var target_enemy: EnemyBase
	var earliest_hit_fraction := 2.0
	var segment_center := previous_position.lerp(next_position, 0.5)
	var query_radius := previous_position.distance_to(next_position) * 0.5 + collision_radius + 70.0
	world_state.enemies_near_into(segment_center, query_radius, _enemy_query_buffer)
	for enemy in _enemy_query_buffer:
		if not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		var hit_fraction := CollisionMath.segment_circle_hit_fraction(
			previous_position,
			next_position,
			enemy.world_position,
			collision_radius + enemy.collision_radius
		)
		if hit_fraction >= 0.0 and hit_fraction < earliest_hit_fraction:
			earliest_hit_fraction = hit_fraction
			target_enemy = enemy
	if target_enemy != null:
		world_position = previous_position.lerp(next_position, earliest_hit_fraction)
		position = IsoMath.world_to_screen(world_position)
		_impact(target_enemy)
		return
	queue_redraw()

func _impact(target_enemy: EnemyBase) -> void:
	var direction := velocity.normalized()
	if spell_kind == GameIds.SPELL_FIREBALL:
		# Snapshot не меняется, если один из врагов погиб и удалился из реестра в ходе AoE.
		var explosion_radius := definition.explosion_radius + float(spell_level - 1) * definition.explosion_radius_per_level
		world_state.enemies_near_into(world_position, explosion_radius + 70.0, _enemy_query_buffer)
		for enemy in _enemy_query_buffer:
			if is_instance_valid(enemy) and enemy.is_alive and enemy.world_position.distance_to(world_position) <= explosion_radius + enemy.collision_radius:
				enemy.take_damage(damage, direction)
	else:
		target_enemy.take_damage(damage, direction)
	queue_free()

func _draw() -> void:
	var direction := IsoMath.world_to_screen(velocity.normalized()).normalized()
	var side := direction.orthogonal()
	if spell_kind == GameIds.SPELL_LIGHTNING:
		var length := visual_radius * 2.0
		var points := PackedVector2Array([
			direction * -length + side * 2.0,
			direction * -8.0 - side * 5.0,
			direction * 5.0 + side * 5.0,
			direction * length
		])
		draw_polyline(points, Color("5a9cff"), 9.0)
		draw_polyline(points, Color("b9dcff"), 3.0)
	else:
		var pulse := sin(age * 12.0) * 2.0
		draw_circle(Vector2.ZERO, visual_radius * 0.84 + pulse, Color(0.45, 0.04, 0.02, 0.5))
		draw_circle(Vector2.ZERO, visual_radius * 0.61 + pulse * 0.5, Color("d74724"))
		draw_circle(direction * 3.0, 5.0, Color("ffc15b"))
