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
var hand_results: Array[Dictionary] = []

func _init(p_event_id: String, p_names: Array, start_stack: int, p_sb: int, p_bb: int, p_blind_level_hands: int = 6) -> void:
	event_id = p_event_id; initial_sb=p_sb; initial_bb=p_bb; blind_level_hands=maxi(p_blind_level_hands,1)
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
