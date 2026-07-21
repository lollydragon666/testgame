class_name WaveManager
extends Node

enum CombatPhase {
	# Обычные волны обновляют таймер появления врагов.
	WAVES,
	# В фазе босса обычный спавн полностью остановлен.
	BOSS,
}

signal spawn_requested(enemy_kind: StringName, difficulty: float)
signal boss_requested(difficulty: float)
signal wave_changed(wave: int)
signal combat_phase_changed(phase: int)

var wave := 1
## Время, прошедшее с начала текущей волны.
var wave_time := 0.0
## Обратный отсчёт до следующей попытки создать противника.
var spawn_time := 0.0
## Индекс обеспечивает предсказуемое чередование состава внутри волны.
var spawn_index := 0
var running := false
var combat_phase := CombatPhase.WAVES
var active_enemy_count_provider: Callable
var world_config: WorldConfig

func setup(enemy_count_provider: Callable, config: WorldConfig) -> void:
	active_enemy_count_provider = enemy_count_provider
	world_config = config

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

func _process(delta: float) -> void:
	if not running or combat_phase == CombatPhase.BOSS or world_config == null:
		return
	wave_time += delta
	spawn_time -= delta
	if spawn_time <= 0.0:
		# С каждой волной интервал уменьшается, но никогда не проходит ниже minimum_spawn_delay.
		spawn_time = maxf(
			world_config.minimum_spawn_delay,
			world_config.base_spawn_delay - float(wave) * world_config.spawn_delay_reduction_per_wave
		)
		var active_count := 0
		if active_enemy_count_provider.is_valid():
			active_count = int(active_enemy_count_provider.call())
		if active_count < world_config.max_active_enemies:
			spawn_requested.emit(_choose_enemy(), 1.0 + float(wave - 1) * world_config.difficulty_growth_per_wave)
	if wave_time >= world_config.wave_duration:
		wave_time -= world_config.wave_duration
		wave += 1
		# Босс — отдельная фаза, а не фиктивная восьмая волна в HUD.
		if wave > 7:
			combat_phase = CombatPhase.BOSS
			combat_phase_changed.emit(combat_phase)
			boss_requested.emit(1.0)
		else:
			wave_changed.emit(wave)

func _choose_enemy() -> StringName:
	# Повторяющиеся элементы массива задают относительную частоту конкретного вида.
	var roster: Array[StringName]
	if wave == 1:
		roster = [GameIds.ENEMY_BRAWLER, GameIds.ENEMY_BRAWLER, GameIds.ENEMY_MELEE, GameIds.ENEMY_SHOOTER]
	elif wave == 2:
		roster = [GameIds.ENEMY_BRAWLER, GameIds.ENEMY_LIGHTNING_MAGE, GameIds.ENEMY_MELEE, GameIds.ENEMY_SHOOTER, GameIds.ENEMY_BRAWLER, GameIds.ENEMY_LANCER]
	elif wave <= 4:
		roster = [GameIds.ENEMY_BRAWLER, GameIds.ENEMY_MELEE, GameIds.ENEMY_LIGHTNING_MAGE, GameIds.ENEMY_SHOOTER, GameIds.ENEMY_LANCER, GameIds.ENEMY_BRAWLER, GameIds.ENEMY_SHOOTER]
	else:
		roster = [GameIds.ENEMY_BRAWLER, GameIds.ENEMY_LIGHTNING_MAGE, GameIds.ENEMY_LANCER, GameIds.ENEMY_FIRE_MAGE, GameIds.ENEMY_SHOOTER, GameIds.ENEMY_MELEE, GameIds.ENEMY_BRAWLER]
	var enemy_kind := roster[spawn_index % roster.size()]
	spawn_index += 1
	return enemy_kind
