extends SceneTree

const CONFIG: WorldConfig = preload("res://resources/world_config.tres")
const CONTENT: GameContent = preload("res://resources/game_content.tres")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _initialize() -> void:
	_run.call_deferred()


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
	player.set_physics_process(false)
	player.attack.set_physics_process(false)
	var state := WorldState.new()
	state.configure(CONFIG)
	root.add_child(state)
	player.set_combat_registry(state)
	var starts := [0]
	player.attack.attack_started.connect(func() -> void: starts[0] += 1)

	player.attack.cooldown = 0.05
	_require(not player.attack.try_attack(), "Cooldown attack started immediately")
	_require(is_equal_approx(player.attack.attack_buffer_remaining, PlayerAttack.ATTACK_BUFFER_TIME), "Cooldown press was not buffered")
	player.attack._physics_process(0.03)
	_require(starts[0] == 0, "Buffered attack started before cooldown ended")
	player.attack._physics_process(0.03)
	_require(starts[0] == 1, "Buffered attack did not start after cooldown")
	_require(is_equal_approx(player.attack.attack_buffer_remaining, 0.0), "Executed buffer was not cleared")

	player.attack.reset()
	player.attack.cooldown = 1.0
	player.attack.try_attack()
	player.attack._physics_process(PlayerAttack.ATTACK_BUFFER_TIME + 0.01)
	_require(is_equal_approx(player.attack.attack_buffer_remaining, 0.0), "Attack buffer did not expire")
	player.attack.cooldown = 0.0
	player.attack._physics_process(0.01)
	_require(starts[0] == 1, "Expired buffer started an attack")

	player.attack.reset()
	player.attack.cooldown = 0.05
	player.attack.try_attack()
	player.attack._physics_process(0.06)
	player.attack._physics_process(0.01)
	_require(starts[0] == 2, "One buffer started more than one attack")

	player.reset_run()
	player.invulnerability = 0.0
	player.attack.cooldown = 1.0
	player.attack.try_attack()
	player.take_damage(player.max_health * 2.0)
	_require(is_equal_approx(player.attack.attack_buffer_remaining, 0.0), "Death retained the attack buffer")

	player.reset_run()
	player.attack.cooldown = 1.0
	player.attack.try_attack()
	player.reset_run()
	_require(is_equal_approx(player.attack.attack_buffer_remaining, 0.0), "reset_run retained the attack buffer")

	player.attack.cooldown = 1.0
	player.attack.try_attack()
	player.set_gameplay_active(false)
	_require(is_equal_approx(player.attack.attack_buffer_remaining, 0.0), "Gameplay deactivation retained the attack buffer")

	print("ATTACK INPUT BUFFER PASS")
	quit()
