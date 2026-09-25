import json,sys
from pathlib import Path
import pytest
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'));import ingest_notion_bundle as INGEST;import import_original_scenes as IMPORT;sys.path.remove(str(ROOT/'tools'))
def fixture_bundle(tmp_path):
    m=json.loads((ROOT/'game/data/world_manifest.json').read_text(encoding='utf8'));pages=[];audit=[]
    for r in m['regions']:
        body='# 지역 요약과 실제 지도 - 원본 문서 전체 보존\n'
        for scene in r['scene_ids']:
            body+=f'## {scene} 실제 NPC와 이동\n'+'원래 지역 대사와 보상/실패/귀환 조건을 손실 없이 보존해야 합니다. '*4+'\n'
            body+=f'### {scene} v4.2 선택 후 재대화\n'+'이 문장은 같은 장면의 조건별 선택을 보존합니다. '*4+'\n'
        body+='# 지역 전체 편집·QA 경로\n이 문단은 마지막 장면 R02의 대사가 아닙니다.\n';raw=body.encode('utf8')
        pages.append({'id':r['id'],'source_page_id':r['source_page_id'],'source_revision':'15_v4.2','verbatim_enhanced_markdown':body,'scene_ids':r['scene_ids']})
        audit.append({'id':r['id'],'source_utf8_bytes':len(raw),'fnv32':IMPORT.fnv1a32(raw)})
    bundle=tmp_path/'bundle.json';bundle.write_text(json.dumps({'schema':INGEST.SCHEMA,'game_implementation_status':'NOT_IMPLEMENTED','regions':pages},ensure_ascii=False),encoding='utf8')
    meta=tmp_path/'remote.json';meta.write_text(json.dumps({'regions':audit}),encoding='utf8');orig=tmp_path/'manifest.json';orig.write_text(json.dumps(m,ensure_ascii=False),encoding='utf8')
    return bundle,meta,orig
def test_eight_source_capture_can_promote_only_original_flags(tmp_path,monkeypatch):
    bundle,meta,manifest=fixture_bundle(tmp_path);monkeypatch.setattr(IMPORT,'REMOTE_AUDIT',meta);monkeypatch.setattr(INGEST,'REMOTE_AUDIT',meta)
    src,dst=tmp_path/'sources',tmp_path/'game_data'/'original_scenes';report=INGEST.reconstruct(bundle,src,dst,commit_source_status=True,manifest_path=manifest)
    assert report['scene_source_captured']==88 and report['scene_game_implemented']==0 and report['source_flag_advanced_in_manifest'] is True
    assert len(list(src.glob('15_??.md')))==8 and len(list(dst.glob('??-?*.json')))==88
    m=json.loads(manifest.read_text(encoding='utf8'));assert all(s['source_import_status']=='IMPORTED' for s in m['scenes']) and all(s['game_implementation_status']=='NOT_IMPLEMENTED' for s in m['scenes'])
    last=json.loads((dst/'08-R02.json').read_text(encoding='utf8'));assert '# 지역 전체 편집·QA 경로' not in last['verbatim_source_markdown'] and '# 지역 전체 편집·QA 경로' in (src/'15_08.md').read_text(encoding='utf8')
def test_one_modified_page_rejects_entire_bundle_before_writing(tmp_path,monkeypatch):
    bundle,meta,manifest=fixture_bundle(tmp_path);monkeypatch.setattr(IMPORT,'REMOTE_AUDIT',meta);monkeypatch.setattr(INGEST,'REMOTE_AUDIT',meta)
    j=json.loads(bundle.read_text(encoding='utf8'));j['regions'][-1]['verbatim_enhanced_markdown']+='임의 변경';bundle.write_text(json.dumps(j,ensure_ascii=False),encoding='utf8');untouched=manifest.read_bytes()
    with pytest.raises(ValueError,match='fingerprint mismatch'):INGEST.reconstruct(bundle,tmp_path/'sources',tmp_path/'data'/'original_scenes',commit_source_status=True,manifest_path=manifest)
    assert not (tmp_path/'sources').exists() and not (tmp_path/'data').exists() and manifest.read_bytes()==untouched
