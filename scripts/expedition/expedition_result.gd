class_name ExpeditionResult
extends Resource

@export var victory := false
@export var location_id: StringName = &"test_location"
@export var tier_number := 1
@export var earned_gold := 0
@export var reached_wave := 1
@export var defeated_enemies := 0
@export var defeated_elites := 0
@export var duration_seconds := 0.0
@export var reward_claimed := false

static func create(
	was_victorious: bool,
	expedition_location_id: StringName,
	wave: int,
	defeated: int,
	duration: float,
	tier: int = 1,
	elites: int = 0,
	reward_override: int = -1
) -> ExpeditionResult:
	var result := ExpeditionResult.new()
	result.victory = was_victorious
	result.location_id = expedition_location_id
	result.tier_number = maxi(1, tier)
	result.earned_gold = maxi(0, reward_override) if reward_override >= 0 else (100 if was_victorious else 20)
	result.reached_wave = maxi(1, wave)
	result.defeated_enemies = maxi(0, defeated)
	result.defeated_elites = maxi(0, elites)
	result.duration_seconds = maxf(0.0, duration)
	return result
