class_name CombatSandboxController
extends Node

const COMBAT_SCENE := preload("res://scenes/main.tscn")
const CONTENT: GameContent = preload("res://resources/game_content.tres")

var combat: GameMain
var sandbox_ui: SandboxUI
var god_mode := false
var auto_waves := false
var stats_update_remaining := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	combat = COMBAT_SCENE.instantiate() as GameMain
	combat.name = "Combat"
	combat.configure_mode(CombatModeConfig.sandbox(), true)
	combat.result_action_requested.connect(reset_arena)
	add_child(combat)

	sandbox_ui = SandboxUI.new()
	sandbox_ui.name = "SandboxUI"
	sandbox_ui.configure_content(CONTENT)
	_connect_debug_ui(sandbox_ui)
	add_child(sandbox_ui)

func _physics_process(delta: float) -> void:
	if god_mode and combat != null and combat.player != null:
		combat.player.invulnerability = maxf(combat.player.invulnerability, 0.5)
	stats_update_remaining -= delta
	if stats_update_remaining <= 0.0:
		stats_update_remaining = 0.2
		_update_stats()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("sandbox_reset"):
		reset_arena()
		get_viewport().set_input_as_handled()

func _connect_debug_ui(debug_ui: SandboxUI) -> void:
	debug_ui.leave_requested.connect(leave_to_menu)
	debug_ui.reset_requested.connect(reset_arena)
	debug_ui.clear_enemies_requested.connect(combat.clear_enemies)
	debug_ui.clear_projectiles_requested.connect(combat.clear_projectiles)
	debug_ui.restore_player_requested.connect(_restore_player)
	debug_ui.spawn_requested.connect(_spawn_enemy)
	debug_ui.give_experience_requested.connect(combat.debug_give_experience)
	debug_ui.level_up_requested.connect(_give_level)
	debug_ui.reset_upgrades_requested.connect(_reset_player_upgrades)
	debug_ui.god_mode_changed.connect(_set_god_mode)
	debug_ui.upgrade_requested.connect(combat.debug_apply_upgrade)
	debug_ui.time_scale_changed.connect(_set_time_scale)
	debug_ui.auto_waves_changed.connect(_set_auto_waves)

func _spawn_enemy(enemy_id: StringName, count: int) -> void:
	combat.debug_spawn_enemy(enemy_id, count)

func execute_item_debug_command(command_text: String) -> ItemInstance:
	if combat == null:
		return null
	return RandomItemDebugCommand.execute(command_text, combat.inventory_service, CONTENT)

func _give_level() -> void:
	var amount := maxi(1, combat.player.experience_required - combat.player.experience)
	combat.debug_give_experience(amount)

func _restore_player() -> void:
	if combat.running:
		combat.restore_player()
	else:
		reset_arena()

func _reset_player_upgrades() -> void:
	combat.player.reset_run()
	combat.player.set_gameplay_active(combat.running)

func _set_god_mode(enabled: bool) -> void:
	god_mode = enabled
	if not god_mode:
		combat.player.invulnerability = 0.0

func _set_time_scale(value: float) -> void:
	Engine.time_scale = value

func _set_auto_waves(enabled: bool) -> void:
	auto_waves = enabled
	combat.set_auto_waves(enabled)

func reset_arena() -> void:
	Engine.time_scale = 1.0
	god_mode = false
	auto_waves = false
	combat.set_auto_waves(false)
	combat.start_run()
	if sandbox_ui != null:
		sandbox_ui.reset_controls()

func leave_to_menu() -> void:
	get_node("/root/SceneRouter").leave_combat_sandbox()

func before_scene_exit() -> void:
	Engine.time_scale = 1.0
	god_mode = false
	auto_waves = false
	if combat != null:
		combat.shutdown()

func _update_stats() -> void:
	if sandbox_ui == null or combat == null or combat.player == null:
		return
	var player := combat.player
	var spell_name := "НЕТ" if player.magic.active_spell.is_empty() else String(player.magic.active_spell)
	sandbox_ui.set_stats(
		"HP: %d / %d\nУРОВЕНЬ: %d   XP: %d / %d\nУРОН: ×%.2f   COOLDOWN: ×%.2f\nБРОНЯ: %d%%   МАГНИТ: %.0f\nМЕЧ: %d   МАГИЯ: %s\nВРАГИ: %d   СНАРЯДЫ: %d\nFPS: %d" % [
			ceili(player.health),
			ceili(player.max_health),
			player.level,
			player.experience,
			player.experience_required,
			player.profile_damage_multiplier * player.power_multiplier,
			player.haste_cooldown_multiplier,
			int(player.armor_damage_reduction * 100.0),
			player.experience_magnet_range(),
			player.attack.sword_tier,
			spell_name,
			combat.world_state.enemy_count(),
			combat.world_state.enemy_projectile_count() + combat.world_state.player_projectile_count(),
			Engine.get_frames_per_second(),
		]
	)
