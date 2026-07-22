extends SceneTree

const CONTENT: GameContent = preload("res://resources/game_content.tres")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const TEST_ENEMY_SCENE := preload("res://scenes/enemies/brawler_enemy.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _run() -> void:
	# Этот ID отсутствует в main.gd: фабрика обязана найти сцену только через GameContent.
	var definition := EnemyDefinition.new()
	definition.id = &"catalog_only_enemy"
	definition.scene = TEST_ENEMY_SCENE
	definition.max_health = 137.0
	definition.move_speed = 43.0
	definition.experience_value = 77
	CONTENT.enemies.append(definition)

	var game := MAIN_SCENE.instantiate() as GameMain
	root.add_child(game)
	await process_frame
	game.running = true
	game._spawn_enemy(definition.id, 1.0)
	var enemies := game.world_state.enemy_snapshot()
	_require(enemies.size() == 1, "EnemyDefinition was not spawned through the generic factory")
	var enemy := enemies[0]
	_require(enemy.enemy_kind == definition.id, "Spawned enemy did not receive the definition ID")
	_require(is_equal_approx(enemy.max_health, definition.max_health), "Enemy stats did not come from EnemyDefinition")
	_require(is_equal_approx(enemy.move_speed, definition.move_speed), "Enemy movement did not come from EnemyDefinition")
	_require(enemy.experience_value == definition.experience_value, "Enemy reward did not come from EnemyDefinition")

	print("DATA-DRIVEN CONTENT PASS")
	quit()
