extends SceneTree
## Execute on the user's Godot 4.x installation:
## godot --headless --path game --script res://tests_headless.gd
const Poker = preload("res://scripts/core/poker_rules.gd")
const Betting = preload("res://scripts/core/betting_round.gd")
const Q = preload("res://scripts/services/qualification.gd")
var checks := 0
var failures: Array[String] = []

func must(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append("TEST FAILED: " + label)

func _initialize() -> void:
	must(Poker.full_deck().size() == 52, "52 cards")
	must(Poker.full_deck().duplicate().size() == 52, "stable deck")
	must(Poker.score_five(["As", "Ks", "Qs", "Js", "Ts"]) > Poker.score_five(["9s", "9h", "9d", "9c", "2s"]), "straight flush beats quads")
	must(Poker.score_five(["As", "2h", "3d", "4c", "5s"]) < Poker.score_five(["2s", "3h", "4d", "5c", "6s"]), "wheel is 5-high")
	must(Poker.best_score(["As", "Ah", "Ad", "Ks", "Kd", "2h", "3d"]) > Poker.best_score(["As", "Ah", "Ks", "Kd", "2h", "3d", "4c"]), "full house beats two pair")
	must(Poker.score_five(["As", "As", "Qs", "Js", "Ts"]) == -1, "duplicate rejected")
	var board: Array[String] = ["Ah", "Kh", "Qh", "Jd", "2c"]
	var hands: Array = [["Th", "9s"], ["Ad", "3c"], ["Kd", "4c"]]
	var pots := Poker.evaluate_pots([20, 50, 50], [true, true, true], hands, board)
	must(not pots.has("error") and pots.pots.size() == 2, "side pots partition")
	must(pots.pots[0].amount == 60 and pots.pots[1].amount == 60, "side pots size")
	must(pots.payouts[0] + pots.payouts[1] + pots.payouts[2] == 120, "chip conservation")
	var round := Betting.new([100, 100, 100], 2)
	must(round.post_forced(0, 1) and round.post_forced(1, 2), "blinds")
	must(not round.act(2, "check"), "no free check facing blind")
	must(round.act(2, "raise", 6), "legal opening raise")
	must(round.act(0, "call") and round.act(1, "call"), "calls")
	must(round.is_street_over(), "round closes")
	must(round.begin_next_street(), "begin flop")
	must(round.act(0, "check") and round.act(1, "check") and round.act(2, "check"), "check through")
	must(round.is_street_over(), "flop closes")
	var short_round := Betting.new([100, 100, 7], 2)
	must(short_round.act(0, "raise", 6), "full raise starts street")
	must(short_round.act(1, "call"), "first opponent calls")
	must(short_round.act(2, "raise", 7), "short all-in allowed")
	must(not short_round.legal_actions(0).can_raise and short_round.legal_actions(0).can_call, "single short allin does not reopen")
	must(short_round.act(0, "call") and short_round.act(1, "call"), "short allin callers")
	must(short_round.is_street_over(), "short allin round closes")
	var evidence := {"event_id": "qual-04", "owner_id": "player", "actually_participated": true, "review_status": "VERIFIED", "match_status": "FINISHED", "final_rank": 1}
	var rules := {"event_id": "qual-04", "owner_id": "player", "sanction_status": "OFFICIAL", "national_qualifier": true, "qualifying_rank_cutoff": 1}
	must(Q.qualify_from_result(evidence, rules) == "YES", "valid independently reviewed qualifier result")
	rules.national_qualifier = false
	must(Q.qualify_from_result(evidence, rules) == "NO", "official local event is not necessarily a national qualifier")
	rules.national_qualifier = true
	evidence.review_status = "ENGINE_RANK_ONLY"
	must(Q.qualify_from_result(evidence, rules) == "PENDING", "unreviewed finished official qualifier is pending, not denied or granted")
	evidence.review_status = "VERIFIED"
	rules.owner_id = "narae"
	must(Q.qualify_from_result(evidence, rules) == "NO", "NPC cannot transfer Q")
	must(not Q.official_registration_allowed("PENDING", "OFFICIAL", true, 1), "pending cannot enter")
	var manifest_file := FileAccess.open("res://data/world_manifest.json", FileAccess.READ)
	must(manifest_file != null, "world manifest exists")
	var m = JSON.parse_string(manifest_file.get_as_text())
	must(m.regions.size() == 8 and m.scenes.size() == 88, "all original scene IDs reserved")
	var implemented := 0
	var invalid := false
	for scene in m.scenes:
		if scene.original_dialogue != null:
			invalid = true
		if scene.game_implementation_status == "IMPLEMENTED":
			implemented += 1
			if scene.player_action_bindings.is_empty() or scene.qa_status != "PASS":
				invalid = true
	must(not invalid and implemented == 32, "first thirty-two QA-backed scenes marked implemented")
	if not failures.is_empty():
		for problem in failures:
			push_error(problem)
		quit(1)
	else:
		print("POKERROAD_GODOT_HEADLESS: %s checks passed" % checks)
		quit(0)
