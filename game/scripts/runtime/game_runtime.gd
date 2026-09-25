class_name GameRuntime
extends Node

const Tournament = preload("res://scripts/core/tournament_director.gd")
const AI = preload("res://scripts/core/poker_ai.gd")

var mode := "WORLD"
var scene_runner
var world_runtime
var active_tournament
var active_event_rule: Dictionary = {}
var active_event_instance_id := ""
var active_registered_official := false
var current_result: Dictionary = {}
var pending_paid_event: Dictionary = {}

func _init() -> void:
	scene_runner = SceneRunner.new()
	world_runtime = WorldRuntime.new(scene_runner)

func validate_runtime() -> Array[String]:
	var errors := SceneBindingStore.validate_catalog()
	errors.append_array(PresentationContract.validate_all_regions())
	var descriptors := world_runtime.all_region_descriptors()
	if descriptors.size() != 8:
		errors.append("runtime must expose all eight regions")
	for descriptor in descriptors:
		if descriptor.has("error"):
			errors.append(str(descriptor.get("error", "unknown region runtime error")))
	return errors

func open_scene(scene_id: String) -> Dictionary:
	if mode != "WORLD":
		return {"error":"world interaction requires WORLD mode"}
	var opened := world_runtime.open_scene(scene_id)
	if opened.has("error"):
		return opened
	var target := str(opened.get("open_mode", "DIALOGUE"))
	if not _transition(target):
		return {"error":"illegal world-to-scene mode transition"}
	return opened

func select_scene_choice(interaction_id: String, choice_id: String) -> Dictionary:
	if mode != "DIALOGUE":
		return {"error":"scene choice requires DIALOGUE mode"}
	var result := scene_runner.choose(interaction_id, choice_id)
	if result.has("error"):
		return result
	var requests: Array = result.get("external_requests", [])
	if requests.size() > 1:
		return {"error":"one choice cannot start multiple external activities"}
	if requests.size() == 1:
		var started := _handle_external_request(requests[0])
		if started.has("error") or started.get("requires_confirmation", false):
			return started
		result["event_start"] = started
		return result
	var target := str(result.get("requested_mode", mode))
	if target != mode and not _transition(target):
		return {"error":"choice requested illegal presentation mode"}
	return result

func _handle_external_request(request: Dictionary) -> Dictionary:
	if request.get("type", "") != "START_EVENT":
		return {"error":"unsupported external request"}
	return start_event(str(request.get("event_id", "")), request.get("participants", []),
		bool(request.get("registered_official", false)), false)

func start_event(event_id: String, participants: Array, registered_official: bool = false,
		cost_confirmed: bool = false) -> Dictionary:
	if not ["WORLD","DIALOGUE"].has(mode):
		return {"error":"event can only start from world/dialogue"}
	var event := EventRegistry.event_by_id(event_id)
	if event.is_empty():
		return {"error":"unknown event"}
	var expected_seats := int(event.get("seat_count_dev", 0))
	if participants.size() != expected_seats or expected_seats < 2:
		return {"error":"participant count does not match event contract"}
	var names: Array[String] = []
	for value in participants:
		var name := str(value)
		if name.is_empty() or names.has(name):
			return {"error":"participant identities must be unique"}
		names.append(name)
	if event.get("record_owner", "") == "PLAYER" and not names.has("PLAYER"):
		return {"error":"player-owned event requires PLAYER seat"}
	var fee := int(event.get("wallet_entry_fee_dev", 0))
	if fee > 0 and not cost_confirmed:
		pending_paid_event = {"event_id":event_id,"participants":participants.duplicate(),
			"registered_official":registered_official,"fee":fee}
		return {"requires_confirmation":true,"event_id":event_id,"fee":fee}
	if fee > 0 and not GameState.pay_entry_fee(fee):
		return {"error":"insufficient wallet for confirmed entry fee"}
	var instance_id := GameState.allocate_event_instance_id(event_id)
	var bb := int(event.get("start_big_blind_dev", 0))
	var stack := int(event.get("start_tournament_stack_dev", 0))
	var blind_hands := int(event.get("blind_level_every_completed_hands_dev", 6))
	if bb < 1 or stack < 1:
		return {"error":"event has invalid tournament defaults"}
	var sb := maxi(1, int(floor(float(bb) / 2.0)))
	var tournament = Tournament.new(event_id, names, stack, sb, bb, blind_hands)
	if tournament.finished and tournament.final_ranks.is_empty():
		return {"error":"tournament construction failed"}
	var previous_mode := mode
	if previous_mode != "POKER" and not _transition("POKER"):
		return {"error":"presentation contract blocks poker transition"}
	active_tournament = tournament
	active_event_rule = event.duplicate(true)
	active_event_instance_id = instance_id
	active_registered_official = registered_official
	pending_paid_event.clear()
	var first_hand := active_tournament.begin_hand()
	if first_hand.has("error"):
		active_tournament = null
		active_event_rule.clear()
		active_event_instance_id = ""
		mode = previous_mode
		return first_hand
	return {"event_instance_id":instance_id,"event_id":event_id,"mode":mode,"first_hand":first_hand}

func confirm_pending_event() -> Dictionary:
	if pending_paid_event.is_empty():
		return {"error":"no paid event awaiting confirmation"}
	var request := pending_paid_event.duplicate(true)
	return start_event(str(request.event_id), request.participants,
		bool(request.registered_official), true)

func begin_next_hand(seed: int = -1) -> Dictionary:
	if mode != "POKER" or active_tournament == null:
		return {"error":"no active tournament"}
	if active_tournament.finished:
		return {"error":"tournament already finished"}
	if active_tournament.active_hand != null:
		return {"error":"current hand still active"}
	var started := active_tournament.begin_hand(seed)
	if active_tournament.finished:
		_finalize_event("FINISHED")
	return started

func submit_action(seat: int, choice: String, total_bet: int = -1) -> Dictionary:
	if mode != "POKER" or active_tournament == null or active_tournament.active_hand == null:
		return {"error":"no active poker hand"}
	if not active_tournament.act(seat, choice, total_bet):
		return {"error":"illegal poker action"}
	if active_tournament.finished:
		return _finalize_event("FINISHED")
	return {"ok":true,"current_actor":active_tournament.active_hand.current_actor if active_tournament.active_hand != null else -1}

func submit_ai_action(profile: String, strength_hint: float, seed: int) -> Dictionary:
	if mode != "POKER" or active_tournament == null or active_tournament.active_hand == null:
		return {"error":"no active poker hand"}
	var hand = active_tournament.active_hand
	var seat: int = hand.current_actor
	var legal := hand.current_options()
	var context := {
		"own_hole_cards":hand.holes[seat].duplicate(),
		"public_board":hand.board.duplicate(),
		"public_bets":hand.round.street_committed.duplicate(),
		"public_stacks":hand.round.stacks.duplicate(),
		"seat_position":seat,
		"blind_level":int(floor(float(active_tournament.completed_hands) / float(active_tournament.blind_level_hands))),
		"prior_public_actions":hand.history.duplicate(true),
		"legal_actions":legal.duplicate(true),
		"strength_hint":strength_hint
	}
	var action := AI.choose_action(legal, context, profile, seed)
	if action.has("error"):
		return action
	return submit_action(seat, str(action.get("choice", "")), int(action.get("total_bet", -1)))

func withdraw_active_event() -> Dictionary:
	if mode != "POKER" or active_tournament == null:
		return {"error":"no active tournament"}
	return _finalize_event("WITHDRAW")

func _finalize_event(status: String) -> Dictionary:
	if active_tournament == null:
		return {"error":"no tournament to finalize"}
	if status == "FINISHED" and not active_tournament.finished:
		return {"error":"cannot finalize unfinished tournament"}
	var has_player := active_tournament.seat_names.has("PLAYER")
	var rank := int(active_tournament.final_ranks.get("PLAYER", 0)) if has_player else 0
	var outcome := "WITHDRAW"
	if status == "FINISHED" and has_player:
		outcome = "WIN" if rank == 1 else "LOSS"
	var result := {
		"event_instance_id":active_event_instance_id,
		"event_id":active_event_rule.get("event_id", ""),
		"owner_id":"PLAYER" if has_player else active_event_rule.get("record_owner", ""),
		"actually_participated":true,
		"match_status":"FINISHED" if status == "FINISHED" else "WITHDRAWN",
		"final_rank":rank,
		"outcome":outcome,
		"registered_official":active_registered_official,
		"review_status":"ENGINE_RANK_ONLY" if active_event_rule.get("sanction_status", "") == "OFFICIAL" and status == "FINISHED" else "NOT_APPLICABLE",
		"hand_count":active_tournament.completed_hands
	}
	if has_player:
		GameState.record_player_event(active_event_instance_id, result)
	else:
		GameState.record_npc_event(active_event_instance_id, result)
	if scene_runner.has_active_scene():
		var consumed := scene_runner.apply_external_result(str(active_event_rule.get("event_id", "")), outcome)
		if consumed.has("error") and status != "WITHDRAW":
			result["scene_result_warning"] = consumed.error
	current_result = result.duplicate(true)
	active_tournament = null
	active_event_rule.clear()
	active_event_instance_id = ""
	active_registered_official = false
	if not _transition("RESULT"):
		return {"error":"presentation contract blocks poker result"}
	return current_result

func finish_observation() -> Dictionary:
	if mode != "OBSERVE":
		return {"error":"not in observation mode"}
	current_result = {"kind":"OBSERVATION","scene_id":scene_runner.active_scene_id()}
	if not _transition("RESULT"):
		return {"error":"presentation contract blocks observation result"}
	return current_result

func acknowledge_result() -> Dictionary:
	if mode != "RESULT":
		return {"error":"no result to acknowledge"}
	var result := current_result.duplicate(true)
	if not _transition("WORLD"):
		return {"error":"result cannot return to world"}
	current_result.clear()
	return {"acknowledged":result,"mode":mode,"scene_ready_to_complete":scene_runner.ready_to_complete() if scene_runner.has_active_scene() else false}

func commit_active_scene() -> Dictionary:
	if mode != "WORLD":
		return {"error":"scene completion commits only from world"}
	return scene_runner.commit_completion()

func save_runtime() -> bool:
	var mode_state: Dictionary = {}
	if mode == "POKER":
		if active_tournament == null:
			return false
		mode_state = SessionSaveService.tournament_mode_state(active_event_instance_id, active_tournament)
	elif mode == "DIALOGUE":
		mode_state = scene_runner.snapshot()
	elif mode == "OBSERVE" or mode == "RESULT":
		mode_state = {"runtime_result":current_result.duplicate(true),"active_scene":scene_runner.snapshot()}
	return GameState.save_session_v2(mode, mode_state)

func restore_runtime() -> Dictionary:
	var loaded := GameState.load_session_v2()
	if loaded.has("error"):
		return loaded
	var loaded_mode := str(loaded.get("mode", "WORLD"))
	var state: Dictionary = loaded.get("mode_state", {})
	mode = "WORLD"
	if loaded_mode == "POKER":
		active_tournament = SessionSaveService.restore_tournament(state)
		if active_tournament == null:
			return {"error":"saved tournament could not be restored"}
		active_event_instance_id = str(state.get("event_instance_id", ""))
		active_event_rule = EventRegistry.event_by_id(str(state.get("event_id", "")))
		if active_event_rule.is_empty():
			return {"error":"saved event rule missing"}
		mode = "POKER"
	elif loaded_mode == "DIALOGUE":
		var restored_scene := scene_runner.restore(state)
		if restored_scene.has("error"):
			return restored_scene
		mode = "DIALOGUE"
	elif loaded_mode == "WORLD":
		mode = "WORLD"
	else:
		return {"error":"resume mode not yet supported by runtime"}
	return {"mode":mode}

func _transition(target: String) -> bool:
	if target == mode:
		return true
	if not PresentationContract.can_transition(mode, target):
		return false
	mode = target
	return true
