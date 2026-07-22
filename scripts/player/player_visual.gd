class_name PlayerVisual
extends Node2D

func _draw() -> void:
	var player := get_parent() as PlayerHero
	if player == null or player.attack == null:
		return
	draw_set_transform(Vector2(0.0, 9.0), 0.0, Vector2(1.35, 0.48))
	draw_circle(Vector2.ZERO, player.visual_radius, Color(0.01, 0.008, 0.008, 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body_color := Color("751714")
	if player.invulnerability > 0.0 and int(Time.get_ticks_msec() / 55) % 2 == 0:
		body_color.a = 0.38
	draw_circle(Vector2.ZERO, player.visual_radius, body_color)
	draw_arc(Vector2.ZERO, player.visual_radius, 0.0, TAU, 40, Color("d4c4a4"), 2.0)
	var look_angle := IsoMath.screen_angle(player.aim_direction)
	var eye := Vector2.from_angle(look_angle) * player.visual_radius * 0.5
	draw_circle(eye, 3.2, Color("d4c4a4"))
	var weapon_aim := player.attack.swing_aim_direction if player.attack.swing_time > 0.0 else player.aim_direction
	if player.attack.swing_time > 0.0:
		_draw_swing_trail(player, weapon_aim)
	_draw_sword(player, weapon_aim.rotated(player.attack.swing_offset()))

func _draw_swing_trail(player: PlayerHero, weapon_aim: Vector2) -> void:
	var start_offset := player.attack.swing_start_offset()
	var current_offset := player.attack.swing_offset()
	var trail := PackedVector2Array()
	for index in 24:
		var progress := float(index) / 23.0
		var world_direction := weapon_aim.rotated(lerpf(start_offset, current_offset, progress))
		var screen_direction := IsoMath.world_to_screen(world_direction).normalized()
		trail.append(screen_direction * player.attack.visual_sword_length)
	draw_polyline(trail, Color(0.69, 0.19, 0.16, 0.72), 10.0)

func _draw_sword(player: PlayerHero, world_direction: Vector2) -> void:
	var direction := IsoMath.world_to_screen(world_direction).normalized()
	var side := direction.orthogonal()
	var is_final_tier := player.attack.definition != null and player.attack.sword_tier == player.attack.definition.max_tier
	var style := player.attack.definition.visual_style if player.attack.definition != null else &"gladius"
	var style_variant := absi(String(style).hash()) % 4
	var guard_distance := player.visual_radius + (18.0 if is_final_tier else 6.0) + float(style_variant)
	var blade_base := direction * (guard_distance + 5.0)
	var tip := direction * player.attack.visual_sword_length
	var palette := _weapon_palette(style)
	var guard_half_width := 8.0 + player.attack.sword_tier * 3.0 + float(style_variant) * 2.0
	draw_line(direction * player.visual_radius * 0.55, blade_base, palette["grip"], 7.0)
	draw_line(direction * guard_distance - side * guard_half_width, direction * guard_distance + side * guard_half_width, palette["guard"], 6.0)
	var width := 5.0 + player.attack.sword_tier * 0.8 + float(style_variant) * 0.7
	var shoulder := tip - direction * (14.0 + player.attack.sword_tier * 2.0 + float(style_variant) * 2.0)
	var blade := PackedVector2Array([blade_base - side * width, shoulder - side * width, tip, shoulder + side * width, blade_base + side * width])
	draw_colored_polygon(blade, palette["blade"])
	draw_polyline(PackedVector2Array([blade_base - side * width, shoulder - side * width, tip, shoulder + side * width, blade_base + side * width]), palette["edge"], 1.5)

func _weapon_palette(style: StringName) -> Dictionary:
	var palettes := {
		&"void": {"blade": Color("66547f"), "edge": Color("b69ad8"), "guard": Color("31243f"), "grip": Color("17101e")},
		&"sunforged": {"blade": Color("f0c65a"), "edge": Color("fff0a1"), "guard": Color("b97921"), "grip": Color("5a2d17")},
		&"dragon": {"blade": Color("d8d0bd"), "edge": Color("fff2d2"), "guard": Color("9c3d29"), "grip": Color("3b1915")},
		&"storm": {"blade": Color("9ac7dc"), "edge": Color("e2f5ff"), "guard": Color("547d91"), "grip": Color("253b45")},
		&"royal": {"blade": Color("d7d5c8"), "edge": Color("fff8d1"), "guard": Color("d0ad64"), "grip": Color("4c263f")},
	}
	return palettes.get(style, {"blade": Color("d4c4a4"), "edge": Color("574637"), "guard": Color("a8874d"), "grip": Color("35271d")})
