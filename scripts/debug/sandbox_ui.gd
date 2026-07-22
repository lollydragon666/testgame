class_name SandboxUI
extends CanvasLayer

signal leave_requested
signal reset_requested
signal clear_enemies_requested
signal clear_projectiles_requested
signal restore_player_requested
signal spawn_requested(enemy_id: StringName, count: int)
signal give_experience_requested(amount: int)
signal level_up_requested
signal reset_upgrades_requested
signal god_mode_changed(enabled: bool)
signal upgrade_requested(upgrade_id: StringName)
signal time_scale_changed(value: float)
signal auto_waves_changed(enabled: bool)

var game_content: GameContent
var panel: Control
var enemy_select: OptionButton
var upgrade_select: OptionButton
var stats_label: Label
var god_mode_button: Button
var auto_waves_button: Button
var god_mode := false
var auto_waves := false

func configure_content(content: GameContent) -> void:
	game_content = content

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	_build_interface()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_sandbox_ui"):
		panel.visible = not panel.visible
		get_viewport().set_input_as_handled()

func _build_interface() -> void:
	panel = ColorRect.new()
	panel.color = Color(0.035, 0.022, 0.018, 0.95)
	panel.position = Vector2(14.0, 14.0)
	panel.size = Vector2(360.0, 692.0)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10.0, 10.0)
	scroll.size = Vector2(340.0, 672.0)
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(318.0, 0.0)
	box.add_theme_constant_override("separation", 7)
	scroll.add_child(box)

	var title := Label.new()
	title.text = "БОЕВАЯ ЛАБОРАТОРИЯ  •  F1"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("d0ad64"))
	box.add_child(title)
	_add_button(box, "ВЕРНУТЬСЯ В МЕНЮ", func(): leave_requested.emit())
	_add_button(box, "ПЕРЕЗАПУСТИТЬ АРЕНУ  •  F5", func(): reset_requested.emit())
	_add_button(box, "ОЧИСТИТЬ ВРАГОВ", func(): clear_enemies_requested.emit())
	_add_button(box, "ОЧИСТИТЬ СНАРЯДЫ", func(): clear_projectiles_requested.emit())
	_add_button(box, "ВОССТАНОВИТЬ ИГРОКА", func(): restore_player_requested.emit())

	_add_section(box, "СОЗДАНИЕ ВРАГОВ")
	enemy_select = OptionButton.new()
	for definition in game_content.enemies:
		enemy_select.add_item(String(definition.id))
		enemy_select.set_item_metadata(enemy_select.item_count - 1, definition.id)
	box.add_child(enemy_select)
	_add_button(box, "SPAWN", _spawn_selected.bind(1))
	_add_button(box, "SPAWN ×10", _spawn_selected.bind(10))

	_add_section(box, "ИГРОК И УЛУЧШЕНИЯ")
	_add_button(box, "ВЫДАТЬ 100 ОПЫТА", func(): give_experience_requested.emit(100))
	_add_button(box, "ПОВЫСИТЬ УРОВЕНЬ", func(): level_up_requested.emit())
	_add_button(box, "СБРОСИТЬ УЛУЧШЕНИЯ", func(): reset_upgrades_requested.emit())
	god_mode_button = _add_button(box, "НЕУЯЗВИМОСТЬ: OFF", _toggle_god_mode)

	upgrade_select = OptionButton.new()
	for definition in game_content.upgrades:
		upgrade_select.add_item(definition.display_name)
		upgrade_select.set_item_metadata(upgrade_select.item_count - 1, definition.id)
	box.add_child(upgrade_select)
	_add_button(box, "APPLY SELECTED", _apply_selected_upgrade)
	for definition in game_content.upgrades:
		_add_button(box, "APPLY %s" % String(definition.id).to_upper(), upgrade_requested.emit.bind(definition.id))

	_add_section(box, "ВРЕМЯ И ВОЛНЫ")
	var time_select := OptionButton.new()
	for label in ["×0.5", "×1.0", "×2.0"]:
		time_select.add_item(label)
	time_select.select(1)
	time_select.item_selected.connect(_select_time_scale)
	box.add_child(time_select)
	auto_waves_button = _add_button(box, "AUTO WAVES: OFF", _toggle_auto_waves)

	_add_section(box, "СТАТИСТИКА")
	stats_label = Label.new()
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.add_theme_color_override("font_color", Color("d4c4a4"))
	box.add_child(stats_label)

func _add_button(parent: VBoxContainer, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 38.0)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _add_section(parent: VBoxContainer, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("a8874d"))
	parent.add_child(label)

func _spawn_selected(count: int) -> void:
	if enemy_select.item_count == 0:
		return
	spawn_requested.emit(enemy_select.get_selected_metadata() as StringName, count)

func _apply_selected_upgrade() -> void:
	if upgrade_select.item_count == 0:
		return
	upgrade_requested.emit(upgrade_select.get_selected_metadata() as StringName)

func _toggle_god_mode() -> void:
	god_mode = not god_mode
	god_mode_button.text = "НЕУЯЗВИМОСТЬ: %s" % ("ON" if god_mode else "OFF")
	god_mode_changed.emit(god_mode)

func _toggle_auto_waves() -> void:
	auto_waves = not auto_waves
	auto_waves_button.text = "AUTO WAVES: %s" % ("ON" if auto_waves else "OFF")
	auto_waves_changed.emit(auto_waves)

func _select_time_scale(index: int) -> void:
	var values := [0.5, 1.0, 2.0]
	time_scale_changed.emit(values[index])

func reset_controls() -> void:
	god_mode = false
	auto_waves = false
	god_mode_button.text = "НЕУЯЗВИМОСТЬ: OFF"
	auto_waves_button.text = "AUTO WAVES: OFF"

func set_stats(text_value: String) -> void:
	stats_label.text = text_value
