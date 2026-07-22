class_name LootService
extends RefCounted

const NORMAL_TABLE_ID := &"normal"
const ELITE_TABLE_ID := &"elite"
const BOSS_TABLE_ID := &"boss"
const MAX_WORLD_ITEM_DROPS := 60

var game_content: GameContent
var _active_drops: Array[WorldItemDrop] = []
var item_factory := ItemFactory.new()
var rarity_roller := ItemRarityRoller.new()

func configure(content: GameContent) -> void:
	game_content = content
	item_factory.configure(content)

func roll_for_enemy(
	enemy: EnemyBase,
	wave: int,
	loot_chance: float,
	rng: RandomNumberGenerator
) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	if enemy == null or enemy.definition == null or game_content == null or rng == null:
		return result
	if not enemy.definition.grants_loot:
		return result
	var table_id := enemy.definition.loot_table_id if not enemy.definition.loot_table_id.is_empty() else NORMAL_TABLE_ID
	if enemy.definition.is_boss:
		table_id = BOSS_TABLE_ID
	elif enemy.is_elite:
		table_id = ELITE_TABLE_ID
	var table := game_content.loot_table(table_id)
	if table == null:
		return result
	var final_chance := clampf(table.base_drop_chance * (1.0 + maxf(0.0, loot_chance)), 0.0, 1.0)
	if rng.randf() > final_chance:
		return result
	var entry := table.roll_entry(wave, rng)
	var definition := _roll_definition(entry, wave, rng)
	if definition == null:
		return result
	var quantity := rng.randi_range(maxi(1, entry.min_quantity), maxi(entry.min_quantity, entry.max_quantity))
	var is_boss := enemy.definition.is_boss
	var item_level := clampi(wave + (2 if is_boss else 1 if enemy.is_elite else 0), 1, 30)
	var rarity := rarity_roller.roll(wave, rng, enemy.is_elite, is_boss)
	var item := item_factory.create_random_item(definition.id, item_level, rarity, rng)
	if item == null:
		return result
	item.quantity = quantity if definition.stackable else 1
	result.append(item)
	return result

func _roll_definition(entry: LootTableEntry, wave: int, rng: RandomNumberGenerator) -> ItemDefinition:
	if entry == null:
		return null
	if not entry.definition_id.is_empty():
		var explicit_definition := game_content.item(entry.definition_id)
		return explicit_definition if explicit_definition != null and explicit_definition.minimum_wave <= wave else null
	var candidates: Array[ItemDefinition] = []
	for definition in game_content.all_items():
		if (
			definition != null
			and definition.item_type == entry.item_type
			and definition.minimum_wave <= wave
			and definition.id != InventoryService.STARTER_WEAPON_ID
		):
			candidates.append(definition)
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func can_spawn_world_drop() -> bool:
	_prune_drops()
	return _active_drops.size() < MAX_WORLD_ITEM_DROPS

func register_world_drop(drop: WorldItemDrop) -> bool:
	if drop == null or not can_spawn_world_drop() or _active_drops.has(drop):
		return false
	_active_drops.append(drop)
	drop.tree_exiting.connect(_on_drop_exiting.bind(drop), CONNECT_ONE_SHOT)
	return true

func active_drop_count() -> int:
	_prune_drops()
	return _active_drops.size()

func clear_runtime() -> void:
	_active_drops.clear()

func _prune_drops() -> void:
	for index in range(_active_drops.size() - 1, -1, -1):
		if not is_instance_valid(_active_drops[index]) or _active_drops[index].is_queued_for_deletion():
			_active_drops.remove_at(index)

func _on_drop_exiting(drop: WorldItemDrop) -> void:
	_active_drops.erase(drop)
