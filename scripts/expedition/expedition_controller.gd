class_name ExpeditionController
extends Node

const COMBAT_SCENE := preload("res://scenes/main.tscn")
const CONTENT: GameContent = preload("res://resources/game_content.tres")

var location_id: StringName = &"test_location"
var combat: GameMain
var result: ExpeditionResult
var location_definition: LocationDefinition
var tier_definition: ExpeditionTierDefinition
var startup_error := ""

func configure_location(value: StringName) -> void:
	location_id = value

func _ready() -> void:
	startup_error = _validate_selection()
	if not startup_error.is_empty():
		push_error(startup_error)
		_show_startup_error()
		return
	# Direct scene/test entry still receives a real run context; normal routing has
	# already created it in GameSession.begin_expedition().
	if not _session().run_context.is_active() and not _session().start_new_run():
		startup_error = "Не удалось создать контекст вылазки"
		push_error(startup_error)
		_show_startup_error()
		return
	combat = COMBAT_SCENE.instantiate() as GameMain
	combat.name = "Combat"
	combat.configure_mode(CombatModeConfig.expedition(), true)
	combat.configure_inventory(_session().inventory)
	combat.configure_run_inventory(_session().run_inventory, _session().run_context)
	combat.configure_economy(_session().profile, _session().shop_service)
	combat.configure_expedition(location_definition, tier_definition, _session().current_run_seed)
	combat.run_setup_requested.connect(_apply_profile_bonuses)
	combat.run_finished.connect(_on_run_finished)
	combat.result_action_requested.connect(_return_to_hub)
	add_child(combat)

func _show_startup_error() -> void:
	var layer := CanvasLayer.new()
	layer.name = "StartupErrorUI"
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.035, 0.022, 0.018, 0.97)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-280.0, -100.0)
	box.size = Vector2(560.0, 200.0)
	panel.add_child(box)
	var title := Label.new()
	title.text = "ВЫЛАЗКА НЕ МОЖЕТ БЫТЬ ЗАПУЩЕНА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("af3029"))
	box.add_child(title)
	var details := Label.new()
	details.text = startup_error
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(details)
	var return_button := Button.new()
	return_button.text = "ВЕРНУТЬСЯ В ХАБ"
	return_button.custom_minimum_size = Vector2(0.0, 54.0)
	return_button.pressed.connect(_return_to_hub)
	box.add_child(return_button)

func _validate_selection() -> String:
	location_definition = _session().selected_location()
	tier_definition = _session().selected_tier()
	if location_definition == null:
		return "Неизвестная локация вылазки: %s" % _session().selected_location_id
	if tier_definition == null:
		return "Ступень %d отсутствует в локации %s" % [_session().selected_location_tier, location_definition.id]
	location_id = location_definition.id
	if not _session().profile.is_location_unlocked(location_definition.id):
		return "Локация заблокирована: %s" % location_definition.id
	var progress: LocationProgress = _session().profile.get_location_progress(location_definition.id)
	if progress == null or not progress.is_tier_unlocked(tier_definition.tier):
		return "Ступень заблокирована: %d" % tier_definition.tier
	var errors := tier_definition.validate_definition()
	if not errors.is_empty():
		return "Некорректная ступень: %s" % ", ".join(errors)
	if not tier_definition.boss_id.is_empty() and CONTENT.enemy(tier_definition.boss_id) == null:
		return "Неизвестный босс: %s" % tier_definition.boss_id
	for wave_number in range(1, tier_definition.wave_count + 1):
		var wave := CONTENT.wave(wave_number)
		if wave == null or wave.enemy_roster.is_empty():
			return "Отсутствует конфигурация волны %d" % wave_number
		for enemy_id in wave.enemy_roster:
			if CONTENT.enemy(enemy_id) == null:
				return "Неизвестный противник %s в волне %d" % [enemy_id, wave_number]
	return ""

func _apply_profile_bonuses(player: PlayerHero) -> void:
	var profile: PlayerProfile = _session().profile
	player.apply_profile_bonuses(
		profile.permanent_max_health_bonus,
		profile.permanent_damage_bonus
	)
	player.apply_equipment_stats(PlayerStatCalculator.calculate(_session().inventory))

func _on_run_finished(victory: bool) -> void:
	if result != null:
		return
	var reward := 0
	if victory:
		if not _session().complete_run_successfully():
			push_error("Failed to commit expedition run loot")
			return
		reward = _session().profile.calculate_tier_reward(location_definition, tier_definition.tier)
		if not _session().profile.register_location_victory(location_definition, tier_definition.tier):
			push_error("Failed to register expedition victory")
			return
	result = ExpeditionResult.create(
		victory,
		location_definition.id,
		combat.current_wave(),
		combat.defeated_enemies,
		combat.run_duration_seconds,
		tier_definition.tier,
		combat.defeated_elites,
		reward
	)
	_session().claim_expedition_result(result)
	var details := "НАГРАДА: %d ЗОЛОТА\nСТУПЕНЬ: %d   ВОЛНА: %d\nВРАГОВ: %d   ЭЛИТНЫХ: %d   ВРЕМЯ: %.1f С" % [
		result.earned_gold,
		result.tier_number,
		result.reached_wave,
		result.defeated_enemies,
		result.defeated_elites,
		result.duration_seconds,
	]
	if victory:
		details += "\n\nДОБЫЧА СОХРАНЕНА: %d\nВ ОЖИДАНИИ МЕСТА: %d" % [
			_session().run_context.committed_item_count,
			_session().run_context.pending_item_count,
		]
	combat.ui.show_game_over(victory, "ВЕРНУТЬСЯ В ХАБ", details)

func _return_to_hub() -> void:
	get_node("/root/SceneRouter").finish_expedition(result)

func before_scene_exit() -> void:
	if combat != null:
		combat.shutdown()

func _session() -> Node:
	return get_node("/root/GameSession")
