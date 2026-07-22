class_name LocationProgress
extends Resource

@export var location_id: StringName
@export_range(1, 10, 1) var highest_unlocked_tier := 1
@export_range(0, 10, 1) var highest_completed_tier := 0
@export var boss_defeated := false
@export var completion_counts: Dictionary = {}

func is_tier_unlocked(tier_number: int) -> bool:
	return tier_number >= 1 and tier_number <= highest_unlocked_tier

func is_tier_completed(tier_number: int) -> bool:
	return tier_number >= 1 and completion_count(tier_number) > 0

func completion_count(tier: int) -> int:
	return maxi(0, int(completion_counts.get(tier, 0)))

func register_victory(tier: int, maximum_tier: int) -> bool:
	if tier < 1 or tier > maximum_tier or not is_tier_unlocked(tier):
		return false
	completion_counts[tier] = completion_count(tier) + 1
	highest_completed_tier = maxi(highest_completed_tier, tier)
	highest_unlocked_tier = mini(maximum_tier, maxi(highest_unlocked_tier, tier + 1))
	if tier == maximum_tier:
		boss_defeated = true
	return true
