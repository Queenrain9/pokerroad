import json
from collections import deque
from pathlib import Path
D=Path(__file__).parents[2]/'game/data';M=json.loads((D/'world_manifest.json').read_text(encoding='utf8'));G=json.loads((D/'traversal_graph_dev.json').read_text(encoding='utf8'))
def path(edges,start,goal,blocked=()):
    q=deque([start]);seen={start}
    while q:
        a=q.popleft()
        if a==goal:return True
        for e in edges:
            if e['from']!=a or e['to'] in blocked or e.get('requires_last_train_available'):continue
            if e['to'] not in seen:seen.add(e['to']);q.append(e['to'])
    return False
def test_all_regions_have_safe_free_main_route_without_tower():
    assert len(G['regions'])==8
    for r in G['regions']:
        assert path(r['edges'],r['entry_anchor'],r['public_exit_anchor'],blocked={r['optional_tower_anchor']})
        assert set(r['anchors'])==set(next(x for x in M['regions'] if x['id']==r['id'])['anchors'][i]['id'] for i in range(len(r['anchors'])))
        assert all(e['fee']==0 for e in r['edges']) and all(e['to'] in r['anchors'] and e['from'] in r['anchors'] for e in r['edges'])
        assert r['full_spatial_map_status']=='NOT_IMPLEMENTED'
def test_forest_has_both_real_vertical_route_choices():
    r=next(r for r in G['regions'] if r['id']=='03');e=next(e for e in r['edges'] if e['from']=='F2' and e['to']=='F3')
    assert e['requires_player_route_choice'] and set(e['choices'])=={'WORK_LIFT','EXTERNAL_STAIRS'}
def test_port_tide_choice_and_last_train_free_bus():
    h=next(r for r in G['regions'] if r['id']=='04');e=next(e for e in h['edges'] if e['from']=='H1' and e['to']=='H2')
    assert set(e['choices'])=={'LOW_TIDE_MARKER_PATH','HIGH_TIDE_SAFE_PATH'}
    station=next(r for r in G['regions'] if r['id']=='05');assert path(station['edges'],'E3','E4')
    assert any(e['from']=='E3' and e['to']=='E3B' and e['fee']==0 for e in station['edges'])
def test_city_public_access_is_not_official_registration():
    r=next(r for r in G['regions'] if r['id']=='08');e=next(e for e in r['edges'] if e['from']=='C2' and e['to']=='C3')
    assert 'PUBLIC_SPECTATOR' in e['choices'] and 'REGISTERED_PLAYER_ONLY' in e['choices']
