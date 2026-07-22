class_name ExpeditionController
extends Node

const COMBAT_SCENE := preload("res://scenes/main.tscn")

var location_id: StringName = &"test_location"
var combat: GameMain
var result: ExpeditionResult

func configure_location(value: StringName) -> void:
	location_id = value

func _ready() -> void:
	combat = COMBAT_SCENE.instantiate() as GameMain
	combat.name = "Combat"
	combat.configure_mode(CombatModeConfig.expedition(), true)
	combat.configure_run_seed(_session().current_run_seed)
	combat.run_setup_requested.connect(_apply_profile_bonuses)
	combat.run_finished.connect(_on_run_finished)
	combat.result_action_requested.connect(_return_to_hub)
	add_child(combat)

func _apply_profile_bonuses(player: PlayerHero) -> void:
	var profile: PlayerProfile = _session().profile
	player.apply_profile_bonuses(
		profile.permanent_max_health_bonus,
		profile.permanent_damage_bonus
	)

func _on_run_finished(victory: bool) -> void:
	if result != null:
		return
	result = ExpeditionResult.create(
		victory,
		location_id,
		combat.current_wave(),
		combat.defeated_enemies,
		combat.run_duration_seconds
	)
	_session().claim_expedition_result(result)
	var details := "НАГРАДА: %d ЗОЛОТА\nВОЛНА: %d   ВРАГОВ: %d   ВРЕМЯ: %.1f С" % [
		result.earned_gold,
		result.reached_wave,
		result.defeated_enemies,
		result.duration_seconds,
	]
	combat.ui.show_game_over(victory, "ВЕРНУТЬСЯ В ХАБ", details)

func _return_to_hub() -> void:
	if result == null:
		return
	get_node("/root/SceneRouter").finish_expedition(result)

func before_scene_exit() -> void:
	if combat != null:
		combat.shutdown()

func _session() -> Node:
	return get_node("/root/GameSession")
