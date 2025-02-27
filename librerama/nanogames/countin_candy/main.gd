###############################################################################
# Librerama                                                                   #
# Copyright (C) 2023 Michael Alexsander                                       #
#-----------------------------------------------------------------------------#
# This file is part of Librerama.                                             #
#                                                                             #
# Librerama is free software: you can redistribute it and/or modify           #
# it under the terms of the GNU General Public License as published by        #
# the Free Software Foundation, either version 3 of the License, or           #
# (at your option) any later version.                                         #
#                                                                             #
# Librerama is distributed in the hope that it will be useful,                #
# but WITHOUT ANY WARRANTY; without even the implied warranty of              #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               #
# GNU General Public License for more details.                                #
#                                                                             #
# You should have received a copy of the GNU General Public License           #
# along with Librerama.  If not, see <http://www.gnu.org/licenses/>.          #
###############################################################################

extends Node2D

signal ended(has_won: bool)

const CANDY_COUNTING_TIME = 3.0
const CANDY_FALL_DURATION = 1.0

const CANDY_QUANTITY_BASE = 3
const CANDY_OTHER_QUANTITY_MIN = 2

const CANDIES_TEXTURE = preload("_assets/candies.png")

var _difficulty := 0
var _candy_quantity_answer := 0
var _answer_hovered := 0

func nanogame_prepare(difficulty: int, debug_code: int) -> void:
	_difficulty = difficulty

	_candy_quantity_answer = CANDY_QUANTITY_BASE
	if difficulty > 1:
		_candy_quantity_answer *= 2
	_candy_quantity_answer += randi() % CANDY_QUANTITY_BASE + 1

	var answers: Array[int] = [_candy_quantity_answer, _candy_quantity_answer, _candy_quantity_answer]

	answers[0] += randi() % 2 + 1
	if answers[0] > 0:
		if answers[1] > 2 and randi() % 2 == 0:
			answers[1] -= randi() % 2 + 1
		else:
			answers[1] += 1
			if answers[1] == answers[0]:
				answers[1] += 1

	answers.shuffle()

	for i: Label in ($GUI/Fade/CandyCounter/Answers as HBoxContainer).get_children() as Array[Label]:
		i.text = str(answers.pop_front())

		if debug_code == 1 and int(i.text) == _candy_quantity_answer:
			i.self_modulate = Color.CORNFLOWER_BLUE

	($AnimationPlayer as AnimationPlayer).queue("jar_shake")

func nanogame_start() -> void:
	var candies: Array[int] = []
	if _difficulty < 3:
		for i: int in _candy_quantity_answer:
			candies.append(0)
		(%Type as TextureRect).texture = preload("_assets/peppermint.png")
	else:
		var candy_other_quantity: int = maxi(CANDY_OTHER_QUANTITY_MIN, randi() % _candy_quantity_answer)
		for i: int in candy_other_quantity:
			candies.append(1)

		_candy_quantity_answer -= candy_other_quantity
		for i: int in _candy_quantity_answer:
			candies.append(0)

		candies.shuffle()

		if randi() % 2 == 0:
			(%Type as TextureRect).texture = preload("_assets/peppermint.png")
		else:
			_candy_quantity_answer = candy_other_quantity
			(%Type as TextureRect).texture = preload("_assets/chocolate.png")

	var candy_quantity: int = candies.size()
	var spawn_interval: float = CANDY_COUNTING_TIME / candy_quantity
	var jar_position: Vector2 = ($Jar as Sprite2D).position + Vector2(0,200)

	for i: int in candy_quantity:
		var candy := Sprite2D.new()
		candy.texture = CANDIES_TEXTURE
		candy.hframes = 2
		candy.frame = candies[i]

		var spawn_side := randi() % 3
		var spawn_position: Vector2
		var arc_peak: Vector2

		match spawn_side:
			0:  # Left side
				spawn_position = Vector2(-CANDIES_TEXTURE.get_width(), randf_range(0, NanogamePlayer.VIEW_SIZE.y))
				arc_peak = Vector2(jar_position.x / 2, spawn_position.y - randf_range(150, 250))
			1:  # Right side
				spawn_position = Vector2(NanogamePlayer.VIEW_SIZE.x + CANDIES_TEXTURE.get_width(), randf_range(0, NanogamePlayer.VIEW_SIZE.y))
				arc_peak = Vector2(jar_position.x + (NanogamePlayer.VIEW_SIZE.x - jar_position.x) / 2, spawn_position.y - randf_range(150, 250))
			2:  # Top
				spawn_position = Vector2(randf_range(0, NanogamePlayer.VIEW_SIZE.x), -CANDIES_TEXTURE.get_height())
				arc_peak = spawn_position

		candy.position = spawn_position
		add_child(candy)

		var tween: Tween = create_tween()
		tween.tween_interval(spawn_interval * i)

		if spawn_side != 2:
			tween.tween_property(candy, "position", arc_peak, CANDY_FALL_DURATION / 2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(candy, "position", jar_position, CANDY_FALL_DURATION / 2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			tween.tween_property(candy, "position", jar_position, CANDY_FALL_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

		tween.parallel().tween_property(candy, "rotation", randf_range(-PI, PI), CANDY_FALL_DURATION)

		if i == candy_quantity - 1:
			tween.chain().tween_callback(_show_answers)

	get_tree().create_timer(CANDY_COUNTING_TIME).timeout.connect(($AnimationPlayer as AnimationPlayer).stop.bind(true))

func _show_answers() -> void:
	($GUI/Fade as ColorRect).show()
	($AnimationPlayer as AnimationPlayer).play("show_answers")

func _on_answer_input_event(_viewport: Node, event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.is_pressed():
		return

	($GUI/Fade/CandyCounter/Result/Quantity as Label).text = "× %02d" % _candy_quantity_answer

	var label := ($GUI/Fade/CandyCounter/Answers as HBoxContainer).get_child(_answer_hovered) as Label
	if int(label.text) == _candy_quantity_answer:
		label.self_modulate = Color.LIME_GREEN
		($Result as AudioStreamPlayer).stream = preload("_assets/crunch.wav")
		ended.emit(true)
	else:
		label.self_modulate = Color.TOMATO
		($Result as AudioStreamPlayer).stream = preload("_assets/cough.wav")
		ended.emit(false)

	($Result as AudioStreamPlayer).play()

func _on_answer_mouse_entered(index: int) -> void:
	_answer_hovered = index
