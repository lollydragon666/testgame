extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameMain
	root.add_child(game)
	await process_frame
	game._start_run()
	game.wave_manager.stop()

	game.player.add_experience(1000)
	var earned_levels := game.player.level - 1
	_require(earned_levels > 1, "Test setup did not earn several levels at once")
	_require(game.pending_level_ups == earned_levels, "Simultaneous level-ups were lost")
	_require(paused, "Game was not paused for the first queued upgrade")
	_require(game.ui.upgrade_panel.visible, "Upgrade panel is not visible")

	for remaining_after_choice in range(earned_levels - 1, -1, -1):
		game._apply_upgrade(GameIds.UPGRADE_SPEED)
		_require(game.pending_level_ups == remaining_after_choice, "Queue did not consume exactly one level-up")
		if remaining_after_choice > 0:
			_require(paused, "Game resumed before queued upgrades were exhausted")
			_require(game.ui.upgrade_panel.visible, "Next queued panel was not shown")
			_require(game.ui.upgrade_selection_locked, "Next panel skipped its input delay")

	_require(not paused, "Game remained paused after the final queued upgrade")
	_require(not game.ui.upgrade_panel.visible, "Panel remained visible after queue completion")

	game.player.attack.sword_tier = PlayerAttack.MAX_SWORD_TIER
	for _index in PlayerMagic.MAX_SPELL_LEVEL:
		game.player.magic.unlock_or_upgrade(GameIds.SPELL_LIGHTNING)
		game.player.magic.unlock_or_upgrade(GameIds.SPELL_FIREBALL)
	_require(not game.player.magic.unlock_or_upgrade(GameIds.SPELL_LIGHTNING), "Lightning exceeded its maximum level")
	_require(not game.player.magic.unlock_or_upgrade(GameIds.SPELL_FIREBALL), "Fireball exceeded its maximum level")
	_require(game.player.magic.get_spell_level(GameIds.SPELL_LIGHTNING) == PlayerMagic.MAX_SPELL_LEVEL, "Lightning level limit is incorrect")
	_require(game.player.magic.get_spell_level(GameIds.SPELL_FIREBALL) == PlayerMagic.MAX_SPELL_LEVEL, "Fireball level limit is incorrect")

	var choices := game.available_upgrade_choices()
	_require(not choices.has(GameIds.UPGRADE_SWORD), "Tier 6 sword remained in available upgrades")
	_require(not choices.has(GameIds.SPELL_LIGHTNING), "Max-level lightning remained available")
	_require(not choices.has(GameIds.SPELL_FIREBALL), "Max-level fireball remained available")
	_require(choices.has(GameIds.UPGRADE_SPEED) and choices.has(GameIds.UPGRADE_VITALITY), "Unlimited upgrades disappeared")

	game._on_level_up(99)
	_require(not game.ui.upgrade_buttons[GameIds.UPGRADE_SWORD].visible, "Sword button was not hidden")
	_require(not game.ui.upgrade_buttons[GameIds.SPELL_LIGHTNING].visible, "Lightning button was not hidden")
	_require(not game.ui.upgrade_buttons[GameIds.SPELL_FIREBALL].visible, "Fireball button was not hidden")
	_require(game.ui.upgrade_buttons[GameIds.UPGRADE_SPEED].visible, "Speed button should remain visible")

	print("LEVEL-UP QUEUE PASS")
	quit()
