class_name EnemyVisual
extends CharacterVisual

const FALLBACK_VISUAL := preload("res://resources/content/visuals/enemy_swordsman.tres")

func _ready() -> void:
	var enemy := get_parent() as EnemyBase
	var profile := FALLBACK_VISUAL
	if enemy != null and enemy.definition != null and enemy.definition.visual_definition != null:
		profile = enemy.definition.visual_definition
	apply_visual_definition(profile)
	super._ready()

func sync_from_enemy(enemy: EnemyBase) -> void:
	if enemy.player != null:
		set_facing(enemy.player.world_position - enemy.world_position)
	set_movement_state(enemy.world_position - enemy.previous_world_position)

func refresh_status() -> void:
	refresh_effects()

func draw_part(part_id: StringName) -> void:
	if part_id == PART_EFFECTS:
		super.draw_part(part_id)
		_draw_enemy_status()
		return
	super.draw_part(part_id)

func _draw_enemy_status() -> void:
	var enemy := get_parent() as EnemyBase
	if enemy == null:
		return
	if enemy.is_elite:
		var gold := Color("d8b45c")
		effects.draw_arc(Vector2(0.0, -visual_definition.body_height * 0.52), enemy.visual_radius + 7.0, 0.0, TAU, 32, gold, 3.0)
		var marker_y := -visual_definition.visual_height - 18.0
		effects.draw_colored_polygon(PackedVector2Array([Vector2(0.0, marker_y - 7.0), Vector2(7.0, marker_y), Vector2(0.0, marker_y + 7.0), Vector2(-7.0, marker_y)]), gold)
	if enemy.health < enemy.max_health:
		var width := maxf(44.0, enemy.visual_radius * 2.0)
		var ratio := clampf(enemy.health / enemy.max_health, 0.0, 1.0)
		var y := -visual_definition.visual_height - 10.0
		effects.draw_rect(Rect2(-width * 0.5, y, width, 4.0), Color(0.05, 0.03, 0.025, 0.8))
		effects.draw_rect(Rect2(-width * 0.5, y, width * ratio, 4.0), Color("af3029"))
