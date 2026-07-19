class_name PlayerMagicProjectile
extends Node2D

var spell_kind := "lightning"
var spell_level := 1
var world_position := Vector2.ZERO
var velocity := Vector2.ZERO
var damage := 30.0
var hit_radius := 13.0
var lifetime := 4.5
var age := 0.0

func setup(kind: String, origin: Vector2, direction: Vector2, projectile_damage: float, level: int) -> void:
	spell_kind = kind
	spell_level = level
	world_position = origin
	damage = projectile_damage
	if spell_kind == "lightning":
		velocity = direction.normalized() * (520.0 + float(level - 1) * 20.0)
		hit_radius = 13.0 + float(level - 1) * 0.8
		lifetime = 3.2
	else:
		velocity = direction.normalized() * (330.0 + float(level - 1) * 10.0)
		hit_radius = 18.0 + float(level - 1) * 1.2
		lifetime = 5.0

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
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		if world_position.distance_to(enemy.world_position) <= hit_radius + enemy.hit_radius:
			_impact(enemy)
			break
	queue_redraw()

func _impact(direct_enemy) -> void:
	var direction := velocity.normalized()
	if spell_kind == "fireball":
		var explosion_radius := 82.0 + float(spell_level - 1) * 8.0
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(enemy) and enemy.is_alive and enemy.world_position.distance_to(world_position) <= explosion_radius + enemy.hit_radius:
				enemy.take_damage(damage, direction)
	else:
		direct_enemy.take_damage(damage, direction)
	queue_free()

func _draw() -> void:
	var direction := IsoMath.world_to_screen(velocity.normalized()).normalized()
	var side := direction.orthogonal()
	if spell_kind == "lightning":
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

