class_name CharacterVisual
extends Node2D

const PART_SHADOW := &"shadow"
const PART_BODY := &"body"
const PART_HEAD := &"head"
const PART_HELMET := &"helmet"
const PART_ADDITIONAL := &"additional"
const PART_WEAPON := &"weapon"
const PART_EFFECTS := &"effects"

var visual_definition: CharacterVisualDefinition
var ground_shadow: CharacterVisualPart
var mirrored_visual_root: Node2D
var body: CharacterVisualPart
var head: CharacterVisualPart
var helmet: CharacterVisualPart
var additional_visual: CharacterVisualPart
var weapon_socket: Node2D
var weapon_visual: CharacterVisualPart
var effects: CharacterVisualPart
var facing_direction := Vector2.RIGHT
var movement_velocity := Vector2.ZERO
var animation_time := 0.0
var attack_pulse := 0.0
var hurt_pulse := 0.0
var death_progress := 0.0

func _ready() -> void:
	_build_visual_tree()
	refresh_visual()

func _build_visual_tree() -> void:
	if ground_shadow != null:
		return
	ground_shadow = _make_part("GroundShadow", PART_SHADOW, self)
	mirrored_visual_root = Node2D.new()
	mirrored_visual_root.name = "MirroredVisualRoot"
	add_child(mirrored_visual_root)
	body = _make_part("Body", PART_BODY, mirrored_visual_root)
	head = _make_part("Head", PART_HEAD, mirrored_visual_root)
	helmet = _make_part("Helmet", PART_HELMET, mirrored_visual_root)
	additional_visual = _make_part("AdditionalVisual", PART_ADDITIONAL, mirrored_visual_root)
	weapon_socket = Node2D.new()
	weapon_socket.name = "WeaponSocket"
	mirrored_visual_root.add_child(weapon_socket)
	weapon_visual = _make_part("WeaponVisual", PART_WEAPON, weapon_socket)
	effects = _make_part("Effects", PART_EFFECTS, self)

func _make_part(node_name: String, id: StringName, parent: Node) -> CharacterVisualPart:
	var part := CharacterVisualPart.new()
	part.name = node_name
	part.setup(self, id)
	parent.add_child(part)
	return part

func apply_visual_definition(definition: CharacterVisualDefinition) -> void:
	visual_definition = definition
	refresh_visual()

func set_enemy_weapon_style(style: StringName) -> void:
	if visual_definition != null:
		visual_definition.enemy_weapon_style = style
	refresh_visual()

func set_helmet_style(style: StringName) -> void:
	if visual_definition != null:
		visual_definition.helmet_style = style
	refresh_visual()

func set_movement_state(velocity: Vector2) -> void:
	movement_velocity = velocity
	if not velocity.is_zero_approx():
		facing_direction = velocity.normalized()

func set_facing(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		facing_direction = direction.normalized()

func play_attack() -> void:
	attack_pulse = 1.0

func play_hurt() -> void:
	hurt_pulse = 1.0

func play_death() -> void:
	death_progress = 0.01

func _process(delta: float) -> void:
	animation_time += delta
	attack_pulse = maxf(0.0, attack_pulse - delta * 5.0)
	hurt_pulse = maxf(0.0, hurt_pulse - delta * 7.0)
	if death_progress > 0.0:
		death_progress = minf(1.0, death_progress + delta * 2.5)
	_apply_transforms()

func _apply_transforms() -> void:
	if mirrored_visual_root == null:
		return
	var moving := movement_velocity.length_squared() > 1.0
	var bob := sin(animation_time * (10.0 if moving else 3.2)) * (2.0 if moving else 0.8)
	var screen_facing := IsoMath.world_to_screen(facing_direction).normalized()
	mirrored_visual_root.scale.x = -1.0 if screen_facing.x < 0.0 else 1.0
	mirrored_visual_root.position.y = bob + death_progress * 16.0
	mirrored_visual_root.rotation = sin(animation_time * 7.0) * 0.025 if moving else 0.0
	mirrored_visual_root.rotation += attack_pulse * 0.10
	mirrored_visual_root.scale.y = 1.0 - death_progress * 0.55
	mirrored_visual_root.modulate = Color(1.0, 0.55, 0.55) if hurt_pulse > 0.0 else Color.WHITE
	if ground_shadow != null:
		ground_shadow.scale = Vector2(1.08, 0.92) if moving else Vector2.ONE

func refresh_visual() -> void:
	for part in [ground_shadow, body, head, helmet, additional_visual, weapon_visual, effects]:
		if part != null:
			part.queue_redraw()

func draw_part(part_id: StringName) -> void:
	if visual_definition == null:
		return
	match part_id:
		PART_SHADOW: _draw_shadow()
		PART_BODY: _draw_body()
		PART_HEAD: _draw_head()
		PART_HELMET: _draw_helmet()
		PART_ADDITIONAL: _draw_additional()
		PART_WEAPON: _draw_enemy_weapon()
		PART_EFFECTS: _draw_effects()

func _draw_shadow() -> void:
	ground_shadow.draw_set_transform(Vector2(4.0, 2.0), 0.0, Vector2(1.25, 0.38) * visual_definition.shadow_scale)
	ground_shadow.draw_circle(Vector2.ZERO, visual_definition.body_width * 0.62, Color(0.01, 0.008, 0.008, 0.34))
	ground_shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_body() -> void:
	var width := visual_definition.body_width
	var height := visual_definition.body_height
	var shoulder := visual_definition.shoulder_width * 0.5
	var silhouette := PackedVector2Array([
		Vector2(-shoulder * 0.72, -height), Vector2(-shoulder, -height * 0.78),
		Vector2(-width * 0.64, -height * 0.38), Vector2(-width * 0.48, -height * 0.08),
		Vector2(-width * 0.30, 0.0), Vector2(-width * 0.10, -height * 0.24),
		Vector2(width * 0.15, 0.0), Vector2(width * 0.42, -height * 0.10),
		Vector2(width * 0.62, -height * 0.42), Vector2(shoulder, -height * 0.78),
		Vector2(shoulder * 0.68, -height),
	])
	body.draw_colored_polygon(silhouette, visual_definition.outline_color)
	var inner := PackedVector2Array()
	for point in silhouette:
		inner.append(Vector2(point.x * 0.88, lerpf(-height * 0.91, point.y - 2.0, 0.92)))
	body.draw_colored_polygon(inner, visual_definition.body_color)
	body.draw_colored_polygon(PackedVector2Array([Vector2(-shoulder * 0.7, -height * 0.9), Vector2(0.0, -height), Vector2(-width * 0.08, -height * 0.2), Vector2(-width * 0.42, -height * 0.12)]), visual_definition.body_color.lightened(visual_definition.highlight_strength))
	body.draw_line(Vector2(-width * 0.42, -height * 0.32), Vector2(width * 0.42, -height * 0.32), visual_definition.secondary_color, 4.0)

func _draw_head() -> void:
	var size := visual_definition.head_size
	var center := Vector2(0.0, -visual_definition.body_height - size * 0.72)
	var head_style := visual_definition.resolved_head_style()
	var scale_value := Vector2(1.0, 1.08)
	if head_style == &"heavy": scale_value = Vector2(1.22, 1.0)
	elif head_style == &"thin": scale_value = Vector2(0.76, 1.18)
	elif head_style == &"rough": scale_value = Vector2(1.08, 1.12)
	head.draw_set_transform(center, 0.0, scale_value * visual_definition.head_scale)
	head.draw_circle(Vector2.ZERO, size * 0.62, visual_definition.outline_color)
	head.draw_circle(Vector2(-1.0, -1.0), size * 0.54, visual_definition.skin_color)
	head.draw_colored_polygon(PackedVector2Array([Vector2(-size * 0.48, 0.0), Vector2(size * 0.48, 0.0), Vector2(size * 0.38, size * 0.28), Vector2(-size * 0.38, size * 0.28)]), visual_definition.secondary_color.darkened(0.3))
	head.draw_line(Vector2(-size * 0.28, 0.0), Vector2(size * 0.28, 0.0), visual_definition.accent_color, 2.0)
	head.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_helmet() -> void:
	var style := visual_definition.resolved_helmet_style()
	if style == &"none": return
	var s := visual_definition.head_size
	var center := Vector2(0.0, -visual_definition.body_height - s * 0.82)
	var color := visual_definition.helmet_color
	match style:
		&"leather_cap": helmet.draw_arc(center, s * 0.62, PI, TAU, 16, color, 6.0)
		&"open_helmet":
			helmet.draw_arc(center, s * 0.68, PI, TAU, 16, color, 7.0)
			helmet.draw_line(center + Vector2(-s * 0.55, 0.0), center + Vector2(-s * 0.48, s * 0.5), color, 5.0)
			helmet.draw_line(center + Vector2(s * 0.55, 0.0), center + Vector2(s * 0.48, s * 0.5), color.darkened(0.2), 5.0)
		&"closed_helmet", &"heavy_helmet":
			var wide := 0.82 if style == &"heavy_helmet" else 0.68
			helmet.draw_rect(Rect2(center + Vector2(-s * wide, -s * 0.55), Vector2(s * wide * 2.0, s * 1.1)), color)
			helmet.draw_line(center + Vector2(-s * 0.45, 0.0), center + Vector2(s * 0.45, 0.0), visual_definition.outline_color, 3.0)
		&"hood":
			helmet.draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -s), center + Vector2(-s * 0.82, s * 0.5), center + Vector2(s * 0.82, s * 0.5)]), color)
		&"horned_helmet":
			helmet.draw_arc(center, s * 0.68, PI, TAU, 16, color, 7.0)
			helmet.draw_line(center + Vector2(-s * 0.5, -s * 0.3), center + Vector2(-s, -s * 0.9), visual_definition.accent_color, 5.0)
			helmet.draw_line(center + Vector2(s * 0.5, -s * 0.3), center + Vector2(s, -s * 0.9), visual_definition.accent_color, 5.0)
		&"commander_helmet":
			helmet.draw_arc(center, s * 0.68, PI, TAU, 16, color, 7.0)
			helmet.draw_line(center + Vector2(0.0, -s * 0.55), center + Vector2(0.0, -s * 1.55), visual_definition.accent_color, 7.0)

func _draw_additional() -> void:
	if visual_definition.additional_style == &"cape":
		additional_visual.draw_colored_polygon(PackedVector2Array([Vector2(-14.0, -visual_definition.body_height + 5.0), Vector2(16.0, -visual_definition.body_height + 9.0), Vector2(22.0, -3.0), Vector2(-18.0, -8.0)]), visual_definition.secondary_color)
	elif visual_definition.additional_style == &"quiver":
		additional_visual.draw_line(Vector2(-13.0, -32.0), Vector2(-20.0, -8.0), Color("6b4226"), 8.0)

func _draw_enemy_weapon() -> void:
	var style := visual_definition.enemy_weapon_style
	if style.is_empty(): return
	var c := Color("c7bea8")
	match style:
		&"sword", &"short_sword", &"heavy_sword":
			var length := 62.0 if style == &"heavy_sword" else 46.0
			weapon_visual.draw_line(Vector2(12.0, 0.0), Vector2(length, 0.0), c, 7.0 if style == &"heavy_sword" else 4.0)
			weapon_visual.draw_line(Vector2(14.0, -9.0), Vector2(14.0, 9.0), visual_definition.accent_color, 4.0)
		&"spear":
			weapon_visual.draw_line(Vector2(4.0, 0.0), Vector2(82.0, 0.0), Color("714725"), 5.0)
			weapon_visual.draw_colored_polygon(PackedVector2Array([Vector2(82.0, -7.0), Vector2(102.0, 0.0), Vector2(82.0, 7.0)]), c)
		&"bow": weapon_visual.draw_arc(Vector2(28.0, 0.0), 22.0, -PI * 0.5, PI * 0.5, 16, Color("7b4d2a"), 5.0)
		&"staff":
			weapon_visual.draw_line(Vector2(6.0, 0.0), Vector2(76.0, 0.0), Color("714725"), 6.0)
			weapon_visual.draw_circle(Vector2(78.0, 0.0), 8.0, visual_definition.accent_color)
		&"shield_sword":
			weapon_visual.draw_colored_polygon(PackedVector2Array([Vector2(8.0, -18.0), Vector2(30.0, -13.0), Vector2(30.0, 13.0), Vector2(8.0, 18.0)]), visual_definition.helmet_color)
			weapon_visual.draw_line(Vector2(16.0, 0.0), Vector2(55.0, 0.0), c, 4.0)
		&"bomb":
			weapon_visual.draw_circle(Vector2(28.0, 0.0), 12.0, Color("282421"))
			weapon_visual.draw_line(Vector2(33.0, -9.0), Vector2(39.0, -17.0), Color("d49a3a"), 3.0)

func _draw_effects() -> void:
	if hurt_pulse > 0.0:
		effects.draw_arc(Vector2(0.0, -visual_definition.body_height * 0.5), visual_definition.shoulder_width, 0.0, TAU, 24, Color(1.0, 0.3, 0.2, hurt_pulse), 3.0)
