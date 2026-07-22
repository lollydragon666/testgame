class_name WaveManager
extends Node

enum CombatPhase {
	WAVES,
	BOSS,
}

signal spawn_requested(enemy_kind: StringName, difficulty: float, is_elite: bool)
signal boss_requested(enemy_kind: StringName, difficulty: float)
signal wave_changed(current_wave: int, total_waves: int)
signal combat_phase_changed(phase: int)
signal expedition_waves_completed
signal run_failed(reason: String)

var wave := 1
var total_waves := 1
var wave_time := 0.0
var spawn_time := 0.0
var spawn_index := 0
var spawned_in_wave := 0
var remaining_to_spawn := 0
var total_spawned := 0
var remaining_guaranteed_elites := 0
var running := false
var combat_phase := CombatPhase.WAVES
var active_enemy_count_provider: Callable
var active_enemy_kind_count_provider: Callable
var world_config: WorldConfig
var game_content: GameContent

var runtime_difficulty_multiplier := 1.0
var runtime_enemy_count_multiplier := 1.0
var runtime_spawn_rate_multiplier := 1.0
var runtime_elite_chance := 0.0
var runtime_boss_id: StringName
var run_seed := 0

var _rng := RandomNumberGenerator.new()
var _wave_enemy_counts := PackedInt32Array()
var _guaranteed_schedule: Array = []
var _elite_schedule: Array = []
var _spawn_pending := false
var _boss_spawned := false
var _completion_emitted := false
var _opening_spawn_queue: Array[StringName] = []
var _spawned_by_kind: Dictionary[StringName, int] = {}
var _pending_enemy_kind: StringName

func setup(enemy_count_provider: Callable, config: WorldConfig, content: GameContent, enemy_kind_count_provider: Callable = Callable()) -> void:
	active_enemy_count_provider = enemy_count_provider
	active_enemy_kind_count_provider = enemy_kind_count_provider
	world_config = config
	game_content = content

func start_run() -> void:
	var location := game_content.location(&"test_location") if game_content != null else null
	var tier := location.tier_definition(1) if location != null else null
	start_expedition(tier, randi())

func start_expedition(tier_definition: ExpeditionTierDefinition, seed_value: int) -> bool:
	var error_message := _configuration_error(tier_definition)
	if not error_message.is_empty():
		stop()
		run_failed.emit(error_message)
		push_error(error_message)
		return false
	_reset_runtime()
	total_waves = tier_definition.wave_count
	runtime_difficulty_multiplier = tier_definition.difficulty_multiplier
	runtime_enemy_count_multiplier = tier_definition.enemy_count_multiplier
	runtime_spawn_rate_multiplier = tier_definition.spawn_rate_multiplier
	runtime_elite_chance = tier_definition.elite_chance
	runtime_boss_id = tier_definition.boss_id
	run_seed = seed_value if seed_value != 0 else 1
	_rng.seed = run_seed
	_build_spawn_plan(tier_definition.guaranteed_elite_count)
	running = true
	combat_phase_changed.emit(combat_phase)
	_begin_wave(1)
	return true

func stop() -> void:
	running = false
	_spawn_pending = false

func _reset_runtime() -> void:
	wave = 1
	total_waves = 1
	wave_time = 0.0
	spawn_time = 0.0
	spawn_index = 0
	spawned_in_wave = 0
	remaining_to_spawn = 0
	total_spawned = 0
	remaining_guaranteed_elites = 0
	running = false
	combat_phase = CombatPhase.WAVES
	runtime_difficulty_multiplier = 1.0
	runtime_enemy_count_multiplier = 1.0
	runtime_spawn_rate_multiplier = 1.0
	runtime_elite_chance = 0.0
	runtime_boss_id = &""
	run_seed = 0
	_wave_enemy_counts = PackedInt32Array()
	_guaranteed_schedule.clear()
	_elite_schedule.clear()
	_spawn_pending = false
	_boss_spawned = false
	_completion_emitted = false
	_opening_spawn_queue.clear()
	_spawned_by_kind.clear()
	_pending_enemy_kind = &""

func _configuration_error(tier_definition: ExpeditionTierDefinition) -> String:
	if world_config == null or game_content == null:
		return "WaveManager is not configured"
	if tier_definition == null:
		return "Expedition tier definition is missing"
	var errors := tier_definition.validate_definition()
	if not errors.is_empty():
		return "Invalid expedition tier: %s" % ", ".join(errors)
	if tier_definition.wave_count > game_content.wave_count():
		return "Not enough WaveDefinition resources for tier %d" % tier_definition.tier
	for wave_number in range(1, tier_definition.wave_count + 1):
		var definition := game_content.wave(wave_number)
		if definition == null or definition.enemy_roster.is_empty():
			return "Missing or empty WaveDefinition: %d" % wave_number
		for enemy_id in definition.enemy_roster:
			if game_content.enemy(enemy_id) == null:
				return "Wave %d references unknown enemy: %s" % [wave_number, enemy_id]
	if not tier_definition.boss_id.is_empty() and game_content.enemy(tier_definition.boss_id) == null:
		return "Unknown expedition boss: %s" % tier_definition.boss_id
	return ""

func base_spawn_interval_for_wave(wave_number: int) -> float:
	return maxf(
		world_config.minimum_spawn_delay,
		world_config.base_spawn_delay - float(wave_number) * world_config.spawn_delay_reduction_per_wave
	)

func spawn_interval_for_wave(wave_number: int) -> float:
	return maxf(
		world_config.minimum_spawn_delay,
		base_spawn_interval_for_wave(wave_number) / runtime_spawn_rate_multiplier
	)

func base_enemy_count_for_wave(wave_number: int) -> int:
	var definition := game_content.wave(wave_number)
	var duration := definition.duration_override if definition != null and definition.duration_override > 0.0 else world_config.wave_duration
	return maxi(1, roundi(duration / base_spawn_interval_for_wave(wave_number)))

func enemy_count_for_wave(wave_number: int) -> int:
	return maxi(1, roundi(base_enemy_count_for_wave(wave_number) * runtime_enemy_count_multiplier))

func difficulty_for_wave(wave_number: int) -> float:
	var base_difficulty := 1.0 + float(wave_number - 1) * world_config.difficulty_growth_per_wave
	return base_difficulty * runtime_difficulty_multiplier

func boss_difficulty() -> float:
	return runtime_difficulty_multiplier

func elite_schedule_snapshot() -> Array:
	return _elite_schedule.duplicate(true)

func guaranteed_elite_schedule_snapshot() -> Array:
	return _guaranteed_schedule.duplicate(true)

func planned_enemy_counts() -> PackedInt32Array:
	return _wave_enemy_counts.duplicate()

func _build_spawn_plan(requested_guaranteed_elites: int) -> void:
	_wave_enemy_counts.resize(total_waves)
	_guaranteed_schedule.resize(total_waves)
	_elite_schedule.resize(total_waves)
	var total_enemies := 0
	for wave_index in total_waves:
		var count := enemy_count_for_wave(wave_index + 1)
		_wave_enemy_counts[wave_index] = count
		total_enemies += count
		_guaranteed_schedule[wave_index] = PackedByteArray()
		_guaranteed_schedule[wave_index].resize(count)
	var guaranteed_count := mini(requested_guaranteed_elites, total_enemies)
	var guaranteed_per_wave := PackedInt32Array()
	guaranteed_per_wave.resize(total_waves)
	var start_wave := _rng.randi_range(0, total_waves - 1)
	for _guaranteed_index in guaranteed_count:
		var selected_wave := -1
		var smallest_allocation := 2147483647
		for offset in total_waves:
			var wave_index := (start_wave + offset) % total_waves
			if guaranteed_per_wave[wave_index] >= _wave_enemy_counts[wave_index]:
				continue
			if guaranteed_per_wave[wave_index] < smallest_allocation:
				smallest_allocation = guaranteed_per_wave[wave_index]
				selected_wave = wave_index
		if selected_wave >= 0:
			guaranteed_per_wave[selected_wave] += 1
			start_wave = (selected_wave + 1) % total_waves
	for wave_index in total_waves:
		var slot_order: Array[int] = []
		for slot in _wave_enemy_counts[wave_index]:
			slot_order.append(slot)
		_shuffle_int_array(slot_order)
		for quota_index in guaranteed_per_wave[wave_index]:
			_guaranteed_schedule[wave_index][slot_order[quota_index]] = 1
		var elite_slots: PackedByteArray = _guaranteed_schedule[wave_index].duplicate()
		for slot in elite_slots.size():
			if elite_slots[slot] == 0 and _rng.randf() < runtime_elite_chance:
				elite_slots[slot] = 1
		_elite_schedule[wave_index] = elite_slots
	remaining_guaranteed_elites = guaranteed_count

func _shuffle_int_array(values: Array[int]) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temporary := values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary

func _begin_wave(wave_number: int) -> void:
	wave = wave_number
	wave_time = 0.0
	spawned_in_wave = 0
	remaining_to_spawn = _wave_enemy_counts[wave - 1]
	_spawned_by_kind.clear()
	_build_opening_spawn_queue(game_content.wave(wave))
	spawn_time = world_config.first_spawn_delay
	wave_changed.emit(wave, total_waves)

func _physics_process(delta: float) -> void:
	if not running:
		return
	wave_time += delta
	spawn_time -= delta
	if combat_phase == CombatPhase.BOSS:
		if not _boss_spawned and not _spawn_pending and spawn_time <= 0.0:
			_spawn_pending = true
			boss_requested.emit(runtime_boss_id, boss_difficulty())
		return
	if remaining_to_spawn > 0:
		if spawn_time <= 0.0 and not _spawn_pending and _active_enemy_count() < world_config.max_active_enemies:
			_request_next_spawn()
		return
	if not _spawn_pending and _active_enemy_count() == 0:
		_finish_wave()

func _request_next_spawn() -> void:
	var definition := game_content.wave(wave)
	var enemy_kind := _select_enemy_kind(definition)
	if enemy_kind.is_empty():
		spawn_time = world_config.minimum_spawn_delay
		return
	var is_elite: bool = _elite_schedule[wave - 1][spawned_in_wave] == 1
	_pending_enemy_kind = enemy_kind
	_spawn_pending = true
	spawn_requested.emit(enemy_kind, difficulty_for_wave(wave), is_elite)

func report_spawn_result(success: bool) -> void:
	if not running or combat_phase != CombatPhase.WAVES or not _spawn_pending:
		return
	_spawn_pending = false
	if not success:
		if not _pending_enemy_kind.is_empty():
			_opening_spawn_queue.push_front(_pending_enemy_kind)
		_pending_enemy_kind = &""
		spawn_time = world_config.minimum_spawn_delay
		return
	if _guaranteed_schedule[wave - 1][spawned_in_wave] == 1:
		remaining_guaranteed_elites = maxi(0, remaining_guaranteed_elites - 1)
	spawned_in_wave += 1
	remaining_to_spawn -= 1
	total_spawned += 1
	_spawned_by_kind[_pending_enemy_kind] = _spawned_by_kind.get(_pending_enemy_kind, 0) + 1
	_pending_enemy_kind = &""
	spawn_index += 1
	spawn_time = spawn_interval_for_wave(wave)

func report_boss_spawn_result(success: bool) -> void:
	if not running or combat_phase != CombatPhase.BOSS or not _spawn_pending:
		return
	_spawn_pending = false
	_boss_spawned = success
	if not success:
		spawn_time = world_config.minimum_spawn_delay

func notify_boss_defeated() -> void:
	if running and combat_phase == CombatPhase.BOSS and _boss_spawned:
		_complete_expedition()

func _finish_wave() -> void:
	if wave < total_waves:
		_begin_wave(wave + 1)
		return
	if runtime_boss_id.is_empty():
		_complete_expedition()
		return
	combat_phase = CombatPhase.BOSS
	spawn_time = world_config.minimum_spawn_delay
	_boss_spawned = false
	_spawn_pending = false
	combat_phase_changed.emit(combat_phase)

func _complete_expedition() -> void:
	if _completion_emitted:
		return
	_completion_emitted = true
	running = false
	_spawn_pending = false
	expedition_waves_completed.emit()

func _active_enemy_count() -> int:
	return int(active_enemy_count_provider.call()) if active_enemy_count_provider.is_valid() else 0

func _active_enemy_kind_count(enemy_id: StringName) -> int:
	return int(active_enemy_kind_count_provider.call(enemy_id)) if active_enemy_kind_count_provider.is_valid() else 0

func _build_opening_spawn_queue(definition: WaveDefinition) -> void:
	_opening_spawn_queue.clear()
	if definition == null:
		return
	var group_ids := definition.sequence_group_ids if not definition.sequence_group_ids.is_empty() else definition.guaranteed_group_ids
	for group_id in group_ids:
		var group := game_content.enemy_spawn_group(group_id)
		if group != null:
			_opening_spawn_queue.append_array(group.build_spawn_list(_rng, wave))
	if _opening_spawn_queue.size() > remaining_to_spawn:
		_opening_spawn_queue.resize(remaining_to_spawn)

func _select_enemy_kind(definition: WaveDefinition) -> StringName:
	while not _opening_spawn_queue.is_empty():
		var opening_id: StringName = _opening_spawn_queue.pop_front()
		if _enemy_allowed(definition, opening_id):
			return opening_id
	var candidates: Array[StringName] = []
	var weights: Array[float] = []
	var total_weight := 0.0
	for enemy_id in definition.enemy_roster:
		if candidates.has(enemy_id) or not _enemy_allowed(definition, enemy_id):
			continue
		var weight := maxf(0.0, definition.spawn_weights.get(enemy_id, 1.0))
		if weight <= 0.0:
			continue
		candidates.append(enemy_id)
		weights.append(weight)
		total_weight += weight
	if candidates.is_empty():
		return &""
	var roll := _rng.randf() * total_weight
	for index in candidates.size():
		roll -= weights[index]
		if roll <= 0.0:
			return candidates[index]
	return candidates.back()

func _enemy_allowed(definition: WaveDefinition, enemy_id: StringName) -> bool:
	var alive_limit: int = definition.maximum_alive.get(enemy_id, 0)
	if alive_limit > 0 and _active_enemy_kind_count(enemy_id) >= alive_limit:
		return false
	var wave_limit: int = definition.maximum_per_wave.get(enemy_id, 0)
	if wave_limit > 0 and _spawned_by_kind.get(enemy_id, 0) >= wave_limit:
		return false
	return true
