class_name GameMain
extends Node2D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const LOCATION_SCENE := preload("res://scenes/world/location.tscn")
## Один ресурс баланса передаётся всем системам, чтобы границы и интервалы не расходились.
const WORLD_CONFIG: WorldConfig = preload("res://resources/world_config.tres")
const GAME_CONTENT: GameContent = preload("res://resources/game_content.tres")

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
var running := false
## Число повышений, за которые игрок ещё не выбрал усиление.
var pending_level_ups := 0
## Не более трёх ID, показанных в текущем окне. Только они принимаются _apply_upgrade().
var current_upgrade_choices: Array[StringName] = []

const MAX_UPGRADE_CHOICES := 3

func _ready() -> void:
	randomize()
	world_state = WorldState.new()
	world_state.name = "WorldState"
	world_state.configure(WORLD_CONFIG)
	add_child(world_state)

	location = LOCATION_SCENE.instantiate() as GameLocation
	location.name = "Location"
	location.configure(WORLD_CONFIG, GAME_CONTENT, world_root)
	floor_layer.add_child(location)
	location.potion_requested.connect(_spawn_potion)
	_register_location_destructibles()

	player = PLAYER_SCENE.instantiate() as PlayerHero
	player.name = "Player"
	player.configure_world(WORLD_CONFIG)
	player.configure_content(GAME_CONTENT)
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
	wave_manager.setup(world_state.enemy_count, WORLD_CONFIG, GAME_CONTENT)
	wave_manager.spawn_requested.connect(_spawn_enemy)
	wave_manager.boss_requested.connect(_start_boss)
	wave_manager.wave_changed.connect(_on_wave_changed)
	wave_manager.combat_phase_changed.connect(_on_combat_phase_changed)

	ui = GameUI.new()
	ui.name = "UI"
	ui.configure_content(GAME_CONTENT)
	add_child(ui)
	ui.start_requested.connect(_start_run)
	ui.upgrade_selected.connect(_apply_upgrade)
	ui.set_health(player.health, player.max_health)
	ui.set_experience(player.experience, player.experience_required, player.level)
	ui.set_wave(1)
	ui.set_magic(&"", 0)

func _start_run() -> void:
	get_tree().paused = false
	pending_level_ups = 0
	current_upgrade_choices.clear()
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
			node.set_physics_process(false)
			node.queue_free()

func _spawn_enemy(enemy_kind: StringName, difficulty: float) -> void:
	if not running or world_state.enemy_count() >= WORLD_CONFIG.max_active_enemies:
		return
	var definition := GAME_CONTENT.enemy(enemy_kind)
	if definition == null or definition.scene == null:
		push_error("Unknown enemy kind: %s" % enemy_kind)
		return
	var enemy: EnemyBase = definition.scene.instantiate() as EnemyBase
	if enemy == null:
		push_error("Enemy scene does not contain EnemyBase: %s" % enemy_kind)
		return
	var spawn_position := _find_spawn_position(definition.spawn_distance, definition.collision_radius)
	if not spawn_position.is_finite():
		return
	enemy.setup(player, spawn_position, difficulty, WORLD_CONFIG, definition)
	enemy.died.connect(_on_enemy_died)
	enemy.projectile_requested.connect(_spawn_projectile)
	enemy.spell_requested.connect(_spawn_enemy_spell)
	world_state.register_enemy(enemy)
	world_root.add_child(enemy)

func _find_spawn_position(distance: float, spawn_radius: float = 24.0) -> Vector2:
	# Несколько попыток сохраняют нужную дистанцию даже рядом с краем ограниченного мира.
	var map_limit := maxf(0.0, WORLD_CONFIG.world_limit - WORLD_CONFIG.safe_spawn_margin)
	var minimum_distance := distance * 0.85
	for _attempt in 16:
		var candidate := player.world_position + Vector2.from_angle(randf_range(0.0, TAU)) * distance
		candidate = candidate.clamp(Vector2.ONE * -map_limit, Vector2.ONE * map_limit)
		if candidate.distance_to(player.world_position) >= minimum_distance and world_state.is_enemy_spawn_clear(
			candidate,
			spawn_radius,
			player.world_position,
			player.collision_radius,
			WORLD_CONFIG.enemy_spawn_clearance
		):
			return candidate
	return Vector2.INF

func _spawn_projectile(origin: Vector2, direction: Vector2, damage: float) -> void:
	if not running or not world_state.can_spawn_enemy_projectile(WORLD_CONFIG):
		return
	var projectile := EnemyProjectile.new()
	projectile.setup(player, origin, direction, damage)
	_register_enemy_projectile(projectile)
	projectiles_root.add_child(projectile)

func _spawn_player_magic(spell_kind: StringName, origin: Vector2, direction: Vector2, damage: float, spell_level: int) -> void:
	if not running or not world_state.can_spawn_player_projectile(WORLD_CONFIG):
		return
	var projectile := PlayerMagicProjectile.new()
	var definition := GAME_CONTENT.spell(spell_kind)
	if definition == null:
		push_error("Unknown player spell: %s" % spell_kind)
		return
	projectile.setup(definition, origin, direction, damage, spell_level, world_state)
	world_state.register_player_projectile(projectile)
	projectiles_root.add_child(projectile)

func _spawn_enemy_spell(spell_kind: StringName, origin: Vector2, direction: Vector2, damage: float) -> void:
	if not running or not world_state.can_spawn_enemy_projectile(WORLD_CONFIG):
		return
	var projectile := EnemySpellProjectile.new()
	projectile.setup(player, spell_kind, origin, direction, damage)
	_register_enemy_projectile(projectile)
	projectiles_root.add_child(projectile)

func _register_enemy_projectile(projectile: DeflectableProjectile) -> void:
	world_state.register_enemy_projectile(projectile)

func _register_location_destructibles() -> void:
	world_state.replace_world_props(location.generated_props)

func _spawn_potion(spawn_position: Vector2) -> void:
	if not running or not world_state.can_spawn_pickup(WORLD_CONFIG):
		return
	var potion := GamePickup.new()
	potion.setup(player, GameIds.PICKUP_POTION, spawn_position, 28)
	world_state.register_pickup(potion)
	world_root.add_child(potion)

func _spawn_experience(spawn_position: Vector2, amount: int) -> void:
	var remaining := amount
	while remaining > 0 and world_state.pickup_count() < WORLD_CONFIG.max_pickups:
		var slots_left := WORLD_CONFIG.max_pickups - world_state.pickup_count()
		var orb_value := remaining if slots_left == 1 else mini(10, remaining)
		remaining -= orb_value
		var orb := GamePickup.new()
		orb.setup(player, GameIds.PICKUP_EXPERIENCE, spawn_position + Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(5.0, 28.0), orb_value)
		world_state.register_pickup(orb)
		world_root.add_child(orb)

func _on_enemy_died(enemy: EnemyBase, experience_value: int) -> void:
	world_state.unregister_enemy(enemy)
	if enemy.definition != null and enemy.definition.is_boss:
		_finish_run(true)
		return
	if running:
		_spawn_experience(enemy.world_position, experience_value)

func _start_boss(enemy_kind: StringName, difficulty: float) -> void:
	_clear_group(&"enemy")
	_clear_group(&"enemy_projectile")
	world_state.clear_runtime()
	_spawn_enemy(enemy_kind, difficulty)

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
	pending_level_ups += 1
	if pending_level_ups == 1:
		_show_next_level_up()

func _show_next_level_up() -> void:
	current_upgrade_choices.clear()
	if not running or pending_level_ups <= 0:
		pending_level_ups = 0
		ui.hide_upgrade()
		get_tree().paused = false
		return
	var available_upgrades := available_upgrade_choices()
	if available_upgrades.is_empty():
		pending_level_ups = 0
		ui.hide_upgrade()
		get_tree().paused = false
		return
	current_upgrade_choices = _random_upgrade_choices(available_upgrades)
	get_tree().paused = true
	ui.show_upgrade(current_upgrade_choices)

func available_upgrade_choices() -> Array[StringName]:
	var choices: Array[StringName] = []
	for definition in GAME_CONTENT.upgrades:
		if definition.requires_sword_upgrade and not player.attack.can_upgrade_sword():
			continue
		if not definition.spell_id.is_empty() and not player.magic.can_upgrade_spell(definition.spell_id):
			continue
		if definition.id == GameIds.UPGRADE_ARMOR and not player.can_upgrade_armor():
			continue
		choices.append(definition.id)
	return choices

func _random_upgrade_choices(available_upgrades: Array[StringName]) -> Array[StringName]:
	var unique_choices: Array[StringName] = []
	for kind in available_upgrades:
		if not unique_choices.has(kind):
			unique_choices.append(kind)
	unique_choices.shuffle()
	if unique_choices.size() > MAX_UPGRADE_CHOICES:
		unique_choices.resize(MAX_UPGRADE_CHOICES)
	return unique_choices

func _apply_upgrade(kind: StringName) -> bool:
	if pending_level_ups <= 0 or not current_upgrade_choices.has(kind):
		return false
	match kind:
		GameIds.UPGRADE_SWORD:
			player.attack.upgrade_sword()
		GameIds.UPGRADE_SPEED:
			player.upgrade_speed()
		GameIds.UPGRADE_VITALITY:
			player.upgrade_vitality()
		GameIds.UPGRADE_POWER:
			player.upgrade_power()
		GameIds.UPGRADE_HASTE:
			player.upgrade_haste()
		GameIds.UPGRADE_ARMOR:
			player.upgrade_armor()
		GameIds.UPGRADE_MAGNET:
			player.upgrade_magnet()
		_:
			var definition := GAME_CONTENT.upgrade(kind)
			if definition == null or definition.spell_id.is_empty():
				push_error("Unknown upgrade kind: %s" % kind)
				return false
			player.magic.unlock_or_upgrade(definition.spell_id)
	current_upgrade_choices.clear()
	pending_level_ups -= 1
	if pending_level_ups > 0:
		_show_next_level_up()
	else:
		ui.hide_upgrade()
		get_tree().paused = false
	return true

func _on_magic_changed(spell_kind: StringName, spell_level: int) -> void:
	ui.set_magic(spell_kind, spell_level)

func _on_player_died() -> void:
	_finish_run(false)

func _finish_run(victory: bool) -> void:
	running = false
	pending_level_ups = 0
	current_upgrade_choices.clear()
	wave_manager.stop()
	player.set_gameplay_active(false)
	_clear_runtime_nodes()
	get_tree().paused = false
	ui.show_game_over(victory)
