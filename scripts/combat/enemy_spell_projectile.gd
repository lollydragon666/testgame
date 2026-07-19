class_name EnemySpellProjectile
extends Node2D

var spell_kind := "lightning"
var world_position := Vector2.ZERO
var velocity := Vector2.ZERO
var damage := 14.0
var hit_radius := 15.0
var player
var lifetime := 6.0
var age := 0.0

func setup(player_target, kind: String, origin: Vector2, direction: Vector2, projectile_damage: float) -> void:
	player = player_target
	spell_kind = kind
	world_position = origin
	damage = projectile_damage
	if spell_kind == "lightning":
		velocity = direction.normalized() * 390.0
		hit_radius = 15.0
	else:
		velocity = direction.normalized() * 255.0
		hit_radius = 19.0

func _ready() -> void:
	add_to_group("enemy_projectile")
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
	if player != null and world_position.distance_to(player.world_position) <= hit_radius + player.radius:
		player.take_damage(damage)
		queue_free()
	queue_redraw()

func destroy_by_sword() -> void:
	queue_free()

func _draw() -> void:
	var direction := IsoMath.world_to_screen(velocity.normalized()).normalized()
	var side := direction.orthogonal()
	if spell_kind == "lightning":
		var points := PackedVector2Array([
			direction * -22.0 + side * 2.0,
			direction * -7.0 - side * 5.0,
			direction * 6.0 + side * 5.0,
			direction * 24.0
		])
		draw_polyline(points, Color("397fe8"), 9.0)
		draw_polyline(points, Color("b9dcff"), 3.0)
	else:
		var pulse := sin(age * 11.0) * 2.0
		draw_circle(Vector2.ZERO, 16.0 + pulse, Color(0.48, 0.02, 0.01, 0.5))
		draw_circle(Vector2.ZERO, 12.0 + pulse * 0.5, Color("c92e1c"))
		draw_circle(direction * 3.0, 5.0, Color("ff9b42"))

