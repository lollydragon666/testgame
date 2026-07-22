extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _require_unique(choices: Array[StringName], message: String) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for kind in choices:
		_require(not seen.has(kind), message)
		seen[kind] = true

func _visible_upgrade_ids(ui: GameUI) -> Array[StringName]:
	var result: Array[StringName] = []
	for kind in ui.upgrade_buttons:
		var button: Button = ui.upgrade_buttons[kind]
		if button.visible:
			result.append(kind)
	return result

func _assert_current_panel(game: GameMain) -> void:
	_require(not game.current_upgrade_choices.is_empty(), "Current upgrade set is empty")
	_require(game.current_upgrade_choices.size() <= GameMain.MAX_UPGRADE_CHOICES, "More than three upgrades were offered")
	_require_unique(game.current_upgrade_choices, "Current upgrade set contains duplicate IDs")
	var visible_ids := _visible_upgrade_ids(game.ui)
	_require(visible_ids.size() <= GameUI.MAX_VISIBLE_UPGRADES, "UI displays more than three upgrade buttons")
	_require(visible_ids.size() == game.current_upgrade_choices.size(), "UI buttons do not match the current upgrade set")
	for kind in visible_ids:
		_require(game.current_upgrade_choices.has(kind), "UI displays an ID outside the current upgrade set")

func _apply_forced_upgrade(game: GameMain, kind: StringName) -> void:
	game.pending_level_ups = 1
	game.current_upgrade_choices = [kind]
	_require(game._apply_upgrade(kind), "Upgrade mapping rejected a current choice: %s" % kind)

func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameMain
	root.add_child(game)
	await process_frame
	game._start_run()
	game.wave_manager.stop()

	for kind in [GameIds.UPGRADE_POWER, GameIds.UPGRADE_HASTE, GameIds.UPGRADE_ARMOR, GameIds.UPGRADE_MAGNET]:
		_require(GameMain.GAME_CONTENT.upgrade(kind) != null, "New UpgradeDefinition is missing: %s" % kind)
		_require(game.ui.upgrade_buttons.has(kind), "Data-driven UI did not create a button: %s" % kind)

	var two_choices: Array[StringName] = [GameIds.UPGRADE_POWER, GameIds.UPGRADE_HASTE]
	var rolled_two := game._random_upgrade_choices(two_choices)
	_require(rolled_two.size() == 2 and rolled_two.has(GameIds.UPGRADE_POWER) and rolled_two.has(GameIds.UPGRADE_HASTE), "Fewer than three available upgrades were not all returned")
	var duplicate_input: Array[StringName] = [GameIds.UPGRADE_POWER, GameIds.UPGRADE_POWER, GameIds.UPGRADE_HASTE]
	_require_unique(game._random_upgrade_choices(duplicate_input), "Random selection retained a duplicate ID")

	game.player.add_experience(1000)
	var earned_levels := game.player.level - 1
	_require(earned_levels > 1, "Test setup did not earn several levels at once")
	_require(game.pending_level_ups == earned_levels, "Simultaneous level-ups were lost")
	_require(paused, "Game was not paused for the first queued upgrade")
	_require(game.ui.upgrade_panel.visible, "Upgrade panel is not visible")
	_assert_current_panel(game)

	var rejected_kind: StringName = &""
	for kind in game.available_upgrade_choices():
		if not game.current_upgrade_choices.has(kind):
			rejected_kind = kind
			break
	_require(not rejected_kind.is_empty(), "Test setup has no globally available ID outside the current set")
	var pending_before_rejection := game.pending_level_ups
	var shown_before_rejection := game.current_upgrade_choices.duplicate()
	_require(not game._apply_upgrade(rejected_kind), "Upgrade outside the current set was accepted")
	_require(game.pending_level_ups == pending_before_rejection, "Rejected choice consumed a queued level")
	_require(game.current_upgrade_choices == shown_before_rejection, "Rejected choice replaced the current set")

	for remaining_after_choice in range(earned_levels - 1, -1, -1):
		_assert_current_panel(game)
		var selected_kind := game.current_upgrade_choices[0]
		_require(game._apply_upgrade(selected_kind), "A displayed upgrade was rejected")
		_require(game.pending_level_ups == remaining_after_choice, "Queue did not consume exactly one level-up")
		if remaining_after_choice > 0:
			_require(paused, "Game resumed before queued upgrades were exhausted")
			_require(game.ui.upgrade_panel.visible, "Next queued panel was not shown")
			_require(game.ui.upgrade_selection_locked, "Next panel skipped its input delay")
			_assert_current_panel(game)

	_require(not paused, "Game remained paused after the final queued upgrade")
	_require(not game.ui.upgrade_panel.visible, "Panel remained visible after queue completion")
	_require(game.current_upgrade_choices.is_empty(), "Current set remained after queue completion")

	game.player.reset_run()
	game.player.magic.unlock_or_upgrade(GameIds.SPELL_LIGHTNING)
	var sword_damage_before := game.player.attack.effective_damage()
	var magic_damage_before := game.player.magic.effective_spell_damage(GameIds.SPELL_LIGHTNING)
	_apply_forced_upgrade(game, GameIds.UPGRADE_POWER)
	_require(is_equal_approx(game.player.power_multiplier, 1.15), "POWER multiplier is incorrect")
	_require(is_equal_approx(game.player.attack.effective_damage(), sword_damage_before * 1.15), "POWER did not affect sword damage")
	_require(is_equal_approx(game.player.magic.effective_spell_damage(GameIds.SPELL_LIGHTNING), magic_damage_before * 1.15), "POWER did not affect magic damage")

	_apply_forced_upgrade(game, GameIds.UPGRADE_HASTE)
	for _index in 99:
		game.player.upgrade_haste()
	_require(is_equal_approx(game.player.attack.effective_cooldown_duration(), 0.14), "Sword cooldown crossed its 0.14 minimum")
	game.player.attack.cooldown = 0.0
	game.player.attack.try_attack()
	_require(is_equal_approx(game.player.attack.cooldown, 0.14), "Sword attack did not use the HASTE-adjusted cooldown")
	for spell_kind in [GameIds.SPELL_LIGHTNING, GameIds.SPELL_FIREBALL]:
		if game.player.magic.get_spell_level(spell_kind) == 0:
			game.player.magic.unlock_or_upgrade(spell_kind)
		var spell_definition := GameMain.GAME_CONTENT.spell(spell_kind)
		_require(game.player.magic.effective_spell_cooldown(spell_kind) >= spell_definition.minimum_cooldown, "Spell cooldown crossed its minimum: %s" % spell_kind)
		_require(is_equal_approx(game.player.magic.effective_spell_cooldown(spell_kind), spell_definition.minimum_cooldown), "HASTE did not reach the spell minimum: %s" % spell_kind)
	game.player.magic.active_spell = GameIds.SPELL_LIGHTNING
	game.player.magic.cooldown = 0.0
	game.player.magic.try_cast()
	_require(is_equal_approx(game.player.magic.cooldown, GameMain.GAME_CONTENT.spell(GameIds.SPELL_LIGHTNING).minimum_cooldown), "Magic cast did not use the HASTE-adjusted cooldown")

	_apply_forced_upgrade(game, GameIds.UPGRADE_ARMOR)
	for _index in 9:
		game.player.upgrade_armor()
	_require(is_equal_approx(game.player.armor_damage_reduction, 0.40), "ARMOR exceeded or missed the 40% cap")
	game.player.health = 100.0
	game.player.invulnerability = 0.0
	game.player.take_damage(100.0)
	_require(is_equal_approx(game.player.health, 40.0), "ARMOR was not applied to incoming damage")
	var magnet_before := game.player.experience_magnet_range()
	_apply_forced_upgrade(game, GameIds.UPGRADE_MAGNET)
	_require(is_equal_approx(game.player.experience_magnet_range(), magnet_before + 35.0), "MAGNET did not add 35 world-space units")

	game.player.attack.sword_tier = game.player.attack.definition.max_tier
	for spell_definition in GameMain.GAME_CONTENT.spells:
		while game.player.magic.can_upgrade_spell(spell_definition.id):
			game.player.magic.unlock_or_upgrade(spell_definition.id)
		_require(game.player.magic.get_spell_level(spell_definition.id) == spell_definition.max_level, "Spell level limit is incorrect: %s" % spell_definition.id)
		_require(not game.player.magic.unlock_or_upgrade(spell_definition.id), "Spell exceeded its maximum level: %s" % spell_definition.id)

	var choices := game.available_upgrade_choices()
	_require(not choices.has(GameIds.UPGRADE_SWORD), "Max-tier sword remained in available upgrades")
	_require(not choices.has(GameIds.SPELL_LIGHTNING), "Max-level lightning remained available")
	_require(not choices.has(GameIds.SPELL_FIREBALL), "Max-level fireball remained available")
	_require(not choices.has(GameIds.UPGRADE_ARMOR), "Capped ARMOR remained available")
	_require(choices.has(GameIds.UPGRADE_SPEED) and choices.has(GameIds.UPGRADE_VITALITY), "Unlimited existing upgrades disappeared")
	_require(choices.has(GameIds.UPGRADE_POWER) and choices.has(GameIds.UPGRADE_HASTE) and choices.has(GameIds.UPGRADE_MAGNET), "Unlimited new upgrades disappeared")

	game._on_level_up(99)
	_assert_current_panel(game)
	_require(not game.current_upgrade_choices.has(GameIds.UPGRADE_SWORD), "Max-tier sword appeared in the current set")
	_require(not game.current_upgrade_choices.has(GameIds.SPELL_LIGHTNING), "Max-level lightning appeared in the current set")
	_require(not game.current_upgrade_choices.has(GameIds.SPELL_FIREBALL), "Max-level fireball appeared in the current set")
	_require(not game.ui.upgrade_buttons[GameIds.UPGRADE_SWORD].visible, "Sword button was not hidden")
	_require(not game.ui.upgrade_buttons[GameIds.SPELL_LIGHTNING].visible, "Lightning button was not hidden")
	_require(not game.ui.upgrade_buttons[GameIds.SPELL_FIREBALL].visible, "Fireball button was not hidden")

	game.player.reset_run()
	_require(is_equal_approx(game.player.power_multiplier, 1.0), "reset_run did not reset POWER")
	_require(is_equal_approx(game.player.haste_cooldown_multiplier, 1.0), "reset_run did not reset HASTE")
	_require(is_equal_approx(game.player.armor_damage_reduction, 0.0), "reset_run did not reset ARMOR")
	_require(is_equal_approx(game.player.magnet_range_bonus, 0.0), "reset_run did not reset MAGNET")
	_require(is_equal_approx(game.player.attack.effective_cooldown_duration(), game.player.attack.definition.cooldown), "reset_run did not restore sword cooldown")

	print("LEVEL-UP QUEUE PASS")
	quit()
