import json
from pathlib import Path

TARGET=Path(__file__).resolve().parents[1]/'game'/'data'
REGIONS=[
 ('새봄동',7,'3e5fc392d5b481058eabc72ff9412b5d','복례', [('P0','아파트 앞 골목'),('P1','슈퍼 앞 평상'),('P2','문방구·분식집'),('P3','오락실 예선'),('P4','새봄 카지노 타워'),('P5','강변행 버스')]),
 ('한강',6,'3e5fc392d5b481e585c6c3e597640b18','윤하루',[('K0','강변 버스 정류장'),('K1','낮 강변·자전거길'),('K2','방송 스크린'),('K3','선착장·야간 유람선'),('K4','수상 카지노 타워'),('K5','숲행 정기 버스')]),
 ('도토리들의 숲',5,'3e5fc392d5b481808a4bee1b4c7bd976','솔개',[('F0','뿌리 시장'),('F1','보관고·뿌리 통로'),('F2','승강 수레·외부 계단'),('F3','상부 마을'),('F4','시범전 전망대'),('F5','거목 내부 카지노 타워'),('F6','항구행 정기 교통')]),
 ('갈매기항',6,'3e5fc392d5b4814aafcdf6bdcc64eab7','박조류',[('H0','항구 철도 출구'),('H1','어시장·조수표'),('H2','안전 갯벌 길'),('H3','등대 전망대'),('H4','구조선 연락부두'),('H5','카페·공식 예선'),('H6','NPC 초청전 경기장'),('H7','해상 카지노 타워'),('H8','역행 정기 철도')]),
 ('마지막 역',5,'3e5fc392d5b481cb8387c5e88f38a391','차유경',[('E0','지상 광장'),('E1','지하 상가'),('E2','선수 기록대'),('E3','환승 플랫폼·시간표'),('E3B','무료 야간 버스'),('E4','공개 심야 경기장'),('E5','지하 카지노 타워'),('E6','궁궐행 정기 전철')]),
 ('달 아래 궁궐',5,'3e5fc392d5b48122842cea65f35245e6','월인',[('G0','전철 종점'),('G1','시장·장인 골목'),('G2','성문·접수대'),('G3','낮 경연장·연못'),('G4','밤 가면 연회·별채'),('G5','누각 카지노 타워'),('G6','장터행 정기 행렬')]),
 ('잠들지 않는 장터',6,'3e5fc392d5b481a5bea8c48d4c2ee0cb','봉희',[('N0','철도 하차'),('N1','노점 골목'),('N2','무료 카드판'),('N3','공연·등불'),('N4','임시 전광판'),('N5','주민 경기·자격 키오스크'),('N6','축제 카지노 타워'),('N7','시티행 정기선')]),
 ('센트럴시티',8,'3e5fc392d5b48187bdf3e91b84c28713','서지완',[('C0','도시 지하철'),('C1','쇼핑몰·공원'),('C2','정식 본선 컨벤션'),('C3','선수 등록·공용 관람'),('C4','특정 중계 회차'),('C5','NPC 와일드카드 경기장'),('C6','이안 별도 공개전'),('C7','그랜드 카지노 타워'),('C8','재방문 터미널')])
]
regions=[]; scenes=[]; main_ids=[]
for index,(name,num_main,page,boss,anchors) in enumerate(REGIONS,1):
    prefix=f'{index:02}'
    ids=[f'{prefix}-M{i:02}' for i in range(1,num_main+1)]+[f'{prefix}-S01',f'{prefix}-S02',f'{prefix}-T01',f'{prefix}-R01',f'{prefix}-R02']
    regions.append({'id':prefix,'name':name,'boss':boss,'source_page_id':page,'scene_ids':ids,'anchors':[{'id':a,'description':desc,'world_coordinates':None,'visual_status':'NOT_DESIGNED'} for a,desc in anchors], 'next_region':f'{index+1:02}' if index<8 else None})
    for scene_id in ids:
        typ={'M':'MAIN','S':'SIDE','T':'TOWER_ROUTE','R':'REVISIT'}[scene_id[3]]
        scenes.append({'id':scene_id,'region_id':prefix,'kind':typ,'source_page_id':page,'source_revision':'v4.2', 'original_dialogue':None, 'source_import_status':'NOT_IMPORTED', 'game_implementation_status':'NOT_IMPLEMENTED', 'qa_status':'NOT_RUN', 'player_action_bindings':[], 'npc_independent_event_ids':[], 'location_anchor_id':None})
        if typ=='MAIN':main_ids.append(scene_id)
for i,scene_id in enumerate(main_ids):
    next_scene=main_ids[i+1] if i+1<len(main_ids) else None
    next(s for s in scenes if s['id']==scene_id)['next_main_scene_id']=next_scene
manifest={'schema_version':1,'source_project':'포커로드 — 여덟 개의 탑','source_note':'Only exact scene IDs and logical map anchors. Original dialogue intentionally NOT imported; no scene is claimed playable.','regions':regions,'scenes':scenes,'first_main_scene':'01-M01','last_main_scene':'08-M08'}
assert len(regions)==8 and len(scenes)==88 and len(main_ids)==48 and len(set(s['id'] for s in scenes))==88
TARGET.mkdir(parents=True,exist_ok=True)
(TARGET/'world_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('manifest generated: 8 regions / 88 scene IDs / 48 mains / original dialogues NOT imported')
