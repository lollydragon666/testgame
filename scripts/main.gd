extends Node2D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const LOCATION_SCENE := preload("res://scenes/world/location.tscn")
const BRAWLER_ENEMY_SCENE := preload("res://scenes/enemies/brawler_enemy.tscn")
const MELEE_ENEMY_SCENE := preload("res://scenes/enemies/melee_enemy.tscn")
const SHOOTER_ENEMY_SCENE := preload("res://scenes/enemies/shooter_enemy.tscn")
const LANCER_ENEMY_SCENE := preload("res://scenes/enemies/lancer_enemy.tscn")
const LIGHTNING_MAGE_SCENE := preload("res://scenes/enemies/lightning_mage.tscn")
const FIRE_MAGE_SCENE := preload("res://scenes/enemies/fire_mage.tscn")
const BOSS_ENEMY_SCENE := preload("res://scenes/enemies/boss_enemy.tscn")
## Один ресурс баланса передаётся всем системам, чтобы границы и интервалы не расходились.
const WORLD_CONFIG: WorldConfig = preload("res://resources/world_config.tres")

var location: GameLocation
var player: PlayerHero
var wave_manager: WaveManager
var ui: GameUI
@onready var floor_layer: Node2D = $FloorLayer
## Герой, враги, предметы и пропсы находятся здесь и сортируются по Y.
@onready var world_root: Node2D = $WorldRoot
## Снаряды вынесены из Y-sort мира, чтобы их отрисовка не зависела от ног персонажей.
@onready var projectiles_root: Node2D = $Projectiles
## Типизированные коллекции активных целей для боевых проверок без group scan.
var world_state: WorldState
## Фабрика врагов: GameIds связывает вид противника с его PackedScene.
var enemy_scenes: Dictionary[StringName, PackedScene] = {
	GameIds.ENEMY_BRAWLER: BRAWLER_ENEMY_SCENE,
	GameIds.ENEMY_MELEE: MELEE_ENEMY_SCENE,
	GameIds.ENEMY_SHOOTER: SHOOTER_ENEMY_SCENE,
	GameIds.ENEMY_LANCER: LANCER_ENEMY_SCENE,
	GameIds.ENEMY_LIGHTNING_MAGE: LIGHTNING_MAGE_SCENE,
	GameIds.ENEMY_FIRE_MAGE: FIRE_MAGE_SCENE,
	GameIds.ENEMY_BOSS: BOSS_ENEMY_SCENE,
}
var running := false

func _ready() -> void:
	randomize()
	world_state = WorldState.new()
	world_state.name = "WorldState"
	add_child(world_state)

	location = LOCATION_SCENE.instantiate() as GameLocation
	location.name = "Location"
	location.configure(WORLD_CONFIG, world_root)
	floor_layer.add_child(location)
	location.potion_requested.connect(_spawn_potion)
	_register_location_destructibles()

	player = PLAYER_SCENE.instantiate() as PlayerHero
	player.name = "Player"
	player.configure_world(WORLD_CONFIG)
	world_root.add_child(player)
	player.set_combat_registry(world_state)
	player.health_changed.connect(_on_health_changed)
	player.experience_changed.connect(_on_experience_changed)
	player.level_up_requested.connect(_on_level_up)
	player.magic_cast_requested.connect(_spawn_player_magic)
	player.magic_changed.connect(_on_magic_changed)
	player.died.connect(_on_player_died)
	player.set_gameplay_active(false)

	wave_manager = WaveManager.new()
	wave_manager.name = "WaveManager"
	add_child(wave_manager)
	wave_manager.setup(world_state.enemy_count, WORLD_CONFIG)
	wave_manager.spawn_requested.connect(_spawn_enemy)
	wave_manager.boss_requested.connect(_start_boss)
	wave_manager.wave_changed.connect(_on_wave_changed)
	wave_manager.combat_phase_changed.connect(_on_combat_phase_changed)

	ui = GameUI.new()
	ui.name = "UI"
	add_child(ui)
	ui.start_requested.connect(_start_run)
	ui.upgrade_selected.connect(_apply_upgrade)
	ui.set_health(player.health, player.max_health)
	ui.set_experience(player.experience, player.experience_required, player.level)
	ui.set_wave(1)
	ui.set_magic(&"", 0)

func _start_run() -> void:
	get_tree().paused = false
	_clear_runtime_nodes()
	location.regenerate()
	_register_location_destructibles()
	player.reset_run()
	player.set_gameplay_active(true)
	running = true
	wave_manager.start_run()
	ui.show_game()

func _clear_runtime_nodes() -> void:
	# Группы используются только для редкой массовой очистки между забегами.
	for group_name in [&"enemy", &"enemy_projectile", &"player_magic_projectile", &"pickup"]:
		_clear_group(group_name)
	world_state.clear_runtime()

func _clear_group(group_name: StringName) -> void:
	for node in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(node):
			node.set_process(false)
			node.queue_free()

func _spawn_enemy(enemy_kind: StringName, difficulty: float) -> void:
	if not running or world_state.enemy_count() >= WORLD_CONFIG.max_active_enemies:
		return
	if not enemy_scenes.has(enemy_kind):
		push_error("Unknown enemy kind: %s" % enemy_kind)
		return
	var enemy_scene: PackedScene = enemy_scenes[enemy_kind]
	var enemy: EnemyBase = enemy_scene.instantiate() as EnemyBase
	if enemy == null:
		push_error("Enemy scene does not contain EnemyBase: %s" % enemy_kind)
		return
	var spawn_distance := 520.0 if enemy_kind == GameIds.ENEMY_BOSS else 620.0
	var spawn_position := _find_spawn_position(spawn_distance)
	enemy.setup(player, spawn_position, difficulty, WORLD_CONFIG)
	enemy.died.connect(_on_enemy_died)
	enemy.projectile_requested.connect(_spawn_projectile)
	enemy.spell_requested.connect(_spawn_enemy_spell)
	world_state.register_enemy(enemy)
	world_root.add_child(enemy)

func _find_spawn_position(distance: float) -> Vector2:
	# Несколько попыток сохраняют нужную дистанцию даже рядом с краем ограниченного мира.
	var map_limit := maxf(0.0, WORLD_CONFIG.world_limit - WORLD_CONFIG.safe_spawn_margin)
	var minimum_distance := distance * 0.85
	for _attempt in 16:
		var candidate := player.world_position + Vector2.from_angle(randf_range(0.0, TAU)) * distance
		candidate = candidate.clamp(Vector2.ONE * -map_limit, Vector2.ONE * map_limit)
		if candidate.distance_to(player.world_position) >= minimum_distance:
			return candidate
	var fallback_direction := -player.world_position.normalized()
	if fallback_direction.is_zero_approx():
		fallback_direction = Vector2.RIGHT
	return (player.world_position + fallback_direction * distance).clamp(
		Vector2.ONE * -map_limit,
		Vector2.ONE * map_limit
	)

func _spawn_projectile(origin: Vector2, direction: Vector2, damage: float) -> void:
	if not running:
		return
	var projectile := EnemyProjectile.new()
	projectile.setup(player, origin, direction, damage)
	_register_enemy_projectile(projectile)
	projectiles_root.add_child(projectile)

func _spawn_player_magic(spell_kind: StringName, origin: Vector2, direction: Vector2, damage: float, spell_level: int) -> void:
	if not running:
		return
	var projectile := PlayerMagicProjectile.new()
	projectile.setup(spell_kind, origin, direction, damage, spell_level, world_state)
	projectiles_root.add_child(projectile)

func _spawn_enemy_spell(spell_kind: StringName, origin: Vector2, direction: Vector2, damage: float) -> void:
	if not running:
		return
	var projectile := EnemySpellProjectile.new()
	projectile.setup(player, spell_kind, origin, direction, damage)
	_register_enemy_projectile(projectile)
	projectiles_root.add_child(projectile)

func _register_enemy_projectile(projectile: DeflectableProjectile) -> void:
	world_state.register_enemy_projectile(projectile)

func _register_location_destructibles() -> void:
	world_state.replace_destructibles(location.generated_props)

func _spawn_potion(spawn_position: Vector2) -> void:
	if not running:
		return
	var potion := GamePickup.new()
	potion.setup(player, GameIds.PICKUP_POTION, spawn_position, 28)
	world_root.add_child(potion)

func _spawn_experience(spawn_position: Vector2, amount: int) -> void:
	var remaining := amount
	while remaining > 0:
		var orb_value := mini(10, remaining)
		remaining -= orb_value
		var orb := GamePickup.new()
		orb.setup(player, GameIds.PICKUP_EXPERIENCE, spawn_position + Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(5.0, 28.0), orb_value)
		world_root.add_child(orb)

func _on_enemy_died(enemy: EnemyBase, experience_value: int) -> void:
	world_state.unregister_enemy(enemy)
	if enemy.enemy_kind == GameIds.ENEMY_BOSS:
		_finish_run(true)
		return
	if running:
		_spawn_experience(enemy.world_position, experience_value)

func _start_boss(difficulty: float) -> void:
	_clear_group(&"enemy")
	_clear_group(&"enemy_projectile")
	world_state.clear_runtime()
	_spawn_enemy(GameIds.ENEMY_BOSS, difficulty)

func _on_health_changed(current: float, maximum: float) -> void:
	ui.set_health(current, maximum)

func _on_experience_changed(current: int, required: int, level: int) -> void:
	ui.set_experience(current, required, level)

func _on_wave_changed(value: int) -> void:
	ui.set_wave(value)

func _on_combat_phase_changed(phase: int) -> void:
	if phase == WaveManager.CombatPhase.BOSS:
		ui.set_boss_state()

func _on_level_up(_level: int) -> void:
	if not running:
		return
	get_tree().paused = true
	ui.show_upgrade()

func _apply_upgrade(kind: StringName) -> void:
	match kind:
		GameIds.UPGRADE_SWORD:
			player.attack.upgrade_sword()
		GameIds.UPGRADE_SPEED:
			player.upgrade_speed()
		GameIds.UPGRADE_VITALITY:
			player.upgrade_vitality()
		GameIds.SPELL_LIGHTNING:
			player.magic.unlock_or_upgrade(GameIds.SPELL_LIGHTNING)
		GameIds.SPELL_FIREBALL:
			player.magic.unlock_or_upgrade(GameIds.SPELL_FIREBALL)
		_:
			push_error("Unknown upgrade kind: %s" % kind)
			return
	ui.hide_upgrade()
	get_tree().paused = false

func _on_magic_changed(spell_kind: StringName, spell_level: int) -> void:
	ui.set_magic(spell_kind, spell_level)

func _on_player_died() -> void:
	_finish_run(false)

func _finish_run(victory: bool) -> void:
	running = false
	wave_manager.stop()
	player.set_gameplay_active(false)
	_clear_runtime_nodes()
	get_tree().paused = false
	ui.show_game_over(victory)
