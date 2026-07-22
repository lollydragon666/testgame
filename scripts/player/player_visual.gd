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

func _make_weapon_part(parent: Node) -> CharacterVisualPart:
	var sword := PlayerSwordVisual.new()
	sword.name = "WeaponVisual"
	sword.setup(self, PART_WEAPON)
	parent.add_child(sword)
	return sword

func draw_part(part_id: StringName) -> void:
	if part_id == PART_WEAPON:
		return
	if part_id == PART_EFFECTS:
		super.draw_part(part_id)
		_draw_player_effects()
		return
	super.draw_part(part_id)

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
	var tier_strength := clampf(float(player.attack.sword_tier - 1) / 5.0, 0.0, 1.0)
	effects.draw_polyline(trail, Color(0.69 + tier_strength * 0.18, 0.19 + tier_strength * 0.18, 0.16, 0.70 + tier_strength * 0.18), 9.0 + tier_strength * 5.0)
