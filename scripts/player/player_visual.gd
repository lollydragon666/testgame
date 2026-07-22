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
	var guard_distance := player.visual_radius + (18.0 if is_final_tier else 6.0)
	var blade_base := direction * (guard_distance + 5.0)
	var tip := direction * player.attack.visual_sword_length
	draw_line(direction * player.visual_radius * 0.55, blade_base, Color("35271d"), 7.0)
	draw_line(direction * guard_distance - side * (8.0 + player.attack.sword_tier * 3.0), direction * guard_distance + side * (8.0 + player.attack.sword_tier * 3.0), Color("a8874d"), 6.0)
	var width := 5.0 + player.attack.sword_tier * 0.8
	var shoulder := tip - direction * (14.0 + player.attack.sword_tier * 2.0)
	var blade := PackedVector2Array([blade_base - side * width, shoulder - side * width, tip, shoulder + side * width, blade_base + side * width])
	draw_colored_polygon(blade, Color("d4c4a4"))
	draw_polyline(PackedVector2Array([blade_base - side * width, shoulder - side * width, tip, shoulder + side * width, blade_base + side * width]), Color("574637"), 1.5)
