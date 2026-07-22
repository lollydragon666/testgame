class_name GamePickup
extends Node2D

var pickup_kind: StringName = GameIds.PICKUP_EXPERIENCE
## Позиция предмета в мировых координатах до изометрического преобразования.
var world_position := Vector2.ZERO
## Количество опыта или здоровья в зависимости от pickup_kind.
var value := 20
var player: PlayerHero
## Используется магнитом опыта; бутылки постепенно гасят случайный импульс.
var velocity := Vector2.ZERO
var age := 0.0
var visual_radius := 10.0
var collision_radius := 10.0

func setup(player_target: PlayerHero, kind: StringName, spawn_position: Vector2, amount: int) -> void:
	player = player_target
	pickup_kind = kind
	world_position = spawn_position
	value = amount

func _ready() -> void:
	add_to_group("pickup")
	position = IsoMath.world_to_screen(world_position)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if player == null or not player.is_alive:
		return
	age += delta
	var distance := world_position.distance_to(player.world_position)
	# Только опыт магнитится; бутылка остаётся на месте до касания героем.
	if pickup_kind == GameIds.PICKUP_EXPERIENCE and distance < player.experience_magnet_range() and distance > 0.001:
		var desired_velocity := (player.world_position - world_position).normalized() * player.experience_magnet_speed(distance)
		velocity = velocity.lerp(desired_velocity, player.experience_magnet_lerp_weight(delta))
	else:
		velocity *= exp(-6.0 * delta)
	world_position += velocity * delta
	position = IsoMath.world_to_screen(world_position)
	# После движения дистанция считается заново, чтобы быстрый предмет подобрался в этот же кадр.
	var updated_distance := world_position.distance_to(player.world_position)
	if updated_distance <= player.collision_radius + collision_radius:
		if pickup_kind == GameIds.PICKUP_EXPERIENCE:
			player.add_experience(value)
		else:
			player.heal(float(value))
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var bob := sin(age * 4.8) * 4.0
	if pickup_kind == GameIds.PICKUP_EXPERIENCE:
		var diamond := PackedVector2Array([Vector2(0.0, -visual_radius + bob), Vector2(visual_radius * 0.9, bob), Vector2(0.0, visual_radius + bob), Vector2(-visual_radius * 0.9, bob)])
		draw_colored_polygon(diamond, Color("d0ad64"))
		draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color("d4c4a4"), 1.5)
	else:
		draw_rect(Rect2(-8.0, -16.0 + bob, 16.0, 23.0), Color("547245"))
		draw_rect(Rect2(-5.0, -21.0 + bob, 10.0, 7.0), Color("d4c4a4"))
