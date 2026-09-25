import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'game/data/world_manifest.json'
OUTPUT=ROOT/'game/data/traversal_graph_dev.json'
def generate():
    data=json.loads(MANIFEST.read_text(encoding='utf8')); regions=[]
    for r in data['regions']:
        ids=[x['id'] for x in r['anchors']]
        tower=next(x['id'] for x in r['anchors'] if '카지노 타워' in x['description'])
        primary=[a for a in ids if a!=tower and a!='E3B']; edges=[]
        for a,b in zip(primary,primary[1:]):
            edges.append({'from':a,'to':b,'kind':'WALK_OR_ORIGINAL_TRANSIT','fee':0,'requires_player_route_choice':False})
            edges.append({'from':b,'to':a,'kind':'RETURN','fee':0,'requires_player_route_choice':False})
        idx=ids.index(tower); before=ids[idx-1]
        edges.extend([{'from':before,'to':tower,'kind':'OPTIONAL_TOWER_ENTRY','fee':0,'requires_player_route_choice':True},
                      {'from':tower,'to':before,'kind':'OPTIONAL_TOWER_EXIT','fee':0,'requires_player_route_choice':False}])
        if r['id']=='03':
            for edge in edges:
                if edge['from']=='F2' and edge['to']=='F3':
                    edge.update(kind='VERTICAL_RIDE_OR_STAIRS',requires_player_route_choice=True,choices=['WORK_LIFT','EXTERNAL_STAIRS'])
        if r['id']=='04':
            for edge in edges:
                if edge['from']=='H1' and edge['to']=='H2':
                    edge.update(kind='TIDE_ROUTE',requires_player_route_choice=True,choices=['LOW_TIDE_MARKER_PATH','HIGH_TIDE_SAFE_PATH'])
        if r['id']=='05':
            edges.extend([
                {'from':'E3','to':'E3B','kind':'FREE_NIGHT_BUS','fee':0,'requires_player_route_choice':True,'choices':['BOARD_FREE_NIGHT_BUS']},
                {'from':'E3B','to':'E4','kind':'FREE_NIGHT_BUS','fee':0,'requires_player_route_choice':True,'choices':['RIDE_FREE_NIGHT_BUS_TO_EVENT']},
                {'from':'E4','to':'E3B','kind':'RETURN_BY_FREE_NIGHT_BUS','fee':0,'requires_player_route_choice':False}])
            for e in edges:
                if e['from']=='E3' and e['to']=='E4':
                    e.update(kind='LAST_TRAIN_ONLY',requires_player_route_choice=True,requires_last_train_available=True,choices=['TAKE_LAST_TRAIN'])
        if r['id']=='08':
            for edge in edges:
                if edge['from']=='C2' and edge['to']=='C3':
                    edge.update(kind='PUBLIC_OR_APPROVED_PLAYER_ENTRY',choices=['PUBLIC_SPECTATOR','REGISTERED_PLAYER_ONLY'],requires_player_route_choice=True)
        regions.append({'id':r['id'],'name':r['name'],'entry_anchor':ids[0],'public_exit_anchor':primary[-1],
                        'optional_tower_anchor':tower,'anchors':ids,'edges':edges,'full_spatial_map_status':'NOT_IMPLEMENTED',
                        'note':'Logical routes only. Original scenes and physical movement still NOT_IMPLEMENTED.'})
    result={'schema_version':1,'all_8_regions_required':True,'travel_fee':0,'scene_navigation_is_not_world_exploration':True,'regions':regions}
    OUTPUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8'); return result
if __name__=='__main__':
    result=generate(); print('Generated safe logical topology for',len(result['regions']),'regions')
