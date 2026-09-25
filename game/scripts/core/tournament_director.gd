class_name TournamentDirector
extends RefCounted
const Hand = preload("res://scripts/core/holdem_hand.gd")
var event_id := ""
var seat_names: Array[String] = []
var stacks: Array[int] = []
var eliminations: Array[Dictionary] = []
var completed_hands := 0
var blind_level_hands := 6
var initial_sb := 1
var initial_bb := 2
var dealer := 0
var active_hand: HoldemHand
var finished := false
var final_ranks: Dictionary = {}
var hand_results: Array[Dictionary] = []\nvar initial_start_stack := 0

func _init(p_event_id: String, p_names: Array, start_stack: int, p_sb: int, p_bb: int, p_blind_level_hands: int = 6) -> void:
	event_id = p_event_id; initial_sb=p_sb; initial_bb=p_bb; blind_level_hands=maxi(p_blind_level_hands,1); initial_start_stack=start_stack
	if p_names.size() < 2 or p_names.size() > 9 or start_stack <= 0 or p_sb <= 0 or p_bb < p_sb:
		finished = true; return
	for value in p_names:
		if typeof(value) != TYPE_STRING or value.is_empty(): finished=true; return
		seat_names.append(str(value))
	if _has_duplicate_name(seat_names): finished=true; return
	for i in range(seat_names.size()): stacks.append(start_stack)

static func _has_duplicate_name(names: Array[String]) -> bool:
	var seen := {}
	for name in names:
		if seen.has(name): return true
		seen[name] = true
	return false

func _remaining() -> int:
	var n := 0
	for value in stacks:
		if value > 0: n += 1
	return n

func begin_hand(seed: int = -1) -> Dictionary:
	if finished or active_hand != null or _remaining() < 2: return {"error":"hand start forbidden"}
	var level: int = int(floor(float(completed_hands)/float(blind_level_hands)))
	var bb: int = initial_bb * int(pow(2, level)); var sb: int = initial_sb * int(pow(2, level))
	active_hand = Hand.new(stacks, dealer, sb, bb, "%s:hand:%s" % [event_id, completed_hands+1], seed)
	if active_hand.settlement.has("error"):
		var fail=active_hand.settlement.duplicate(); active_hand=null; return fail
	if active_hand.finished:
		var auto_id:String=active_hand.hand_id; _record_finished_hand()
		return {"event_id":event_id,"hand_id":auto_id,"hand_completed_automatically":true,"event_finished":finished}
	return {"event_id":event_id,"hand_id":active_hand.hand_id,"dealer":dealer,"small_blind":sb,"big_blind":bb,"current_actor":active_hand.current_actor}

func act(seat:int, choice:String, total_bet:int=-1)->bool:
	if active_hand == null or finished or not active_hand.act(seat,choice,total_bet): return false
	if active_hand.finished and not active_hand.settlement.has("error"): _record_finished_hand()
	return true

func _record_finished_hand()->void:
	var last:=active_hand; var before:=stacks.duplicate(); stacks=last.stacks.duplicate()
	hand_results.append(last.settlement.duplicate(true)); completed_hands += 1
	var left:=_remaining()
	for i in range(stacks.size()):
		if before[i] > 0 and stacks[i] == 0:
			final_ranks[seat_names[i]]=left+1
			eliminations.append({"seat":i,"owner":seat_names[i],"rank":left+1,"hand_id":last.hand_id})
	if left <= 1:
		finished=true
		for i in range(stacks.size()):
			if stacks[i] > 0: final_ranks[seat_names[i]]=1; break
	else:
		for offset in range(1,stacks.size()+1):
			var candidate:int=(dealer+offset)%stacks.size()
			if stacks[candidate] > 0: dealer=candidate; break
	active_hand=null

func official_player_result(player_id:String, registered_official:bool, event_finished:bool)->Dictionary:
	if not finished or not event_finished or not registered_official or not final_ranks.has(player_id):
		return {"error":"no verified official completed player ranking"}
	return {"event_id":event_id,"owner_id":player_id,"actually_participated":true,
		"match_status":"FINISHED","review_status":"ENGINE_RANK_ONLY","final_rank":int(final_ranks[player_id]),
		"hand_count":completed_hands,"national_qualification_granted":false}


func to_snapshot() -> Dictionary:
	return {
		"schema":1,
		"event_id":event_id,
		"seat_names":seat_names.duplicate(),
		"stacks":stacks.duplicate(),
		"eliminations":eliminations.duplicate(true),
		"completed_hands":completed_hands,
		"blind_level_hands":blind_level_hands,
		"initial_sb":initial_sb,
		"initial_bb":initial_bb,
		"initial_start_stack":initial_start_stack,
		"dealer":dealer,
		"active_hand":active_hand.to_snapshot() if active_hand != null else {},
		"finished":finished,
		"final_ranks":final_ranks.duplicate(true),
		"hand_results":hand_results.duplicate(true)
	}

static func from_snapshot(snapshot: Dictionary):
	if int(snapshot.get("schema", 0)) != 1:
		return null
	var names = snapshot.get("seat_names", [])
	var start_stack := int(snapshot.get("initial_start_stack", 0))
	if typeof(names) != TYPE_ARRAY or names.size() < 2 or start_stack <= 0:
		return null
	var restored := TournamentDirector.new(str(snapshot.get("event_id", "")), names, start_stack,
		int(snapshot.get("initial_sb", 0)), int(snapshot.get("initial_bb", 0)),
		int(snapshot.get("blind_level_hands", 1)))
	if restored.event_id.is_empty():
		return null
	var raw_stacks = snapshot.get("stacks", [])
	if typeof(raw_stacks) != TYPE_ARRAY or raw_stacks.size() != names.size():
		return null
	var ints: Array[int] = []
	for value in raw_stacks: ints.append(int(value))
	restored.stacks = ints
	restored.eliminations = snapshot.get("eliminations", []).duplicate(true)
	restored.completed_hands = int(snapshot.get("completed_hands", 0))
	restored.dealer = int(snapshot.get("dealer", 0))
	restored.finished = bool(snapshot.get("finished", false))
	restored.final_ranks = snapshot.get("final_ranks", {}).duplicate(true)
	restored.hand_results = snapshot.get("hand_results", []).duplicate(true)
	var hand_snapshot = snapshot.get("active_hand", {})
	if typeof(hand_snapshot) != TYPE_DICTIONARY:
		return null
	if not hand_snapshot.is_empty():
		restored.active_hand = Hand.from_snapshot(hand_snapshot)
		if restored.active_hand == null:
			return null
	else:
		restored.active_hand = null
	if restored.dealer < 0 or restored.dealer >= restored.stacks.size():
		return null
	return restored
