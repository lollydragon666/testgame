class_name CombatBenchmark
extends Node

const BENCHMARK_SEED := 123456
const DEFAULT_ENEMY_COUNT := 100
const DEFAULT_PROJECTILE_COUNT := 100
const DEFAULT_SAMPLE_SECONDS := 3.0
const WARMUP_PHYSICS_FRAMES := 30
const MINIMUM_SAMPLE_FRAMES := 60
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CONTENT: GameContent = preload("res://resources/game_content.tres")
const BASE_CONFIG: WorldConfig = preload("res://resources/world_config.tres")

var _random := RandomNumberGenerator.new()
var _world_state: WorldState
var _player: PlayerHero
var _entities_root: Node2D
var _projectiles_root: Node2D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	var enemy_count: int = options["enemies"]
	var projectile_count: int = options["projectiles"]
	var sample_seconds: float = options["duration"]
	_random.seed = BENCHMARK_SEED

	var config := BASE_CONFIG.duplicate(true) as WorldConfig
	config.max_active_enemies = maxi(config.max_active_enemies, enemy_count)
	config.max_enemy_projectiles = maxi(config.max_enemy_projectiles, projectile_count)

	_world_state = WorldState.new()
	_world_state.name = "WorldState"
	_world_state.configure(config)
	add_child(_world_state)

	_entities_root = Node2D.new()
	_entities_root.name = "Entities"
	_entities_root.y_sort_enabled = true
	add_child(_entities_root)
	_projectiles_root = Node2D.new()
	_projectiles_root.name = "Projectiles"
	add_child(_projectiles_root)

	_player = PLAYER_SCENE.instantiate() as PlayerHero
	_player.configure_world(config)
	_player.configure_content(CONTENT)
	_player.world_position = Vector2.ZERO
	_entities_root.add_child(_player)
	_player.set_combat_registry(_world_state)
	_player.set_physics_process(false)
	_player.invulnerability = sample_seconds + 10.0

	_spawn_enemies(enemy_count, config)
	_spawn_projectiles(projectile_count)
	for _frame in WARMUP_PHYSICS_FRAMES:
		await get_tree().physics_frame

	var sample_frames := maxi(MINIMUM_SAMPLE_FRAMES, ceili(sample_seconds * Engine.physics_ticks_per_second))
	var fps_total := 0.0
	var minimum_fps := INF
	var physics_ms_total := 0.0
	var maximum_physics_ms := 0.0
	var previous_tick := Time.get_ticks_usec()
	for _frame in sample_frames:
		await get_tree().physics_frame
		var current_tick := Time.get_ticks_usec()
		var wall_frame_ms := maxf(0.001, float(current_tick - previous_tick) / 1000.0)
		previous_tick = current_tick
		var measured_fps := 1000.0 / wall_frame_ms
		var physics_frame_ms := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		fps_total += measured_fps
		minimum_fps = minf(minimum_fps, measured_fps)
		physics_ms_total += physics_frame_ms
		maximum_physics_ms = maxf(maximum_physics_ms, physics_frame_ms)

	var result := {
		"seed": BENCHMARK_SEED,
		"duration_seconds": sample_seconds,
		"sample_frames": sample_frames,
		"average_fps": snappedf(fps_total / float(sample_frames), 0.01),
		"minimum_fps": snappedf(minimum_fps, 0.01),
		"average_physics_ms": snappedf(physics_ms_total / float(sample_frames), 0.001),
		"maximum_physics_ms": snappedf(maximum_physics_ms, 0.001),
		"enemies": _world_state.enemy_count(),
		"enemy_projectiles": _world_state.enemy_projectile_count(),
		"player_projectiles": _world_state.player_projectile_count(),
		"pickups": _world_state.pickup_count(),
		"spatial_cells": _world_state.spatial_cell_count(),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	}
	print("COMBAT_BENCHMARK %s" % JSON.stringify(result))
	get_tree().quit()


func _spawn_enemies(count: int, config: WorldConfig) -> void:
	var definitions: Array[EnemyDefinition] = []
	for definition in CONTENT.enemies:
		if definition != null and not definition.is_boss:
			definitions.append(definition)
	for index in count:
		var definition := definitions[index % definitions.size()]
		var enemy := definition.scene.instantiate() as EnemyBase
		var angle := float(index) * 2.399963229728653
		var ring := 360.0 + float(index % 20) * 52.0
		var spawn_position := Vector2.from_angle(angle) * ring
		enemy.setup(_player, spawn_position, 1.0, config, definition, false)
		_world_state.register_enemy(enemy)
		_entities_root.add_child(enemy)


func _spawn_projectiles(count: int) -> void:
	for index in count:
		var angle := _random.randf_range(0.0, TAU)
		var origin := Vector2.from_angle(angle) * _random.randf_range(900.0, 2400.0)
		# Тангенциальное направление не даёт снарядам сразу исчезнуть при попадании в героя.
		var direction := Vector2.from_angle(angle + PI * 0.5)
		var projectile := EnemyProjectile.new()
		projectile.setup(_player, origin, direction, 0.0)
		_world_state.register_enemy_projectile(projectile)
		_projectiles_root.add_child(projectile)


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var result := {
		"enemies": DEFAULT_ENEMY_COUNT,
		"projectiles": DEFAULT_PROJECTILE_COUNT,
		"duration": DEFAULT_SAMPLE_SECONDS,
	}
	for argument in arguments:
		if argument.begins_with("--benchmark-enemies="):
			result["enemies"] = maxi(0, argument.get_slice("=", 1).to_int())
		elif argument.begins_with("--benchmark-projectiles="):
			result["projectiles"] = maxi(0, argument.get_slice("=", 1).to_int())
		elif argument.begins_with("--benchmark-duration="):
			result["duration"] = maxf(1.0, argument.get_slice("=", 1).to_float())
	return result
