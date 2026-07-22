class_name GameRoot
extends Node

@onready var current_scene_container: Node = $CurrentScene

var active_scene: Node
var active_scene_path := ""
var transition_in_progress := false

func _ready() -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router == null:
		push_error("GameRoot requires SceneRouter autoload")
		return
	router.register_root(self)
	router.show_main_menu()

func transition_to(scene: PackedScene, setup_callback: Callable = Callable()) -> Node:
	if transition_in_progress or scene == null:
		return active_scene
	var scene_path := scene.resource_path
	if active_scene != null and scene_path == active_scene_path:
		return active_scene
	transition_in_progress = true
	if active_scene != null:
		if active_scene.has_method("before_scene_exit"):
			active_scene.call("before_scene_exit")
		active_scene.process_mode = Node.PROCESS_MODE_DISABLED
		current_scene_container.remove_child(active_scene)
		active_scene.queue_free()
		active_scene = null
	var next_scene := scene.instantiate()
	if setup_callback.is_valid():
		setup_callback.call(next_scene)
	current_scene_container.add_child(next_scene)
	active_scene = next_scene
	active_scene_path = scene_path
	transition_in_progress = false
	return active_scene
