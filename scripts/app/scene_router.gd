extends Node

const MAIN_MENU_SCENE := preload("res://scenes/menu/main_menu.tscn")
const HUB_SCENE := preload("res://scenes/hub/hub.tscn")
const EXPEDITION_SCENE := preload("res://scenes/expeditions/expedition.tscn")
const COMBAT_SANDBOX_SCENE := preload("res://scenes/debug/combat_sandbox.tscn")

var _game_root: Node

func register_root(root: Node) -> void:
	_game_root = root

func show_main_menu() -> void:
	_session().enter_menu()
	_change_scene(MAIN_MENU_SCENE)

func show_hub() -> void:
	_session().enter_hub()
	_change_scene(HUB_SCENE)

func start_expedition(location_id: StringName) -> void:
	if not _session().begin_expedition(location_id):
		push_warning("Location is locked: %s" % location_id)
		return
	_change_scene(EXPEDITION_SCENE, _configure_expedition.bind(location_id))

func show_combat_sandbox() -> void:
	_session().enter_combat_sandbox()
	_change_scene(COMBAT_SANDBOX_SCENE)

func finish_expedition(result: ExpeditionResult) -> void:
	if result != null:
		_session().last_expedition_result = result
	show_hub()

func restart_combat_sandbox() -> void:
	if _game_root == null:
		return
	var sandbox := _game_root.active_scene as CombatSandboxController
	if sandbox != null:
		sandbox.reset_arena()

func leave_combat_sandbox() -> void:
	Engine.time_scale = 1.0
	show_main_menu()

func _change_scene(scene: PackedScene, setup_callback: Callable = Callable()) -> void:
	if _game_root == null:
		push_error("SceneRouter has no registered GameRoot")
		return
	_game_root.transition_to(scene, setup_callback)

func _configure_expedition(node: Node, location_id: StringName) -> void:
	var expedition := node as ExpeditionController
	if expedition != null:
		expedition.configure_location(location_id)

func _session() -> Node:
	return get_node("/root/GameSession")
