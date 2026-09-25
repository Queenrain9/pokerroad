class_name PokerRoadPlayUI
extends CanvasLayer

# The first playable story slice uses the shared runtime and source-backed
# bindings. This interface deliberately presents navigation and decisions,
# without claiming to be the final region art or mobile layout.
var root
var panel: PanelContainer
var body: VBoxContainer
var world_label: Label
var hint_label: Label
var prompt_label: Label
var move_vector := Vector2.ZERO
var last_mode := ""
var last_scene := ""
var last_actor := -2
var last_hand_count := -1
var message := ""

func setup(game_root) -> void:
	root = game_root

func _ready() -> void:
	var layer: Control = Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)

	var world_card := PanelContainer.new()
	world_card.position = Vector2(18, 18)
	world_card.custom_minimum_size = Vector2(500, 90)
	var world_style := StyleBoxFlat.new()
	world_style.bg_color = Color(0.06, 0.12, 0.14, 0.86)
	world_style.corner_radius_top_left = 10
	world_style.corner_radius_top_right = 10
	world_style.corner_radius_bottom_left = 10
	world_style.corner_radius_bottom_right = 10
	world_style.content_margin_left = 18
	world_style.content_margin_right = 18
	world_style.content_margin_top = 12
	world_style.content_margin_bottom = 10
	world_card.add_theme_stylebox_override("panel", world_style)
	layer.add_child(world_card)
	var world_box := VBoxContainer.new()
	world_box.add_theme_constant_override("separation", 4)
	world_card.add_child(world_box)
	world_label = Label.new()
	world_label.add_theme_font_size_override("font_size", 25)
	world_label.add_theme_color_override("font_color", Color("#f2dfb7"))
	world_box.add_child(world_label)
	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.add_theme_color_override("font_color", Color("#e9ece3"))
	world_box.add_child(hint_label)

	prompt_label = Label.new()
	prompt_label.position = Vector2(910, 574)
	prompt_label.custom_minimum_size = Vector2(330, 42)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color("#f2dfb7"))
	layer.add_child(prompt_label)

	panel = PanelContainer.new()
	panel.position = Vector2(110, 405)
	panel.custom_minimum_size = Vector2(1060, 0)
	var dialogue_style := StyleBoxFlat.new()
	dialogue_style.bg_color = Color(0.04, 0.08, 0.10, 0.93)
	dialogue_style.border_width_left = 2
	dialogue_style.border_width_top = 2
	dialogue_style.border_width_right = 2
	dialogue_style.border_width_bottom = 2
	dialogue_style.border_color = Color(0.73, 0.59, 0.34, 0.75)
	dialogue_style.corner_radius_top_left = 12
	dialogue_style.corner_radius_top_right = 12
	dialogue_style.corner_radius_bottom_left = 12
	dialogue_style.corner_radius_bottom_right = 12
	dialogue_style.content_margin_left = 20
	dialogue_style.content_margin_right = 20
	dialogue_style.content_margin_top = 16
	dialogue_style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", dialogue_style)
	layer.add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	panel.add_child(body)

	var controls: HBoxContainer = HBoxContainer.new()
	controls.position = Vector2(18, 626)
	controls.add_theme_constant_override("separation", 5)
	layer.add_child(controls)
	for direction in [Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2.RIGHT]:
		var key: Button = Button.new()
		key.text = {Vector2.LEFT:"◀",Vector2.UP:"▲",Vector2.DOWN:"▼",Vector2.RIGHT:"▶"}[direction]
		key.custom_minimum_size = Vector2(52, 52)
		key.button_down.connect(_move_down.bind(direction))
		key.button_up.connect(_move_up.bind(direction))
		controls.add_child(key)

	var interact: Button = Button.new()
	interact.text = "상호작용  E"
	interact.position = Vector2(1080, 620)
	interact.custom_minimum_size = Vector2(165, 58)
	interact.pressed.connect(_interact)
	layer.add_child(interact)

	var save: Button = Button.new()
	save.text = "저장"
	save.position = Vector2(1090, 22)
	save.custom_minimum_size = Vector2(70, 44)
	save.pressed.connect(_save)
	layer.add_child(save)
	var load: Button = Button.new()
	load.text = "이어하기"
	load.position = Vector2(1164, 22)
	load.custom_minimum_size = Vector2(98, 44)
	load.pressed.connect(_load)
	layer.add_child(load)
	_refresh()

func _process(_delta: float) -> void:
	if root == null or root.runtime == null:
		return
	if Input.is_key_pressed(KEY_E) and not _e_was_down:
		_interact()
	_e_was_down = Input.is_key_pressed(KEY_E)
	if root.runtime.mode == "POKER" and root.runtime.active_tournament != null:
		var tournament = root.runtime.active_tournament
		if tournament.active_hand != null:
			var actor: int = tournament.active_hand.current_actor
			if actor >= 0 and tournament.seat_names[actor] != "PLAYER":
				var acted: Dictionary = root.runtime.submit_ai_action("BALANCED", 0.5, Time.get_ticks_msec())
				if acted.has("error"):
					message = str(acted.error)
			_refresh()
	var mode: String = root.runtime.mode
	var scene: String = root.runtime.scene_runner.active_scene_id()
	var actor_now := -2
	var hands_now := -1
	if mode == "POKER" and root.runtime.active_tournament != null:
		hands_now = root.runtime.active_tournament.completed_hands
		if root.runtime.active_tournament.active_hand != null:
			actor_now = root.runtime.active_tournament.active_hand.current_actor
	if mode != last_mode or scene != last_scene or actor_now != last_actor or hands_now != last_hand_count:
		last_mode = mode
		last_scene = scene
		last_actor = actor_now
		last_hand_count = hands_now
		_refresh()
	var region_name := root.state.current_region
	for region in root.state.manifest.get("regions", []):
		if str(region.get("id", "")) == root.state.current_region:
			region_name = str(region.get("name", root.state.current_region))
			break
	world_label.text = region_name
	hint_label.text = message if not message.is_empty() else _world_objective()
	prompt_label.text = _interaction_prompt() if mode == "WORLD" else ""
	root.player.set_virtual_move_vector(move_vector if mode == "WORLD" else Vector2.ZERO)
	root.player.set_physics_process(mode == "WORLD")

func _world_objective() -> String:
	if root == null or root.state == null:
		return ""
	match root.state.main_cursor:
		"01-M01": return "골목 게시판을 확인하거나 주민에게 길을 물어보세요"
		"01-M02": return "슈퍼 앞 평상에서 복례와 이야기하세요"
	var binding: Dictionary = SceneBindingStore.binding_by_id(root.state.main_cursor)
	if not binding.is_empty():
		return "목표 · " + str(binding.get("target", ""))
	return "동네를 둘러보세요"

func _interaction_prompt() -> String:
	if root == null or root.runtime == null:
		return ""
	var nearby: Dictionary = root.inspect_world_interaction()
	match str(nearby.get("kind", "")):
		"CURRENT_ANCHOR":
			var scene_id: String = root.state.main_cursor
			if nearby.get("scene_ids", []).has(scene_id):
				return "E  대화 / 확인"
			return "E  살펴보기"
		"TRAVEL_CONFIRMABLE": return "E  다음 길로 이동"
		"ROUTE_CHOICE_REQUIRED": return "E  이동 경로 선택"
	return ""


var _e_was_down := false

func _move_down(direction: Vector2) -> void:
	move_vector = direction

func _move_up(_direction: Vector2) -> void:
	move_vector = Vector2.ZERO

func _label(value: String) -> void:
	var line: Label = Label.new()
	line.text = value
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 540
	line.add_theme_font_size_override("font_size", 17)
	body.add_child(line)

func _button(title: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = title
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	body.add_child(button)

func _refresh() -> void:
	if body == null or root == null or root.runtime == null:
		return
	for child in body.get_children():
		child.queue_free()
	var mode: String = root.runtime.mode
	panel.visible = mode != "WORLD"
	if mode == "DIALOGUE":
		if not root.runtime.pending_paid_event.is_empty():
			var pending: Dictionary = root.runtime.pending_paid_event
			_label("공식 경기 참가비 " + str(pending.get("fee", 0)) + "칩을 지불하고 참가할까요?")
			_button("참가비 지불하고 입장", _confirm_paid_event)
			_button("이번엔 참가하지 않기", _cancel_paid_event)
			return
		var view: Dictionary = root.runtime.scene_runner.view_model()
		_label(str(view.get("scene_id", "")) + "  " + str(view.get("target", "")))
		if view.get("completed", false):
			_label(str(view.get("replay_dialogue", "이미 마친 이야기입니다.")))
			_button("월드로 돌아가기", _close_completed)
			return
		for line in view.get("dialogue", []):
			_label(str(line.get("speaker", "")) + ": " + str(line.get("text", "")))
		for interaction in view.get("interactions", []):
			for option in interaction.get("choices", []):
				var enabled := true
				for requirement in option.get("requires", []):
					if root.state.story_flags.get(str(requirement.get("key", ""))) != requirement.get("value"):
						enabled = false
				var required_anchors: Array = option.get("requires_anchor", [])
				if not required_anchors.is_empty() and not required_anchors.has(root.state.current_anchor):
					enabled = false
				if enabled:
					_button(str(option.get("label", "")), _choose.bind(str(interaction.get("interaction_id", "")), str(option.get("choice_id", ""))))
	elif mode == "OBSERVE":
		_label("현장을 관전하고 결과를 확인합니다. 이 기록은 직접 참가 성적과 구분됩니다.")
		_button("관전 마치기", _finish_observation)
	elif mode == "RESULT":
		_label("결과 확인: " + str(root.runtime.current_result))
		_button("월드로 돌아가기", _acknowledge)
	elif mode == "POKER":
		var tournament = root.runtime.active_tournament
		if tournament == null:
			_label("경기 복원 실패")
			return
		_label(str(tournament.event_id) + "  |  완료 핸드 " + str(tournament.completed_hands))
		_label("스택: " + str(tournament.stacks))
		if tournament.active_hand == null:
			_button("다음 핸드", _next_hand)
		else:
			var hand = tournament.active_hand
			_label("보드: " + str(hand.board) + "   내 카드: " + str(hand.holes[0]))
			var actor: int = hand.current_actor
			if actor >= 0:
				_label("차례: " + str(tournament.seat_names[actor]))
				if tournament.seat_names[actor] == "PLAYER":
					var legal: Dictionary = hand.current_options()
					for action in ["fold", "check", "call", "raise"]:
						if legal.get("can_" + action, false):
							var amount := int(legal.get("min_total_bet", -1)) if action == "raise" else -1
							_button(action + (" " + str(amount) if action == "raise" else ""), _poker_action.bind(actor, action, amount))
		_button("경기 중단", _withdraw)

func _interact() -> void:
	if root.runtime.mode != "WORLD":
		return
	var nearby: Dictionary = root.inspect_world_interaction()
	match str(nearby.get("kind", "")):
		"CURRENT_ANCHOR":
			var scene_id: String = root.state.main_cursor
			var available: Array = nearby.get("scene_ids", [])
			if available.has(scene_id):
				var opened: Dictionary = root.open_nearby_scene(scene_id)
				message = str(opened.get("error", ""))
			elif not available.is_empty():
				var opened: Dictionary = root.open_nearby_scene(str(available[0]))
				message = str(opened.get("error", ""))
			else:
				message = "이 장소의 현재 메인 장면은 없습니다."
		"TRAVEL_CONFIRMABLE":
			var arrived: Dictionary = root.confirm_world_interaction()
			message = str(arrived.get("error", ""))
		"ROUTE_CHOICE_REQUIRED":
			panel.visible = true
			for child in body.get_children(): child.queue_free()
			_label("이동 경로를 고르세요")
			for route in nearby.get("choices", []):
				_button(str(route), _travel_choice.bind(str(route)))
		"BLOCKED": message = str(nearby.get("reason", ""))
		_: message = "상호작용할 대상에 가까이 가세요."
	_refresh() if root.runtime.mode != "WORLD" else null

func _travel_choice(route: String) -> void:
	var result: Dictionary = root.confirm_world_interaction(route)
	message = str(result.get("error", ""))
	panel.visible = false

func _close_completed() -> void:
	var closed: Dictionary = root.runtime.close_completed_scene()
	message = str(closed.get("error", ""))
	_refresh()

func _choose(interaction: String, option: String) -> void:
	var result: Dictionary = root.runtime.select_scene_choice(interaction, option)
	message = str(result.get("error", ""))
	if root.runtime.mode == "WORLD" and root.runtime.scene_runner.ready_to_complete():
		_commit()
	_refresh()

func _confirm_paid_event() -> void:
	var result: Dictionary = root.runtime.confirm_pending_event()
	message = str(result.get("error", ""))
	_refresh()

func _cancel_paid_event() -> void:
	var result: Dictionary = root.runtime.cancel_pending_event()
	message = str(result.get("error", ""))
	_refresh()

func _finish_observation() -> void:
	var result: Dictionary = root.runtime.finish_observation()
	message = str(result.get("error", ""))
	_refresh()

func _acknowledge() -> void:
	var result: Dictionary = root.runtime.acknowledge_result()
	message = str(result.get("error", ""))
	if not result.has("error") and root.runtime.scene_runner.ready_to_complete():
		_commit()
	_refresh()

func _commit() -> void:
	var result: Dictionary = root.runtime.commit_active_scene()
	message = str(result.get("error", ""))
	if not result.has("error"):
		root.runtime.save_runtime()

func _poker_action(seat: int, action: String, amount: int) -> void:
	var result: Dictionary = root.runtime.submit_action(seat, action, amount)
	message = str(result.get("error", ""))
	_refresh()

func _next_hand() -> void:
	var result: Dictionary = root.runtime.begin_next_hand()
	message = str(result.get("error", ""))
	_refresh()

func _withdraw() -> void:
	var result: Dictionary = root.runtime.withdraw_active_event()
	message = str(result.get("error", ""))
	_refresh()

func _save() -> void:
	message = "저장 완료" if root.runtime.save_runtime() else "저장 실패"

func _load() -> void:
	var result: Dictionary = root.runtime.restore_runtime()
	message = str(result.get("error", "이어하기 완료"))
	root._on_world_changed()
	_refresh()
