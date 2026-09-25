from pathlib import Path
import collections,json
ROOT=Path(__file__).resolve().parents[2];GRAPH=json.loads((ROOT/'game/data/traversal_graph_dev.json').read_text(encoding='utf8'))
def test_eight_regions_have_safe_free_non_tower_logical_paths():
    assert len(GRAPH['regions'])==8
    for region in GRAPH['regions']:
        found={region['entry_anchor']};todo=collections.deque(found)
        while todo:
            now=todo.popleft()
            for edge in region['edges']:
                if edge['from']!=now or edge.get('fee')!=0 or 'TOWER' in edge.get('kind','') or edge.get('kind')=='LAST_TRAIN_ONLY': continue
                if edge['to'] not in found: found.add(edge['to']);todo.append(edge['to'])
        assert region['public_exit_anchor'] in found,region['id']
def test_station_late_night_bus_is_explicit_not_an_arbitrary_route_string():
    station=next(r for r in GRAPH['regions'] if r['id']=='05')
    assert {e['to']:e['choices'] for e in station['edges'] if e['from']=='E3' and e['kind'] in ('LAST_TRAIN_ONLY','FREE_NIGHT_BUS')}=={'E4':['TAKE_LAST_TRAIN'],'E3B':['BOARD_FREE_NIGHT_BUS']}
    ride=next(e for e in station['edges'] if e['from']=='E3B' and e['to']=='E4');assert ride['choices']==['RIDE_FREE_NIGHT_BUS_TO_EVENT'] and ride['fee']==0
def test_p3_events_cover_separate_ian_broadcast_and_eunsol_without_forced_win():
    e=json.loads((ROOT/'game/data/event_catalog_dev.json').read_text(encoding='utf8'))['events'];assert len(e)==26 and len({v['event_id'] for v in e})==26
    assert {v['event_id']:v['record_owner'] for v in e if v['event_id'] in {'r01_ian_separate_local','r02_ian_river_broadcast','r06_eunsol_independent'}}=={'r01_ian_separate_local':'NPC_IAN','r02_ian_river_broadcast':'NPC_IAN','r06_eunsol_independent':'NPC_EUNSOL'}
