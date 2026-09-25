import hashlib, json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
DATA=ROOT/'game/data'

def load(name):
    return json.loads((DATA/name).read_text(encoding='utf8'))

def test_authored_runtime_bindings_match_canonical_source_hashes():
    cat=load('scene_bindings_v1.json')
    assert cat['schema_version']==1
    assert {b['scene_id'] for b in cat['scenes']}=={'01-M01','01-M02','05-M03','08-M03'}
    for b in cat['scenes']:
        src=load(f"original_scenes/{b['scene_id']}.json")
        assert src['source_section_sha256']==b['source_section_sha256']
        assert hashlib.sha256(src['verbatim_source_markdown'].encode()).hexdigest()==b['source_section_sha256']
        assert b['physical_world_binding_status']=='NOT_IMPLEMENTED'

def test_binding_anchors_exist_and_do_not_invent_coordinates():
    manifest=load('world_manifest.json')
    regions={r['id']:r for r in manifest['regions']}
    for b in load('scene_bindings_v1.json')['scenes']:
        anchors={a['id'] for a in regions[b['region_id']]['anchors']}
        assert set(b['entry_anchors'])<=anchors
        assert all(a['world_coordinates'] is None for a in regions[b['region_id']]['anchors'])

def test_tutorial_binding_enters_canonical_free_match_and_keeps_result_separate():
    b=next(x for x in load('scene_bindings_v1.json')['scenes'] if x['scene_id']=='01-M02')
    play=next(c for c in b['interactions'][0]['choices'] if c['choice_id']=='PLAY_FREE')
    request=next(e for e in play['effects'] if e['type']=='REQUEST_EVENT')
    assert request['event_id']=='r01_grandma_practice'
    assert request['participants']==['PLAYER','NPC_BOKRYE']
    assert set(b['external_results']['r01_grandma_practice'])=={'WIN','LOSS','WITHDRAW'}

def test_cross_region_bindings_do_not_smuggle_later_story_state():
    bindings={b['scene_id']:b for b in load('scene_bindings_v1.json')['scenes']}
    assert set(bindings['05-M03']['forbidden_side_effects'])=={'NARAE_SEAT_RESTORED','DOYUN_PROXY_CANCELLED','PLAYER_Q_CHANGED'}
    assert set(bindings['08-M03']['forbidden_side_effects'])=={'NARAE_SEAT_RESTORED','DOYUN_PROXY_CANCELLED','WILDCARD_GRANTED'}
    serialized=json.dumps(bindings['08-M03']['interactions'],ensure_ascii=False)
    assert 'NARAE_SEAT_RESTORED' not in serialized and 'DOYUN_PROXY_CANCELLED' not in serialized

def test_runtime_foundation_does_not_falsely_mark_any_scene_playable():
    manifest=load('world_manifest.json')
    assert sum(s['game_implementation_status']=='IMPLEMENTED' for s in manifest['scenes'])==0
    assert len(load('scene_bindings_v1.json')['scenes'])==4

def test_runtime_scripts_exist_and_cover_world_dialogue_poker_result_loop():
    runtime=(ROOT/'game/scripts/runtime/game_runtime.gd').read_text(encoding='utf8')
    runner=(ROOT/'game/scripts/runtime/scene_runner.gd').read_text(encoding='utf8')
    world=(ROOT/'game/scripts/runtime/world_runtime.gd').read_text(encoding='utf8')
    assert 'func open_scene(' in runtime and 'func start_event(' in runtime and 'func acknowledge_result()' in runtime
    assert 'apply_external_result' in runner and 'physical scene implementation gate not satisfied' in runner
    assert 'all_region_descriptors' in world and 'travel_to_anchor' in world
