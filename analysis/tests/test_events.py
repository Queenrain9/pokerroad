import json
from pathlib import Path
D=Path(__file__).parents[2]/'game/data'
M=json.loads((D/'world_manifest.json').read_text(encoding='utf-8'))
E=json.loads((D/'event_catalog_dev.json').read_text(encoding='utf-8'))
def test_event_ids_unique_and_bound_to_original_scene():
    ids={s['id'] for s in M['scenes']};assert len(E['events'])==29;assert len({x['event_id'] for x in E['events']})==len(E['events']);assert all(e['scene_id'] in ids for e in E['events'])
def test_solo_npc_events_are_not_player_qualifiers():
    npc=[e for e in E['events'] if e['record_owner']!='PLAYER']
    assert {e['event_id'] for e in npc}=={'r01_ian_separate_local','r02_ian_river_broadcast','r02_yunharu_boat_demo','r03_doyun_showcase','r04_narae_qualifier','r04_doyun_ian_invite','r06_eunsol_independent','r08_doyun_wildcard'}
    replay={'r01_ian_separate_local','r02_ian_river_broadcast','r02_yunharu_boat_demo','r03_doyun_showcase','r04_narae_qualifier','r04_doyun_ian_invite'}
    assert all(e['npc_card_action_replay_status']=='ENGINE_REPLAY' for e in npc if e['event_id'] in replay)
    assert all(e['npc_card_action_replay_status']=='NOT_IMPLEMENTED' for e in npc if e['event_id'] not in replay)
def test_only_official_personal_qualifier_creates_player_q():
    selfq=[e for e in E['events'] if e['national_qualifier'] and e['record_owner']=='PLAYER']
    assert len(selfq)==1 and selfq[0]['event_id']=='r04_player_qualifier'
    assert not next(e for e in E['events'] if e['event_id']=='r01_arcade_local_record')['national_qualifier']
    assert not next(e for e in E['events'] if e['event_id']=='r08_national_final')['national_qualifier']
    assert all(not e['national_qualifier'] for e in E['events'] if e['kind']=='OPTIONAL_TOWER_FINAL')
def test_early_job_recovery_has_no_chore_lock():
    b=E['balance'];assert b['job_wage_dev']>0 and b['early_qualifier_fee_dev']>0
    assert (b['early_qualifier_fee_dev']+b['job_wage_dev']-1)//b['job_wage_dev']<=b['maximum_early_fee_to_job_wage_ratio_dev']
    assert b['loser_consolation_wallet']==0
def test_tournament_chips_are_separate_from_wallet():
    assert all(e['wallet_and_tournament_chips_are_separate'] for e in E['events'])
    assert next(e for e in E['events'] if e['event_id']=='r08_national_final')['seat_count_dev']==8
def test_source_04_m03_keeps_three_distinct_matches():
    e=[e for e in E['events'] if e['scene_id']=='04-M03'];assert {i['event_id'] for i in e}=={'r04_narae_cafe_practice','r04_narae_qualifier','r04_player_qualifier'}
    assert next(x for x in e if x['event_id']=='r04_narae_qualifier')['qualifying_places_dev']==0
def test_extra_npc_matches_from_the_original_script_do_not_force_player_record():
    new={e['event_id']:e for e in E['events'] if e['event_id'] in {'r01_ian_separate_local','r02_ian_river_broadcast','r06_eunsol_independent'}}
    assert len(new)==3 and all(e['record_owner'] in ('NPC_IAN','NPC_EUNSOL') for e in new.values())
    assert new['r01_ian_separate_local']['npc_card_action_replay_status']=='ENGINE_REPLAY'
    assert new['r02_ian_river_broadcast']['npc_card_action_replay_status']=='ENGINE_REPLAY'
    assert new['r06_eunsol_independent']['npc_card_action_replay_status']=='NOT_IMPLEMENTED'
    assert not any(e['national_qualifier'] for e in new.values())
