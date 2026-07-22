extends SceneTree

const CONFIG: WorldConfig = preload("res://resources/world_config.tres")
const CONTENT: GameContent = preload("res://resources/game_content.tres")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MELEE_SCENE := preload("res://scenes/enemies/melee_enemy.tscn")
const ENEMY_COUNT := 8

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerHero
	player.configure_world(CONFIG)
	player.configure_content(CONTENT)
	root.add_child(player)
	await process_frame
	player.set_process(false)

	var state := WorldState.new()
	root.add_child(state)
	var targets: Array[EnemyBase] = []
	for index in ENEMY_COUNT:
		var enemy := MELEE_SCENE.instantiate() as MeleeEnemy
		enemy.setup(player, Vector2(float(index) * 5.0, 0.0), 1.0, CONFIG)
		enemy.died.connect(func(dead_enemy: EnemyBase, _experience: int) -> void:
			state.unregister_enemy(dead_enemy)
		)
		root.add_child(enemy)
		enemy.set_process(false)
		state.register_enemy(enemy)
		targets.append(enemy)

	var external_snapshot := state.enemy_snapshot()
	external_snapshot.clear()
	_require(state.enemy_count() == ENEMY_COUNT, "A caller mutated the private enemy registry")

	var fireball := PlayerMagicProjectile.new()
	fireball.setup(CONTENT.spell(GameIds.SPELL_FIREBALL), Vector2.ZERO, Vector2.RIGHT, 9999.0, 1, state)
	root.add_child(fireball)
	fireball.set_process(false)
	fireball._physics_process(0.0)

	for enemy in targets:
		_require(not enemy.is_alive, "Fireball skipped an enemy when the registry changed during AoE")
	_require(state.enemy_count() == 0, "Killed enemies remained in the combat registry")

	print("FIREBALL REGISTRY MASS-KILL PASS")
	quit()
