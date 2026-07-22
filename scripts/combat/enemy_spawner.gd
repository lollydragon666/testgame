class_name EnemySpawner
extends Node

signal enemy_died(enemy: EnemyBase, experience_value: int)
signal projectile_requested(origin: Vector2, direction: Vector2, damage: float)
signal arrow_requested(origin: Vector2, direction: Vector2, damage: float)
signal spell_requested(spell_kind: StringName, origin: Vector2, direction: Vector2, damage: float)

var game_content: GameContent
var world_config: WorldConfig
var world_state: WorldState
var player: PlayerHero
var world_root: Node2D
var random := RandomNumberGenerator.new()

func configure(
	content: GameContent,
	config: WorldConfig,
	state: WorldState,
	player_target: PlayerHero,
	parent: Node2D
) -> void:
	game_content = content
	world_config = config
	world_state = state
	player = player_target
	world_root = parent

func configure_seed(seed_value: int) -> void:
	random.seed = seed_value if seed_value != 0 else 1

func spawn(enemy_id: StringName, difficulty: float = 1.0, requested_position := Vector2.INF, is_elite := false) -> EnemyBase:
	if not _is_configured() or world_state.enemy_count() >= world_config.max_active_enemies:
		return null
	var definition := game_content.enemy(enemy_id)
	if definition == null or definition.scene == null:
		push_warning("Unknown enemy ID: %s" % enemy_id)
		return null
	var spawn_position: Vector2 = requested_position
	if not spawn_position.is_finite():
		spawn_position = _find_spawn_position(definition.spawn_distance, definition.collision_radius)
	if not spawn_position.is_finite() or not world_state.is_enemy_spawn_clear(
		spawn_position,
		definition.collision_radius,
		player.world_position,
		player.collision_radius,
		world_config.enemy_spawn_clearance
	):
		return null
	var enemy := definition.scene.instantiate() as EnemyBase
	if enemy == null:
		push_error("Enemy scene does not contain EnemyBase: %s" % enemy_id)
		return null
	enemy.setup(player, spawn_position, difficulty, world_config, definition, is_elite)
	enemy.died.connect(_relay_enemy_died)
	enemy.projectile_requested.connect(_relay_projectile)
	enemy.arrow_requested.connect(_relay_arrow)
	enemy.spell_requested.connect(_relay_spell)
	world_state.register_enemy(enemy)
	world_root.add_child(enemy)
	return enemy

func spawn_many(enemy_id: StringName, count: int, difficulty: float = 1.0) -> int:
	var spawned := 0
	var allowed := mini(maxi(0, count), world_config.max_active_enemies - world_state.enemy_count())
	for _index in allowed:
		if spawn(enemy_id, difficulty) != null:
			spawned += 1
	return spawned

func _find_spawn_position(distance: float, spawn_radius: float) -> Vector2:
	var map_limit := maxf(0.0, world_config.world_limit - world_config.safe_spawn_margin)
	var minimum_distance := distance * 0.85
	for _attempt in 16:
		var candidate := player.world_position + Vector2.from_angle(random.randf_range(0.0, TAU)) * distance
		candidate = candidate.clamp(Vector2.ONE * -map_limit, Vector2.ONE * map_limit)
		if candidate.distance_to(player.world_position) >= minimum_distance and world_state.is_enemy_spawn_clear(
			candidate,
			spawn_radius,
			player.world_position,
			player.collision_radius,
			world_config.enemy_spawn_clearance
		):
			return candidate
	return Vector2.INF

func _is_configured() -> bool:
	return game_content != null and world_config != null and world_state != null and player != null and world_root != null

func _relay_enemy_died(enemy: EnemyBase, experience_value: int) -> void:
	enemy_died.emit(enemy, experience_value)

func _relay_projectile(origin: Vector2, direction: Vector2, damage: float) -> void:
	projectile_requested.emit(origin, direction, damage)

func _relay_arrow(origin: Vector2, direction: Vector2, damage: float) -> void:
	arrow_requested.emit(origin, direction, damage)

func _relay_spell(spell_kind: StringName, origin: Vector2, direction: Vector2, damage: float) -> void:
	spell_requested.emit(spell_kind, origin, direction, damage)
