class_name PokerAI
extends RefCounted

const ALLOWED_CONTEXT = [
	"own_hole_cards", "public_board", "public_bets", "public_stacks", "seat_position",
	"blind_level", "prior_public_actions", "legal_actions", "strength_hint"
]
const FORBIDDEN_CONTEXT = [
	"opponent_hole_cards", "future_deck_order", "hidden_rng_state_of_others",
	"scripted_player_choice", "future_story_result"
]

static func validate_context(context: Dictionary) -> bool:
	for key in FORBIDDEN_CONTEXT:
		if context.has(key):
			return false
	for key in context.keys():
		if not ALLOWED_CONTEXT.has(str(key)):
			return false
	return true

static func choose_action(legal: Dictionary, context: Dictionary, profile: String, seed: int) -> Dictionary:
	if legal.has("error") or not validate_context(context):
		return {"error":"invalid or omniscient AI context"}
	if not ["BEGINNER","BALANCED","STRONG"].has(profile):
		return {"error":"unknown AI profile"}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var strength: float = clampf(float(context.get("strength_hint", 0.5)), 0.0, 1.0)
	var can_raise: bool = legal.get("can_raise", false)
	var can_call: bool = legal.get("can_call", false)
	var can_check: bool = legal.get("can_check", false)
	var to_call: int = int(legal.get("to_call", 0))
	var max_total: int = int(legal.get("max_total_bet", 0))
	var min_total: int = int(legal.get("min_total_bet", 0))
	var aggression := {"BEGINNER":0.30,"BALANCED":0.50,"STRONG":0.58}[profile]
	var mistake := {"BEGINNER":0.22,"BALANCED":0.08,"STRONG":0.02}[profile]
	var roll := rng.randf()

	# Legal-action-first baseline. Skill tuning may change thresholds, never legality.
	if can_check and (strength < 0.58 or not can_raise):
		if can_raise and roll < aggression * maxf(strength - 0.45, 0.0):
			return {"choice":"raise","total_bet":_raise_target(min_total,max_total,strength)}
		return {"choice":"check","total_bet":-1}
	if can_call:
		if can_raise and strength >= 0.72 and roll < aggression:
			return {"choice":"raise","total_bet":_raise_target(min_total,max_total,strength)}
		var fold_threshold := 0.20 + minf(float(to_call) / maxf(float(max_total), 1.0), 0.35)
		if strength + (rng.randf() * mistake) < fold_threshold:
			return {"choice":"fold","total_bet":-1}
		return {"choice":"call","total_bet":-1}
	if can_raise:
		return {"choice":"raise","total_bet":_raise_target(min_total,max_total,strength)}
	if can_check:
		return {"choice":"check","total_bet":-1}
	return {"choice":"fold","total_bet":-1}

static func _raise_target(min_total: int, max_total: int, strength: float) -> int:
	if max_total <= min_total:
		return max_total
	var span := max_total - min_total
	return mini(max_total, min_total + int(round(span * clampf((strength - 0.5) * 0.5, 0.0, 0.5))))
