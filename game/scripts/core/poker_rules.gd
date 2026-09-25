class_name PokerRules
extends RefCounted
const SUITS = "shdc"
const RANKS = "23456789TJQKA"

static func full_deck() -> Array[String]:
	var deck: Array[String] = []
	for rank in RANKS:
		for suit in SUITS:
			deck.append(rank + suit)
	return deck

static func rank_value(card: String) -> int:
	if card.length() != 2 or not SUITS.contains(card[1]) or not RANKS.contains(card[0]):
		return -1
	return RANKS.find(card[0]) + 2

static func _encoded(category: int, kickers: Array[int]) -> int:
	var value := category
	for index in range(5):
		value = value * 15 + (kickers[index] if index < kickers.size() else 0)
	return value

static func score_five(cards: Array) -> int:
	if cards.size() != 5: return -1
	var seen := {}
	var ranks: Array[int] = []
	var suits: Array[String] = []
	var counts := {}
	for card in cards:
		var rank := rank_value(card)
		if rank < 0 or seen.has(card): return -1
		seen[card] = true
		ranks.append(rank); suits.append(card[1]); counts[rank] = counts.get(rank, 0) + 1
	ranks.sort(); ranks.reverse()
	var distinct := counts.keys(); distinct.sort(); distinct.reverse()
	var straight_high := 0
	if distinct.size() == 5:
		if distinct[0] - distinct[4] == 4: straight_high = distinct[0]
		elif distinct == [14, 5, 4, 3, 2]: straight_high = 5
	var is_flush := true
	for suit in suits:
		if suit != suits[0]: is_flush = false; break
	if is_flush and straight_high > 0: return _encoded(8, [straight_high])
	var fours: Array[int] = []; var triples: Array[int] = []; var pairs: Array[int] = []; var singles: Array[int] = []
	for rank in distinct:
		match counts[rank]:
			4: fours.append(rank)
			3: triples.append(rank)
			2: pairs.append(rank)
			1: singles.append(rank)
	if not fours.is_empty(): return _encoded(7, [fours[0], singles[0]])
	if not triples.is_empty() and not pairs.is_empty(): return _encoded(6, [triples[0], pairs[0]])
	if is_flush: return _encoded(5, ranks)
	if straight_high > 0: return _encoded(4, [straight_high])
	if not triples.is_empty(): return _encoded(3, [triples[0], singles[0], singles[1]])
	if pairs.size() == 2: return _encoded(2, [pairs[0], pairs[1], singles[0]])
	if pairs.size() == 1: return _encoded(1, [pairs[0], singles[0], singles[1], singles[2]])
	return _encoded(0, ranks)

static func best_score(cards: Array) -> int:
	if cards.size() < 5 or cards.size() > 7: return -1
	var seen := {}
	for card in cards:
		if rank_value(card) < 0 or seen.has(card): return -1
		seen[card] = true
	var best := -1
	for a in range(cards.size() - 4):
		for b in range(a + 1, cards.size() - 3):
			for c in range(b + 1, cards.size() - 2):
				for d in range(c + 1, cards.size() - 1):
					for e in range(d + 1, cards.size()):
						best = maxi(best, score_five([cards[a], cards[b], cards[c], cards[d], cards[e]]))
	return best

static func evaluate_pots(contributions: Array, live: Array, hands: Array, board: Array, dealer_index: int = -1) -> Dictionary:
	var n := contributions.size()
	if n < 2 or live.size() != n or hands.size() != n or board.size() != 5: return {"error":"invalid dimensions"}
	var levels: Array[int] = []; var live_count := 0
	for i in range(n):
		if contributions[i] < 0: return {"error":"negative contribution"}
		if live[i]: live_count += 1
		if contributions[i] > 0 and not levels.has(contributions[i]): levels.append(contributions[i])
	if live_count < 1: return {"error":"no live seat"}
	var known_cards := {}
	for card in board:
		if rank_value(card) < 0 or known_cards.has(card): return {"error":"invalid or duplicate physical card"}
		known_cards[card] = true
	for hand in hands:
		for card in hand:
			if rank_value(card) < 0 or known_cards.has(card): return {"error":"invalid or duplicate physical card"}
			known_cards[card] = true
	levels.sort()
	var payouts: Array[int] = []; var refunds: Array[int] = []
	payouts.resize(n); refunds.resize(n); payouts.fill(0); refunds.fill(0)
	var breakdown := []; var prior := 0
	for level in levels:
		var contributors: Array[int] = []; var eligible: Array[int] = []
		for seat in range(n):
			if contributions[seat] >= level:
				contributors.append(seat)
				if live[seat]: eligible.append(seat)
		var amount: int = (level-prior)*contributors.size(); prior=level
		if contributors.size() == 1:
			refunds[contributors[0]] += amount
			breakdown.append({"amount":amount,"refund":contributors[0]})
			continue
		if eligible.is_empty(): return {"error":"orphan pot: no eligible player"}
		var winners: Array[int] = []
		if eligible.size() == 1: winners = eligible.duplicate()
		else:
			var highest := -1
			for seat in eligible:
				if hands[seat].size() != 2: return {"error":"missing live hole cards"}
				var seven: Array[String] = []; seven.append_array(hands[seat]); seven.append_array(board)
				var score := best_score(seven)
				if score < 0: return {"error":"invalid or duplicate card"}
				if score > highest: highest=score; winners=[seat]
				elif score == highest: winners.append(seat)
		var share: int = amount / winners.size(); var remainder: int = amount % winners.size()
		for seat in winners: payouts[seat] += share
		if remainder > 0:
			var first: int = posmod(dealer_index + 1, n)
			for shift in range(n):
				var seat: int = (first + shift) % n
				if winners.has(seat):
					payouts[seat] += 1; remainder -= 1
					if remainder == 0: break
		breakdown.append({"amount":amount,"eligible":eligible,"winners":winners})
	var distributed := 0; var contributed := 0
	for seat in range(n):
		distributed += payouts[seat] + refunds[seat]; contributed += contributions[seat]
	if distributed != contributed: return {"error":"chip conservation failure"}
	return {"payouts":payouts,"refunds":refunds,"pots":breakdown}
