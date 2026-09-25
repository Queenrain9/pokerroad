extends SceneTree
const Hand = preload("res://scripts/core/holdem_hand.gd")
const Tournament = preload("res://scripts/core/tournament_director.gd")
const Story = preload("res://scripts/services/story_timeline.gd")
const Betting = preload("res://scripts/core/betting_round.gd")
const Travel = preload("res://scripts/services/traversal_service.gd")
var checked := 0
var errors: Array[String] = []

func must(ok: bool, why: String) -> void:
	checked += 1
	if not ok:
		errors.append(why)

func _initialize() -> void:
	var a := Hand.new([10, 10], 0, 1, 2, "folded", 1234)
	must(not a.finished and a.current_actor == 0, "HU button/small blind acts first before flop")
	must(not a.act(1, "check"), "cannot act out of turn")
	must(a.act(0, "fold"), "legal player fold")
	must(a.finished and a.settlement.get("reason") == "everyone_else_folded", "fold ends whole hand")
	must(a.stacks == [9, 11], "fold pot balances")
	var b := Hand.new([100, 100], 0, 1, 2, "showdown", 4321)
	must(b.act(0, "call") and b.act(1, "check"), "preflop complete")
	must(b.board.size() == 3 and b.current_actor == 1, "flop dealt and BB acts first")
	for s in range(1, 4):
		must(b.act(1, "check") and b.act(0, "check"), "street %s check through" % s)
	must(b.finished and b.settlement.get("reason") == "showdown", "river showdown completed")
	must(b.board.size() == 5 and b.stacks[0] + b.stacks[1] == 200, "full hand chips and board count")
	var c := Hand.new([5, 5], 0, 1, 2, "allin", 3333)
	must(c.act(0, "raise", 5) and c.act(1, "call"), "all-in and call")
	must(c.finished and c.board.size() == 5 and c.stacks[0] + c.stacks[1] == 10, "all-in runs out and settles")
	var d := Hand.new([3, 8, 8], 0, 1, 2, "sidepots", 9876)
	must(d.current_actor == 0 and d.act(0, "raise", 3), "short stack preflop short all-in")
	must(d.act(1, "call") and d.act(2, "call"), "side pot matched")
	for s in range(1, 4):
		must(d.act(1, "check") and d.act(2, "check"), "side pot street %s" % s)
	must(d.finished and d.stacks[0] + d.stacks[1] + d.stacks[2] == 19, "side pots conserve chips")
	var t := Tournament.new("r04_player_qualifier", ["PLAYER", "NPC_OTHER"], 5, 1, 2)
	must(t.begin_hand(13).has("hand_id") and not t.finished, "independent tournament starts")
	must(t.active_hand != null and t.active_hand.current_actor == 0, "tournament holds a real hand")
	must(t.act(0, "fold") and not t.finished and t.final_ranks.is_empty(), "first hand loss is not tournament elimination")
	must(t.official_player_result("PLAYER", true, true).has("error"), "unfinished tournament has no rank")
	var e := Hand.new([100, 100], 0, 1, 2, "uncalled_raise", 777)
	must(e.act(0, "raise", 20) and e.act(1, "fold"), "uncalled raise then fold")
	must(e.finished and e.stacks == [102, 98], "uncalled 18 refunded to aggressor")
	var unattended := Hand.new([100, 1, 1], 0, 1, 2, "one_actor_two_allin", 101)
	must(not unattended.finished and unattended.current_actor == 0, "real outstanding call remains")
	must(unattended.act(0, "call") and unattended.finished and unattended.board.size() == 5, "after legal call remaining streets auto-run out")
	var easy_runout := Hand.new([100, 1], 0, 1, 2, "one_actor_nocall", 202)
	must(easy_runout.finished and easy_runout.board.size() == 5, "heads-up short all-in BB no redundant check")
	var still_owed := Hand.new([100, 1, 2], 0, 1, 2, "call_is_not_automatic", 303)
	must(not still_owed.finished and still_owed.current_actor == 0, "real call/fold choice preserved")
	must(still_owed.act(0, "fold") and still_owed.finished, "outstanding call may be declined")
	var short_blind := Betting.new([100, 100, 1], 2)
	must(short_blind.post_forced(1, 1) and short_blind.post_forced(2, 2), "short BB posts one")
	must(short_blind.legal_actions(0).get("min_total_bet", -1) == 2, "short BB cannot inflate minimum open")
	var bankrupt := Tournament.new("native_hu_rank", ["LEFT", "RIGHT"], 1, 1, 2)
	var auto_started: Dictionary = bankrupt.begin_hand(13)
	must(auto_started.get("hand_completed_automatically", false), "both blinds all-in auto-runout")
	var guard := 0
	while not bankrupt.finished and guard < 40:
		var next_auto: Dictionary = bankrupt.begin_hand(13 + guard)
		must(next_auto.get("hand_completed_automatically", false), "tied one-chip runouts remain automatic")
		guard += 1
	must(bankrupt.finished and bankrupt.final_ranks.has("LEFT") and bankrupt.final_ranks.has("RIGHT"), "both seats receive rank")
	var seat_rank: Dictionary = bankrupt.official_player_result("LEFT", true, true)
	must(seat_rank.get("review_status", "") == "ENGINE_RANK_ONLY" and not seat_rank.get("national_qualification_granted", true), "caller booleans cannot turn engine rank into verified national entitlement")
	var graph := Travel.load_graph()
	must(not graph.has("error"), "real eight-region traversal data loads")
	must(Travel.plan_step(graph, "03", "F2", "F3").has("error"), "forest route choice required")
	must(Travel.plan_step(graph, "03", "F2", "F3", "EXTERNAL_STAIRS").get("to") == "F3", "forest external stairs chosen")
	must(Travel.plan_step(graph, "04", "H1", "H2", "LOW_TIDE_MARKER_PATH", {"tide":"HIGH"}).has("error"), "tide hazard blocks wrong crossing")
	must(Travel.plan_step(graph, "05", "E3", "E4", "TAKE_LAST_TRAIN", {"last_train_available":false}).get("alternative_anchor", "") == "E3B", "missed train points to free bus")
	must(Travel.plan_step(graph, "05", "E3", "E3B", "BOARD_FREE_NIGHT_BUS", {"last_train_available":false}).get("to", "") == "E3B", "explicit free bus boarding")
	must(Travel.plan_step(graph, "05", "E3B", "E4", "RIDE_FREE_NIGHT_BUS_TO_EVENT", {"last_train_available":false}).get("to", "") == "E4", "free bus ride reaches event")
	must(Travel.plan_step(graph, "08", "C2", "C3", "REGISTERED_PLAYER_ONLY", {"player_q":"NO"}).has("error"), "spectator cannot enter player gate")
	var story := Story.initial_state()
	must(Story.apply_checkpoint(story, "08-M04").has("error"), "cannot restore seat before pause/reform")
	must(Story.apply_checkpoint(story, "04-M03").has("error"), "Narae event needs independent evidence")
	for error in errors:
		push_error("P1 HEADLESS FAILED: " + error)
	if errors.is_empty():
		print("POKERROAD_P1_HEADLESS: %d checks passed" % checked)
		quit(0)
	else:
		quit(1)
