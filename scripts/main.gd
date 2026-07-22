class_name GameMain
extends Node2D

signal run_setup_requested(player: PlayerHero)
signal run_started
signal run_finished(victory: bool)
signal result_action_requested
signal world_item_dropped(drop: WorldItemDrop)
signal world_item_picked_up(item: ItemInstance)

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const LOCATION_SCENE := preload("res://scenes/world/location.tscn")
## Один ресурс баланса передаётся всем системам, чтобы границы и интервалы не расходились.
const WORLD_CONFIG: WorldConfig = preload("res://resources/world_config.tres")
const GAME_CONTENT: GameContent = preload("res://resources/game_content.tres")

var location: GameLocation
var player: PlayerHero
var wave_manager: WaveManager
var enemy_spawner: EnemySpawner
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
var mode_config: CombatModeConfig
var auto_start_on_ready := false
var run_seed := 0
var defeated_enemies := 0
var defeated_elites := 0
var run_duration_seconds := 0.0
var expedition_location: LocationDefinition
var expedition_tier: ExpeditionTierDefinition
var run_random := RandomNumberGenerator.new()
## Число повышений, за которые игрок ещё не выбрал усиление.
var pending_level_ups := 0
## Не более трёх ID, показанных в текущем окне. Только они принимаются _apply_upgrade().
var current_upgrade_choices: Array[StringName] = []
var inventory_service: InventoryService
var run_inventory: RunInventoryService
var run_context: RunContext
var loot_service := LootService.new()
var player_profile: PlayerProfile
var shop_service: ShopService
var inventory_ui: InventoryUI

const MAX_UPGRADE_CHOICES := 3

func configure_mode(config: CombatModeConfig, start_automatically := true) -> void:
	mode_config = config
	auto_start_on_ready = start_automatically

func configure_run_seed(value: int) -> void:
	run_seed = value

func configure_inventory(service: InventoryService) -> void:
	inventory_service = service

func configure_run_inventory(storage: RunInventoryService, context: RunContext) -> void:
	run_inventory = storage
	run_context = context

func configure_economy(profile: PlayerProfile, economy_service: ShopService) -> void:
	player_profile = profile
	shop_service = economy_service

func configure_expedition(location_definition: LocationDefinition, tier_definition: ExpeditionTierDefinition, seed_value: int) -> void:
	expedition_location = location_definition
	expedition_tier = tier_definition
	run_seed = seed_value

func _ready() -> void:
	if mode_config == null:
		mode_config = CombatModeConfig.expedition()
	if expedition_location == null:
		expedition_location = GAME_CONTENT.location(&"test_location")
	if expedition_tier == null and expedition_location != null:
		expedition_tier = expedition_location.tier_definition(1)
	if inventory_service == null:
		inventory_service = InventoryService.new()
		inventory_service.configure(GAME_CONTENT)
		inventory_service.load_serialized([], {})
	if run_inventory == null:
		run_inventory = RunInventoryService.new()
		run_inventory.configure(GAME_CONTENT)
	if run_context == null:
		run_context = RunContext.new()
	inventory_service.attach_run_inventory(run_inventory, run_context.starting_equipment)
	world_state = WorldState.new()
	world_state.name = "WorldState"
	world_state.configure(WORLD_CONFIG)
	add_child(world_state)
	loot_service.configure(GAME_CONTENT)

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
	player.configure_inventory(inventory_service)
	world_root.add_child(player)
	player.set_combat_registry(world_state)
	player.health_changed.connect(_on_health_changed)
	player.experience_changed.connect(_on_experience_changed)
	player.level_up_requested.connect(_on_level_up)
	player.magic_cast_requested.connect(_spawn_player_magic)
	player.magic_changed.connect(_on_magic_changed)
	player.dash_status_changed.connect(_on_dash_status_changed)
	player.died.connect(_on_player_died)
	player.set_gameplay_active(false)

	enemy_spawner = EnemySpawner.new()
	enemy_spawner.name = "EnemySpawner"
	enemy_spawner.configure(GAME_CONTENT, WORLD_CONFIG, world_state, player, world_root)
	enemy_spawner.enemy_died.connect(_on_enemy_died)
	enemy_spawner.projectile_requested.connect(_spawn_projectile)
	enemy_spawner.spell_requested.connect(_spawn_enemy_spell)
	add_child(enemy_spawner)

	wave_manager = WaveManager.new()
	wave_manager.name = "WaveManager"
	add_child(wave_manager)
	wave_manager.setup(world_state.enemy_count, WORLD_CONFIG, GAME_CONTENT)
	wave_manager.spawn_requested.connect(_spawn_enemy)
	wave_manager.boss_requested.connect(_start_boss)
	wave_manager.wave_changed.connect(_on_wave_changed)
	wave_manager.combat_phase_changed.connect(_on_combat_phase_changed)
	wave_manager.expedition_waves_completed.connect(_on_expedition_waves_completed)

	ui = GameUI.new()
	ui.name = "UI"
	ui.configure_content(GAME_CONTENT)
	add_child(ui)
	if expedition_location != null and expedition_tier != null:
		ui.set_expedition_context(expedition_location.display_name, expedition_tier.tier, expedition_tier.wave_count)
	ui.start_requested.connect(_start_run)
	ui.upgrade_selected.connect(_apply_upgrade)
	ui.game_over_action_requested.connect(_on_game_over_action)
	ui.set_health(player.health, player.max_health)
	ui.set_experience(player.experience, player.experience_required, player.level)
	ui.set_wave(1, expedition_tier.wave_count if expedition_tier != null else 1)
	ui.set_magic(&"", 0)
	ui.set_dash_status(0.0, PlayerHero.DASH_COOLDOWN, false)
	inventory_service.inventory_changed.connect(_refresh_consumable_hud)
	inventory_service.consumable_slot_changed.connect(func(_slot: ItemEnums.EquipmentSlot): _refresh_consumable_hud())
	inventory_service.consumable_cooldown_changed.connect(func(_slot: ItemEnums.EquipmentSlot, _remaining: float, _duration: float): _refresh_consumable_hud())
	_refresh_consumable_hud()
	inventory_ui = InventoryUI.new()
	inventory_ui.name = "InventoryUI"
	inventory_ui.configure(
		GAME_CONTENT,
		inventory_service,
		player_profile,
		shop_service,
		_can_open_inventory,
		true
	)
	add_child(inventory_ui)
	if auto_start_on_ready:
		_start_run.call_deferred()

func _physics_process(delta: float) -> void:
	if running:
		run_duration_seconds += delta

func start_run() -> void:
	_start_run()

func _start_run() -> void:
	if run_context.state != RunContext.RunState.ACTIVE:
		run_inventory.clear()
		run_context = RunContext.create(inventory_service.serialized_equipment())
		inventory_service.attach_run_inventory(run_inventory, run_context.starting_equipment)
	get_tree().paused = false
	pending_level_ups = 0
	current_upgrade_choices.clear()
	_clear_runtime_nodes()
	run_random.seed = run_seed if run_seed != 0 else 1
	location.regenerate(run_seed)
	_register_location_destructibles()
	player.reset_run()
	player.apply_equipped_weapon()
	player.apply_equipment_stats(PlayerStatCalculator.calculate(inventory_service))
	_refresh_consumable_hud()
	run_setup_requested.emit(player)
	player.set_gameplay_active(true)
	running = true
	defeated_enemies = 0
	defeated_elites = 0
	run_duration_seconds = 0.0
	enemy_spawner.configure_seed(run_seed)
	if mode_config.enable_auto_waves:
		if not wave_manager.start_expedition(expedition_tier, run_seed):
			running = false
			player.set_gameplay_active(false)
			ui.show_game_over(false, "ВЕРНУТЬСЯ В ХАБ", "ОШИБКА КОНФИГУРАЦИИ ВЫЛАЗКИ")
			return
	else:
		wave_manager.stop()
		ui.set_wave(1, expedition_tier.wave_count if expedition_tier != null else 1)
	ui.show_game()
	run_started.emit()

func _clear_runtime_nodes() -> void:
	# Группы используются только для редкой массовой очистки между забегами.
	for group_name in [&"enemy", &"enemy_projectile", &"player_magic_projectile", &"pickup", &"world_item_drop", &"temporary_effect"]:
		_clear_group(group_name)
	world_state.clear_runtime()
	loot_service.clear_runtime()

func _clear_group(group_name: StringName) -> void:
	for node in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(node):
			node.set_process(false)
			node.set_physics_process(false)
			node.queue_free()

func _spawn_enemy(enemy_kind: StringName, difficulty: float, is_elite := false) -> EnemyBase:
	if not running:
		return null
	var enemy := enemy_spawner.spawn(enemy_kind, difficulty, Vector2.INF, is_elite)
	if wave_manager.running and wave_manager.combat_phase == WaveManager.CombatPhase.WAVES:
		wave_manager.report_spawn_result(enemy != null)
	return enemy

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
		orb.setup(player, GameIds.PICKUP_EXPERIENCE, spawn_position + Vector2.from_angle(run_random.randf_range(0.0, TAU)) * run_random.randf_range(5.0, 28.0), orb_value)
		world_state.register_pickup(orb)
		world_root.add_child(orb)

func _on_enemy_died(enemy: EnemyBase, experience_value: int) -> void:
	world_state.unregister_enemy(enemy)
	defeated_enemies += 1
	if enemy.is_elite:
		defeated_elites += 1
	if running:
		var dropped_items := loot_service.roll_for_enemy(enemy, current_wave(), player.equipment_loot_chance, run_random)
		for dropped_item in dropped_items:
			_spawn_world_item(dropped_item, enemy.world_position)
	if enemy.definition != null and enemy.definition.is_boss:
		if wave_manager.running:
			wave_manager.notify_boss_defeated()
		return
	if running:
		_spawn_experience(enemy.world_position, experience_value)

func _spawn_world_item(item: ItemInstance, spawn_position: Vector2) -> WorldItemDrop:
	if item == null or not running or not loot_service.can_spawn_world_drop():
		return null
	var definition := GAME_CONTENT.item(item.definition_id)
	if definition == null:
		return null
	var drop := WorldItemDrop.new()
	var offset := Vector2.from_angle(run_random.randf_range(0.0, TAU)) * run_random.randf_range(8.0, 24.0)
	drop.setup(item, definition, player, run_inventory, spawn_position + offset, run_context)
	if not loot_service.register_world_drop(drop):
		drop.free()
		return null
	drop.picked_up.connect(_on_world_item_picked_up)
	drop.pickup_failed.connect(_on_world_item_pickup_failed)
	world_root.add_child(drop)
	world_item_dropped.emit(drop)
	return drop

func _on_world_item_picked_up(item: ItemInstance) -> void:
	world_item_picked_up.emit(item)

func _on_world_item_pickup_failed(message: String) -> void:
	if ui != null:
		ui.show_notification(message)

func _start_boss(enemy_kind: StringName, difficulty: float) -> void:
	clear_projectiles()
	var boss := enemy_spawner.spawn(enemy_kind, difficulty, Vector2.INF, false) if running else null
	wave_manager.report_boss_spawn_result(boss != null)

func _on_health_changed(current: float, maximum: float) -> void:
	ui.set_health(current, maximum)

func _on_experience_changed(current: int, required: int, level: int) -> void:
	ui.set_experience(current, required, level)

func _on_wave_changed(value: int, total: int) -> void:
	ui.set_wave(value, total)

func _on_combat_phase_changed(phase: int) -> void:
	if phase == WaveManager.CombatPhase.BOSS:
		ui.set_boss_state()

func _on_expedition_waves_completed() -> void:
	_finish_run(true)

func _on_level_up(_level: int) -> void:
	if not running or not mode_config.enable_level_up_choices:
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
	for index in range(unique_choices.size() - 1, 0, -1):
		var swap_index := run_random.randi_range(0, index)
		var temporary := unique_choices[index]
		unique_choices[index] = unique_choices[swap_index]
		unique_choices[swap_index] = temporary
	if unique_choices.size() > MAX_UPGRADE_CHOICES:
		unique_choices.resize(MAX_UPGRADE_CHOICES)
	return unique_choices

func _apply_upgrade(kind: StringName) -> bool:
	if pending_level_ups <= 0 or not current_upgrade_choices.has(kind):
		return false
	if not _apply_upgrade_effect(kind):
		return false
	current_upgrade_choices.clear()
	pending_level_ups -= 1
	if pending_level_ups > 0:
		_show_next_level_up()
	else:
		ui.hide_upgrade()
		get_tree().paused = false
	return true

func _apply_upgrade_effect(kind: StringName) -> bool:
	match kind:
		GameIds.UPGRADE_SWORD:
			if not player.attack.can_upgrade_sword():
				return false
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
			if not player.can_upgrade_armor():
				return false
			player.upgrade_armor()
		GameIds.UPGRADE_MAGNET:
			player.upgrade_magnet()
		_:
			var definition := GAME_CONTENT.upgrade(kind)
			if definition == null or definition.spell_id.is_empty():
				push_warning("Unknown upgrade ID: %s" % kind)
				return false
			return player.magic.unlock_or_upgrade(definition.spell_id)
	return true

func _on_magic_changed(spell_kind: StringName, spell_level: int) -> void:
	ui.set_magic(spell_kind, spell_level)

func _on_dash_status_changed(cooldown_remaining: float, cooldown_duration: float, active: bool) -> void:
	if ui != null:
		ui.set_dash_status(cooldown_remaining, cooldown_duration, active)

func _refresh_consumable_hud() -> void:
	if ui != null:
		ui.set_consumable_slots(inventory_service)

func _can_open_inventory() -> bool:
	return running and not get_tree().paused

func _on_player_died() -> void:
	_finish_run(false)

func _finish_run(victory: bool) -> void:
	if not running:
		return
	if inventory_ui != null:
		inventory_ui.close()
	running = false
	pending_level_ups = 0
	current_upgrade_choices.clear()
	wave_manager.stop()
	player.set_gameplay_active(false)
	player.clear_temporary_effects()
	inventory_service.reset_consumable_runtime()
	_clear_runtime_nodes()
	get_tree().paused = false
	var action_text := "ВЕРНУТЬСЯ В ХАБ" if mode_config.mode_id == CombatModeConfig.MODE_EXPEDITION else "ПЕРЕЗАПУСТИТЬ АРЕНУ"
	ui.show_game_over(victory, action_text)
	run_finished.emit(victory)

func _on_game_over_action() -> void:
	if auto_start_on_ready:
		result_action_requested.emit()
	else:
		_start_run()

func set_auto_waves(enabled: bool) -> void:
	mode_config.enable_auto_waves = enabled
	if not running:
		return
	if enabled:
		wave_manager.start_expedition(expedition_tier, run_seed)
	else:
		wave_manager.stop()

func current_wave() -> int:
	return wave_manager.wave if wave_manager != null else 1

func debug_spawn_enemy(enemy_id: StringName, count: int = 1) -> int:
	if not running or enemy_spawner == null or GAME_CONTENT.enemy(enemy_id) == null:
		return 0
	return enemy_spawner.spawn_many(enemy_id, count)

func debug_apply_upgrade(upgrade_id: StringName) -> bool:
	if not running or GAME_CONTENT.upgrade(upgrade_id) == null:
		return false
	return _apply_upgrade_effect(upgrade_id)

func debug_give_experience(amount: int) -> void:
	if running and amount > 0:
		player.add_experience(amount)

func restore_player() -> void:
	player.is_alive = true
	player.health = player.max_health
	player.invulnerability = 0.0
	player.health_changed.emit(player.health, player.max_health)
	player.set_gameplay_active(running)

func clear_enemies() -> void:
	_clear_group(&"enemy")
	world_state.clear_enemies()

func clear_projectiles() -> void:
	_clear_group(&"enemy_projectile")
	_clear_group(&"player_magic_projectile")
	world_state.clear_projectiles()

func clear_pickups() -> void:
	_clear_group(&"pickup")
	world_state.clear_pickups()

func shutdown() -> void:
	if inventory_ui != null:
		inventory_ui.close()
	running = false
	pending_level_ups = 0
	current_upgrade_choices.clear()
	if wave_manager != null:
		wave_manager.stop()
	if player != null:
		player.set_gameplay_active(false)
	if world_state != null:
		_clear_runtime_nodes()
	if get_tree() != null:
		get_tree().paused = false
