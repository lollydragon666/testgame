class_name CharacterVisualDefinition
extends Resource

const BODY_STYLES: Array[StringName] = [&"medium", &"narrow", &"wide", &"tall", &"robed", &"small"]
const HEAD_STYLES: Array[StringName] = [&"human", &"rough", &"heavy", &"thin", &"hooded", &"undead"]
const HELMET_STYLES: Array[StringName] = [&"none", &"leather_cap", &"open_helmet", &"closed_helmet", &"heavy_helmet", &"hood", &"horned_helmet", &"commander_helmet"]

@export var id: StringName
@export var body_style: StringName = &"medium"
@export var head_style: StringName = &"human"
@export var helmet_style: StringName = &"none"
@export var additional_style: StringName
@export var enemy_weapon_style: StringName
@export var body_scale := Vector2.ONE
@export var head_scale := Vector2.ONE
@export var body_width := 30.0
@export var body_height := 42.0
@export var shoulder_width := 34.0
@export var head_size := 16.0
@export var body_color := Color("6d2421")
@export var secondary_color := Color("3d1817")
@export var skin_color := Color("b98b68")
@export var helmet_color := Color("77736b")
@export var accent_color := Color("d0ad64")
@export var outline_color := Color("211714")
@export_range(0.0, 0.8, 0.01) var shadow_strength := 0.30
@export_range(0.0, 0.8, 0.01) var highlight_strength := 0.18
@export var visual_height := 44.0
@export var shadow_scale := Vector2.ONE
@export var weapon_offset := Vector2.ZERO
@export var weapon_rotation_offset := 0.0
@export var weapon_scale := Vector2.ONE

func resolved_body_style() -> StringName:
	return body_style if BODY_STYLES.has(body_style) else &"medium"

func resolved_head_style() -> StringName:
	return head_style if HEAD_STYLES.has(head_style) else &"human"

func resolved_helmet_style() -> StringName:
	return helmet_style if HELMET_STYLES.has(helmet_style) else &"none"

func is_valid_definition() -> bool:
	return (
		not id.is_empty()
		and body_width > 0.0
		and body_height > 0.0
		and shoulder_width > 0.0
		and head_size > 0.0
		and visual_height > 0.0
		and not body_scale.is_zero_approx()
		and not head_scale.is_zero_approx()
	)

