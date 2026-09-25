extends SceneTree

const Tournament = preload("res://scripts/core/tournament_director.gd")
const AI = preload("res://scripts/core/poker_ai.gd")
const Competition = preload("res://scripts/services/competition_contract.gd")
const Presentation = preload("res://scripts/services/presentation_contract.gd")
const Save = preload("res://scripts/services/session_save_service.gd")
const Events = preload("res://scripts/services/event_registry.gd")

var checked := 0
var errors: Array[String] = []

func must(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		errors.append(label)

func _world_fixture() -> Dictionary:
	return {
		"main_cursor":"04-M03",
		"current_region":"04",
		"current_anchor":"H5",
		"world_layer":0,
		"return_anchor":"H5",
		"unlocked_regions":{"01":true,"02":true,"03":true,"04":true},
		"finished_main":{"01-M01":true},
		"finished_optional":{},
		"rewards_paid":{"intro":true},
		"world_phase":4,
		"chips":0,
		"player_q":"PENDING",
		"registration_intent":"VIEW",
		"player_events":{},
		"npc_events":{"r04_narae_qualifier":{"owner":"NPC_NARAE"}},
		"npc_seat_status":{},
		"observed_events":{"r04_narae_qualifier":"LEARNED_BULLETIN"},
		"story_flags":{},
		"event_serial":0
	}

func _initialize() -> void:
	var catalog := Events.catalog()
	must(not catalog.has("error"), "event catalog loads")
	must(Competition.validate_event_catalog(catalog).is_empty(), "event catalog obeys fixed competition invariants")
	must(Competition.can_transition("REGISTRATION_OPEN", "REGISTERED"), "registration transition allowed")
	must(not Competition.can_transition("DISCOVERED", "IN_PROGRESS"), "cannot skip registration lifecycle")
	must(Competition.mainline_must_remain_open({"tower_required":false,"requires_match_win":false,"requires_positive_wallet":false}), "loss/tower/wallet never gates mainline")
	must(not Competition.official_champion({"owner_id":"PLAYER","registered_official":true,"match_status":"FINISHED","final_rank":2},
		{"kind":"OFFICIAL_FINAL","record_owner":"PLAYER"}), "second place is not national champion")
	must(Competition.official_champion({"owner_id":"PLAYER","registered_official":true,"match_status":"FINISHED","final_rank":1},
		{"kind":"OFFICIAL_FINAL","record_owner":"PLAYER"}), "verified own final rank one is champion condition")

	var legal := {"can_fold":true,"can_check":false,"can_call":true,"can_raise":true,"to_call":2,"min_total_bet":6,"max_total_bet":40}
	var ai := AI.choose_action(legal, {"strength_hint":0.8,"public_board":[],"own_hole_cards":["As","Ks"]}, "BALANCED", 42)
	must(not ai.has("error") and ["fold","call","raise"].has(ai.get("choice","")), "AI chooses legal action only")
	var cheating := AI.choose_action(legal, {"strength_hint":0.8,"opponent_hole_cards":["2c","2d"]}, "STRONG", 42)
	must(cheating.has("error"), "AI rejects omniscient hidden-card context")

	must(Presentation.validate_all_regions().is_empty(), "all eight region presentation capability contracts exist")
	must(Presentation.can_transition("POKER","RESULT") and Presentation.can_transition("RESULT","WORLD"), "poker result returns to world")
	must(not Presentation.can_transition("POKER","DIALOGUE"), "poker cannot bypass result ownership")
	must(Presentation.region_capabilities("02").has("MOVING_WORLD_PARENT"), "river region requires moving world parent")
	must(Presentation.region_capabilities("08").has("EIGHT_SEAT_FINAL"), "city contract includes eight-seat final")

	var tour := Tournament.new("save_roundtrip", ["PLAYER","BOT"], 20, 1, 2, 6)
	var start := tour.begin_hand(250925)
	must(not start.has("error") and tour.active_hand != null, "tournament starts for save test")
	must(tour.act(0,"call"), "player call recorded before interruption")
	var snap := tour.to_snapshot()
	var restored = Tournament.from_snapshot(snap)
	must(restored != null, "mid-hand tournament snapshot restores")
	must(restored != null and JSON.stringify(restored.to_snapshot()) == JSON.stringify(snap), "restored tournament exactly matches snapshot")
	if restored != null:
		must(tour.act(1,"check") and restored.act(1,"check"), "original and restored continue same legal action")
		must(JSON.stringify(tour.to_snapshot()) == JSON.stringify(restored.to_snapshot()), "restored deck/board/bets continue deterministically")

	var mode_state := Save.tournament_mode_state("save_roundtrip:instance:1", restored)
	var payload := Save.build_payload(_world_fixture(), "POKER", mode_state)
	must(not payload.has("error"), "POKER save contains complete world+tournament state")
	must(Save.validate_payload(payload).is_empty(), "POKER payload validates")
	var path := "user://pokerroad_system_contract_test.json"
	must(Save.write_atomic(path,payload), "save writes through temp file")
	var loaded := Save.read_payload(path)
	must(not loaded.has("error") and loaded.mode == "POKER", "saved payload reads and validates")
	var loaded_tour = Save.restore_tournament(loaded.mode_state if not loaded.has("error") else {})
	must(loaded_tour != null, "saved tournament object restores")
	if loaded_tour != null:
		must(loaded_tour.event_id == restored.event_id, "saved event id exact")
		must(loaded_tour.stacks == restored.stacks, "saved tournament stacks exact")
		must(loaded_tour.completed_hands == restored.completed_hands, "saved hand count exact")
		must(loaded_tour.dealer == restored.dealer, "saved dealer exact")
		must(loaded_tour.active_hand != null and restored.active_hand != null, "saved active hand exists")
		if loaded_tour.active_hand != null and restored.active_hand != null:
			must(loaded_tour.active_hand.deck == restored.active_hand.deck, "saved deck order exact")
			must(loaded_tour.active_hand.board == restored.active_hand.board, "saved board exact")
			must(loaded_tour.active_hand.holes == restored.active_hand.holes, "saved hole cards exact")
			must(loaded_tour.active_hand.current_actor == restored.active_hand.current_actor, "saved actor exact")
			must(loaded_tour.active_hand.round.to_snapshot() == restored.active_hand.round.to_snapshot(), "saved betting state exact")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var bad_dialogue := Save.build_payload(_world_fixture(), "DIALOGUE", {"active_scene_id":"04-M03"})
	must(bad_dialogue.has("error"), "dialogue interruption cannot omit cursor/return fields")
	var legacy := _world_fixture()
	legacy["schema"] = 1
	legacy.erase("world_layer")
	legacy.erase("return_anchor")
	var migrated := Save.migrate_v1_world_only(legacy)
	must(not migrated.has("error") and migrated.mode == "WORLD", "legacy world save migrates without inventing mid-hand state")

	for error in errors:
		push_error("SYSTEM CONTRACT FAILED: " + error)
	if errors.is_empty():
		print("POKERROAD_SYSTEM_CONTRACTS: %d checks passed" % checked)
		quit(0)
	else:
		quit(1)
