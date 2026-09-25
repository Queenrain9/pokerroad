class_name BettingRound
extends RefCounted
## Street-level no-limit action legality, independent from UI, AI, hand dealing.
## Remaining work: complete match lifecycle/dealer positions/forced ante policy.

var stacks: Array[int] = []
var street_committed: Array[int] = []
var hand_committed: Array[int] = []
var folded: Array[bool] = []
var last_acted_bet: Array[int] = []
var pending: Array[int] = []
var current_bet: int = 0
var min_full_raise: int = 0
var big_blind: int = 0
var street_index: int = 0

func _init(starting_stacks: Array, big_blind_amount: int) -> void:
	assert(starting_stacks.size() >= 2)
	assert(big_blind_amount >= 1)
	big_blind = big_blind_amount
	min_full_raise = big_blind_amount
	for amount in starting_stacks:
		assert(typeof(amount) == TYPE_INT and amount >= 0)
		stacks.append(int(amount))
	for i in range(stacks.size()):
		street_committed.append(0); hand_committed.append(0)
		folded.append(stacks[i] == 0); last_acted_bet.append(-1)
		if stacks[i] > 0: pending.append(i)

func post_forced(seat: int, amount: int) -> bool:
	if street_index != 0 or current_bet > big_blind or not pending.has(seat) or amount < 0: return false
	var posted: int = mini(stacks[seat], amount)
	stacks[seat] -= posted; street_committed[seat] += posted; hand_committed[seat] += posted
	current_bet = maxi(current_bet, street_committed[seat])
	if stacks[seat] == 0: pending.erase(seat)
	return true

func _can_raise(seat: int) -> bool:
	if not pending.has(seat) or folded[seat] or stacks[seat] <= current_bet - street_committed[seat]: return false
	var opponent_can_respond := false
	for other in range(stacks.size()):
		if other != seat and not folded[other] and stacks[other] > 0:
			opponent_can_respond = true; break
	if not opponent_can_respond: return false
	if last_acted_bet[seat] < 0: return true
	return current_bet - last_acted_bet[seat] >= min_full_raise

func legal_actions(seat: int) -> Dictionary:
	if not pending.has(seat) or folded[seat] or stacks[seat] <= 0: return {"error":"not this seat's turn"}
	var to_call: int = maxi(0, current_bet - street_committed[seat])
	var cap: int = street_committed[seat] + stacks[seat]
	var minimum: int = big_blind if current_bet < big_blind else current_bet + min_full_raise
	return {"can_fold":true,"can_check":to_call==0,"can_call":to_call>0,
		"to_call":mini(to_call,stacks[seat]),"can_raise":_can_raise(seat),
		"min_total_bet":mini(minimum,cap),"max_total_bet":cap,
		"all_in_is_short_raise":_can_raise(seat) and cap < minimum and cap > current_bet}

func act(seat: int, choice: String, new_total: int = -1) -> bool:
	var options := legal_actions(seat)
	if options.has("error"): return false
	var to_call: int = maxi(0, current_bet - street_committed[seat])
	var spend: int = 0
	match choice:
		"fold": folded[seat] = true
		"check":
			if to_call != 0: return false
		"call":
			if to_call == 0: return false
			spend = mini(to_call, stacks[seat])
		"raise":
			if not options.get("can_raise", false): return false
			var cap: int = street_committed[seat] + stacks[seat]
			if new_total <= current_bet or new_total > cap: return false
			var min_total: int = big_blind if current_bet < big_blind else current_bet + min_full_raise
			if new_total < min_total and new_total != cap: return false
			spend = new_total - street_committed[seat]
		_: return false
	stacks[seat] -= spend; street_committed[seat] += spend; hand_committed[seat] += spend
	pending.erase(seat); last_acted_bet[seat] = current_bet
	if choice == "raise":
		var before_raise: int = current_bet
		var increment: int = new_total - before_raise
		var is_full: bool = new_total >= big_blind if before_raise < big_blind else increment >= min_full_raise
		current_bet = new_total; last_acted_bet[seat] = new_total
		if is_full:
			min_full_raise = big_blind if before_raise < big_blind else increment
		for other in range(stacks.size()):
			if other != seat and not folded[other] and stacks[other] > 0 and street_committed[other] < current_bet and not pending.has(other):
				pending.append(other)
	if stacks[seat] == 0: pending.erase(seat)
	if active_players() <= 1: pending.clear()
	return true

func skip_uncontested_check() -> bool:
	if pending.size() != 1: return false
	var seat: int = pending[0]
	if folded[seat] or stacks[seat] <= 0 or current_bet > street_committed[seat]: return false
	for other in range(stacks.size()):
		if other != seat and not folded[other] and stacks[other] > 0: return false
	pending.erase(seat); last_acted_bet[seat] = current_bet
	return true

func active_players() -> int:
	var count := 0
	for seat in range(stacks.size()):
		if not folded[seat]: count += 1
	return count

func is_street_over() -> bool:
	return pending.is_empty()

func begin_next_street() -> bool:
	if not is_street_over() or active_players() <= 1 or street_index >= 3: return false
	street_index += 1; current_bet = 0; min_full_raise = big_blind; pending.clear()
	for seat in range(stacks.size()):
		street_committed[seat] = 0; last_acted_bet[seat] = -1
		if not folded[seat] and stacks[seat] > 0: pending.append(seat)
	return true


func to_snapshot() -> Dictionary:
	return {
		"schema":1,
		"stacks":stacks.duplicate(),
		"street_committed":street_committed.duplicate(),
		"hand_committed":hand_committed.duplicate(),
		"folded":folded.duplicate(),
		"last_acted_bet":last_acted_bet.duplicate(),
		"pending":pending.duplicate(),
		"current_bet":current_bet,
		"min_full_raise":min_full_raise,
		"big_blind":big_blind,
		"street_index":street_index
	}

static func from_snapshot(snapshot: Dictionary):
	if int(snapshot.get("schema", 0)) != 1:
		return null
	var raw_stacks = snapshot.get("stacks", [])
	if typeof(raw_stacks) != TYPE_ARRAY or raw_stacks.size() < 2:
		return null
	var bb := int(snapshot.get("big_blind", 0))
	if bb < 1:
		return null
	var restored := BettingRound.new(raw_stacks, bb)
	var size := raw_stacks.size()
	for key in ["street_committed","hand_committed","folded","last_acted_bet"]:
		var value = snapshot.get(key, [])
		if typeof(value) != TYPE_ARRAY or value.size() != size:
			return null
	var raw_pending = snapshot.get("pending", [])
	if typeof(raw_pending) != TYPE_ARRAY:
		return null
	var ints: Array[int] = []
	for value in raw_stacks: ints.append(int(value))
	restored.stacks = ints
	ints = []
	for value in snapshot.street_committed: ints.append(int(value))
	restored.street_committed = ints
	ints = []
	for value in snapshot.hand_committed: ints.append(int(value))
	restored.hand_committed = ints
	var bools: Array[bool] = []
	for value in snapshot.folded: bools.append(bool(value))
	restored.folded = bools
	ints = []
	for value in snapshot.last_acted_bet: ints.append(int(value))
	restored.last_acted_bet = ints
	ints = []
	for value in raw_pending:
		var seat := int(value)
		if seat < 0 or seat >= size:
			return null
		ints.append(seat)
	restored.pending = ints
	restored.current_bet = int(snapshot.get("current_bet", 0))
	restored.min_full_raise = int(snapshot.get("min_full_raise", bb))
	restored.street_index = int(snapshot.get("street_index", 0))
	if restored.current_bet < 0 or restored.min_full_raise < 1 or restored.street_index < 0 or restored.street_index > 3:
		return null
	return restored
