class_name GameUI
extends CanvasLayer

enum CombatDisplayState {
	WAVES,
	BOSS,
}

signal start_requested
signal upgrade_selected(kind: StringName)

## Небольшая блокировка предотвращает случайный выбор кнопкой, открывшей окно уровня.
const UPGRADE_INPUT_DELAY := 0.20
const MAX_VISIBLE_UPGRADES := 3

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
var magic_label: Label
var game_over_title: Label
var upgrade_buttons: Dictionary[StringName, Button] = {}
var upgrade_delay_timer: Timer
## Пока true, кнопки улучшений игнорируют ввод.
var upgrade_selection_locked := true
## Босс отображается отдельным состоянием, а не как восьмая обычная волна.
var combat_display_state := CombatDisplayState.WAVES
var game_content: GameContent
var total_waves := 1

func configure_content(content: GameContent) -> void:
	game_content = content
	total_waves = maxi(1, content.wave_count())

func _ready() -> void:
	if game_content == null:
		push_error("GameUI requires GameContent before entering the tree")
		return
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
	var magic_controls := Label.new()
	magic_controls.text = "ПКМ — выбранное заклинание"
	magic_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	magic_controls.add_theme_color_override("font_color", Color("7fa9d8"))
	box.add_child(magic_controls)

func _build_hud() -> void:
	hud = Control.new()
	_full_rect(hud)
	add_child(hud)
	var top_left := MarginContainer.new()
	top_left.name = "TopLeftContainer"
	top_left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_left.offset_left = 28.0
	top_left.offset_top = 24.0
	top_left.offset_right = 358.0
	top_left.offset_bottom = 154.0
	hud.add_child(top_left)
	var left_box := VBoxContainer.new()
	left_box.custom_minimum_size = Vector2(330.0, 125.0)
	top_left.add_child(left_box)
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

	var top_right := MarginContainer.new()
	top_right.name = "TopRightContainer"
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.offset_left = -280.0
	top_right.offset_top = 24.0
	top_right.offset_right = -28.0
	top_right.offset_bottom = 62.0
	hud.add_child(top_right)
	level_label = Label.new()
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.add_theme_font_size_override("font_size", 20)
	top_right.add_child(level_label)

	var bottom_left := MarginContainer.new()
	bottom_left.name = "BottomLeftContainer"
	bottom_left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom_left.offset_left = 28.0
	bottom_left.offset_top = -55.0
	bottom_left.offset_right = 280.0
	bottom_left.offset_bottom = -24.0
	hud.add_child(bottom_left)
	wave_label = Label.new()
	wave_label.add_theme_font_size_override("font_size", 22)
	bottom_left.add_child(wave_label)

	var bottom_right := MarginContainer.new()
	bottom_right.name = "BottomRightContainer"
	bottom_right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom_right.offset_left = -440.0
	bottom_right.offset_top = -55.0
	bottom_right.offset_right = -28.0
	bottom_right.offset_bottom = -24.0
	hud.add_child(bottom_right)
	magic_label = Label.new()
	magic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	magic_label.add_theme_font_size_override("font_size", 18)
	magic_label.add_theme_color_override("font_color", Color("7fa9d8"))
	bottom_right.add_child(magic_label)

func _build_upgrade_panel() -> void:
	upgrade_panel = ColorRect.new()
	upgrade_panel.color = _panel_color()
	_full_rect(upgrade_panel)
	add_child(upgrade_panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-280.0, -300.0)
	box.size = Vector2(560.0, 600.0)
	box.add_theme_constant_override("separation", 12)
	upgrade_panel.add_child(box)
	var title := Label.new()
	title.text = "ВЫБЕРИ ДАР БЕЗДНЫ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("d0ad64"))
	box.add_child(title)
	for definition in game_content.upgrades:
		var choice := _button(definition.display_name)
		choice.pressed.connect(_emit_upgrade.bind(definition.id))
		box.add_child(choice)
		upgrade_buttons[definition.id] = choice

	upgrade_delay_timer = Timer.new()
	upgrade_delay_timer.name = "UpgradeInputDelay"
	upgrade_delay_timer.one_shot = true
	upgrade_delay_timer.wait_time = UPGRADE_INPUT_DELAY
	upgrade_delay_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	upgrade_delay_timer.timeout.connect(_unlock_upgrade_buttons)
	upgrade_panel.add_child(upgrade_delay_timer)

func _emit_upgrade(kind: StringName) -> void:
	if upgrade_selection_locked:
		return
	upgrade_selection_locked = true
	_set_upgrade_buttons_disabled(true)
	upgrade_selected.emit(kind)

func _set_upgrade_buttons_disabled(disabled: bool) -> void:
	for kind in upgrade_buttons:
		var button: Button = upgrade_buttons[kind]
		button.disabled = disabled

func _unlock_upgrade_buttons() -> void:
	if upgrade_panel.visible:
		upgrade_selection_locked = false
		for kind in upgrade_buttons:
			var button: Button = upgrade_buttons[kind]
			button.disabled = not button.visible

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
	upgrade_delay_timer.stop()
	upgrade_selection_locked = true
	menu.visible = true
	hud.visible = false
	upgrade_panel.visible = false
	game_over_panel.visible = false

func show_game() -> void:
	upgrade_delay_timer.stop()
	upgrade_selection_locked = true
	menu.visible = false
	hud.visible = true
	upgrade_panel.visible = false
	game_over_panel.visible = false

func show_upgrade(available_upgrades: Array[StringName]) -> void:
	upgrade_selection_locked = true
	var visible_upgrades: Array[StringName] = []
	for kind in available_upgrades:
		if visible_upgrades.size() >= MAX_VISIBLE_UPGRADES:
			break
		if upgrade_buttons.has(kind) and not visible_upgrades.has(kind):
			visible_upgrades.append(kind)
	for kind in upgrade_buttons:
		var button: Button = upgrade_buttons[kind]
		button.visible = visible_upgrades.has(kind)
		button.disabled = true
	upgrade_delay_timer.start()
	upgrade_panel.visible = true
	hud.visible = false

func hide_upgrade() -> void:
	upgrade_delay_timer.stop()
	upgrade_selection_locked = true
	upgrade_panel.visible = false
	hud.visible = true

func show_game_over(victory: bool = false) -> void:
	upgrade_delay_timer.stop()
	upgrade_selection_locked = true
	game_over_title.text = "БЕЗДНА ПОВЕРЖЕНА" if victory else "ГЕРОЙ ПАЛ"
	menu.visible = false
	hud.visible = false
	upgrade_panel.visible = false
	game_over_panel.visible = true

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
	combat_display_state = CombatDisplayState.WAVES
	wave_label.add_theme_color_override("font_color", Color("d4c4a4"))
	wave_label.text = "ВОЛНА %d / %d" % [value, total_waves]

func set_boss_state() -> void:
	combat_display_state = CombatDisplayState.BOSS
	wave_label.add_theme_color_override("font_color", Color("af3029"))
	wave_label.text = "БОСС"

func set_magic(spell_kind: StringName, spell_level: int) -> void:
	if spell_kind.is_empty():
		magic_label.text = "МАГИЯ: НЕ ВЫБРАНА · ПКМ"
		return
	var definition := game_content.spell(spell_kind)
	if definition == null:
		push_error("Unknown UI spell: %s" % spell_kind)
		return
	var short_name := definition.display_name.get_slice(" — ", 0)
	magic_label.text = "МАГИЯ: %s · УР. %d · ПКМ" % [short_name, spell_level]
