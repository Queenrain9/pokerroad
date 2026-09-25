class_name Qualification
extends RefCounted
## Official qualification and seat registration are distinct operations.

static func qualify_from_result(evidence: Dictionary, rules: Dictionary) -> String:
	if evidence.get("event_id", "") != rules.get("event_id", ""):
		return "NO"
	if evidence.get("owner_id", "") != rules.get("owner_id", ""):
		return "NO"
	if rules.get("sanction_status", "") != "OFFICIAL":
		return "NO"
	if not rules.get("national_qualifier", false):
		return "NO"
	if not evidence.get("actually_participated", false):
		return "NO"
	if evidence.get("review_status", "") == "ENGINE_RANK_ONLY":
		return "PENDING" if evidence.get("match_status", "") == "FINISHED" else "NO"
	if evidence.get("review_status", "") == "REVIEW_PENDING":
		return "PENDING"
	if evidence.get("review_status", "") != "VERIFIED" or evidence.get("match_status", "") != "FINISHED":
		return "NO"
	var rank: int = evidence.get("final_rank", 0)
	var cutoff: int = rules.get("qualifying_rank_cutoff", 0)
	if cutoff <= 0 or rank <= 0:
		return "NO"
	return "YES" if rank <= cutoff else "NO"

static func official_registration_allowed(qualified: String, intent: String, window_open: bool, remaining_capacity: int) -> bool:
	return qualified == "YES" and intent == "OFFICIAL" and window_open and remaining_capacity > 0
