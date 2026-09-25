class_name StoryTimeline
extends RefCounted
## Preserves the independent NPC evidence and fixed original 04→08 chronology.

static func initial_state() -> Dictionary:
	return {"phase": "PRE_04", "narae_evidence": "NONE", "narae_seat": "UNASSIGNED",
		"doyun_ian_result": "UNPLAYED", "doyun_backup": "NONE",
		"doyun_proposal": "NONE", "broadcast": "SCHEDULED",
		"wildcard_authority": "NOT_APPROVED", "doyun_wildcard": "NOT_ENTERED",
		"ian_contract": "ORIGINAL", "other_city_events": "OPEN"}

static func _npc_verified(record: Dictionary, event_id: String, owner: String, winner: String) -> bool:
	if record.get("event_id", "") != event_id or record.get("owner_id", "") != owner or not record.get("engine_verified", false):
		return false
	if winner.is_empty():
		return record.get("actually_participated", false) and record.get("qualifying_evidence_valid", false) and int(record.get("final_rank", 0)) > 0
	return record.get("actual_winner", "") == winner

static func apply_checkpoint(previous: Dictionary, scene_id: String, npc_result: Dictionary = {}) -> Dictionary:
	var s: Dictionary = previous.duplicate(true)
	match scene_id:
		"04-M03":
			if s.get("phase", "") != "PRE_04" or not _npc_verified(npc_result, "r04_narae_qualifier", "NPC_NARAE", ""):
				return {"error": "Narae's independent qualifying event not engine-verified"}
			s.narae_evidence = "VALID"
			s.narae_seat = "EARNED"
			s.phase = "NARAE_EARNED"
		"04-M04":
			if s.get("phase", "") != "NARAE_EARNED" or not _npc_verified(npc_result, "r04_doyun_ian_invite", "NPC_DOYUN", "DOYUN"):
				return {"error": "Doyun-Ian independent NPC match not verified"}
			s.doyun_ian_result = "DOYUN_WIN"
			s.phase = "DOYUN_BEATS_IAN"
		"05-M03":
			if s.get("phase", "") != "DOYUN_BEATS_IAN" or s.get("narae_evidence", "") != "VALID":
				return {"error": "sponsor standby has no valid originating evidence"}
			s.doyun_backup = "PROVISIONAL"
			s.phase = "SPONSOR_STANDBY"
		"07-M03":
			if s.get("phase", "") != "SPONSOR_STANDBY":
				return {"error": "wrong provisional roster phase"}
			s.narae_seat = "DISPUTED"
			s.phase = "NARAE_CONTESTS"
		"07-M04":
			if s.get("phase", "") != "NARAE_CONTESTS":
				return {"error": "unapproved wildcard proposal out of order"}
			s.doyun_proposal = "CONDITIONAL"
			s.ian_contract = "RENEGOTIATION_REQUESTED"
			s.phase = "PROPOSAL_ONLY"
		"08-M03":
			if s.get("phase", "") != "PROPOSAL_ONLY":
				return {"error": "target broadcast pause out of order"}
			s.broadcast = "TARGET_BROADCAST_PAUSED_BEFORE_START"
			s.phase = "TARGET_BROADCAST_PAUSED"
		"08-M04":
			if s.get("phase", "") != "TARGET_BROADCAST_PAUSED" or s.get("broadcast", "") != "TARGET_BROADCAST_PAUSED_BEFORE_START":
				return {"error": "reform cannot predate target broadcast suspension"}
			s.narae_seat = "CONFIRMED"
			s.doyun_backup = "CANCELLED"
			s.wildcard_authority = "APPROVED_WITHIN_CAPACITY"
			s.phase = "REFORM_APPROVED"
		"08-M05":
			if s.get("phase", "") != "REFORM_APPROVED" or s.get("doyun_backup", "") != "CANCELLED" or s.get("wildcard_authority", "") != "APPROVED_WITHIN_CAPACITY" or not _npc_verified(npc_result, "r08_doyun_wildcard", "NPC_DOYUN", "DOYUN"):
				return {"error": "Doyun needs authorized, separate, verified wildcard win"}
			s.doyun_wildcard = "WON_OWN_EVENT"
			s.ian_contract = "RENEGOTIATED_AT_OWN_COST"
			s.phase = "INDEPENDENT_WILDCARD_FINISHED"
		"08-M06":
			if s.get("phase", "") != "INDEPENDENT_WILDCARD_FINISHED":
				return {"error": "player finale cannot precede NPC own wildcard"}
			s.phase = "PLAYER_FINAL_SCENE"
		"08-M08":
			if s.get("phase", "") != "PLAYER_FINAL_SCENE":
				return {"error": "ending before player's real play/watch outcome"}
			s.phase = "STORY_END"
		_:
			return {"error": "not a declared NPC chronology checkpoint"}
	return s
