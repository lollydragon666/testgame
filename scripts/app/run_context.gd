class_name RunContext
extends RefCounted

enum RunState {
	NONE,
	ACTIVE,
	SUCCESS_PENDING,
	COMPLETED,
	FAILED,
}

enum RunFailureReason {
	PLAYER_DEATH,
	LEVEL_FAILED,
	SURRENDERED,
	RESTARTED,
	ABANDONED,
}

var run_id := ""
var state := RunState.NONE
var started_at_unix := 0
var completed_at_unix := 0
var starting_equipment: Dictionary = {}
var starting_quick_slots: Dictionary = {}
var rewards_committed := false
var failure_processed := false

static func create(equipment: Dictionary) -> RunContext:
	var context := RunContext.new()
	context.run_id = _generate_run_id()
	context.state = RunState.ACTIVE
	context.started_at_unix = int(Time.get_unix_time_from_system())
	context.starting_equipment = equipment.duplicate(true)
	for slot in [ItemEnums.EquipmentSlot.CONSUMABLE_2, ItemEnums.EquipmentSlot.CONSUMABLE_3]:
		var key := String.num_int64(slot)
		context.starting_quick_slots[key] = String(equipment.get(key, ""))
	return context

func is_active() -> bool:
	return state == RunState.ACTIVE

static func _generate_run_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	var hexadecimal := ""
	for value in bytes:
		hexadecimal += "%02x" % value
	if not hexadecimal.is_empty():
		return "run-%s" % hexadecimal
	return "run-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
