extends SceneTree

const TEST_SAVE_PATH := "user://test_profile_reset.json"

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_require(session != null, "GameSession autoload is missing")
	session.reset_profile_for_tests()
	session.profile.gold = 777
	session.profile.permanent_max_health_bonus = 50.0
	session.profile.completed_expeditions = 4
	var progress: LocationProgress = session.profile.get_location_progress(&"test_location")
	progress.highest_unlocked_tier = 6
	progress.highest_completed_tier = 5

	_require(session.reset_profile(TEST_SAVE_PATH), "Clean profile could not be saved")
	_require(session.profile.gold == 0, "Gold survived profile reset")
	_require(is_zero_approx(session.profile.permanent_max_health_bonus), "Permanent health survived profile reset")
	_require(session.profile.completed_expeditions == 0, "Completed expeditions survived profile reset")
	progress = session.profile.get_location_progress(&"test_location")
	_require(progress != null and progress.highest_unlocked_tier == 1, "Location progression survived profile reset")
	_require(session.inventory.inventory_size() == 1, "Reset profile did not restore only the starter equipment")
	_require(FileAccess.file_exists(TEST_SAVE_PATH), "Reset profile was not persisted")

	var absolute_test_path := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	DirAccess.remove_absolute(absolute_test_path)
	print("PROFILE RESET PASS")
	quit()
