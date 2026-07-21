class_name PlayerHero
extends Node2D

signal died
signal health_changed(current: float, maximum: float)
signal experience_changed(current: int, required: int, level: int)
signal level_up_requested(level: int)
signal magic_cast_requested(spell_kind: StringName, origin: Vector2, direction: Vector2, damage: float, spell_level: int)
signal magic_changed(spell_kind: StringName, spell_level: int)

## Логическая позиция героя; Node2D.position содержит её изометрическую проекцию.
var world_position := Vector2.ZERO
## Нормализованное направление взгляда и атак в мировых координатах.
var aim_direction := Vector2.RIGHT
## Радиус тела; увеличение живучести одновременно увеличивает модель героя.
var radius := 22.0
var max_health := 100.0
var health := 100.0
var level := 1
var experience := 0
var experience_required := 100
## Оставшееся время неуязвимости после получения урона.
var invulnerability := 0.0
var is_alive := true

# Движение, ближняя атака и магия разделены на самостоятельные компоненты.
var movement: PlayerMovement
var attack: PlayerAttack
var magic: PlayerMagic
var world_config: WorldConfig

var world_limit: float:
	get:
		return world_config.world_limit if world_config != null else 0.0

func configure_world(config: WorldConfig) -> void:
	world_config = config

func _ready() -> void:
	movement = PlayerMovement.new()
	movement.name = "Movement"
	add_child(movement)
	attack = PlayerAttack.new()
	attack.name = "Attack"
	add_child(attack)
	attack.setup(self)
	magic = PlayerMagic.new()
	magic.name = "Magic"
	add_child(magic)
	magic.setup(self)
	magic.cast_requested.connect(_relay_magic_cast)
	magic.magic_changed.connect(_relay_magic_changed)
	var camera := Camera2D.new()
	camera.name = "Camera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0
	camera.enabled = true
	add_child(camera)
	position = IsoMath.world_to_screen(world_position)
	queue_redraw()

func set_combat_registry(state: WorldState) -> void:
	attack.set_world_state(state)

func set_gameplay_active(active: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func _process(delta: float) -> void:
	if not is_alive or world_config == null:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	_update_aim()
	world_position = movement.step(delta, world_position, world_limit)
	# Камера следует за героем, поэтому сам герой остаётся около центра экрана.
	position = IsoMath.world_to_screen(world_position)
	if Input.is_action_just_pressed("attack"):
		attack.try_attack()
	if Input.is_action_just_pressed("cast_magic"):
		magic.try_cast()
	queue_redraw()

func experience_magnet_range() -> float:
	return attack.sword_length + world_config.pickup_magnet_extra_range

func experience_magnet_speed(distance: float) -> float:
	return world_config.pickup_magnet_base_speed + maxf(
		0.0,
		world_config.pickup_magnet_close_distance - distance
	) * world_config.pickup_magnet_close_acceleration

func experience_magnet_lerp_weight(delta: float) -> float:
	return 1.0 - exp(-world_config.pickup_magnet_smoothing * delta)

func _relay_magic_cast(spell_kind: StringName, origin: Vector2, direction: Vector2, damage: float, spell_level: int) -> void:
	magic_cast_requested.emit(spell_kind, origin, direction, damage, spell_level)

func _relay_magic_changed(spell_kind: StringName, spell_level: int) -> void:
	magic_changed.emit(spell_kind, spell_level)

func _update_aim() -> void:
	var mouse_delta := get_global_mouse_position() - global_position
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
	magic.reset()
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
	var look_angle := IsoMath.screen_angle(aim_direction)
	var eye := Vector2.from_angle(look_angle) * radius * 0.5
	draw_circle(eye, 3.2, Color("d4c4a4"))
	var weapon_aim := attack.swing_aim_direction if attack.swing_time > 0.0 else aim_direction
	var base_angle := IsoMath.screen_angle(weapon_aim)
	if attack.swing_time > 0.0:
		_draw_swing_trail(base_angle)
	_draw_sword(base_angle + attack.swing_offset())

func _draw_swing_trail(base_angle: float) -> void:
	var start_offset := attack.swing_start_offset()
	var current_offset := attack.swing_offset()
	var trail := PackedVector2Array()
	for index in 24:
		var progress := float(index) / 23.0
		var angle := base_angle + lerpf(start_offset, current_offset, progress)
		trail.append(Vector2.from_angle(angle) * attack.sword_length)
	draw_polyline(trail, Color(0.69, 0.19, 0.16, 0.72), 10.0)

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
