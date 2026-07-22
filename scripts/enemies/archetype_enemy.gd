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

func setup(player_target: PlayerHero, spawn_position: Vector2, difficulty: float, config: WorldConfig, enemy_definition: EnemyDefinition = null, elite := false) -> void:
	super.setup(player_target, spawn_position, difficulty, config, enemy_definition, elite)
	movement_controller.configure(self)
	targeting_controller.configure(self)
	if definition != null:
		attack_controller.configure(definition)
		ability_controller.configure(definition.ability_cooldown)
		drop_controller.configure(definition)

func tick_behavior(delta: float) -> void:
	if definition == null:
		return
	ability_controller.tick(delta)
	disengage_remaining = maxf(0.0, disengage_remaining - delta)
	shield_open_remaining = maxf(0.0, shield_open_remaining - delta)
	combat_facing = targeting_controller.direction_to_player()
	match definition.enemy_class:
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

func _tick_swordsman(delta: float) -> void:
	var distance := targeting_controller.distance_to_player()
	var hit_frame := attack_controller.tick(delta)
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
	var hit_frame := attack_controller.tick(delta)
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
	var hit_frame := attack_controller.tick(delta)
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
	var hit_frame := attack_controller.tick(delta)
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
	var hit_frame := attack_controller.tick(delta)
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
