class_name GamePickup
extends Node2D

var pickup_kind := "experience"
var world_position := Vector2.ZERO
var value := 20
var player
var velocity := Vector2.ZERO
var age := 0.0
var hit_radius := 10.0

func setup(player_target, kind: String, spawn_position: Vector2, amount: int) -> void:
	player = player_target
	pickup_kind = kind
	world_position = spawn_position
	value = amount

func _ready() -> void:
	add_to_group("pickup")
	position = IsoMath.world_to_screen(world_position)
	queue_redraw()

func _process(delta: float) -> void:
	if player == null or not player.is_alive:
		return
	age += delta
	var distance := world_position.distance_to(player.world_position)
	if pickup_kind == "experience" and distance < player.attack.sword_length + 42.0 and distance > 0.001:
		var desired_velocity := (player.world_position - world_position).normalized() * (220.0 + maxf(0.0, 150.0 - distance) * 2.0)
		velocity = velocity.lerp(desired_velocity, 1.0 - exp(-9.0 * delta))
	else:
		velocity *= exp(-6.0 * delta)
	world_position += velocity * delta
	position = IsoMath.world_to_screen(world_position)
	if distance <= player.radius + hit_radius:
		if pickup_kind == "experience":
			player.add_experience(value)
		else:
			player.heal(float(value))
		queue_free()
	queue_redraw()

func _draw() -> void:
	var bob := sin(age * 4.8) * 4.0
	if pickup_kind == "experience":
		var diamond := PackedVector2Array([Vector2(0.0, -10.0 + bob), Vector2(9.0, bob), Vector2(0.0, 10.0 + bob), Vector2(-9.0, bob)])
		draw_colored_polygon(diamond, Color("d0ad64"))
		draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color("d4c4a4"), 1.5)
	else:
		draw_rect(Rect2(-8.0, -16.0 + bob, 16.0, 23.0), Color("547245"))
		draw_rect(Rect2(-5.0, -21.0 + bob, 10.0, 7.0), Color("d4c4a4"))

