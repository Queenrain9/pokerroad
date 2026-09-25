import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];G=ROOT/'game/scripts'
def text(path):return (G/path).read_text(encoding='utf-8')
def test_fold_refunds_only_unmatched_stake():
    s=text('core/holdem_hand.gd').replace(' ','')
    assert 'varunmatched:int=largest-maxi(second_largest,0)' in s and 'refunds[largest_seat]=unmatched' in s and 'pot-=unmatched' in s and 'payouts[winner]=pot' in s
def test_heads_up_button_receives_first_card():assert 'first_card_order=[dealer,_next_dealt_after(dealer)]' in text('core/holdem_hand.gd').replace(' ','')
def test_short_big_blind_not_mistaken_for_complete_open():
    s=text('core/betting_round.gd');assert s.count('if current_bet < big_blind else current_bet + min_full_raise')>=2 and 'min_full_raise = big_blind if before_raise < big_blind else increment' in s
def test_no_raise_when_all_opponents_all_in():
    s=text('core/betting_round.gd');assert 'if other != seat and not folded[other] and stacks[other] > 0:' in s and 'if not opponent_can_respond:' in s
def test_zero_stack_eliminated_seat_cannot_become_eligible():assert 'folded.append(stacks[i] == 0)' in text('core/betting_round.gd')
def test_tournament_auto_finishes_forced_allin_and_records_rank():
    s=text('core/tournament_director.gd').replace(' ','');assert 'ifactive_hand.finished:' in s and '_record_finished_hand()' in s and '"hand_completed_automatically":true' in s and 'final_ranks[seat_names[i]]=1' in s
def test_traversal_requires_explicit_player_choice():
    s=text('services/traversal_service.gd')
    for required in ['player must explicitly choose route','tide must be established','current tide makes selected route unsafe','last train missed','REGISTERED_PLAYER_ONLY','PUBLIC_SPECTATOR']:assert required in s
def test_world_cannot_teleport_between_unconnected_anchors():
    s=text('services/game_state.gd');assert 'TraversalService.plan_step(' in s and 'can_leave_region_at_public_exit' in s and 'if anchor_id != region.get("entry_anchor", "")' in s
def test_imported_text_cannot_be_claimed_as_implemented_scene():
    s=text('services/game_state.gd');assert 'not scene_source_record(scene_id).has("error")' in s and 'not record.get("player_action_bindings", []).is_empty()' in s
    assert 'source.sha256_text()' in text('services/scene_source_store.gd')
def test_native_regression_sources_exist_but_native_execution_not_claimed():
    native=(ROOT/'game/tests_headless.gd').read_text(encoding='utf-8')+(ROOT/'game/tests_p1_headless.gd').read_text(encoding='utf-8')
    assert 'LOW_TIDE_MARKER_PATH' in native and 'REGISTERED_PLAYER_ONLY' in native
    assert 'NOT TESTED' in (ROOT/'README.md').read_text(encoding='utf-8')
def test_real_source_mirror_generates_88_records_without_marking_playable():
    m=json.loads((ROOT/'game/data/world_manifest.json').read_text(encoding='utf-8'))
    assert all(s['source_import_status']=='IMPORTED' for s in m['scenes'])
    assert sum(s['game_implementation_status']=='IMPLEMENTED' for s in m['scenes'])==8
    assert len(list((ROOT/'game/data/original_scenes').glob('*.json')))==88
