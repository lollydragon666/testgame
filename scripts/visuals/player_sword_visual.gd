class_name PlayerSwordVisual
extends CharacterVisualPart

const SUPPORTED_STYLES: Array[StringName] = [
	&"training", &"gladius", &"sabre", &"mercenary", &"falchion",
	&"bastard", &"rapier", &"cleaver", &"royal", &"executioner",
	&"storm", &"dragon", &"void", &"titan", &"sunforged",
]

const FALLBACK_STYLE := &"gladius"

func _draw() -> void:
	var player_visual := visual as PlayerVisual
	var player := player_visual.get_parent() as PlayerHero if player_visual != null else null
	if player == null or player.attack == null or player.attack.definition == null:
		return
	_update_socket_rotation(player_visual, player)
	var style := resolved_style(player.attack.definition)
	var profile := sword_profile(style)
	_draw_model(player, profile)

static func resolved_style(definition: WeaponDefinition) -> StringName:
	if definition == null:
		return FALLBACK_STYLE
	if definition.id == &"player_sword":
		return &"training"
	return definition.visual_style if SUPPORTED_STYLES.has(definition.visual_style) else FALLBACK_STYLE

static func sword_profile(style: StringName) -> Dictionary:
	var profiles := {
		&"training": _profile(0.82, 5.4, 0.0, &"round", &"straight", Color("8a6842"), Color("c09a63"), Color("5b3b25"), Color("3a2518"), false),
		&"gladius": _profile(0.88, 6.5, 0.0, &"leaf", &"short", Color("aaa89f"), Color("e0d8c3"), Color("867044"), Color("452d20"), true),
		&"sabre": _profile(1.00, 4.8, -7.0, &"curved", &"knuckle", Color("b9bec0"), Color("eef2ec"), Color("8e7652"), Color("3b2a21"), true),
		&"mercenary": _profile(0.98, 7.0, 0.0, &"angular", &"cross", Color("8f9695"), Color("d3d6ce"), Color("6e5740"), Color("29231f"), true),
		&"falchion": _profile(1.02, 8.5, -4.0, &"heavy_curve", &"hook", Color("a8aaa3"), Color("e2dfcf"), Color("785331"), Color("36251a"), true),
		&"bastard": _profile(1.12, 7.2, 0.0, &"diamond", &"wide_cross", Color("b7b8b1"), Color("ece7d9"), Color("987748"), Color("3a251b"), true),
		&"rapier": _profile(1.08, 2.8, 0.0, &"needle", &"basket", Color("c4c8c5"), Color("ffffff"), Color("c0a66a"), Color("3d2534"), true),
		&"cleaver": _profile(0.95, 10.5, 1.0, &"cleaver", &"block", Color("969993"), Color("d3d2c8"), Color("74512e"), Color("2d2119"), false),
		&"royal": _profile(1.08, 6.5, 0.0, &"royal", &"winged", Color("d4d3c7"), Color("fff5c7"), Color("d0ad64"), Color("4c263f"), true),
		&"executioner": _profile(1.13, 11.0, 0.0, &"executioner", &"block", Color("7f8582"), Color("c7cbc4"), Color("6a4430"), Color("261b18"), true),
		&"storm": _profile(1.05, 5.2, -6.0, &"curved", &"forked", Color("78abc4"), Color("dff6ff"), Color("547d91"), Color("253b45"), true),
		&"dragon": _profile(1.10, 7.8, 2.0, &"serrated", &"claw", Color("c9c1ae"), Color("fff2d2"), Color("9c3d29"), Color("3b1915"), true),
		&"void": _profile(1.06, 6.8, 0.0, &"split", &"crescent", Color("66547f"), Color("c5a7e8"), Color("31243f"), Color("17101e"), true),
		&"titan": _profile(1.20, 13.0, 0.0, &"titan", &"massive", Color("777b78"), Color("d0d3c9"), Color("59462f"), Color("251d18"), true),
		&"sunforged": _profile(1.12, 8.0, 0.0, &"flame", &"sun", Color("e0a92f"), Color("fff0a1"), Color("b97921"), Color("5a2d17"), true),
	}
	return profiles.get(style, profiles[FALLBACK_STYLE])

static func _profile(length_scale: float, width: float, curve: float, tip: StringName, guard: StringName, blade: Color, edge: Color, guard_color: Color, grip: Color, fuller: bool) -> Dictionary:
	return {"length_scale": length_scale, "width": width, "curve": curve, "tip": tip, "guard": guard, "blade": blade, "edge": edge, "guard_color": guard_color, "grip": grip, "fuller": fuller}

func _update_socket_rotation(player_visual: PlayerVisual, player: PlayerHero) -> void:
	var world_direction := player.attack.swing_aim_direction if player.attack.swing_time > 0.0 else player.aim_direction
	world_direction = world_direction.rotated(player.attack.swing_offset())
	var screen_direction := IsoMath.world_to_screen(world_direction).normalized()
	var facing_sign := -1.0 if screen_direction.x < 0.0 else 1.0
	player_visual.mirrored_visual_root.scale.x = facing_sign
	player_visual.weapon_socket.rotation = Vector2(screen_direction.x * facing_sign, screen_direction.y).angle()

func _draw_model(player: PlayerHero, profile: Dictionary) -> void:
	var tier := player.attack.sword_tier
	var tier_strength := clampf(float(tier - 1) / 5.0, 0.0, 1.0)
	var guard_x := player.visual_radius + 5.0
	var base_x := guard_x + 5.0
	var length := maxf(base_x + 22.0, player.attack.effective_visual_sword_length() * float(profile["length_scale"]))
	var width := float(profile["width"]) + tier_strength * 1.8
	var curve := float(profile["curve"])
	var outline := Color("211714")
	if tier >= 4:
		draw_line(Vector2(base_x, curve), Vector2(length - 5.0, curve * 0.25), Color(profile["edge"], 0.12 + tier_strength * 0.18), width * 3.0)
	draw_line(Vector2(player.visual_radius * 0.45, 0.0), Vector2(guard_x + 3.0, 0.0), profile["grip"], 7.0 + tier_strength)
	_draw_guard(guard_x, width, profile)
	var blade := _blade_polygon(base_x, length, width, curve, profile["tip"])
	draw_colored_polygon(blade, outline)
	var inner := PackedVector2Array()
	for point in blade:
		inner.append(Vector2(lerpf(base_x, point.x, 0.985), lerpf(curve * 0.2, point.y, 0.82)))
	draw_colored_polygon(inner, profile["blade"])
	draw_polyline(PackedVector2Array([blade[0], blade[1], blade[2], blade[3], blade[4]]), profile["edge"], 1.4 + tier_strength)
	if bool(profile["fuller"]):
		draw_line(Vector2(base_x + 6.0, curve * 0.35), Vector2(length - maxf(13.0, width * 1.6), curve * 0.3), Color(profile["edge"], 0.62), 1.5 + tier_strength)
	_draw_tip_detail(length, width, curve, profile["tip"], profile["edge"])

func _blade_polygon(base_x: float, length: float, width: float, curve: float, tip_style: StringName) -> PackedVector2Array:
	var shoulder_x := length - maxf(10.0, width * 1.6)
	var upper_width := width
	var lower_width := width
	match tip_style:
		&"leaf", &"royal", &"flame":
			upper_width *= 1.22
			lower_width *= 1.22
		&"cleaver", &"executioner", &"titan":
			upper_width *= 1.35
			shoulder_x = length - 5.0
		&"heavy_curve", &"curved": lower_width *= 0.60
		&"needle":
			upper_width *= 0.55
			lower_width *= 0.55
		&"serrated": upper_width *= 1.32
	return PackedVector2Array([
		Vector2(base_x, -width + curve),
		Vector2(shoulder_x, -upper_width + curve * 0.25),
		Vector2(length, curve * 0.12),
		Vector2(shoulder_x, lower_width + curve * 0.25),
		Vector2(base_x, width + curve),
	])

func _draw_guard(x: float, width: float, profile: Dictionary) -> void:
	var half := 10.0 + width * 0.55
	var color: Color = profile["guard_color"]
	match profile["guard"]:
		&"short": draw_line(Vector2(x, -half * 0.72), Vector2(x, half * 0.72), color, 5.0)
		&"knuckle": draw_arc(Vector2(x - 5.0, 0.0), half, -PI * 0.5, PI * 0.5, 12, color, 4.0)
		&"basket":
			draw_arc(Vector2(x - 5.0, 0.0), half, -PI * 0.5, PI * 0.5, 12, color, 4.0)
			draw_line(Vector2(x, -half), Vector2(x, half), color, 3.0)
		&"winged", &"forked", &"claw":
			draw_polyline(PackedVector2Array([Vector2(x + 5.0, -half), Vector2(x, -half * 0.45), Vector2(x, half * 0.45), Vector2(x + 5.0, half)]), color, 5.0)
		&"crescent": draw_arc(Vector2(x + 3.0, 0.0), half, PI * 0.62, PI * 1.38, 12, color, 5.0)
		&"massive", &"block": draw_line(Vector2(x, -half), Vector2(x, half), color, 8.0)
		&"sun":
			draw_circle(Vector2(x, 0.0), 7.0, color)
			draw_line(Vector2(x, -half), Vector2(x, half), color, 5.0)
		_: draw_line(Vector2(x - 2.0, -half), Vector2(x + 2.0, half), color, 5.0)

func _draw_tip_detail(length: float, width: float, curve: float, tip_style: StringName, color: Color) -> void:
	if tip_style == &"split":
		draw_line(Vector2(length - width * 1.7, -width * 0.7), Vector2(length - 2.0, -2.0), color, 2.0)
		draw_line(Vector2(length - width * 1.7, width * 0.7), Vector2(length - 2.0, 2.0), color, 2.0)
	elif tip_style == &"serrated":
		for index in 3:
			var x := length - width * (1.3 + index * 0.8)
			draw_line(Vector2(x, width * 0.75 + curve * 0.2), Vector2(x - width * 0.35, width * 1.3 + curve * 0.2), color, 2.0)
	elif tip_style == &"flame":
		draw_arc(Vector2(length - width * 1.8, curve), width * 0.55, -PI * 0.7, PI * 0.7, 10, color, 2.0)
