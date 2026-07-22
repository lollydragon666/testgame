class_name PlayerHero
extends Node2D

signal died
signal health_changed(current: float, maximum: float)
signal experience_changed(current: int, required: int, level: int)
signal level_up_requested(level: int)
signal magic_cast_requested(spell_kind: StringName, origin: Vector2, direction: Vector2, damage: float, spell_level: int)
signal magic_changed(spell_kind: StringName, spell_level: int)
signal dash_status_changed(cooldown_remaining: float, cooldown_duration: float, active: bool)
signal player_stats_changed(stats: PlayerStats)

const DASH_DISTANCE := 165.0
const DASH_COOLDOWN := 1.1
const DASH_DURATION := 0.16
const DASH_INVULNERABILITY := 0.18
const DASH_COLLISION_STEP := 12.0

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
## Runtime-множитель общего урона меча и магии. POWER добавляет по 0.15.
var power_multiplier := 1.0
## Постоянный множитель профиля хранится отдельно от временного POWER забега.
var profile_damage_multiplier := 1.0
## Runtime-множитель перезарядки атак. HASTE умножает его на 0.90.
var haste_cooldown_multiplier := 1.0
## Доля поглощаемого входящего урона, ограниченная 40%.
var armor_damage_reduction := 0.0
## Локальный бонус радиуса магнита, не изменяющий общий WorldConfig.
var magnet_range_bonus := 0.0
var dash_cooldown_remaining := 0.0
var dash_time_remaining := 0.0
var dash_distance_remaining := 0.0
var dash_direction := Vector2.RIGHT
var is_dashing := false
var equipment_stats := PlayerStats.new()
var equipment_damage_multiplier := 1.0
var equipment_attack_speed_bonus := 0.0
var equipment_defense := 0.0
var equipment_loot_chance := 0.0
var critical_chance := 0.0
var critical_damage := 1.5
var combat_random := RandomNumberGenerator.new()

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
var inventory_service: InventoryService

var world_limit: float:
	get:
		return world_config.world_limit if world_config != null else 0.0

func configure_world(config: WorldConfig) -> void:
	world_config = config

func configure_content(content: GameContent) -> void:
	game_content = content

func configure_inventory(service: InventoryService) -> void:
	inventory_service = service

func _ready() -> void:
	if game_content == null:
		push_error("PlayerHero requires GameContent before entering the tree")
		return
	if inventory_service == null:
		inventory_service = InventoryService.new()
		inventory_service.configure(game_content)
		inventory_service.load_serialized([], {})
	var equipped_weapon := inventory_service.equipped_item(ItemEnums.EquipmentSlot.WEAPON)
	var weapon_definition := inventory_service.equipped_definition(ItemEnums.EquipmentSlot.WEAPON) as WeaponDefinition
	if weapon_definition == null:
		push_error("PlayerHero requires an equipped sword")
		return
	attack.setup(self, weapon_definition, equipped_weapon)
	inventory_service.equipment_changed.connect(_on_equipment_changed)
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
	if not active:
		_cancel_dash()
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func _physics_process(delta: float) -> void:
	if not is_alive or world_config == null:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	dash_cooldown_remaining = maxf(0.0, dash_cooldown_remaining - delta)
	input_state.sample(global_position, get_global_mouse_position())
	aim_direction = input_state.aim_world
	if input_state.dash_pressed:
		try_start_dash(input_state.movement_screen)
	if is_dashing:
		_step_dash(delta)
	else:
		var previous_position := world_position
		world_position = movement.step(delta, world_position, world_limit, input_state.movement_screen)
		if world_state != null:
			world_position = world_state.resolve_obstacle_motion(previous_position, world_position, collision_radius)
	# Камера следует за героем, поэтому сам герой остаётся около центра экрана.
	position = IsoMath.world_to_screen(world_position)
	if not is_dashing and input_state.attack_pressed:
		attack.try_attack()
	if not is_dashing and input_state.magic_pressed:
		magic.try_cast()
	dash_status_changed.emit(dash_cooldown_remaining, DASH_COOLDOWN, is_dashing)
	refresh_visual()

func try_start_dash(movement_screen_input: Vector2 = Vector2.ZERO) -> bool:
	if is_dashing or dash_cooldown_remaining > 0.0 or not is_alive or world_config == null:
		return false
	var requested_direction := aim_direction
	if movement_screen_input.length_squared() > 0.0:
		requested_direction = IsoMath.world_direction_from_screen(movement_screen_input)
	if requested_direction.is_zero_approx():
		return false
	dash_direction = requested_direction.normalized()
	dash_distance_remaining = DASH_DISTANCE
	dash_time_remaining = DASH_DURATION
	dash_cooldown_remaining = DASH_COOLDOWN
	is_dashing = true
	invulnerability = maxf(invulnerability, DASH_INVULNERABILITY)
	movement.velocity = Vector2.ZERO
	dash_status_changed.emit(dash_cooldown_remaining, DASH_COOLDOWN, true)
	return true

func _step_dash(delta: float) -> void:
	if not is_dashing:
		return
	var dash_speed := DASH_DISTANCE / DASH_DURATION
	var requested_distance := minf(dash_distance_remaining, dash_speed * delta)
	var step_count := maxi(1, ceili(requested_distance / DASH_COLLISION_STEP))
	var step_distance := requested_distance / float(step_count)
	for _step_index in step_count:
		var previous_position := world_position
		var candidate := (world_position + dash_direction * step_distance).clamp(
			Vector2.ONE * -world_limit,
			Vector2.ONE * world_limit
		)
		if world_state != null:
			candidate = world_state.resolve_obstacle_motion(world_position, candidate, collision_radius)
		var moved_distance := previous_position.distance_to(candidate)
		if moved_distance <= 0.001:
			_finish_dash()
			break
		world_position = candidate
		dash_distance_remaining = maxf(0.0, dash_distance_remaining - moved_distance)
		if world_position.x <= -world_limit or world_position.x >= world_limit or world_position.y <= -world_limit or world_position.y >= world_limit:
			_finish_dash()
			break
	dash_time_remaining = maxf(0.0, dash_time_remaining - delta)
	if is_dashing and (dash_time_remaining <= 0.0 or dash_distance_remaining <= 0.001):
		_finish_dash()

func _finish_dash() -> void:
	is_dashing = false
	dash_time_remaining = 0.0
	dash_distance_remaining = 0.0
	movement.velocity = Vector2.ZERO

func _cancel_dash() -> void:
	_finish_dash()
	dash_status_changed.emit(dash_cooldown_remaining, DASH_COOLDOWN, false)

func experience_magnet_range() -> float:
	return attack.attack_reach + world_config.pickup_magnet_extra_range + magnet_range_bonus

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
	var armor_reduced := amount * (1.0 - armor_damage_reduction)
	var reduced_amount := maxf(0.0, armor_reduced) * 100.0 / (100.0 + maxf(0.0, equipment_defense))
	health = maxf(0.0, health - reduced_amount)
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

func upgrade_power() -> void:
	power_multiplier += 0.15

func upgrade_haste() -> void:
	haste_cooldown_multiplier *= 0.90

func upgrade_armor() -> void:
	armor_damage_reduction = minf(0.40, armor_damage_reduction + 0.08)

func can_upgrade_armor() -> bool:
	return armor_damage_reduction < 0.40 - 0.001

func upgrade_magnet() -> void:
	magnet_range_bonus += 35.0

func apply_profile_bonuses(max_health_bonus: float, damage_bonus: float) -> void:
	max_health += maxf(0.0, max_health_bonus)
	health = max_health
	profile_damage_multiplier = maxf(0.0, 1.0 + damage_bonus)
	health_changed.emit(health, max_health)

func apply_equipment_stats(stats: PlayerStats) -> void:
	var previous_health_bonus := equipment_stats.max_health_bonus
	var previous_movement_factor := maxf(0.25, 1.0 + equipment_stats.movement_speed_bonus)
	equipment_stats = stats if stats != null else PlayerStats.new()
	equipment_stats.finalize()
	var health_delta := equipment_stats.max_health_bonus - previous_health_bonus
	max_health = maxf(1.0, max_health + health_delta)
	health = clampf(health + maxf(0.0, health_delta), 0.0, max_health)
	movement.speed = movement.speed / previous_movement_factor * maxf(0.25, 1.0 + equipment_stats.movement_speed_bonus)
	equipment_damage_multiplier = maxf(0.05, 1.0 + equipment_stats.damage_bonus)
	equipment_attack_speed_bonus = equipment_stats.attack_speed_bonus
	equipment_defense = equipment_stats.defense
	equipment_loot_chance = equipment_stats.loot_chance
	critical_chance = equipment_stats.critical_chance
	critical_damage = equipment_stats.critical_damage
	health_changed.emit(health, max_health)
	player_stats_changed.emit(equipment_stats)

func apply_equipped_weapon() -> bool:
	if inventory_service == null:
		return false
	var weapon_item := inventory_service.equipped_item(ItemEnums.EquipmentSlot.WEAPON)
	var weapon_definition := inventory_service.equipped_definition(ItemEnums.EquipmentSlot.WEAPON) as WeaponDefinition
	if weapon_item == null or weapon_definition == null:
		return false
	attack.equip_weapon(weapon_definition, weapon_item)
	refresh_visual()
	return true

func _on_equipment_changed() -> void:
	apply_equipped_weapon()
	apply_equipment_stats(PlayerStatCalculator.calculate(inventory_service))

func roll_attack_damage(base_amount: float) -> float:
	var result := base_amount * equipment_damage_multiplier
	if critical_chance > 0.0 and combat_random.randf() < critical_chance:
		result *= critical_damage
	return maxf(0.0, result)

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
	power_multiplier = 1.0
	profile_damage_multiplier = 1.0
	haste_cooldown_multiplier = 1.0
	armor_damage_reduction = 0.0
	magnet_range_bonus = 0.0
	dash_cooldown_remaining = 0.0
	dash_time_remaining = 0.0
	dash_distance_remaining = 0.0
	dash_direction = Vector2.RIGHT
	is_dashing = false
	equipment_stats = PlayerStats.new()
	equipment_damage_multiplier = 1.0
	equipment_attack_speed_bonus = 0.0
	equipment_defense = 0.0
	equipment_loot_chance = 0.0
	critical_chance = 0.0
	critical_damage = 1.5
	combat_random.seed = 1
	movement.speed = 195.0
	movement.reset()
	attack.reset()
	magic.reset()
	input_state.reset()
	hurtbox.set_collision_radius(collision_radius)
	health_changed.emit(health, max_health)
	experience_changed.emit(experience, experience_required, level)
	dash_status_changed.emit(0.0, DASH_COOLDOWN, false)
	refresh_visual()

func refresh_visual() -> void:
	visual_root.queue_redraw()
