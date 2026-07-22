extends SceneTree

const CONTENT: GameContent = preload("res://resources/game_content.tres")
const CONFIG: WorldConfig = preload("res://resources/world_config.tres")
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)

func _tier(number: int) -> ExpeditionTierDefinition:
	return CONTENT.location(&"test_location").tier_definition(number)

func _manager(active_count: Array[int]) -> WaveManager:
	var manager := WaveManager.new()
	manager.setup(func() -> int: return active_count[0], CONFIG, CONTENT)
	root.add_child(manager)
	return manager

func _count_elites(schedule: Array) -> int:
	var count := 0
	for wave_slots in schedule:
		for slot in wave_slots:
			count += int(slot)
	return count

func _waves_with_elites(schedule: Array) -> int:
	var count := 0
	for wave_slots in schedule:
		if wave_slots.has(1):
			count += 1
	return count

func _run() -> void:
	var active: Array[int] = [0]
	var manager := _manager(active)
	_require(manager.start_expedition(_tier(1), 101), "Tier 1 did not start")
	_require(manager.total_waves == 2, "Tier 1 did not use two waves")
	_require(manager.start_expedition(_tier(3), 101), "Tier 3 did not start")
	_require(manager.total_waves == 3, "Tier 3 did not use three waves")
	_require(manager.start_expedition(_tier(8), 101), "Tier 8 did not start")
	_require(manager.total_waves == 5, "Tier 8 did not use five waves")
	_require(manager.start_expedition(_tier(10), 101), "Tier 10 did not start")
	_require(manager.total_waves == 3 and manager.runtime_boss_id == GameIds.ENEMY_BOSS, "Tier 10 did not configure three waves and boss")
	for tier_number in range(1, 10):
		_require(_tier(tier_number).boss_id.is_empty(), "Tier %d unexpectedly has a boss" % tier_number)

	manager.start_expedition(_tier(3), 222)
	var wave_events: Array[Vector2i] = []
	manager.wave_changed.connect(func(current: int, total: int): wave_events.append(Vector2i(current, total)))
	manager.start_expedition(_tier(3), 222)
	_require(wave_events[0] == Vector2i(1, 3), "wave_changed did not include current and total waves")
	var base_count := manager.base_enemy_count_for_wave(1)
	_require(manager.enemy_count_for_wave(1) == maxi(1, roundi(base_count * _tier(3).enemy_count_multiplier)), "Enemy multiplier was not applied exactly once")
	manager.start_expedition(_tier(8), 223)
	_require(manager.spawn_interval_for_wave(1) < manager.base_spawn_interval_for_wave(1), "Spawn rate multiplier did not reduce interval")
	manager.start_expedition(_tier(3), 222)
	var base_difficulty := 1.0 + CONFIG.difficulty_growth_per_wave
	_require(is_equal_approx(manager.difficulty_for_wave(2), base_difficulty * _tier(3).difficulty_multiplier), "Difficulty multiplier was not applied exactly once")

	manager.start_expedition(_tier(10), 333)
	_require(is_equal_approx(manager.boss_difficulty(), _tier(10).difficulty_multiplier), "Boss did not receive tier difficulty")
	var guaranteed := manager.guaranteed_elite_schedule_snapshot()
	_require(_count_elites(guaranteed) == _tier(10).guaranteed_elite_count, "Guaranteed elite count is incorrect")
	_require(_waves_with_elites(guaranteed) > 1, "Guaranteed elites were not distributed across waves")

	var custom := _tier(8).duplicate(true) as ExpeditionTierDefinition
	custom.guaranteed_elite_count = 0
	custom.elite_chance = 0.0
	manager.start_expedition(custom, 444)
	_require(_count_elites(manager.elite_schedule_snapshot()) == 0, "elite_chance zero created elites")
	custom.elite_chance = 1.0
	manager.start_expedition(custom, 444)
	var planned_total := 0
	for count in manager.planned_enemy_counts():
		planned_total += count
	_require(_count_elites(manager.elite_schedule_snapshot()) == planned_total, "elite_chance one did not make every spawn elite")

	custom.elite_chance = 0.45
	custom.guaranteed_elite_count = 5
	manager.start_expedition(custom, 777)
	var same_seed_schedule := manager.elite_schedule_snapshot()
	manager.start_expedition(custom, 777)
	_require(manager.elite_schedule_snapshot() == same_seed_schedule, "Same seed changed elite schedule")
	manager.start_expedition(custom, 778)
	_require(manager.elite_schedule_snapshot() != same_seed_schedule, "Different seed did not change elite schedule")

	var tier_copy := _tier(1).duplicate(true) as ExpeditionTierDefinition
	var tier_copy_values := [tier_copy.wave_count, tier_copy.difficulty_multiplier, tier_copy.enemy_count_multiplier, tier_copy.spawn_rate_multiplier, tier_copy.guaranteed_elite_count, tier_copy.elite_chance, tier_copy.boss_id]
	var config_values := [CONFIG.wave_duration, CONFIG.max_active_enemies, CONFIG.base_spawn_delay, CONFIG.minimum_spawn_delay, CONFIG.difficulty_growth_per_wave]
	manager.start_expedition(tier_copy, 909)
	_require(tier_copy_values == [tier_copy.wave_count, tier_copy.difficulty_multiplier, tier_copy.enemy_count_multiplier, tier_copy.spawn_rate_multiplier, tier_copy.guaranteed_elite_count, tier_copy.elite_chance, tier_copy.boss_id], "WaveManager mutated ExpeditionTierDefinition")
	_require(config_values == [CONFIG.wave_duration, CONFIG.max_active_enemies, CONFIG.base_spawn_delay, CONFIG.minimum_spawn_delay, CONFIG.difficulty_growth_per_wave], "WaveManager mutated WorldConfig")

	var spawn_events: Array = []
	var completions: Array[int] = [0]
	manager.spawn_requested.connect(func(kind: StringName, difficulty: float, elite: bool):
		spawn_events.append([manager.wave, kind, difficulty, elite])
		active[0] += 1
		manager.report_spawn_result(true)
	)
	manager.expedition_waves_completed.connect(func(): completions[0] += 1)
	manager.start_expedition(tier_copy, 909)
	while manager.running and manager.combat_phase == WaveManager.CombatPhase.WAVES:
		manager._physics_process(10.0)
		if manager.remaining_to_spawn > 0:
			active[0] = 0
		elif active[0] > 0:
			manager._physics_process(10.0)
			_require(completions[0] == 0, "Non-boss tier completed while enemies were alive")
			active[0] = 0
	_require(completions[0] == 1, "Non-boss tier did not complete exactly once")
	manager._physics_process(10.0)
	_require(completions[0] == 1, "Completion signal was emitted twice")

	var boss_requested_count: Array[int] = [0]
	manager.boss_requested.connect(func(kind: StringName, difficulty: float):
		boss_requested_count[0] += 1
		_require(kind == GameIds.ENEMY_BOSS, "Wrong boss was requested")
		_require(is_equal_approx(difficulty, _tier(10).difficulty_multiplier), "Boss request used wrong difficulty")
		manager.report_boss_spawn_result(true)
	)
	active[0] = 0
	manager.start_expedition(_tier(10), 1001)
	while manager.running and manager.combat_phase == WaveManager.CombatPhase.WAVES:
		manager._physics_process(10.0)
		active[0] = 0
	manager._physics_process(10.0)
	_require(boss_requested_count[0] == 1, "Boss was not requested exactly once")
	_require(manager.running, "Boss tier completed before boss death")
	manager.notify_boss_defeated()
	_require(not manager.running, "Boss tier did not complete after boss death")
	_require(completions[0] == 2, "Boss completion signal count is incorrect")

	manager.start_expedition(_tier(10), 12)
	manager.start_expedition(_tier(1), 13)
	_require(manager.total_waves == 2, "Restart retained tier 10 wave count")
	_require(manager.runtime_boss_id.is_empty(), "Restart retained tier 10 boss")
	_require(is_equal_approx(manager.runtime_difficulty_multiplier, _tier(1).difficulty_multiplier), "Restart retained tier 10 difficulty")
	_require(is_equal_approx(manager.runtime_elite_chance, _tier(1).elite_chance), "Restart retained tier 10 elite chance")

	var invalid_boss := _tier(10).duplicate(true) as ExpeditionTierDefinition
	invalid_boss.boss_id = &"missing_boss"
	_require(not manager._configuration_error(invalid_boss).is_empty(), "Invalid boss ID was accepted")

	var player_scene := preload("res://scenes/player/player.tscn")
	var enemy_scene := CONTENT.enemy(GameIds.ENEMY_MELEE).scene
	var player := player_scene.instantiate() as PlayerHero
	player.configure_world(CONFIG)
	player.configure_content(CONTENT)
	root.add_child(player)
	var elite_enemy := enemy_scene.instantiate() as EnemyBase
	elite_enemy.setup(player, Vector2.ZERO, 1.5, CONFIG, CONTENT.enemy(GameIds.ENEMY_MELEE), true)
	_require(elite_enemy.is_elite, "Elite flag was not applied")
	_require(is_equal_approx(elite_enemy.max_health, CONTENT.enemy(GameIds.ENEMY_MELEE).max_health * 1.5 * CONFIG.elite_health_multiplier), "Elite health multiplier is incorrect")
	var boss_enemy := CONTENT.enemy(GameIds.ENEMY_BOSS).scene.instantiate() as EnemyBase
	boss_enemy.setup(player, Vector2.ZERO, 2.0, CONFIG, CONTENT.enemy(GameIds.ENEMY_BOSS), true)
	_require(not boss_enemy.is_elite, "Boss became elite")
	elite_enemy.free()
	boss_enemy.free()
	manager.queue_free()
	player.queue_free()
	await process_frame

	if failed:
		quit(1)
	else:
		print("WAVE MANAGER TIERS PASS")
		quit()
