extends SceneTree

const GAME_ROOT_SCENE := preload("res://scenes/app/game_root.tscn")

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
	var router := root.get_node_or_null("SceneRouter")
	var session := root.get_node_or_null("GameSession")
	_require(router != null and session != null, "Application autoloads are missing")
	session.reset_profile_for_tests()

	var app := GAME_ROOT_SCENE.instantiate() as GameRoot
	root.add_child(app)
	await process_frame
	_require(app.current_scene_container != null, "GameRoot did not create CurrentScene")
	_require(app.active_scene is MainMenu, "GameRoot did not open MainMenu on startup")
	_require(app.current_scene_container.get_child_count() == 1, "MainMenu startup created more than one major scene")
	_require(InputMap.has_action("interact"), "Hub interact action is missing")
	var has_e := false
	for event in InputMap.action_get_events("interact"):
		var key_event := event as InputEventKey
		if key_event != null and key_event.physical_keycode == KEY_E:
			has_e = true
	_require(has_e, "Hub interact action is not bound to E")

	var first_menu := app.active_scene
	var rpg_button := first_menu.find_child("RpgModeButton", true, false) as Button
	_require(rpg_button != null, "MainMenu RPG button is missing")
	var reset_button := first_menu.find_child("ResetProgressButton", true, false) as Button
	var reset_dialog := first_menu.find_child("ResetProgressConfirmation", true, false) as ConfirmationDialog
	_require(reset_button != null and reset_dialog != null, "MainMenu progress reset controls are missing")
	reset_button.pressed.emit()
	_require(reset_dialog.visible, "Progress reset confirmation did not open")
	reset_dialog.hide()
	rpg_button.pressed.emit()
	_require(app.active_scene is HubController, "MainMenu to Hub route failed")
	_require(first_menu.get_parent() == null, "Previous scene remained attached after transition")
	_require(app.current_scene_container.get_child_count() == 1, "Hub transition left multiple major scenes")

	router.show_hub()
	_require(app.current_scene_container.get_child_count() == 1, "Repeated route request duplicated the scene")
	var hub := app.active_scene as HubController
	hub.portal.expedition_requested.emit(&"test_location")
	_require(app.active_scene is ExpeditionController, "Hub to Expedition route failed")
	await process_frame
	var expedition := app.active_scene as ExpeditionController
	_require(expedition.combat != null, "Expedition did not create shared combat")

	var result := ExpeditionResult.create(false, &"test_location", 1, 0, 1.0)
	router.finish_expedition(result)
	_require(app.active_scene is HubController, "Expedition to Hub route failed")

	router.show_main_menu()
	_require(app.active_scene is MainMenu, "Hub to MainMenu route failed")
	var sandbox_button := app.active_scene.find_child("CombatSandboxButton", true, false) as Button
	_require(sandbox_button != null, "MainMenu sandbox button is missing")
	sandbox_button.pressed.emit()
	_require(app.active_scene is CombatSandboxController, "MainMenu to CombatSandbox route failed")
	await process_frame
	Engine.time_scale = 2.0
	router.leave_combat_sandbox()
	_require(app.active_scene is MainMenu, "CombatSandbox to MainMenu route failed")
	_require(is_equal_approx(Engine.time_scale, 1.0), "Sandbox exit did not restore time_scale")
	_require(app.current_scene_container.get_child_count() == 1, "Sandbox exit left multiple major scenes")

	print("SCENE ROUTER PASS")
	quit()
