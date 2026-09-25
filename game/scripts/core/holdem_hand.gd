class_name HoldemHand
extends RefCounted
const Poker = preload("res://scripts/core/poker_rules.gd")
const Betting = preload("res://scripts/core/betting_round.gd")

var hand_id: String = ""
var stacks: Array[int] = []
var starting_stacks: Array[int] = []
var dealer: int = -1
var small_blind: int = 0
var big_blind: int = 0
var street: int = 0
var board: Array[String] = []
var holes: Array = []
var deck: Array[String] = []
var round: BettingRound
var current_actor: int = -1
var finished := false
var settlement: Dictionary = {}
var history: Array[Dictionary] = []
var dealt_seats: Array[int] = []

func _init(p_stacks: Array, p_dealer: int, p_sb: int, p_bb: int, p_hand_id: String, seed: int = -1) -> void:
	for value in p_stacks:
		if typeof(value) != TYPE_INT or value < 0:
			settlement={"error":"invalid starting stack"}; finished=true; return
		stacks.append(int(value))
	starting_stacks=stacks.duplicate(); dealer=p_dealer; small_blind=p_sb; big_blind=p_bb; hand_id=p_hand_id
	if stacks.size()<2 or stacks.size()>9 or dealer<0 or dealer>=stacks.size() or small_blind<1 or big_blind<small_blind:
		settlement={"error":"invalid table configuration"}; finished=true; return
	for i in range(stacks.size()):
		if stacks[i]>0: dealt_seats.append(i)
	if dealt_seats.size()<2 or not dealt_seats.has(dealer):
		settlement={"error":"not enough live stacks or inactive dealer"}; finished=true; return
	var rng:=RandomNumberGenerator.new()
	if seed>=0: rng.seed=seed
	else: rng.randomize()
	deck=Poker.full_deck()
	for i in range(deck.size()-1,0,-1):
		var j:int=rng.randi_range(0,i); var card:String=deck[i]; deck[i]=deck[j]; deck[j]=card
	for i in range(stacks.size()): holes.append([])
	var first_card_order:Array[int]=_clockwise_dealt_after(dealer)
	if dealt_seats.size()==2: first_card_order=[dealer,_next_dealt_after(dealer)]
	for pass_index in range(2):
		for seat in first_card_order: holes[seat].append(deck.pop_back())
	round=Betting.new(stacks,big_blind)
	var sb_seat:int = dealer if dealt_seats.size()==2 else _next_dealt_after(dealer)
	var bb_seat:int=_next_dealt_after(sb_seat)
	if not round.post_forced(sb_seat,small_blind) or not round.post_forced(bb_seat,big_blind):
		settlement={"error":"invalid forced blinds"}; finished=true; return
	history.append({"type":"blind","seat":sb_seat,"amount":mini(starting_stacks[sb_seat],small_blind)})
	history.append({"type":"blind","seat":bb_seat,"amount":mini(starting_stacks[bb_seat],big_blind)})
	street=0; current_actor=_next_pending_after(bb_seat); _advance_if_ready()

func _next_dealt_after(seat:int)->int:
	for step in range(1,stacks.size()+1):
		var test:int=(seat+step)%stacks.size()
		if dealt_seats.has(test): return test
	return -1

func _clockwise_dealt_after(seat:int)->Array[int]:
	var order:Array[int]=[]; var cursor:=seat
	for i in range(dealt_seats.size()):
		cursor=_next_dealt_after(cursor); order.append(cursor)
	return order

func _next_pending_after(seat:int)->int:
	for step in range(1,stacks.size()+1):
		var test:int=(seat+step)%stacks.size()
		if round.pending.has(test): return test
	return -1

func current_options()->Dictionary:
	if finished or current_actor<0: return {"error":"not waiting for a player"}
	var legal:=round.legal_actions(current_actor)
	legal["seat"]=current_actor; legal["street"]=street; legal["hand_id"]=hand_id
	return legal

func act(seat:int, choice:String, total_bet:int=-1)->bool:
	if finished or seat!=current_actor or not round.act(seat,choice,total_bet): return false
	history.append({"type":"action","street":street,"seat":seat,"choice":choice,"total_bet":total_bet,
		"street_contribution":round.street_committed[seat],"hand_contribution":round.hand_committed[seat]})
	current_actor=_next_pending_after(seat); _advance_if_ready(); return true

func _live_count()->int:
	var remaining:=0
	for seat in dealt_seats:
		if not round.folded[seat]: remaining+=1
	return remaining

func _advance_if_ready()->void:
	if finished: return
	if _live_count()==1: _settle_last_player(); return
	while current_actor>=0 and round.skip_uncontested_check():
		history.append({"type":"uncontested_auto_check","street":street,"seat":current_actor})
		current_actor=_next_pending_after(current_actor)
	if current_actor>=0: return
	if not round.is_street_over():
		settlement={"error":"no actor although betting remains pending"}; finished=true; return
	if street==3: _settle_showdown(); return
	while street<3:
		if not round.begin_next_street():
			settlement={"error":"cannot advance betting street"}; finished=true; return
		street+=1
		if street==1: board.append_array(_deal_board(3))
		else: board.append_array(_deal_board(1))
		history.append({"type":"board","street":street,"cards":board.duplicate()})
		current_actor=_next_pending_after(dealer)
		while current_actor>=0 and round.skip_uncontested_check():
			history.append({"type":"uncontested_auto_check","street":street,"seat":current_actor})
			current_actor=_next_pending_after(current_actor)
		if current_actor>=0: return
	_settle_showdown()

func _deal_board(count:int)->Array[String]:
	deck.pop_back()
	var result:Array[String]=[]
	for i in range(count): result.append(deck.pop_back())
	return result

func _settle_last_player()->void:
	var winner:=-1
	for seat in dealt_seats:
		if not round.folded[seat]: winner=seat
	if winner<0: settlement={"error":"no surviving player"}; finished=true; return
	var pot:=0; var largest:=-1; var second_largest:=0; var largest_seat:=-1
	for seat in range(round.hand_committed.size()):
		var amount:int=round.hand_committed[seat]; pot+=amount
		if amount>largest: second_largest=largest; largest=amount; largest_seat=seat
		elif amount>second_largest: second_largest=amount
	var refunds:=_zero_payouts()
	if largest_seat>=0 and largest>second_largest:
		var unmatched:int=largest-maxi(second_largest,0); refunds[largest_seat]=unmatched; pot-=unmatched
	var payouts:=_zero_payouts(); payouts[winner]=pot
	_finish({"reason":"everyone_else_folded","payouts":payouts,"refunds":refunds,"pots":[{"amount":pot,"winners":[winner]}]})

func _zero_payouts()->Array[int]:
	var amounts:Array[int]=[]; amounts.resize(stacks.size()); amounts.fill(0); return amounts

func _settle_showdown()->void:
	var live:Array[bool]=[]
	for i in range(stacks.size()): live.append(dealt_seats.has(i) and not round.folded[i])
	var result:=Poker.evaluate_pots(round.hand_committed,live,holes,board,dealer)
	if result.has("error"): settlement=result; finished=true; return
	result["reason"]="showdown"; _finish(result)

func _finish(result:Dictionary)->void:
	var total_before:=0; var total_after:=0; var committed:=0
	for i in range(stacks.size()):
		total_before+=starting_stacks[i]; committed+=round.hand_committed[i]
		stacks[i]=round.stacks[i]+int(result.payouts[i])+int(result.refunds[i]); total_after+=stacks[i]
	if total_before!=total_after:
		settlement={"error":"table chip conservation failure","before":total_before,"after":total_after}; finished=true; return
	result["hand_id"]=hand_id; result["initial_stacks"]=starting_stacks.duplicate(); result["ending_stacks"]=stacks.duplicate()
	result["total_committed"]=committed; result["board"]=board.duplicate(); result["hole_cards"]=holes.duplicate(true)
	result["history"]=history.duplicate(true); result["finished"]=true
	settlement=result; finished=true; current_actor=-1


func to_snapshot() -> Dictionary:
	return {
		"schema":1,
		"hand_id":hand_id,
		"stacks":stacks.duplicate(),
		"starting_stacks":starting_stacks.duplicate(),
		"dealer":dealer,
		"small_blind":small_blind,
		"big_blind":big_blind,
		"street":street,
		"board":board.duplicate(),
		"holes":holes.duplicate(true),
		"deck":deck.duplicate(),
		"round":round.to_snapshot() if round != null else {},
		"current_actor":current_actor,
		"finished":finished,
		"settlement":settlement.duplicate(true),
		"history":history.duplicate(true),
		"dealt_seats":dealt_seats.duplicate()
	}

static func from_snapshot(snapshot: Dictionary):
	if int(snapshot.get("schema", 0)) != 1:
		return null
	var starting = snapshot.get("starting_stacks", [])
	if typeof(starting) != TYPE_ARRAY or starting.size() < 2:
		return null
	var normalized_start: Array[int] = []
	for value in starting:
		if not [TYPE_INT, TYPE_FLOAT].has(typeof(value)):
			return null
		var normalized := int(value)
		if normalized < 0 or float(value) != float(normalized):
			return null
		normalized_start.append(normalized)
	var restored := HoldemHand.new(normalized_start, int(snapshot.get("dealer", -1)),
		int(snapshot.get("small_blind", 0)), int(snapshot.get("big_blind", 0)),
		str(snapshot.get("hand_id", "")), 0)
	if restored.settlement.has("error"):
		return null
	var round_restored = Betting.from_snapshot(snapshot.get("round", {}))
	if round_restored == null:
		return null
	var count: int = starting.size()
	var raw_stacks = snapshot.get("stacks", [])
	var raw_holes = snapshot.get("holes", [])
	if typeof(raw_stacks) != TYPE_ARRAY or raw_stacks.size() != count or typeof(raw_holes) != TYPE_ARRAY or raw_holes.size() != count:
		return null
	var ints: Array[int] = []
	for value in raw_stacks: ints.append(int(value))
	restored.stacks = ints
	ints = []
	for value in starting: ints.append(int(value))
	restored.starting_stacks = ints
	restored.street = int(snapshot.get("street", 0))
	restored.board.clear()
	for value in snapshot.get("board", []): restored.board.append(str(value))
	restored.holes = raw_holes.duplicate(true)
	restored.deck.clear()
	for value in snapshot.get("deck", []): restored.deck.append(str(value))
	restored.round = round_restored
	restored.current_actor = int(snapshot.get("current_actor", -1))
	restored.finished = bool(snapshot.get("finished", false))
	restored.settlement = snapshot.get("settlement", {}).duplicate(true)
	restored.history.clear()
	var raw_history = snapshot.get("history", [])
	if typeof(raw_history) != TYPE_ARRAY:
		return null
	for value in raw_history:
		if typeof(value) != TYPE_DICTIONARY:
			return null
		restored.history.append(value.duplicate(true))
	ints = []
	for value in snapshot.get("dealt_seats", []): ints.append(int(value))
	restored.dealt_seats = ints
	if restored.street < 0 or restored.street > 3:
		return null
	if not restored.finished and (restored.current_actor < 0 or not restored.round.pending.has(restored.current_actor)):
		return null
	var seen := {}
	for card in restored.board:
		if Poker.rank_value(card) < 0 or seen.has(card): return null
		seen[card] = true
	for hand in restored.holes:
		for card in hand:
			if Poker.rank_value(card) < 0 or seen.has(card): return null
			seen[card] = true
	for card in restored.deck:
		if Poker.rank_value(card) < 0 or seen.has(card): return null
		seen[card] = true
	return restored
