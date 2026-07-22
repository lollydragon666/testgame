extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/debug/combat_sandbox.tscn")
const CONTENT: GameContent = preload("res://resources/game_content.tres")
const CONFIG: WorldConfig = preload("res://resources/world_config.tres")

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	Engine.time_scale = 1.0
	paused = false
	quit(1)

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_require(session != null, "GameSession autoload is missing")
	session.reset_profile_for_tests()
	session.profile.gold = 37
	var profile_gold_before: int = session.profile.gold
	var profile_completed_before: int = session.profile.completed_expeditions

	var sandbox := SANDBOX_SCENE.instantiate() as CombatSandboxController
	root.add_child(sandbox)
	for _frame in 4:
		await physics_frame
	_require(sandbox.combat != null and sandbox.combat.player is PlayerHero, "Sandbox did not create the normal PlayerHero")
	_require(sandbox.combat.player.game_content == CONTENT, "Sandbox did not use the normal GameContent")
	_require(not sandbox.combat.wave_manager.running, "AUTO WAVES started enabled")

	var spawned := sandbox.combat.debug_spawn_enemy(GameIds.ENEMY_MELEE, 10)
	_require(spawned > 0, "Sandbox could not spawn an existing EnemyDefinition")
	_require(sandbox.combat.world_state.enemy_count() <= CONFIG.max_active_enemies, "Spawn x10 exceeded max_active_enemies")
	_require(sandbox.combat.debug_spawn_enemy(&"missing_enemy", 1) == 0, "Missing enemy ID was not handled safely")
	sandbox.combat.clear_enemies()
	_require(sandbox.combat.world_state.enemy_count() == 0, "Clear Enemies did not clear WorldState")

	sandbox.combat._spawn_projectile(Vector2.ZERO, Vector2.RIGHT, 1.0)
	sandbox.combat._spawn_player_magic(GameIds.SPELL_FIREBALL, Vector2.ZERO, Vector2.RIGHT, 1.0, 1)
	_require(sandbox.combat.world_state.enemy_projectile_count() == 1, "Enemy projectile was not registered")
	_require(sandbox.combat.world_state.player_projectile_count() == 1, "Player projectile was not registered")
	sandbox.combat.clear_projectiles()
	_require(sandbox.combat.world_state.enemy_projectile_count() == 0, "Enemy projectiles were not cleared")
	_require(sandbox.combat.world_state.player_projectile_count() == 0, "Player projectiles were not cleared")
	sandbox.combat.player.health = 1.0
	sandbox.combat.restore_player()
	_require(is_equal_approx(sandbox.combat.player.health, sandbox.combat.player.max_health), "Restore Player did not refill health")

	sandbox.combat.debug_give_experience(100)
	_require(sandbox.combat.player.level == 2, "Give Experience did not level the player")
	_require(sandbox.combat.pending_level_ups == 1, "Sandbox did not use the normal level-up queue")
	var queued_choice: StringName = sandbox.combat.current_upgrade_choices[0]
	_require(sandbox.combat._apply_upgrade(queued_choice), "Sandbox could not apply a queued level-up choice")
	_require(not paused, "Level-up selection left the sandbox paused")

	_require(sandbox.combat.debug_apply_upgrade(GameIds.UPGRADE_POWER), "Sandbox could not apply POWER")
	_require(sandbox.combat.player.power_multiplier > 1.0, "POWER did not affect the sandbox player")
	_require(not sandbox.combat.debug_apply_upgrade(&"missing_upgrade"), "Missing upgrade ID was not handled safely")
	sandbox._set_god_mode(true)
	sandbox._physics_process(0.016)
	var protected_health := sandbox.combat.player.health
	sandbox.combat.player.take_damage(50.0)
	_require(is_equal_approx(sandbox.combat.player.health, protected_health), "Sandbox god mode did not prevent damage")
	Engine.time_scale = 2.0
	var reset_event := InputEventAction.new()
	reset_event.action = "sandbox_reset"
	reset_event.pressed = true
	sandbox._unhandled_input(reset_event)
	_require(is_equal_approx(sandbox.combat.player.power_multiplier, 1.0), "Reset Arena did not reset run upgrades")
	_require(not sandbox.god_mode, "Reset Arena did not disable god mode")
	_require(is_equal_approx(Engine.time_scale, 1.0), "Reset Arena did not restore time_scale")
	_require(not sandbox.combat.wave_manager.running, "Reset Arena enabled AUTO WAVES")

	sandbox._set_auto_waves(true)
	_require(sandbox.combat.wave_manager.running, "AUTO WAVES ON did not use WaveManager")
	sandbox._set_auto_waves(false)
	_require(not sandbox.combat.wave_manager.running, "AUTO WAVES OFF did not stop WaveManager")

	var panel_was_visible := sandbox.sandbox_ui.panel.visible
	var toggle_event := InputEventAction.new()
	toggle_event.action = "toggle_sandbox_ui"
	toggle_event.pressed = true
	sandbox.sandbox_ui._unhandled_input(toggle_event)
	_require(sandbox.sandbox_ui.panel.visible != panel_was_visible, "F1 action did not toggle SandboxUI")

	var boss_spawned := sandbox.combat.debug_spawn_enemy(GameIds.ENEMY_BOSS, 1)
	_require(boss_spawned == 1, "Sandbox could not spawn the normal boss")
	var boss := sandbox.combat.world_state.enemy_snapshot()[0]
	boss.take_damage(100000.0, Vector2.RIGHT)
	_require(sandbox.combat.running, "Manual sandbox boss ended the arena with AUTO WAVES OFF")
	_require(session.profile.gold == profile_gold_before, "Sandbox boss changed PlayerProfile gold")
	sandbox.combat.player.invulnerability = 0.0
	sandbox.combat.player.take_damage(100000.0)
	_require(not sandbox.combat.running, "Sandbox player death did not stop the combat run")
	sandbox._restore_player()
	_require(sandbox.combat.running and is_equal_approx(sandbox.combat.player.health, sandbox.combat.player.max_health), "Restore Player did not recover a defeated sandbox run")

	sandbox.before_scene_exit()
	_require(is_equal_approx(Engine.time_scale, 1.0), "Leaving sandbox did not restore time_scale")
	_require(session.profile.gold == profile_gold_before, "Sandbox changed profile gold")
	_require(session.profile.completed_expeditions == profile_completed_before, "Sandbox changed completed expeditions")
	_require(session.profile.unlocked_location_ids == [&"test_location"], "Sandbox changed unlocked locations")

	print("COMBAT SANDBOX PASS")
	quit()
