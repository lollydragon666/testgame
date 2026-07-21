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
## Размер нарисованного круга; не участвует в боевых столкновениях.
var visual_radius := 22.0
## Радиус world-space Hurtbox, используемый серверной боевой математикой.
var collision_radius := 22.0
var max_health := 100.0
var health := 100.0
var level := 1
var experience := 0
var experience_required := 100
## Оставшееся время неуязвимости после получения урона.
var invulnerability := 0.0
var is_alive := true

# Компоненты объявлены в player.tscn, а поведенческий скрипт только связывает их.
@onready var movement: PlayerMovement = $Movement
@onready var attack: PlayerAttack = $Attack
@onready var magic: PlayerMagic = $Magic
@onready var visual_root: PlayerVisual = $VisualRoot
@onready var hurtbox: EntityHurtbox = $Hurtbox
var input_state := InputState.new()
var world_config: WorldConfig
var game_content: GameContent
var world_state: WorldState

var world_limit: float:
	get:
		return world_config.world_limit if world_config != null else 0.0

func configure_world(config: WorldConfig) -> void:
	world_config = config

func configure_content(content: GameContent) -> void:
	game_content = content

func _ready() -> void:
	if game_content == null:
		push_error("PlayerHero requires GameContent before entering the tree")
		return
	attack.setup(self, game_content.weapon(&"player_sword"))
	magic.setup(self, game_content)
	magic.cast_requested.connect(_relay_magic_cast)
	magic.magic_changed.connect(_relay_magic_changed)
	hurtbox.set_collision_radius(collision_radius)
	position = IsoMath.world_to_screen(world_position)
	refresh_visual()

func set_combat_registry(state: WorldState) -> void:
	world_state = state
	attack.set_world_state(state)

func set_gameplay_active(active: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func _physics_process(delta: float) -> void:
	if not is_alive or world_config == null:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	input_state.sample(global_position, get_global_mouse_position())
	aim_direction = input_state.aim_world
	var previous_position := world_position
	world_position = movement.step(delta, world_position, world_limit, input_state.movement_screen)
	if world_state != null:
		world_position = world_state.resolve_obstacle_motion(previous_position, world_position, collision_radius)
	# Камера следует за героем, поэтому сам герой остаётся около центра экрана.
	position = IsoMath.world_to_screen(world_position)
	if input_state.attack_pressed:
		attack.try_attack()
	if input_state.magic_pressed:
		magic.try_cast()
	refresh_visual()

func experience_magnet_range() -> float:
	return attack.attack_reach + world_config.pickup_magnet_extra_range

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
	visual_radius = minf(36.0, visual_radius + 2.5)
	collision_radius = minf(36.0, collision_radius + 2.5)
	hurtbox.set_collision_radius(collision_radius)
	health_changed.emit(health, max_health)

func reset_run() -> void:
	world_position = Vector2.ZERO
	position = Vector2.ZERO
	aim_direction = Vector2.RIGHT
	visual_radius = 22.0
	collision_radius = 22.0
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
	input_state.reset()
	hurtbox.set_collision_radius(collision_radius)
	health_changed.emit(health, max_health)
	experience_changed.emit(experience, experience_required, level)
	refresh_visual()

func refresh_visual() -> void:
	visual_root.queue_redraw()
