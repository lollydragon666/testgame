extends SceneTree

const CONTENT: GameContent = preload("res://resources/game_content.tres")
const TEST_SAVE_PATH := "user://test_run_loot_lifecycle.json"

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_require(session != null, "GameSession autoload is missing")
	_test_start_pickup_equipment_and_failure(session)
	_test_success_and_idempotency(session)
	_test_pending_rewards(session)
	_test_legacy_profile()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	print("RUN LOOT LIFECYCLE PASS")
	quit()

func _test_start_pickup_equipment_and_failure(session: Node) -> void:
	session.reset_profile_for_tests()
	var permanent_inventory: InventoryService = session.inventory
	_require(permanent_inventory.add_item_by_definition(&"small_healing_potion", 2), "Permanent potion setup failed")
	var permanent_potion := _find_definition(permanent_inventory.get_items(), &"small_healing_potion")
	_require(permanent_inventory.equip_item(permanent_potion.instance_id, ItemEnums.EquipmentSlot.CONSUMABLE_2), "Permanent quick slot setup failed")
	var permanent_count := permanent_inventory.permanent_inventory_size()
	var starting_weapon_id := permanent_inventory.equipped_instance_id(ItemEnums.EquipmentSlot.WEAPON)
	_require(session.start_new_run(), "Run did not start")
	var first_run_id: String = session.run_context.run_id
	_require(not first_run_id.is_empty(), "Run ID is empty")
	_require(session.run_context.state == RunContext.RunState.ACTIVE, "Run did not enter ACTIVE")
	_require(session.run_inventory.item_count() == 0, "Run inventory was not cleared")
	_require(permanent_inventory.permanent_inventory_size() == permanent_count, "Starting a run changed permanent inventory")
	_require(not session.start_new_run(), "A second active run was accepted")
	var quick_key := String.num_int64(ItemEnums.EquipmentSlot.CONSUMABLE_2)
	_require(String(session.run_context.starting_quick_slots[quick_key]) == permanent_potion.instance_id, "Starting quick slot was not captured")

	var factory := ItemFactory.new()
	factory.configure(CONTENT)
	var random := RandomNumberGenerator.new()
	random.seed = 88231
	var run_sword := factory.create_random_item(&"iron_sabre", 8, ItemEnums.ItemRarity.RARE, random)
	var drop := WorldItemDrop.new()
	drop.setup(run_sword, CONTENT.item(run_sword.definition_id), null, session.run_inventory, Vector2.ZERO, session.run_context)
	root.add_child(drop)
	_require(drop.try_pick_up(), "Run loot pickup failed")
	_require(session.run_inventory.find_item(run_sword.instance_id) == run_sword, "Pickup did not keep the original ItemInstance")
	_require(permanent_inventory.permanent_item(run_sword.instance_id) == null, "Pickup leaked into permanent inventory")
	_require(not drop.try_pick_up(), "The same world drop was picked up twice")

	var run_armor := ItemInstance.create(&"cloth_armor")
	var run_ring := ItemInstance.create(&"strength_ring")
	var run_potion := ItemInstance.create(&"large_healing_potion", 2)
	_require(session.run_inventory.add_item(run_armor), "Temporary armor setup failed")
	_require(session.run_inventory.add_item(run_ring), "Temporary jewelry setup failed")
	_require(session.run_inventory.add_item(run_potion), "Temporary potion setup failed")
	_require(permanent_inventory.equip_item(run_sword.instance_id, ItemEnums.EquipmentSlot.WEAPON), "Temporary sword could not be equipped")
	_require(permanent_inventory.equip_item(run_armor.instance_id, ItemEnums.EquipmentSlot.ARMOR), "Temporary armor could not be equipped")
	_require(permanent_inventory.equip_item(run_ring.instance_id, ItemEnums.EquipmentSlot.RING_1), "Temporary jewelry could not be equipped")
	_require(PlayerStatCalculator.calculate(permanent_inventory).defense > 0.0, "Temporary armor stats were not applied")
	var serialized_equipment := permanent_inventory.serialized_equipment()
	_require(String(serialized_equipment[String.num_int64(ItemEnums.EquipmentSlot.WEAPON)]) == starting_weapon_id, "Temporary sword leaked into serialized equipment")
	_require(not _serialized_contains(permanent_inventory.serialized_items(), run_sword.instance_id), "Temporary sword leaked into serialized items")
	_require(session.save_profile(TEST_SAVE_PATH), "Active-run profile save failed")
	_require(not _serialized_contains(session.profile.inventory_items, run_sword.instance_id), "Profile save persisted active run loot")
	var gold_before: int = session.profile.gold
	_require(not session.shop_service.sell_item(run_sword.instance_id), "Temporary run item was sold")
	_require(session.profile.gold == gold_before, "Rejected temporary sale changed gold")

	permanent_inventory.configure_consumable_handler(func(_definition: ConsumableDefinition) -> bool: return true)
	_require(permanent_inventory.use_consumable_slot(ItemEnums.EquipmentSlot.CONSUMABLE_2), "Permanent potion was not consumed")
	_require(permanent_potion.quantity == 1, "Permanent potion quantity did not decrease")
	permanent_inventory.reset_consumable_runtime()
	_require(permanent_inventory.equip_item(run_potion.instance_id, ItemEnums.EquipmentSlot.CONSUMABLE_2), "Temporary potion could not be assigned")
	_require(permanent_inventory.use_consumable_slot(ItemEnums.EquipmentSlot.CONSUMABLE_2), "Temporary potion was not consumed")
	_require(run_potion.quantity == 1, "Temporary potion stack did not decrease")

	_require(session.fail_current_run(RunContext.RunFailureReason.PLAYER_DEATH), "Run failure was not processed")
	_require(session.run_context.state == RunContext.RunState.FAILED and session.run_context.failure_processed, "Failure state is invalid")
	_require(session.run_context.lost_items.size() == 4, "Lost-loot summary has the wrong item count")
	_require(session.run_inventory.item_count() == 0, "Run inventory survived failure")
	_require(permanent_inventory.find_item(run_sword.instance_id) == null, "Temporary sword survived failure")
	_require(permanent_inventory.equipped_instance_id(ItemEnums.EquipmentSlot.WEAPON) == starting_weapon_id, "Starting weapon was not restored")
	_require(permanent_inventory.equipped_instance_id(ItemEnums.EquipmentSlot.CONSUMABLE_2) == permanent_potion.instance_id, "Starting quick slot was not restored")
	_require(permanent_potion.quantity == 1, "Consumed permanent potion was refunded")
	_require(not session.fail_current_run(RunContext.RunFailureReason.PLAYER_DEATH), "Repeated failure was processed")
	_require(not session.complete_run_successfully(), "Failed run was committed")
	drop.queue_free()

func _test_success_and_idempotency(session: Node) -> void:
	session.reset_profile_for_tests()
	var inventory: InventoryService = session.inventory
	_require(session.start_new_run(), "Success test run did not start")
	var factory := ItemFactory.new()
	factory.configure(CONTENT)
	var random := RandomNumberGenerator.new()
	random.seed = 54119
	var loot := factory.create_random_item(&"mercenary_blade", 11, ItemEnums.ItemRarity.EPIC, random)
	var run_potion := ItemInstance.create(&"large_healing_potion", 2)
	var original_data := loot.to_dict()
	_require(session.run_inventory.add_item(loot), "Success loot setup failed")
	_require(session.run_inventory.add_item(run_potion), "Success potion setup failed")
	_require(inventory.equip_item(loot.instance_id, ItemEnums.EquipmentSlot.WEAPON), "Evacuated weapon could not be equipped")
	inventory.configure_consumable_handler(func(_definition: ConsumableDefinition) -> bool: return true)
	_require(inventory.equip_item(run_potion.instance_id, ItemEnums.EquipmentSlot.CONSUMABLE_2), "Success potion could not be assigned")
	_require(inventory.use_consumable_slot(ItemEnums.EquipmentSlot.CONSUMABLE_2), "Success potion could not be consumed")
	_require(session.complete_run_successfully(), "Successful run loot was not committed")
	_require(session.run_context.state == RunContext.RunState.COMPLETED, "Success did not enter COMPLETED")
	_require(session.run_inventory.item_count() == 0, "Run inventory survived success")
	var committed := inventory.permanent_item(loot.instance_id)
	_require(committed == loot, "Victory transfer replaced the ItemInstance")
	_require(JSON.stringify(committed.to_dict()) == JSON.stringify(original_data), "Victory transfer changed rarity, level, affixes, or ID")
	_require(inventory.equipped_instance_id(ItemEnums.EquipmentSlot.WEAPON) == loot.instance_id, "Transferred temporary equipment was not retained")
	var committed_potion := inventory.permanent_item(run_potion.instance_id)
	_require(committed_potion == run_potion and committed_potion.quantity == 1, "Used run potion was duplicated or restored on victory")
	_require(session.save_profile(TEST_SAVE_PATH), "Committed loot save failed")
	var saved_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE_PATH))
	_require(saved_data is Dictionary and _serialized_contains(saved_data.get("inventory_items", []), loot.instance_id), "Committed loot was not present after save")
	var size_after_commit := inventory.permanent_inventory_size()
	_require(not session.complete_run_successfully(), "Repeated success was processed")
	_require(inventory.permanent_inventory_size() == size_after_commit, "Repeated success duplicated loot")
	_require(not session.fail_current_run(RunContext.RunFailureReason.LEVEL_FAILED), "Completed run was failed")

func _test_pending_rewards(session: Node) -> void:
	session.reset_profile_for_tests()
	var inventory: InventoryService = session.inventory
	inventory.clear_for_tests()
	for _index in InventoryService.CAPACITY:
		_require(inventory.add_item(ItemInstance.create(&"old_gladius")), "Could not fill permanent inventory")
	_require(session.start_new_run(), "Pending-reward run did not start")
	var overflow := ItemInstance.create(&"strength_ring")
	_require(session.run_inventory.add_item(overflow), "Overflow loot setup failed")
	_require(session.complete_run_successfully(), "Full inventory destroyed successful loot")
	_require(session.pending_run_rewards.find_item(overflow.instance_id) == overflow, "Overflow loot was not placed in PendingRunRewards")
	_require(_serialized_contains(session.profile.pending_run_rewards, overflow.instance_id), "Pending reward was not persisted")
	_require(not session.pending_run_rewards.claim_item(overflow.instance_id), "Pending reward ignored full inventory")
	var removable := inventory.get_items()[0]
	_require(inventory.remove_item(removable.instance_id), "Could not free a permanent slot")
	_require(session.pending_run_rewards.claim_item(overflow.instance_id), "Pending reward could not be claimed after freeing space")
	_require(inventory.permanent_item(overflow.instance_id) == overflow, "Claimed pending reward changed identity")
	_require(session.pending_run_rewards.find_item(overflow.instance_id) == null, "Claimed pending reward was duplicated")

func _test_legacy_profile() -> void:
	var profile := PlayerProfile.new()
	profile.load_dict({"gold": 15, "inventory_items": []})
	_require(profile.gold == 15 and profile.pending_run_rewards.is_empty(), "Legacy profile migration failed")

func _find_definition(items: Array[ItemInstance], definition_id: StringName) -> ItemInstance:
	for item in items:
		if item.definition_id == definition_id:
			return item
	return null

func _serialized_contains(items: Array, instance_id: String) -> bool:
	for item_data in items:
		if item_data is Dictionary and String(item_data.get("instance_id", "")) == instance_id:
			return true
	return false
