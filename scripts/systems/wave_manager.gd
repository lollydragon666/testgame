class_name WaveManager
extends Node

enum CombatPhase {
	WAVES,
	BOSS,
}

signal spawn_requested(enemy_kind: StringName, difficulty: float)
signal boss_requested(enemy_kind: StringName, difficulty: float)
signal wave_changed(wave: int)
signal combat_phase_changed(phase: int)

var wave := 1
var wave_time := 0.0
var spawn_time := 0.0
var spawn_index := 0
var running := false
var combat_phase := CombatPhase.WAVES
var active_enemy_count_provider: Callable
var world_config: WorldConfig
var game_content: GameContent

func setup(enemy_count_provider: Callable, config: WorldConfig, content: GameContent) -> void:
	active_enemy_count_provider = enemy_count_provider
	world_config = config
	game_content = content

func start_run() -> void:
	wave = 1
	wave_time = 0.0
	spawn_time = world_config.first_spawn_delay
	spawn_index = 0
	running = true
	combat_phase = CombatPhase.WAVES
	combat_phase_changed.emit(combat_phase)
	wave_changed.emit(wave)

func stop() -> void:
	running = false

func _physics_process(delta: float) -> void:
	if not running or combat_phase == CombatPhase.BOSS or world_config == null or game_content == null:
		return
	var definition := game_content.wave(wave)
	if definition == null or definition.enemy_roster.is_empty():
		push_error("Missing or empty WaveDefinition: %d" % wave)
		stop()
		return

	wave_time += delta
	spawn_time -= delta
	if spawn_time <= 0.0:
		spawn_time = maxf(
			world_config.minimum_spawn_delay,
			world_config.base_spawn_delay - float(wave) * world_config.spawn_delay_reduction_per_wave
		)
		var active_count := 0
		if active_enemy_count_provider.is_valid():
			active_count = int(active_enemy_count_provider.call())
		if active_count < world_config.max_active_enemies:
			spawn_requested.emit(_choose_enemy(definition), 1.0 + float(wave - 1) * world_config.difficulty_growth_per_wave)

	var duration := definition.duration_override if definition.duration_override > 0.0 else world_config.wave_duration
	if wave_time < duration:
		return
	wave_time -= duration
	if not definition.boss_enemy_id.is_empty():
		combat_phase = CombatPhase.BOSS
		combat_phase_changed.emit(combat_phase)
		boss_requested.emit(definition.boss_enemy_id, 1.0)
		return
	wave += 1
	wave_changed.emit(wave)

func _choose_enemy(definition: WaveDefinition) -> StringName:
	# Повторения в roster задают вес конкретного вида врага.
	var enemy_kind := definition.enemy_roster[spawn_index % definition.enemy_roster.size()]
	spawn_index += 1
	return enemy_kind
