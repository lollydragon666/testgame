class_name ArchetypeEnemy
extends EnemyBase

var movement_controller := EnemyMovementController.new()
var targeting_controller := EnemyTargetingController.new()
var attack_controller := EnemyAttackController.new()
var ability_controller := EnemyAbilityController.new()
var drop_controller := EnemyDropController.new()
var combat_facing := Vector2.RIGHT
var disengage_remaining := 0.0
var shield_open_remaining := 0.0
var heal_windup_remaining := 0.0
var heal_target: EnemyBase
var strafe_side := 1.0
var summon_windup_remaining := 0.0
var explosion_windup_remaining := 0.0
var explosion_triggered := false
var summoner_owner_id := 0

func setup(player_target: PlayerHero, spawn_position: Vector2, difficulty: float, config: WorldConfig, enemy_definition: EnemyDefinition = null, elite := false) -> void:
	super.setup(player_target, spawn_position, difficulty, config, enemy_definition, elite)
	movement_controller.configure(self)
	targeting_controller.configure(self)
	if definition != null:
		attack_controller.configure(definition)
		ability_controller.configure(definition.ability_cooldown)
		drop_controller.configure(definition)
	strafe_side = -1.0 if get_instance_id() % 2 == 0 else 1.0

func tick_behavior(delta: float) -> void:
	if definition == null:
		return
	ability_controller.tick(delta)
	disengage_remaining = maxf(0.0, disengage_remaining - delta)
	shield_open_remaining = maxf(0.0, shield_open_remaining - delta)
	combat_facing = targeting_controller.direction_to_player()
	match definition.enemy_class:
		EnemyDefinition.EnemyClass.SUMMONER:
			_tick_summoner(delta)
		EnemyDefinition.EnemyClass.BOMBER:
			_tick_bomber(delta)
		EnemyDefinition.EnemyClass.ARCHER:
			_tick_archer(delta)
		EnemyDefinition.EnemyClass.HEALER:
			_tick_healer(delta)
		EnemyDefinition.EnemyClass.COMMANDER:
			_tick_commander(delta)
		EnemyDefinition.EnemyClass.RAIDER:
			_tick_raider(delta)
		EnemyDefinition.EnemyClass.BRUTE:
			_tick_brute(delta)
		EnemyDefinition.EnemyClass.SHIELD_BEARER:
			_tick_shield_bearer(delta)
		EnemyDefinition.EnemyClass.SPEARMAN:
			_tick_spearman(delta)
		EnemyDefinition.EnemyClass.SWORDSMAN, EnemyDefinition.EnemyClass.SUMMONED_MINION:
			_tick_swordsman(delta)
		_:
			_tick_swordsman(delta)

func _tick_summoner(delta: float) -> void:
	if summon_windup_remaining > 0.0:
		summon_windup_remaining = maxf(0.0, summon_windup_remaining - delta)
		visual_root.refresh_effects()
		if summon_windup_remaining <= 0.0:
			var available_slots := maxi(0, 4 - _owned_minion_count())
			if available_slots > 0:
				summon_requested.emit(self, mini(2, available_slots))
		return
	var distance := targeting_controller.distance_to_player()
	if distance < definition.retreat_distance:
		movement_controller.retreat(combat_facing, delta)
	elif distance > definition.preferred_distance:
		movement_controller.approach(combat_facing, delta, 0.78)
	else:
		movement_controller.strafe(combat_facing, strafe_side, delta, 0.25)
	if ability_controller.ready() and _owned_minion_count() < 4 and ability_controller.consume():
		summon_windup_remaining = 0.82
		visual_root.play_attack()

func _owned_minion_count() -> int:
	if world_state == null:
		return 0
	var count := 0
	for enemy in world_state.enemy_snapshot():
		var minion := enemy as ArchetypeEnemy
		if minion != null and minion.is_alive and minion.summoner_owner_id == get_instance_id():
			count += 1
	return count

func _tick_bomber(delta: float) -> void:
	if explosion_triggered:
		return
	if explosion_windup_remaining > 0.0:
		explosion_windup_remaining = maxf(0.0, explosion_windup_remaining - delta)
		visual_root.refresh_effects()
		if explosion_windup_remaining <= 0.0:
			_explode()
		return
	if targeting_controller.distance_to_player() > definition.preferred_distance:
		movement_controller.approach(combat_facing, delta, 1.08)
	else:
		explosion_windup_remaining = 1.2
		visual_root.play_attack()

func _explode() -> void:
	if explosion_triggered or not is_alive:
		return
	explosion_triggered = true
	var radius := definition.attack_range
	if targeting_controller.distance_to_player() <= radius:
		damage_player(definition.attack_damage)
	if world_state != null:
		for enemy in world_state.enemies_near(world_position, radius + 48.0):
			if enemy == self or not enemy.is_alive:
				continue
			var offset := enemy.world_position - world_position
			if offset.length() <= radius + enemy.collision_radius:
				enemy.take_damage(definition.attack_damage * definition.ability_power, offset)
	super.take_damage(health + maxf(1.0, defense) + 1.0)

func _tick_archer(delta: float) -> void:
	var distance := targeting_controller.distance_to_player()
	var hit_frame := attack_controller.tick(delta, runtime_attack_speed_multiplier)
	if hit_frame and targeting_controller.has_line_of_sight(definition.attack_range):
		arrow_requested.emit(world_position, combat_facing, definition.attack_damage)
	if attack_controller.is_busy():
		return
	if distance < definition.retreat_distance:
		movement_controller.retreat(combat_facing, delta)
	elif distance > definition.preferred_distance:
		movement_controller.approach(combat_facing, delta)
	else:
		movement_controller.strafe(combat_facing, strafe_side, delta, 0.45)
		if targeting_controller.has_line_of_sight(definition.attack_range):
			_start_attack()

func _tick_healer(delta: float) -> void:
	if heal_windup_remaining > 0.0:
		heal_windup_remaining = maxf(0.0, heal_windup_remaining - delta)
		visual_root.refresh_effects()
		if heal_windup_remaining <= 0.0:
			_complete_heal()
		return
	var distance := targeting_controller.distance_to_player()
	if distance < definition.retreat_distance:
		movement_controller.retreat(combat_facing, delta)
	elif distance > definition.preferred_distance:
		movement_controller.approach(combat_facing, delta, 0.82)
	if ability_controller.ready():
		var target := _most_injured_ally(360.0)
		if target != null and ability_controller.consume():
			heal_target = target
			heal_windup_remaining = 0.72
			visual_root.play_attack()

func _tick_commander(delta: float) -> void:
	_tick_swordsman(delta)

func _most_injured_ally(radius: float) -> EnemyBase:
	if world_state == null:
		return null
	var best: EnemyBase = null
	var lowest_ratio := 1.0
	for ally in world_state.enemies_near(world_position, radius):
		if not ally.is_alive or ally.health >= ally.max_health:
			continue
		var ratio := ally.health / maxf(1.0, ally.max_health)
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			best = ally
	return best

func _complete_heal() -> void:
	if is_instance_valid(heal_target) and heal_target.is_alive:
		heal_target.health = minf(heal_target.max_health, heal_target.health + heal_target.max_health * definition.ability_power)
		heal_target.visual_root.refresh_status()
	heal_target = null

func _tick_swordsman(delta: float) -> void:
	var distance := targeting_controller.distance_to_player()
	var hit_frame := attack_controller.tick(delta, runtime_attack_speed_multiplier)
	if hit_frame:
		_try_damage_player_in_range(definition.attack_range)
	if attack_controller.is_busy():
		return
	if distance > definition.preferred_distance:
		movement_controller.approach(combat_facing, delta)
	elif distance <= definition.attack_range:
		_start_attack()

func _tick_raider(delta: float) -> void:
	var distance := targeting_controller.distance_to_player()
	var hit_frame := attack_controller.tick(delta, runtime_attack_speed_multiplier)
	if hit_frame:
		_try_damage_player_in_range(definition.attack_range)
		disengage_remaining = 0.72
	if disengage_remaining > 0.0:
		movement_controller.retreat(combat_facing, delta, 1.12)
		return
	if attack_controller.is_busy():
		return
	if distance > definition.preferred_distance:
		movement_controller.approach(combat_facing, delta, 1.08)
	else:
		_start_attack()

func _tick_brute(delta: float) -> void:
	var distance := targeting_controller.distance_to_player()
	var hit_frame := attack_controller.tick(delta, runtime_attack_speed_multiplier)
	if hit_frame:
		_try_damage_player_in_range(definition.attack_range)
	if attack_controller.is_busy():
		return
	if distance > definition.preferred_distance:
		movement_controller.approach(combat_facing, delta)
	else:
		_start_attack()

func _tick_shield_bearer(delta: float) -> void:
	var distance := targeting_controller.distance_to_player()
	var hit_frame := attack_controller.tick(delta, runtime_attack_speed_multiplier)
	if hit_frame:
		_try_damage_player_in_range(definition.attack_range)
		shield_open_remaining = 0.58
	if attack_controller.is_busy():
		return
	if distance > definition.preferred_distance:
		movement_controller.approach(combat_facing, delta, 0.90)
	else:
		_start_attack()

func _tick_spearman(delta: float) -> void:
	var distance := targeting_controller.distance_to_player()
	var hit_frame := attack_controller.tick(delta, runtime_attack_speed_multiplier)
	if hit_frame and targeting_controller.has_line_of_sight(definition.attack_range + 12.0):
		_try_damage_player_in_range(definition.attack_range)
	if attack_controller.is_busy():
		return
	if distance < definition.retreat_distance:
		movement_controller.retreat(combat_facing, delta)
	elif distance > definition.preferred_distance:
		movement_controller.approach(combat_facing, delta)
	elif distance <= definition.attack_range and targeting_controller.has_line_of_sight(definition.attack_range + 12.0):
		_start_attack()

func _start_attack() -> bool:
	if not attack_controller.try_start():
		return false
	visual_root.play_attack()
	return true

func _try_damage_player_in_range(range_value: float) -> bool:
	if targeting_controller.distance_to_player() > range_value:
		return false
	damage_player(definition.attack_damage)
	return true

func take_damage(amount: float, knockback_direction: Vector2 = Vector2.ZERO) -> void:
	var adjusted_amount := amount
	if (
		definition != null
		and definition.enemy_class == EnemyDefinition.EnemyClass.SHIELD_BEARER
		and shield_open_remaining <= 0.0
		and not knockback_direction.is_zero_approx()
	):
		var direction_to_attacker := -knockback_direction.normalized()
		if combat_facing.dot(direction_to_attacker) >= 0.35:
			adjusted_amount *= 0.25
	super.take_damage(adjusted_amount, knockback_direction)
