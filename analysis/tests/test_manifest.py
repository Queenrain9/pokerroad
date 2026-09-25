import json
from pathlib import Path
ROOT=Path(__file__).parents[2]
M=json.loads((ROOT/'game/data/world_manifest.json').read_text(encoding='utf-8'))
def test_exact_unique_88_with_region_counts():
    assert len(M['regions'])==8 and len(M['scenes'])==88
    ids=[r['id'] for r in M['scenes']];assert len(set(ids))==88
    assert [len(r['scene_ids']) for r in M['regions']]==[12,11,10,11,10,10,11,13]
    assert [sum(s['kind']==k for s in M['scenes']) for k in ['MAIN','SIDE','TOWER_ROUTE','REVISIT']]==[48,16,8,16]
def test_source_anchors_are_real_region_logic_not_made_up_coordinates():
    assert all(len(r['anchors'])>=6 for r in M['regions'])
    assert all(a['world_coordinates'] is None for r in M['regions'] for a in r['anchors'])
    assert len(set(a['id'] for r in M['regions'] for a in r['anchors']))==sum(len(r['anchors']) for r in M['regions'])
def test_original_source_and_first_sixteen_playable_status_are_distinct():
    assert all(s['original_dialogue'] is None for s in M['scenes'])
    assert all(s['source_import_status']=='IMPORTED' for s in M['scenes'])
    implemented={s['id'] for s in M['scenes'] if s['game_implementation_status']=='IMPLEMENTED'}
    assert implemented=={'01-M01','01-M02','01-M03','01-M04','01-M05','01-M06','01-M07','02-M01','02-M02','02-M03','02-M04','02-M05','02-M06','03-M01','03-M02','03-M03'}
    assert all(s['qa_status']=='PASS' for s in M['scenes'] if s['id'] in implemented)
    assert all(s['qa_status']=='NOT_RUN' for s in M['scenes'] if s['id'] not in implemented)
    assert len(list((ROOT/'game/data/original_scenes').glob('??-?*.json')))==88
def test_main_order_through_all_eight_regions_and_end():
    mains=[s for s in M['scenes'] if s['kind']=='MAIN'];assert len(mains)==48 and mains[0]['id']=='01-M01' and mains[-1]['id']=='08-M08'
    for a,b in zip(mains,mains[1:]):assert a['next_main_scene_id']==b['id']
    assert mains[-1]['next_main_scene_id'] is None
def test_all_optional_routes_have_no_main_cursor_side_effects():
    for s in M['scenes']:
        if s['kind']!='MAIN':assert 'next_main_scene_id' not in s
