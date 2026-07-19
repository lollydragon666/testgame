class_name EnemyProjectile
extends Node2D

var world_position := Vector2.ZERO
var velocity := Vector2.ZERO
var damage := 12.0
var hit_radius := 14.0
var player
var lifetime := 6.0

func _ready() -> void:
	add_to_group("enemy_projectile")
	position = IsoMath.world_to_screen(world_position)
	queue_redraw()

func setup(player_target, origin: Vector2, direction: Vector2, projectile_damage: float) -> void:
	player = player_target
	world_position = origin
	velocity = direction.normalized() * 280.0
	damage = projectile_damage

func _process(delta: float) -> void:
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
	var tip := direction * 20.0
	var shaft_end := tip - direction * 9.0
	var tail := direction * -18.0
	var red := Color("af3029")
	draw_line(tail, shaft_end, red, 5.0)
	draw_colored_polygon(PackedVector2Array([
		tip,
		shaft_end + side * 8.0,
		shaft_end - side * 8.0
	]), red)
	draw_line(tail, tail + direction * 9.0 + side * 7.0, red, 3.0)
	draw_line(tail, tail + direction * 9.0 - side * 7.0, red, 3.0)
	draw_circle(tip, 2.2, Color("d4c4a4"))
