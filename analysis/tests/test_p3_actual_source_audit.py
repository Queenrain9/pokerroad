import json,importlib.util
from pathlib import Path
import pytest
ROOT=Path(__file__).resolve().parents[2];TOOL=ROOT/'tools/import_original_scenes.py'
SPEC=importlib.util.spec_from_file_location('source_importer_p3',TOOL);MOD=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(MOD)
def test_remote_audit_matches_all_eight_source_page_ids_and_manifest():
    m=json.loads((ROOT/'game/data/world_manifest.json').read_text(encoding='utf8'));a=json.loads((ROOT/'docs/NOTION_SOURCE_REMOTE_AUDIT.json').read_text(encoding='utf8'))
    assert len(m['regions'])==len(a['regions'])==8 and sum(len(r['scene_ids']) for r in m['regions'])==88
    for x,y in zip(m['regions'],a['regions']):assert x['id']==y['id'] and x['source_page_id'].replace('-','')==y['source_page_id'].replace('-','')
def test_remote_identity_rejects_retyped_source():
    audit={'01':{'source_utf8_bytes':len('진짜 원문'.encode()),'fnv32':MOD.fnv1a32('진짜 원문'.encode())}}
    MOD.audit_verbatim_source('01','진짜 원문'.encode(),audit)
    with pytest.raises(ValueError,match='differ'):MOD.audit_verbatim_source('01','진짜 원무'.encode(),audit)
def test_last_revisit_does_not_absorb_regionwide_qa_appendix():
    text=('## 01-R01 방문\n'+'오래된 자료를 보존합니다. '*6+'\n'+'## 01-R02 나중 방문\n'+'복례는 또 이야기합니다. '*6+'\n'+'### 01-R02 보완\n'+'직접 재대화와 무료 버스도 여전히 가능합니다. '*4+'\n'+'# 자체 연속 테스트 경로\n원고 QA\n')
    out=MOD.extract_sections(text,['01-R01','01-R02'],'01');assert '직접 재대화' in out['01-R02'] and '자체 연속 테스트' not in out['01-R02']
def test_p3_director_cannot_claim_external_review():
    s=(ROOT/'game/scripts/core/tournament_director.gd').read_text(encoding='utf8').replace(' ','')
    assert '"review_status":"ENGINE_RANK_ONLY"' in s and '"national_qualification_granted":false' in s
def test_verified_source_is_imported_without_fabricating_playable_implementation():
    m=json.loads((ROOT/'game/data/world_manifest.json').read_text(encoding='utf8'))
    assert all(s['source_import_status']=='IMPORTED' for s in m['scenes'])
    assert sum(s['game_implementation_status']=='IMPLEMENTED' for s in m['scenes'])==32
    records=list((ROOT/'game/data/original_scenes').glob('*.json'));assert len(records)==88
    assert all(json.loads(p.read_text(encoding='utf8'))['source_import_status']=='ORIGINAL_TEXT_CAPTURED' for p in records)
def test_qualification_needs_qualifier_flag_and_external_review():
    q=(ROOT/'game/scripts/services/qualification.gd').read_text(encoding='utf8');assert 'not rules.get("national_qualifier", false)' in q and '"VERIFIED"' in q
def test_unreviewed_real_result_remains_pending():
    q=(ROOT/'game/scripts/services/qualification.gd').read_text(encoding='utf8');assert '"ENGINE_RANK_ONLY"' in q and 'return "PENDING" if evidence.get("match_status", "") == "FINISHED" else "NO"' in q
def test_unlocked_remote_region_cannot_skip_transport_route():
    s=(ROOT/'game/scripts/services/game_state.gd').read_text(encoding='utf8');assert 'absi(int(region_id) - int(current_region)) != 1' in s and 'can_leave_region_at_public_exit' in s
