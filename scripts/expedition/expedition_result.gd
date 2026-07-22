class_name ExpeditionResult
extends Resource

@export var victory := false
@export var location_id: StringName = &"test_location"
@export var earned_gold := 0
@export var reached_wave := 1
@export var defeated_enemies := 0
@export var duration_seconds := 0.0
@export var reward_claimed := false

static func create(
	was_victorious: bool,
	expedition_location_id: StringName,
	wave: int,
	defeated: int,
	duration: float
) -> ExpeditionResult:
	var result := ExpeditionResult.new()
	result.victory = was_victorious
	result.location_id = expedition_location_id
	result.earned_gold = 100 if was_victorious else 20
	result.reached_wave = maxi(1, wave)
	result.defeated_enemies = maxi(0, defeated)
	result.duration_seconds = maxf(0.0, duration)
	return result
