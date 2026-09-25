import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DATA=ROOT/'game/data'

def read(name):
    return json.loads((DATA/name).read_text(encoding='utf8'))

def test_competition_contract_keeps_result_domains_and_mainline_separate():
    c=read('competition_contract_v1.json')
    assert c['schema_version']==1
    assert c['fixed_invariants']['result_domains']==['HAND_RESULT','MATCH_RESULT','OFFICIAL_EVENT_RANK','PLAYER_Q','TOWER_CLEAR']
    assert set(c['fixed_invariants']['mainline_must_survive'])>={'LOSS','WITHDRAW','NOT_ENTERED','PLAYER_Q=PENDING','wallet=0'}
    assert c['fixed_invariants']['single_hand_never_grants_event_rank_or_q'] is True
    assert c['fixed_invariants']['npc_results_never_transfer_to_player'] is True

def test_event_lifecycle_cannot_jump_from_discovery_to_play():
    c=read('competition_contract_v1.json')['event_lifecycle']['allowed_transitions']
    assert 'IN_PROGRESS' not in c['DISCOVERED']
    assert 'REGISTERED' in c['REGISTRATION_OPEN']
    assert c['IN_PROGRESS']==['FINISHED']

def test_ai_contract_forbids_omniscience_and_keeps_tuning_provisional():
    c=read('competition_contract_v1.json')['ai_contract']
    assert {'opponent_hole_cards','future_deck_order','scripted_player_choice'}<=set(c['information_boundary']['forbidden'])
    assert c['deterministic_seed_required_for_replay'] is True
    assert c['profile_numbers_status']=='DEV_TUNING_NOT_FINAL'

def test_save_contract_requires_exact_mid_hand_state():
    c=read('runtime_save_contract_v2.json')
    assert c['schema_version']==2 and 'POKER' in c['save_modes']
    assert c['poker_fields']==['event_instance_id','event_id','tournament_snapshot']
    assert 'exact deck order' in c['interruption_rules']['POKER']
    assert 'no duplicate reward' in c['interruption_rules']['DIALOGUE']

def test_presentation_contract_crosschecks_all_eight_regions():
    c=read('presentation_contract_v1.json')
    assert set(c['region_capabilities'])=={f'{i:02}' for i in range(1,9)}
    assert 'MOVING_WORLD_PARENT' in c['region_capabilities']['02']
    assert 'MULTI_LAYER_VERTICAL_WORLD' in c['region_capabilities']['03']
    assert 'TIDE_DEPENDENT_ROUTE' in c['region_capabilities']['04']
    assert 'FREE_NIGHT_BUS' in c['region_capabilities']['05']
    assert 'SAME_WORLD_DAY_NIGHT' in c['region_capabilities']['06']
    assert 'BONUS_ACTIVITY_NOT_MAIN_GATE' in c['region_capabilities']['07']
    assert {'PUBLIC_VS_REGISTERED_ZONES','EIGHT_SEAT_FINAL'}<=set(c['region_capabilities']['08'])
    assert c['transition_graph']['POKER']==['RESULT']
    assert c['fixed_semantics']['moving_world_parent_must_not_move_card_hud'] is True
    assert c['provisional_layout_reference']['status']=='DEVICE_TEST_REQUIRED_NOT_FINAL'

def test_game_state_has_v2_session_api_without_erasing_legacy_world_save():
    s=(ROOT/'game/scripts/services/game_state.gd').read_text(encoding='utf8')
    assert 'func world_snapshot_v2()' in s
    assert 'func save_session_v2(' in s and 'func load_session_v2()' in s
    assert 'const SAVE_SCHEMA = 1' in s
    assert 'const SESSION_SAVE_PATH = "user://poker_road_save_v2.json"' in s

def test_hand_betting_and_tournament_have_snapshot_roundtrip_code():
    for path in ['core/betting_round.gd','core/holdem_hand.gd','core/tournament_director.gd']:
        s=(ROOT/'game/scripts'/path).read_text(encoding='utf8')
        assert 'func to_snapshot() -> Dictionary:' in s
        assert 'static func from_snapshot(snapshot: Dictionary)' in s

def test_ai_runtime_rejects_hidden_information_keys():
    s=(ROOT/'game/scripts/core/poker_ai.gd').read_text(encoding='utf8')
    assert 'opponent_hole_cards' in s and 'future_deck_order' in s and 'invalid or omniscient AI context' in s
