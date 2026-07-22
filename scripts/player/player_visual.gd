class_name PlayerVisual
extends CharacterVisual

const PLAYER_VISUAL := preload("res://resources/content/visuals/player.tres")

func _ready() -> void:
	apply_visual_definition(PLAYER_VISUAL)
	super._ready()

func sync_from_player(player: PlayerHero) -> void:
	set_facing(player.aim_direction)
	set_movement_state(player.movement.velocity)
	refresh_visual()

func draw_part(part_id: StringName) -> void:
	if part_id == PART_WEAPON:
		_draw_player_sword()
		return
	if part_id == PART_EFFECTS:
		super.draw_part(part_id)
		_draw_player_effects()
		return
	super.draw_part(part_id)

func _draw_player_sword() -> void:
	var player := get_parent() as PlayerHero
	if player == null or player.attack == null:
		return
	var world_direction := player.attack.swing_aim_direction if player.attack.swing_time > 0.0 else player.aim_direction
	world_direction = world_direction.rotated(player.attack.swing_offset())
	var screen_direction := IsoMath.world_to_screen(world_direction).normalized()
	var facing_sign := -1.0 if screen_direction.x < 0.0 else 1.0
	mirrored_visual_root.scale.x = facing_sign
	var local_direction := Vector2(screen_direction.x * facing_sign, screen_direction.y).normalized()
	weapon_socket.rotation = local_direction.angle()
	var style := player.attack.definition.visual_style if player.attack.definition != null else &"gladius"
	var palette := _weapon_palette(style)
	var length := player.attack.effective_visual_sword_length()
	var width := 4.5 + player.attack.sword_tier * 0.7
	var guard_distance := player.visual_radius + 5.0
	var blade_base := Vector2(guard_distance + 5.0, 0.0)
	var tip := Vector2(length, 0.0)
	var shoulder := tip - Vector2(14.0 + player.attack.sword_tier * 2.0, 0.0)
	weapon_visual.draw_line(Vector2(player.visual_radius * 0.55, 0.0), blade_base, palette["grip"], 7.0)
	weapon_visual.draw_line(Vector2(guard_distance, -10.0 - player.attack.sword_tier * 2.0), Vector2(guard_distance, 10.0 + player.attack.sword_tier * 2.0), palette["guard"], 6.0)
	var blade := PackedVector2Array([blade_base + Vector2(0.0, -width), shoulder + Vector2(0.0, -width), tip, shoulder + Vector2(0.0, width), blade_base + Vector2(0.0, width)])
	weapon_visual.draw_colored_polygon(blade, palette["blade"])
	weapon_visual.draw_polyline(PackedVector2Array([blade[0], blade[1], blade[2], blade[3], blade[4]]), palette["edge"], 1.5)

func _draw_player_effects() -> void:
	var player := get_parent() as PlayerHero
	if player == null or player.attack == null or player.attack.swing_time <= 0.0:
		return
	var trail := PackedVector2Array()
	for index in 24:
		var progress := float(index) / 23.0
		var offset := lerpf(player.attack.swing_start_offset(), player.attack.swing_offset(), progress)
		var world_direction := player.attack.swing_aim_direction.rotated(offset)
		trail.append(IsoMath.world_to_screen(world_direction).normalized() * player.attack.effective_visual_sword_length())
	effects.draw_polyline(trail, Color(0.69, 0.19, 0.16, 0.72), 10.0)

func _weapon_palette(style: StringName) -> Dictionary:
	var palettes := {
		&"void": {"blade": Color("66547f"), "edge": Color("b69ad8"), "guard": Color("31243f"), "grip": Color("17101e")},
		&"sunforged": {"blade": Color("f0c65a"), "edge": Color("fff0a1"), "guard": Color("b97921"), "grip": Color("5a2d17")},
		&"dragon": {"blade": Color("d8d0bd"), "edge": Color("fff2d2"), "guard": Color("9c3d29"), "grip": Color("3b1915")},
		&"storm": {"blade": Color("9ac7dc"), "edge": Color("e2f5ff"), "guard": Color("547d91"), "grip": Color("253b45")},
		&"royal": {"blade": Color("d7d5c8"), "edge": Color("fff8d1"), "guard": Color("d0ad64"), "grip": Color("4c263f")},
	}
	return palettes.get(style, {"blade": Color("d4c4a4"), "edge": Color("574637"), "guard": Color("a8874d"), "grip": Color("35271d")})
