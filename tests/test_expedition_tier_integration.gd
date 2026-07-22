extends SceneTree

const EXPEDITION_SCENE := preload("res://scenes/expeditions/expedition.tscn")
const CONTENT: GameContent = preload("res://resources/game_content.tres")

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	paused = false
	quit(1)

func _session() -> Node:
	return root.get_node("GameSession")

func _select_tier(tier: int, seed_value: int) -> bool:
	_session().clear_expedition_selection()
	_session().set_next_run_seed(seed_value)
	return _session().select_expedition(&"test_location", tier)

func _run_victory(tier: int, seed_value: int) -> ExpeditionResult:
	_require(_select_tier(tier, seed_value), "Could not select tier %d" % tier)
	var expedition := EXPEDITION_SCENE.instantiate() as ExpeditionController
	root.add_child(expedition)
	for _frame in 3:
		await physics_frame
	_require(expedition.startup_error.is_empty() and expedition.combat != null, "Expedition configuration failed")
	expedition.combat.mode_config.enable_level_up_choices = false
	var guard := 0
	while expedition.result == null and guard < 1000:
		guard += 1
		expedition.combat.wave_manager._physics_process(10.0)
		for enemy in expedition.combat.world_state.enemy_snapshot():
			enemy.take_damage(1000000.0)
		await process_frame
	_require(expedition.result != null, "Tier %d did not finish" % tier)
	var result := expedition.result
	expedition.before_scene_exit()
	root.remove_child(expedition)
	expedition.queue_free()
	paused = false
	return result

func _run() -> void:
	var session := _session()
	session.reset_profile_for_tests()
	var location := CONTENT.location(&"test_location")

	var tier_one := await _run_victory(1, 1101)
	var progress: LocationProgress = session.profile.get_location_progress(location.id)
	_require(tier_one.victory and tier_one.tier_number == 1, "Tier 1 result is incorrect")
	_require(tier_one.defeated_elites >= location.tier_definition(1).guaranteed_elite_count, "Tier 1 did not defeat guaranteed elites")
	_require(tier_one.earned_gold == 40 and session.profile.gold == 40, "First victory did not grant full reward")
	_require(progress.highest_unlocked_tier == 2, "Tier 1 victory did not unlock tier 2")
	_require(progress.completion_count(1) == 1, "Tier 1 completion was not recorded")

	_require(_select_tier(2, 1102), "Could not select unlocked tier 2")
	var defeat_expedition := EXPEDITION_SCENE.instantiate() as ExpeditionController
	root.add_child(defeat_expedition)
	for _frame in 3:
		await physics_frame
	defeat_expedition.combat.player.take_damage(1000000.0)
	await process_frame
	_require(defeat_expedition.result != null and not defeat_expedition.result.victory, "Tier 2 defeat result is incorrect")
	_require(defeat_expedition.result.earned_gold == 0, "Tier defeat granted gold")
	_require(progress.highest_unlocked_tier == 2 and progress.completion_count(2) == 0, "Defeat changed tier progression")
	defeat_expedition.before_scene_exit()
	root.remove_child(defeat_expedition)
	defeat_expedition.queue_free()

	var tier_two := await _run_victory(2, 1103)
	_require(tier_two.tier_number == 2, "Tier 2 result stored wrong tier")
	_require(progress.highest_unlocked_tier == 3, "Tier 2 victory did not unlock tier 3")
	_require(session.profile.gold == 95, "Tier 2 full reward was not granted")

	var repeat_tier_one := await _run_victory(1, 1104)
	_require(repeat_tier_one.earned_gold == 20, "Repeat tier reward is incorrect")
	_require(progress.completion_count(1) == 2, "Repeat victory did not increment completion count")
	_require(session.profile.gold == 115, "Repeat reward was not granted exactly once")
	_require(not session.claim_expedition_result(repeat_tier_one), "Result reward could be claimed twice")
	_require(session.profile.gold == 115, "Double claim changed gold")

	progress.highest_unlocked_tier = 10
	var tier_ten := await _run_victory(10, 1110)
	_require(tier_ten.tier_number == 10, "Tier 10 result stored wrong tier")
	_require(tier_ten.defeated_elites >= location.tier_definition(10).guaranteed_elite_count, "Tier 10 elite count is incorrect")
	_require(progress.boss_defeated, "Tier 10 did not mark boss defeated")
	_require(progress.highest_unlocked_tier == 10, "Tier 10 unlocked tier 11")
	_require(session.profile.completed_expeditions == 4, "Completed expedition count is incorrect")

	var gold_before_invalid: int = session.profile.gold
	var state_before_invalid := [session.selected_location_id, session.selected_location_tier, session.current_run_seed]
	_require(not session.select_expedition(&"missing_location", 1), "Unknown location was selected")
	_require([session.selected_location_id, session.selected_location_tier, session.current_run_seed] == state_before_invalid, "Invalid location selection partially mutated session")
	progress.highest_unlocked_tier = 1
	_require(not session.select_expedition(&"test_location", 2), "Locked tier was selected")
	_require(session.profile.gold == gold_before_invalid, "Selection changed gold")

	print("EXPEDITION TIER INTEGRATION PASS")
	quit()
