class_name WaveManager
extends Node

signal spawn_requested(enemy_kind: String, difficulty: float)
signal boss_requested(difficulty: float)
signal wave_changed(wave: int)

@export var wave_duration := 18.0

var wave := 1
var wave_time := 0.0
var spawn_time := 0.0
var spawn_index := 0
var running := false
var boss_started := false

func start_run() -> void:
	wave = 1
	wave_time = 0.0
	spawn_time = 0.35
	spawn_index = 0
	running = true
	boss_started = false
	wave_changed.emit(wave)

func stop() -> void:
	running = false

func _process(delta: float) -> void:
	if not running or boss_started:
		return
	wave_time += delta
	spawn_time -= delta
	if spawn_time <= 0.0:
		spawn_time = maxf(0.42, 1.35 - float(wave) * 0.11)
		spawn_requested.emit(_choose_enemy(), 1.0 + float(wave - 1) * 0.13)
	if wave_time >= wave_duration:
		wave_time -= wave_duration
		wave += 1
		if wave > 7:
			boss_started = true
			boss_requested.emit(1.0)
		else:
			wave_changed.emit(wave)

func _choose_enemy() -> String:
	var roster: Array[String]
	if wave == 1:
		roster = ["melee", "melee", "shooter"]
	elif wave == 2:
		roster = ["melee", "shooter", "melee", "lancer"]
	elif wave <= 4:
		roster = ["melee", "shooter", "lancer", "melee", "shooter"]
	else:
		roster = ["lancer", "shooter", "melee", "lancer", "shooter", "melee"]
	var enemy_kind := roster[spawn_index % roster.size()]
	spawn_index += 1
	return enemy_kind
