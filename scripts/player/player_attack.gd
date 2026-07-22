class_name PlayerAttack
extends Node

signal attack_started

const SWEEP_START := -1.22
const SWEEP_END := 1.04
const MAX_SWORD_TIER := 6

## Урон одного замаха мечом.
@export var damage := 34.0
## Дальность hit shape в мировых единицах. Не зависит от размера нарисованного меча.
@export var attack_reach := 91.0
## Половина физической ширины клинка в мировых единицах.
@export var attack_half_width := 7.0
## Визуальная длина меча в пикселях; изменение не влияет на попадания.
@export var visual_sword_length := 91.0
## Минимальная пауза между началами двух атак.
@export var cooldown_duration := 0.36
## Время полного движения клинка от одного края дуги до другого.
@export var swing_duration := 0.28

## Уровни 1–6 выбирают модель меча: от гладиуса до двуручного.
var sword_tier := 1
var cooldown := 0.0
var swing_time := 0.0
## Знак меняется после атаки, поэтому удары чередуются слева направо и обратно.
var swing_direction := 1.0
var next_swing_direction := 1.0
## Направление фиксируется в начале замаха и не залипает за движением мыши.
var swing_aim_direction := Vector2.RIGHT
var previous_swing_offset := 0.0
## Не позволяет одной цели получить урон несколько раз за один замах.
var hit_targets: Dictionary[int, bool] = {}
var host: PlayerHero
var world_state: WorldState
var attack_shape := AttackShape.new()
var definition: WeaponDefinition
var equipped_item: ItemInstance

func setup(player_host: PlayerHero, weapon_definition: WeaponDefinition, weapon_item: ItemInstance = null) -> void:
	host = player_host
	equip_weapon(weapon_definition, weapon_item)

func equip_weapon(weapon_definition: WeaponDefinition, weapon_item: ItemInstance = null) -> void:
	if weapon_definition == null or weapon_definition.weapon_class != ItemEnums.SWORD_CLASS:
		return
	definition = weapon_definition
	equipped_item = weapon_item
	reset()
	if host != null and host.is_node_ready():
		host.refresh_visual()

func set_world_state(state: WorldState) -> void:
	world_state = state

func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if swing_time > 0.0:
		swing_time = maxf(0.0, swing_time - delta)
		var current_offset := swing_offset() if swing_time > 0.0 else swing_end_offset()
		_hit_groups_between(previous_swing_offset, current_offset)
		previous_swing_offset = current_offset
		if host != null:
			host.refresh_visual()

func try_attack() -> void:
	if host == null or world_state == null or cooldown > 0.0 or not host.is_alive:
		return
	cooldown = effective_cooldown_duration()
	swing_time = swing_duration
	swing_direction = next_swing_direction
	next_swing_direction *= -1.0
	swing_aim_direction = host.aim_direction
	previous_swing_offset = swing_start_offset()
	hit_targets.clear()
	attack_started.emit()
	_hit_groups_between(previous_swing_offset, previous_swing_offset)
	host.refresh_visual()

func _hit_groups_between(from_offset: float, to_offset: float) -> void:
	# Проверяется пройденный за кадр участок дуги, а не только текущая позиция меча.
	_hit_enemies_between(from_offset, to_offset)
	_hit_projectiles_between(from_offset, to_offset)
	_hit_destructibles_between(from_offset, to_offset)

func _hit_enemies_between(from_offset: float, to_offset: float) -> void:
	var query_radius := host.collision_radius + effective_attack_reach() + 80.0
	for enemy in world_state.enemies_near(host.world_position, query_radius):
		if not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		var target_id := enemy.get_instance_id()
		if hit_targets.has(target_id):
			continue
		if point_in_blade_sweep(enemy.world_position, enemy.collision_radius, from_offset, to_offset):
			hit_targets[target_id] = true
			enemy.take_damage(effective_damage(), swing_aim_direction)

func _hit_projectiles_between(from_offset: float, to_offset: float) -> void:
	var query_radius := host.collision_radius + effective_attack_reach() + 48.0
	for projectile in world_state.enemy_projectiles_near(host.world_position, query_radius):
		if not is_instance_valid(projectile):
			continue
		var target_id := projectile.get_instance_id()
		if hit_targets.has(target_id):
			continue
		var target_position: Vector2 = projectile.world_position
		var target_radius: float = projectile.collision_radius + 7.0
		if point_in_blade_sweep(target_position, target_radius, from_offset, to_offset):
			hit_targets[target_id] = true
			projectile.destroy_by_sword()

func _hit_destructibles_between(from_offset: float, to_offset: float) -> void:
	var query_radius := host.collision_radius + effective_attack_reach() + 64.0
	for prop in world_state.destructibles_near(host.world_position, query_radius):
		if not is_instance_valid(prop):
			continue
		var target_id := prop.get_instance_id()
		if hit_targets.has(target_id):
			continue
		if point_in_blade_sweep(prop.world_position, prop.collision_radius, from_offset, to_offset):
			hit_targets[target_id] = true
			prop.hit_by_sword()

func point_in_sweep(target_world_position: Vector2, target_radius: float = 0.0) -> bool:
	return point_in_blade_sweep(target_world_position, target_radius, SWEEP_START, SWEEP_END)

func point_in_blade_sweep(target_world_position: Vector2, target_radius: float, from_offset: float, to_offset: float) -> bool:
	attack_shape.configure(
		host.world_position,
		swing_aim_direction,
		host.collision_radius + 5.0,
		effective_attack_reach(),
		effective_attack_half_width()
	)
	return attack_shape.intersects_swept_circle(target_world_position, target_radius, from_offset, to_offset)

func swing_offset() -> float:
	if swing_time <= 0.0:
		return 0.0
	var progress := 1.0 - swing_time / swing_duration
	var eased_progress := ease(progress, -2.5)
	return lerpf(swing_start_offset(), swing_end_offset(), eased_progress)

func swing_start_offset() -> float:
	return SWEEP_START if swing_direction > 0.0 else SWEEP_END

func swing_end_offset() -> float:
	return SWEEP_END if swing_direction > 0.0 else SWEEP_START

func upgrade_sword() -> void:
	# Модель растёт вместе с зоной удара; ширина увеличивается на 12% за уровень.
	if not can_upgrade_sword():
		return
	sword_tier += 1
	attack_reach += definition.reach_per_tier
	attack_half_width = definition.attack_half_width * pow(
		definition.width_multiplier_per_tier,
		float(sword_tier - 1)
	)
	visual_sword_length += definition.visual_length_per_tier
	damage += definition.damage_per_tier
	if sword_tier == definition.max_tier:
		attack_reach += definition.final_tier_bonus_reach
		visual_sword_length += definition.final_tier_bonus_reach
		damage += definition.final_tier_bonus_damage

func can_upgrade_sword() -> bool:
	return definition != null and sword_tier < definition.max_tier

func effective_damage() -> float:
	if host == null:
		return damage
	var damage_after_flat := damage + host.equipment_flat_damage_bonus
	return host.roll_attack_damage(damage_after_flat * host.profile_damage_multiplier * host.power_multiplier)

func effective_attack_reach() -> float:
	var multiplier := maxf(0.5, 1.0 + host.equipment_attack_reach_bonus) if host != null else 1.0
	return attack_reach * multiplier

func effective_attack_half_width() -> float:
	var multiplier := maxf(0.5, 1.0 + host.equipment_attack_width_bonus) if host != null else 1.0
	return attack_half_width * multiplier

func effective_visual_sword_length() -> float:
	var multiplier := effective_attack_reach() / maxf(1.0, attack_reach)
	return visual_sword_length * multiplier

func effective_cooldown_duration() -> float:
	var haste_multiplier := host.haste_cooldown_multiplier if host != null else 1.0
	var equipment_speed := 1.0 + maxf(-0.75, host.equipment_attack_speed_bonus + host.temporary_attack_speed_bonus) if host != null else 1.0
	return maxf(0.14, cooldown_duration * haste_multiplier / equipment_speed)

func reset() -> void:
	if definition == null:
		return
	damage = definition.base_damage
	attack_reach = definition.base_attack_reach
	attack_half_width = definition.attack_half_width
	visual_sword_length = definition.base_visual_length
	cooldown_duration = definition.cooldown
	swing_duration = definition.swing_duration
	sword_tier = 1
	cooldown = 0.0
	swing_time = 0.0
	swing_direction = 1.0
	next_swing_direction = 1.0
	swing_aim_direction = Vector2.RIGHT
	previous_swing_offset = 0.0
	hit_targets.clear()
