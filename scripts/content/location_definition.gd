class_name LocationDefinition
extends Resource

const EXPECTED_TIER_COUNT := 10

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var tiers: Array[ExpeditionTierDefinition] = []

func tier_definition(tier_number: int) -> ExpeditionTierDefinition:
	for definition in tiers:
		if definition != null and definition.tier == tier_number:
			return definition
	return null

func maximum_tier() -> int:
	var result := 0
	for definition in tiers:
		if definition != null:
			result = maxi(result, definition.tier)
	return result

func validate_definition() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("location id cannot be empty")
	if display_name.is_empty():
		errors.append("location display_name cannot be empty")
	if tiers.size() != EXPECTED_TIER_COUNT:
		errors.append("location must contain exactly %d tiers" % EXPECTED_TIER_COUNT)
	var previous_tier := 0
	var seen: Dictionary[int, bool] = {}
	for index in tiers.size():
		var definition := tiers[index]
		if definition == null:
			errors.append("tier entry %d is null" % index)
			continue
		if seen.has(definition.tier):
			errors.append("duplicate tier: %d" % definition.tier)
		seen[definition.tier] = true
		if definition.tier <= previous_tier:
			errors.append("tiers must be in ascending order")
		previous_tier = definition.tier
		for tier_error in definition.validate_definition():
			errors.append("tier %d: %s" % [definition.tier, tier_error])
	for expected_tier in range(1, EXPECTED_TIER_COUNT + 1):
		if not seen.has(expected_tier):
			errors.append("missing tier: %d" % expected_tier)
	return errors
