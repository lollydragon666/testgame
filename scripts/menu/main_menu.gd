class_name MainMenu
extends Control

func _ready() -> void:
	_build_interface()

func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("090706")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-270.0, -205.0)
	panel.size = Vector2(540.0, 410.0)
	panel.add_theme_constant_override("separation", 22)
	background.add_child(panel)

	var title := Label.new()
	title.text = "CIRCLE RAIDER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color("d0ad64"))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "ВЫБЕРИ СВОЙ ПУТЬ"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("8f7c61"))
	panel.add_child(subtitle)

	var rpg_button := _make_button("RpgModeButton", "RPG-РЕЖИМ")
	rpg_button.pressed.connect(_show_hub)
	panel.add_child(rpg_button)
	rpg_button.grab_focus()

	var sandbox_button := _make_button("CombatSandboxButton", "ТЕСТОВАЯ АРЕНА")
	sandbox_button.pressed.connect(_show_sandbox)
	panel.add_child(sandbox_button)

	var exit_button := _make_button("ExitButton", "ВЫЙТИ")
	exit_button.pressed.connect(get_tree().quit)
	exit_button.visible = not OS.has_feature("web")
	panel.add_child(exit_button)

func _show_hub() -> void:
	get_node("/root/SceneRouter").show_hub()

func _show_sandbox() -> void:
	get_node("/root/SceneRouter").show_combat_sandbox()

func _make_button(node_name: String, text_value: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 66.0)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color("d4c4a4"))
	return button
