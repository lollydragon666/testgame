extends Node2D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const LOCATION_SCENE := preload("res://scenes/world/location.tscn")
const BRAWLER_ENEMY_SCENE := preload("res://scenes/enemies/brawler_enemy.tscn")
const MELEE_ENEMY_SCENE := preload("res://scenes/enemies/melee_enemy.tscn")
const SHOOTER_ENEMY_SCENE := preload("res://scenes/enemies/shooter_enemy.tscn")
const LANCER_ENEMY_SCENE := preload("res://scenes/enemies/lancer_enemy.tscn")
const BOSS_ENEMY_SCENE := preload("res://scenes/enemies/boss_enemy.tscn")

var location: GameLocation
var player: PlayerHero
var wave_manager: WaveManager
var ui: GameUI
var running := false

func _ready() -> void:
	randomize()
	location = LOCATION_SCENE.instantiate() as GameLocation
	location.name = "Location"
	add_child(location)
	location.potion_requested.connect(_spawn_potion)

	player = PLAYER_SCENE.instantiate() as PlayerHero
	player.name = "Player"
	add_child(player)
	player.health_changed.connect(_on_health_changed)
	player.experience_changed.connect(_on_experience_changed)
	player.level_up_requested.connect(_on_level_up)
	player.died.connect(_on_player_died)
	player.set_process(false)

	wave_manager = WaveManager.new()
	wave_manager.name = "WaveManager"
	add_child(wave_manager)
	wave_manager.spawn_requested.connect(_spawn_enemy)
	wave_manager.boss_requested.connect(_start_boss)
	wave_manager.wave_changed.connect(_on_wave_changed)

	ui = GameUI.new()
	ui.name = "UI"
	add_child(ui)
	ui.start_requested.connect(_start_run)
	ui.upgrade_selected.connect(_apply_upgrade)
	ui.set_health(player.health, player.max_health)
	ui.set_experience(player.experience, player.experience_required, player.level)
	ui.set_wave(1)

func _start_run() -> void:
	get_tree().paused = false
	_clear_runtime_nodes()
	location.regenerate()
	player.reset_run()
	player.set_process(true)
	wave_manager.start_run()
	running = true
	ui.show_game()

func _clear_runtime_nodes() -> void:
	for group_name in [&"enemy", &"enemy_projectile", &"pickup"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node):
				node.queue_free()

func _spawn_enemy(enemy_kind: String, difficulty: float) -> void:
	if not running:
		return
	var enemy: EnemyBase
	match enemy_kind:
		"brawler":
			enemy = BRAWLER_ENEMY_SCENE.instantiate() as EnemyBase
		"shooter":
			enemy = SHOOTER_ENEMY_SCENE.instantiate() as EnemyBase
		"lancer":
			enemy = LANCER_ENEMY_SCENE.instantiate() as EnemyBase
		"boss":
			enemy = BOSS_ENEMY_SCENE.instantiate() as EnemyBase
		_:
			enemy = MELEE_ENEMY_SCENE.instantiate() as EnemyBase
	var angle := randf_range(0.0, TAU)
	var distance := 620.0 if enemy_kind != "boss" else 520.0
	var spawn_position := player.world_position + Vector2.from_angle(angle) * distance
	spawn_position = spawn_position.clamp(Vector2.ONE * -3450.0, Vector2.ONE * 3450.0)
	enemy.setup(player, spawn_position, difficulty)
	enemy.died.connect(_on_enemy_died)
	enemy.projectile_requested.connect(_spawn_projectile)
	add_child(enemy)

func _spawn_projectile(origin: Vector2, direction: Vector2, damage: float) -> void:
	var projectile := EnemyProjectile.new()
	projectile.setup(player, origin, direction, damage)
	add_child(projectile)

func _spawn_potion(spawn_position: Vector2) -> void:
	var potion := GamePickup.new()
	potion.setup(player, "potion", spawn_position, 28)
	add_child(potion)

func _spawn_experience(spawn_position: Vector2, amount: int) -> void:
	var remaining := amount
	while remaining > 0:
		var orb_value := mini(10, remaining)
		remaining -= orb_value
		var orb := GamePickup.new()
		orb.setup(player, "experience", spawn_position + Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(5.0, 28.0), orb_value)
		add_child(orb)

func _on_enemy_died(enemy, experience_value: int) -> void:
	_spawn_experience(enemy.world_position, experience_value)
	if enemy.enemy_kind == "boss":
		running = false
		wave_manager.stop()
		player.set_process(false)
		ui.show_game_over(true)

func _start_boss(difficulty: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	for projectile in get_tree().get_nodes_in_group("enemy_projectile"):
		if is_instance_valid(projectile):
			projectile.queue_free()
	ui.set_wave(8)
	_spawn_enemy("boss", difficulty)

func _on_health_changed(current: float, maximum: float) -> void:
	ui.set_health(current, maximum)

func _on_experience_changed(current: int, required: int, level: int) -> void:
	ui.set_experience(current, required, level)

func _on_wave_changed(value: int) -> void:
	ui.set_wave(value)

func _on_level_up(_level: int) -> void:
	get_tree().paused = true
	ui.show_upgrade()

func _apply_upgrade(kind: String) -> void:
	match kind:
		"sword":
			player.attack.upgrade_sword()
		"speed":
			player.upgrade_speed()
		"vitality":
			player.upgrade_vitality()
	ui.hide_upgrade()
	get_tree().paused = false

func _on_player_died() -> void:
	running = false
	wave_manager.stop()
	ui.show_game_over(false)
