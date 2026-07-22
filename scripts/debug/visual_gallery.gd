class_name VisualGallery
extends Node2D

const CONTENT: GameContent = preload("res://resources/game_content.tres")
const PLAYER_PROFILE: CharacterVisualDefinition = preload("res://resources/content/visuals/player.tres")

func _ready() -> void:
	_build_character_gallery()
	_build_sword_gallery()
	_build_prop_gallery()

func _build_character_gallery() -> void:
	var profiles: Array[CharacterVisualDefinition] = [PLAYER_PROFILE]
	for enemy_id in [GameIds.ENEMY_SWORDSMAN, GameIds.ENEMY_RAIDER, GameIds.ENEMY_BRUTE, GameIds.ENEMY_SHIELD_BEARER, GameIds.ENEMY_SPEARMAN, GameIds.ENEMY_ARCHER, GameIds.ENEMY_HEALER, GameIds.ENEMY_COMMANDER, GameIds.ENEMY_SUMMONER, GameIds.ENEMY_BOMBER]:
		profiles.append(CONTENT.enemy(enemy_id).visual_definition)
	for index in profiles.size():
		var visual := CharacterVisual.new()
		visual.name = "Character_%s" % profiles[index].id
		visual.position = Vector2(90 + index % 6 * 150, 110 + index / 6 * 180)
		visual.apply_visual_definition(profiles[index])
		add_child(visual)

func _build_sword_gallery() -> void:
	var weapons: Array[WeaponDefinition] = []
	for definition in CONTENT.all_items():
		if definition is WeaponDefinition:
			weapons.append(definition as WeaponDefinition)
	for index in mini(15, weapons.size()):
		var preview := SwordGalleryPreview.new()
		preview.name = "Sword_%s" % weapons[index].id
		preview.position = Vector2(80 + index % 5 * 175, 480 + index / 5 * 90)
		preview.setup(weapons[index], 1 + index % 6)
		add_child(preview)

func _build_prop_gallery() -> void:
	var prop_ids: Array[StringName] = [&"tree", &"column", &"low_wall"]
	for index in 3:
		var definition: PropDefinition = CONTENT.prop(prop_ids[index])
		var prop := WorldProp.new()
		prop.name = "Prop_%s" % definition.id
		prop.setup(definition, Vector2(520 + index * 150, 1050), float(index))
		add_child(prop)
