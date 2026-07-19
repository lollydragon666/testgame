class_name GameUI
extends CanvasLayer

signal start_requested
signal upgrade_selected(kind: String)

var menu: ColorRect
var hud: Control
var upgrade_panel: ColorRect
var game_over_panel: ColorRect
var health_bar: ProgressBar
var health_label: Label
var xp_bar: ProgressBar
var xp_label: Label
var wave_label: Label
var level_label: Label
var game_over_title: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_menu()
	_build_hud()
	_build_upgrade_panel()
	_build_game_over_panel()
	show_menu()

func _full_rect(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _panel_color() -> Color:
	return Color(0.035, 0.022, 0.018, 0.94)

func _build_menu() -> void:
	menu = ColorRect.new()
	menu.color = _panel_color()
	_full_rect(menu)
	add_child(menu)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-250.0, -170.0)
	box.size = Vector2(500.0, 340.0)
	box.add_theme_constant_override("separation", 20)
	menu.add_child(box)
	var title := Label.new()
	title.text = "CIRCLE RAIDER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color("d0ad64"))
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "КРУГ ПРОТИВ БЕЗДНЫ"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color("8f7c61"))
	box.add_child(subtitle)
	var start_button := _button("⚔  НАЧАТЬ ПОХОД  ⚔")
	start_button.pressed.connect(func(): start_requested.emit())
	box.add_child(start_button)
	var controls := Label.new()
	controls.text = "WASD — движение    •    Мышь — направление    •    ЛКМ — удар"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_color_override("font_color", Color("d4c4a4"))
	box.add_child(controls)

func _build_hud() -> void:
	hud = Control.new()
	_full_rect(hud)
	add_child(hud)
	var left_box := VBoxContainer.new()
	left_box.position = Vector2(28.0, 24.0)
	left_box.size = Vector2(330.0, 125.0)
	hud.add_child(left_box)
	health_label = Label.new()
	left_box.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(330.0, 22.0)
	left_box.add_child(health_bar)
	xp_label = Label.new()
	left_box.add_child(xp_label)
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(330.0, 14.0)
	left_box.add_child(xp_bar)
	wave_label = Label.new()
	wave_label.position = Vector2(28.0, 665.0)
	wave_label.add_theme_font_size_override("font_size", 22)
	hud.add_child(wave_label)
	level_label = Label.new()
	level_label.position = Vector2(1110.0, 24.0)
	level_label.add_theme_font_size_override("font_size", 20)
	hud.add_child(level_label)

func _build_upgrade_panel() -> void:
	upgrade_panel = ColorRect.new()
	upgrade_panel.color = _panel_color()
	_full_rect(upgrade_panel)
	add_child(upgrade_panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-270.0, -230.0)
	box.size = Vector2(540.0, 460.0)
	box.add_theme_constant_override("separation", 16)
	upgrade_panel.add_child(box)
	var title := Label.new()
	title.text = "ВЫБЕРИ ДАР БЕЗДНЫ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("d0ad64"))
	box.add_child(title)
	for option in [["sword", "МЕЧ — длина, модель и урон"], ["speed", "ДВИЖЕНИЕ — скорость героя"], ["vitality", "ЖИВУЧЕСТЬ — здоровье и размер"]]:
		var choice := _button(String(option[1]))
		choice.pressed.connect(_emit_upgrade.bind(String(option[0])))
		box.add_child(choice)

func _emit_upgrade(kind: String) -> void:
	upgrade_selected.emit(kind)

func _build_game_over_panel() -> void:
	game_over_panel = ColorRect.new()
	game_over_panel.color = _panel_color()
	_full_rect(game_over_panel)
	add_child(game_over_panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-220.0, -120.0)
	box.size = Vector2(440.0, 240.0)
	game_over_panel.add_child(box)
	game_over_title = Label.new()
	game_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_title.add_theme_font_size_override("font_size", 38)
	box.add_child(game_over_title)
	var restart := _button("НОВЫЙ ПОХОД")
	restart.pressed.connect(func(): start_requested.emit())
	box.add_child(restart)

func _button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 62.0)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("d4c4a4"))
	return button

func show_menu() -> void:
	menu.visible = true
	hud.visible = false
	upgrade_panel.visible = false
	game_over_panel.visible = false

func show_game() -> void:
	menu.visible = false
	hud.visible = true
	upgrade_panel.visible = false
	game_over_panel.visible = false

func show_upgrade() -> void:
	upgrade_panel.visible = true
	hud.visible = false

func hide_upgrade() -> void:
	upgrade_panel.visible = false
	hud.visible = true

func show_game_over(victory: bool = false) -> void:
	game_over_title.text = "БЕЗДНА ПОВЕРЖЕНА" if victory else "ГЕРОЙ ПАЛ"
	game_over_panel.visible = true
	hud.visible = false

func set_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "ЖИЗНЬ  %d / %d" % [ceili(current), ceili(maximum)]

func set_experience(current: int, required: int, level: int) -> void:
	xp_bar.max_value = required
	xp_bar.value = current
	xp_label.text = "ОПЫТ  %d / %d" % [current, required]
	level_label.text = "УРОВЕНЬ %d" % level

func set_wave(value: int) -> void:
	wave_label.text = "ВОЛНА %d / 7" % value
