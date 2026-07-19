class_name PlayerHero
extends Node2D

signal died
signal health_changed(current: float, maximum: float)
signal experience_changed(current: int, required: int, level: int)
signal level_up_requested(level: int)

@export var world_limit := 3600.0

var world_position := Vector2.ZERO
var aim_direction := Vector2.RIGHT
var radius := 22.0
var max_health := 100.0
var health := 100.0
var level := 1
var experience := 0
var experience_required := 100
var invulnerability := 0.0
var is_alive := true

var movement: PlayerMovement
var attack: PlayerAttack

func _ready() -> void:
	movement = PlayerMovement.new()
	movement.name = "Movement"
	add_child(movement)
	attack = PlayerAttack.new()
	attack.name = "Attack"
	add_child(attack)
	attack.setup(self)
	var camera := Camera2D.new()
	camera.name = "Camera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0
	camera.enabled = true
	add_child(camera)
	position = IsoMath.world_to_screen(world_position)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_alive:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	_update_aim()
	world_position = movement.step(delta, world_position, world_limit)
	position = IsoMath.world_to_screen(world_position)
	if Input.is_action_just_pressed("attack"):
		attack.try_attack()
	queue_redraw()

func _update_aim() -> void:
	var viewport_center := get_viewport_rect().size * 0.5
	var mouse_delta := get_viewport().get_mouse_position() - viewport_center
	if mouse_delta.length_squared() > 16.0:
		aim_direction = IsoMath.world_direction_from_screen(mouse_delta)

func take_damage(amount: float) -> void:
	if invulnerability > 0.0 or not is_alive:
		return
	health = maxf(0.0, health - amount)
	invulnerability = 0.45
	health_changed.emit(health, max_health)
	if health <= 0.0:
		is_alive = false
		died.emit()

func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)

func add_experience(amount: int) -> void:
	experience += amount
	while experience >= experience_required:
		experience -= experience_required
		level += 1
		experience_required = int(round(experience_required * 1.24 + 18.0))
		level_up_requested.emit(level)
	experience_changed.emit(experience, experience_required, level)

func upgrade_speed() -> void:
	movement.speed *= 1.12

func upgrade_vitality() -> void:
	max_health += 25.0
	health += 25.0
	radius = minf(36.0, radius + 2.5)
	health_changed.emit(health, max_health)

func reset_run() -> void:
	world_position = Vector2.ZERO
	position = Vector2.ZERO
	aim_direction = Vector2.RIGHT
	radius = 22.0
	max_health = 100.0
	health = max_health
	level = 1
	experience = 0
	experience_required = 100
	invulnerability = 0.0
	is_alive = true
	movement.speed = 195.0
	movement.reset()
	attack.reset()
	health_changed.emit(health, max_health)
	experience_changed.emit(experience, experience_required, level)
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0.0, 9.0), 0.0, Vector2(1.35, 0.48))
	draw_circle(Vector2.ZERO, radius, Color(0.01, 0.008, 0.008, 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body_color := Color("751714")
	if invulnerability > 0.0 and int(Time.get_ticks_msec() / 55) % 2 == 0:
		body_color.a = 0.38
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color("d4c4a4"), 2.0)
	var base_angle := IsoMath.screen_angle(aim_direction)
	var eye := Vector2.from_angle(base_angle) * radius * 0.5
	draw_circle(eye, 3.2, Color("d4c4a4"))
	_draw_sword(base_angle + attack.swing_offset())
	if attack.swing_time > 0.0:
		var progress := 1.0 - attack.swing_time / attack.swing_duration
		var head := lerpf(PlayerAttack.SWEEP_START, PlayerAttack.SWEEP_END, ease(progress, -2.5))
		draw_arc(Vector2.ZERO, attack.sword_length, base_angle + PlayerAttack.SWEEP_START, base_angle + head, 28, Color(0.69, 0.19, 0.16, 0.72), 10.0)

func _draw_sword(angle: float) -> void:
	var direction := Vector2.from_angle(angle)
	var side := direction.orthogonal()
	var guard_distance := radius + (18.0 if attack.sword_tier == 6 else 6.0)
	var blade_base := direction * (guard_distance + 5.0)
	var tip := direction * attack.sword_length
	draw_line(direction * radius * 0.55, blade_base, Color("35271d"), 7.0)
	draw_line(direction * guard_distance - side * (8.0 + attack.sword_tier * 3.0), direction * guard_distance + side * (8.0 + attack.sword_tier * 3.0), Color("a8874d"), 6.0)
	var width := 5.0 + attack.sword_tier * 0.8
	var shoulder := tip - direction * (14.0 + attack.sword_tier * 2.0)
	var blade := PackedVector2Array([blade_base - side * width, shoulder - side * width, tip, shoulder + side * width, blade_base + side * width])
	draw_colored_polygon(blade, Color("d4c4a4"))
	draw_polyline(PackedVector2Array([blade_base - side * width, shoulder - side * width, tip, shoulder + side * width, blade_base + side * width]), Color("574637"), 1.5)
