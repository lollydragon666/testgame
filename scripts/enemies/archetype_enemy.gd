class_name ArchetypeEnemy
extends EnemyBase

var movement_controller := EnemyMovementController.new()
var targeting_controller := EnemyTargetingController.new()
var attack_controller := EnemyAttackController.new()
var ability_controller := EnemyAbilityController.new()
var drop_controller := EnemyDropController.new()

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
	var hit_frame := attack_controller.tick(delta)
	var distance := targeting_controller.distance_to_player()
	if hit_frame and distance <= definition.attack_range:
		damage_player(definition.attack_damage)
	if attack_controller.is_busy():
		return
	if distance > definition.preferred_distance:
		movement_controller.approach(targeting_controller.direction_to_player(), delta)
	if distance <= definition.attack_range and attack_controller.try_start():
		visual_root.play_attack()
