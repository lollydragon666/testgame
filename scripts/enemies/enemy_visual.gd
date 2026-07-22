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
	var archetype := enemy as ArchetypeEnemy
	if archetype != null and archetype.heal_windup_remaining > 0.0:
		refresh_effects()

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
	var archetype := enemy as ArchetypeEnemy
	if archetype != null and enemy.definition != null:
		if enemy.definition.enemy_class == EnemyDefinition.EnemyClass.COMMANDER:
			effects.draw_set_transform(Vector2(0.0, 4.0), 0.0, Vector2(1.0, 0.46))
			effects.draw_arc(Vector2.ZERO, 72.0, 0.0, TAU, 48, Color(0.83, 0.57, 0.18, 0.38), 3.0)
			effects.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif enemy.definition.enemy_class == EnemyDefinition.EnemyClass.HEALER and archetype.heal_windup_remaining > 0.0:
			var pulse := 16.0 + sin(Time.get_ticks_msec() * 0.012) * 4.0
			effects.draw_arc(Vector2(0.0, -24.0), pulse, 0.0, TAU, 24, Color(0.38, 0.92, 0.58, 0.8), 3.0)
			if is_instance_valid(archetype.heal_target):
				var link := IsoMath.world_to_screen(archetype.heal_target.world_position - enemy.world_position)
				effects.draw_dashed_line(Vector2(0.0, -20.0), link, Color(0.42, 0.9, 0.56, 0.72), 3.0, 8.0)
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
