class_name PlayerMagicProjectile
extends Node2D

var spell_kind: StringName = GameIds.SPELL_LIGHTNING
var spell_level := 1
var world_position := Vector2.ZERO
var velocity := Vector2.ZERO
var damage := 30.0
## Радиус прямого столкновения; радиус взрыва фаербола рассчитывается отдельно.
var hit_radius := 13.0
## Защита от бесконечно летящих снарядов за пределами видимой области.
var lifetime := 4.5
var age := 0.0
var world_state: WorldState

func setup(kind: StringName, origin: Vector2, direction: Vector2, projectile_damage: float, level: int, state: WorldState) -> void:
	spell_kind = kind
	spell_level = level
	world_position = origin
	damage = projectile_damage
	world_state = state
	match spell_kind:
		GameIds.SPELL_LIGHTNING:
			velocity = direction.normalized() * (520.0 + float(level - 1) * 20.0)
			hit_radius = 13.0 + float(level - 1) * 0.8
			lifetime = 3.2
		GameIds.SPELL_FIREBALL:
			velocity = direction.normalized() * (330.0 + float(level - 1) * 10.0)
			hit_radius = 18.0 + float(level - 1) * 1.2
			lifetime = 5.0
		_:
			push_error("Unknown player projectile spell: %s" % spell_kind)

func _ready() -> void:
	add_to_group("player_magic_projectile")
	position = IsoMath.world_to_screen(world_position)
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	lifetime -= delta
	world_position += velocity * delta
	position = IsoMath.world_to_screen(world_position)
	if lifetime <= 0.0:
		queue_free()
		return
	for enemy in world_state.enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		if world_position.distance_to(enemy.world_position) <= hit_radius + enemy.hit_radius:
			_impact(enemy)
			break
	queue_redraw()

func _impact(target_enemy: EnemyBase) -> void:
	var direction := velocity.normalized()
	if spell_kind == GameIds.SPELL_FIREBALL:
		# Фаербол поражает все типизированные цели реестра внутри области взрыва.
		var explosion_radius := 82.0 + float(spell_level - 1) * 8.0
		for enemy in world_state.enemies:
			if is_instance_valid(enemy) and enemy.is_alive and enemy.world_position.distance_to(world_position) <= explosion_radius + enemy.hit_radius:
				enemy.take_damage(damage, direction)
	else:
		target_enemy.take_damage(damage, direction)
	queue_free()

func _draw() -> void:
	var direction := IsoMath.world_to_screen(velocity.normalized()).normalized()
	var side := direction.orthogonal()
	if spell_kind == GameIds.SPELL_LIGHTNING:
		var points := PackedVector2Array([
			direction * -24.0 + side * 2.0,
			direction * -8.0 - side * 5.0,
			direction * 5.0 + side * 5.0,
			direction * 26.0
		])
		draw_polyline(points, Color("5a9cff"), 9.0)
		draw_polyline(points, Color("b9dcff"), 3.0)
	else:
		var pulse := sin(age * 12.0) * 2.0
		draw_circle(Vector2.ZERO, 15.0 + pulse, Color(0.45, 0.04, 0.02, 0.5))
		draw_circle(Vector2.ZERO, 11.0 + pulse * 0.5, Color("d74724"))
		draw_circle(direction * 3.0, 5.0, Color("ffc15b"))
