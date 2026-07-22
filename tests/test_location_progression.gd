extends SceneTree

const CONTENT: GameContent = preload("res://resources/game_content.tres")
const LOCATION_ID := &"test_location"

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _run() -> void:
	var location := CONTENT.location(LOCATION_ID)
	_require(location != null, "test_location is missing from GameContent")
	_require(CONTENT.location(&"unknown") == null, "Unknown location lookup was not safe")
	_require(CONTENT.validate_locations().is_empty(), "Location catalog validation failed")
	_require(location.validate_definition().is_empty(), "Location definition validation failed")
	_require(location.tiers.size() == 10, "Location does not contain ten tiers")
	_require(location.maximum_tier() == 10, "Location maximum tier is incorrect")
	for expected_tier in range(1, 11):
		var definition := location.tier_definition(expected_tier)
		_require(definition != null, "Tier %d is missing" % expected_tier)
		_require(definition.tier == expected_tier, "Tier resources are not ordered")
		_require(definition.validate_definition().is_empty(), "Tier %d is invalid" % expected_tier)
	_require(location.tier_definition(0) == null, "Invalid tier zero was found")
	_require(location.tier_definition(11) == null, "Invalid tier eleven was found")
	_require(location.tier_definition(1).wave_count == 2, "Tier 1 does not have two waves")
	_require(location.tier_definition(1).guaranteed_elite_count == 2, "Tier 1 does not have two guaranteed elites")
	var final_tier := location.tier_definition(10)
	_require(final_tier.boss_id == GameIds.ENEMY_BOSS, "Tier 10 has the wrong boss ID")
	_require(CONTENT.enemy(final_tier.boss_id) != null, "Tier 10 boss does not exist")

	var profile := PlayerProfile.new()
	_require(profile.is_location_unlocked(LOCATION_ID), "New profile did not unlock test_location")
	_require(profile.location_progress.size() == 1, "New profile did not create location progress")
	var progress := profile.get_location_progress(LOCATION_ID)
	_require(progress != null, "Default location progress is missing")
	_require(progress.highest_unlocked_tier == 1, "New progress did not start at tier 1")
	_require(progress.highest_completed_tier == 0, "New progress has a completed tier")
	_require(progress.is_tier_unlocked(1), "Tier 1 is locked on a new profile")
	_require(not progress.is_tier_unlocked(2), "Tier 2 is unlocked too early")
	_require(profile.ensure_location_progress(LOCATION_ID) == progress, "ensure_location_progress created a duplicate")
	_require(profile.get_location_progress(&"unknown") == null, "Unknown progress lookup was not safe")
	_require(not profile.register_location_victory(null, 1), "Null location victory was accepted")
	_require(profile.calculate_tier_reward(null, 1) == 0, "Null location returned a reward")

	var gold_before := profile.gold
	_require(profile.calculate_tier_reward(location, 1) == 40, "First tier reward is incorrect")
	_require(profile.gold == gold_before, "Reward calculation changed profile gold")
	_require(profile.register_location_victory(location, 1), "Tier 1 victory was rejected")
	_require(progress.completion_count(1) == 1, "Tier 1 completion was not counted")
	_require(progress.highest_completed_tier == 1, "Highest completed tier was not updated")
	_require(progress.highest_unlocked_tier == 2, "Tier 2 was not unlocked")
	_require(progress.is_tier_completed(1), "Tier 1 was not marked completed")
	_require(profile.calculate_tier_reward(location, 1) == 20, "Repeat reward multiplier was not applied")
	_require(profile.gold == gold_before, "Progress registration changed profile gold")
	_require(profile.register_location_victory(location, 1), "Repeated tier 1 victory was rejected")
	_require(progress.completion_count(1) == 2, "Repeated victory did not increment completion count")
	_require(progress.highest_unlocked_tier == 2, "Repeated victory unlocked an extra tier")
	var unchanged_completed := progress.highest_completed_tier
	var unchanged_unlocked := progress.highest_unlocked_tier
	_require(progress.highest_completed_tier == unchanged_completed and progress.highest_unlocked_tier == unchanged_unlocked, "Defeat changed location progress")
	_require(not profile.register_location_victory(location, 3), "Locked tier victory was accepted")
	_require(not progress.register_victory(0, 10), "Invalid low tier victory was accepted")
	_require(not progress.register_victory(11, 10), "Invalid high tier victory was accepted")

	for tier in range(2, 10):
		_require(profile.register_location_victory(location, tier), "Tier %d victory was rejected" % tier)
	_require(progress.highest_unlocked_tier == 10, "Tier 10 was not unlocked")
	_require(not progress.boss_defeated, "Boss was defeated before tier 10 victory")
	_require(profile.register_location_victory(location, 10), "Tier 10 victory was rejected")
	_require(progress.highest_completed_tier == 10, "Tier 10 was not completed")
	_require(progress.highest_unlocked_tier == 10, "Tier unlock exceeded the maximum")
	_require(progress.boss_defeated, "Tier 10 victory did not mark the boss defeated")

	_require(profile.grant_gold(25), "Positive gold grant was rejected")
	_require(profile.gold == 25, "Gold grant was not applied")
	_require(not profile.grant_gold(-30), "Negative gold grant was accepted")
	_require(profile.gold == 25, "Negative grant changed gold")
	profile.gold = -1
	_require(profile.gold == 0, "Profile gold became negative")
	_require(_contains_no_nodes(profile), "PlayerProfile contains a Node reference")
	_require(_contains_no_nodes(progress), "LocationProgress contains a Node reference")

	var session := root.get_node_or_null("GameSession")
	_require(session != null, "GameSession autoload is missing")
	session.reset_profile_for_tests()
	_require(session.selected_location_tier == 1, "Session did not reset selected tier")
	var old_location: StringName = session.selected_location_id
	var old_tier: int = session.selected_location_tier
	_require(not session.select_expedition(LOCATION_ID, 2), "Session selected a locked tier")
	_require(session.selected_location_id == old_location and session.selected_location_tier == old_tier, "Failed selection mutated session")
	_require(not session.select_expedition(&"unknown", 1), "Session selected an unknown location")
	_require(session.profile.register_location_victory(location, 1), "Session profile did not unlock tier 2")
	_require(session.select_expedition(LOCATION_ID, 2), "Session did not select unlocked tier 2")
	_require(session.selected_location_tier == 2, "Session stored the wrong tier")
	_require(session.begin_expedition(LOCATION_ID), "Compatible begin_expedition failed")
	_require(session.selected_location_tier == 2, "begin_expedition discarded selected tier")

	print("LOCATION PROGRESSION PASS")
	quit()

func _contains_no_nodes(value: Variant, visited: Dictionary = {}) -> bool:
	if value is Node:
		return false
	if value is Resource:
		var resource := value as Resource
		var instance_id := resource.get_instance_id()
		if visited.has(instance_id):
			return true
		visited[instance_id] = true
		for property in resource.get_property_list():
			if (int(property.usage) & PROPERTY_USAGE_STORAGE) != 0:
				if not _contains_no_nodes(resource.get(property.name), visited):
					return false
	elif value is Array:
		for entry in value:
			if not _contains_no_nodes(entry, visited):
				return false
	elif value is Dictionary:
		for key in value:
			if not _contains_no_nodes(key, visited) or not _contains_no_nodes(value[key], visited):
				return false
	return true
