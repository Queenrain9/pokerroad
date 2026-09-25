import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'game/data/world_manifest.json').read_text(encoding='utf-8'))
valid={s['id'] for s in manifest['scenes']}
base={'currency':'IN_GAME_ONLY','maturity':'DEV_DEFAULT_NOT_PLAY_BALANCED','job_wage_dev':20,'early_qualifier_fee_dev':40,'initial_player_wallet_dev':80,
    'free_baseline':['MAIN_TRAVEL','MAIN_DIALOGUE','FREE_PRACTICE','SPECTATOR_ACCESS'], 'loser_consolation_wallet':0,
    'maximum_early_fee_to_job_wage_ratio_dev':2,'fees_repeated_only_on_confirmed_registration':True}
def event(eid,scene,kind,n,bb,bb_stacks,*,sanction='EXHIBITION',national_qualification=False,qualifying_places=0,owner='PLAYER',fee=0,story_result=None):
    assert scene in valid and n>=2 and bb>=1 and bb_stacks>=1
    assert qualifying_places==0 or national_qualification
    return {'event_id':eid,'scene_id':scene,'kind':kind,'seat_count_dev':n,'start_big_blind_dev':bb,
        'start_tournament_stack_dev':bb*bb_stacks,'blind_level_every_completed_hands_dev':6,
        'wallet_entry_fee_dev':fee,'wallet_and_tournament_chips_are_separate':True,
        'sanction_status':sanction,'national_qualifier':national_qualification,
        'qualifying_places_dev':qualifying_places,'record_owner':owner,
        'npc_narrative_result':story_result, 'npc_card_action_replay_status':'NOT_IMPLEMENTED' if story_result else None}
E=[
 event('r01_grandma_practice','01-M02','FREE_TRAINING',2,2,30),
 event('r01_arcade_local_record','01-M04','REGIONAL_OFFICIAL_RECORD',4,2,30,sanction='OFFICIAL',fee=0),
 event('r01_ian_separate_local','01-M04','NPC_LOCAL_EVENT',4,2,30,sanction='OFFICIAL',owner='NPC_IAN',story_result='INDEPENDENT_LOCAL_RECORD_WINNER_NOT_SCRIPTED'),
 event('r02_boat_open','02-M04','PUBLIC_MATCH',4,2,30),
 event('r02_ian_river_broadcast','02-M02','NPC_INVITATIONAL',4,2,30,owner='NPC_IAN',story_result='IAN_ADVANCES_IN_OWN_NPC_EVENT'),
 event('r03_doyun_practice','03-M04','INDIVIDUAL_MATCH',2,2,30),
 event('r04_narae_cafe_practice','04-M03','INDIVIDUAL_CAFE_MATCH',2,2,30,fee=0),
 event('r04_narae_qualifier','04-M03','REGIONAL_QUALIFIER',4,2,30,sanction='OFFICIAL',national_qualification=True,owner='NPC_NARAE',story_result='NARAE_HAS_INDEPENDENT_VALID_EVIDENCE'),
 event('r04_player_qualifier','04-M03','REGIONAL_QUALIFIER',4,2,30,sanction='OFFICIAL',national_qualification=True,qualifying_places=1,fee=40),
 event('r04_doyun_ian_invite','04-M04','NPC_INVITATIONAL',2,2,30,owner='NPC_DOYUN',story_result='DOYUN_DEFEATS_IAN'),
 event('r05_doyun_individual','05-M04','INDIVIDUAL_MATCH',2,2,30),
 event('r06_palace_public','06-M02','PUBLIC_MATCH',4,2,30),
 event('r06_eunsol_independent','06-M02','NPC_PUBLIC_EVENT',4,2,30,owner='NPC_EUNSOL',story_result='ACTUAL_INDEPENDENT_MATCH_RESULT_NOT_PRESET'),
 event('r07_market_public','07-M02','PUBLIC_MATCH',4,2,30),
 event('r07_community_match','07-M04','PUBLIC_MATCH',4,2,30),
 event('r08_doyun_wildcard','08-M05','NPC_WILDCARD',4,2,30,sanction='OFFICIAL',national_qualification=True,qualifying_places=1,owner='NPC_DOYUN',story_result='DOYUN_WINS_AUTHORIZED_INDEPENDENT_WILDCARD'),
 event('r08_national_final','08-M06','OFFICIAL_FINAL',8,2,40,sanction='OFFICIAL'),
 event('r08_ian_exhibition','08-M06','INDIVIDUAL_EXHIBITION',2,2,30),
]
for region in manifest['regions']:
    code=region['id']; E.append(event(f'r{code}_tower_summit',f'{code}-T01','OPTIONAL_TOWER_FINAL',2,2,30))
assert len(E)==26 and len({e['event_id'] for e in E})==26
catalog={'source':'Original 15 v4.2 narrative + proposed adjustable technical defaults','balance':base,'events':E,
         'not_fully_specified':'Floor-by-floor tower matches, repeated qualifier sessions and any undisclosed local rules still require full original-script import and event registration.'}
(root/'game/data/event_catalog_dev.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('event catalog generated',len(E),'canonical event identities (not the full in-game event inventory)')
