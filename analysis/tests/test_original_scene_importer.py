from pathlib import Path
import importlib.util,json,pytest
ROOT=Path(__file__).parents[2]
spec=importlib.util.spec_from_file_location('import_original_scenes',ROOT/'tools/import_original_scenes.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
manifest=json.loads((ROOT/'game/data/world_manifest.json').read_text(encoding='utf8'))
def mock_pages(tmp_path):
    source=tmp_path/'source';source.mkdir()
    for region in manifest['regions']:
        content='# regional original notes\n'
        for sid in region['scene_ids']:
            content+=f"## {sid} 실제 플레이 대본\n**대사:** '내가 선택했어'\n원래 장면 정보가 있으며 선택과 실패·재대화가 존재합니다.\n"
            content+=f"### {sid} 실제 진행·조건 보완 (v4.2)\n보완된 조건과 연속 대사를 원문 순서로 보관합니다.\n"
        (source/f"15_{region['id']}.md").write_text(content,encoding='utf8')
    return source
def test_all_original_scenes_can_be_captured_without_rewriting(tmp_path):
    source=mock_pages(tmp_path);dest=tmp_path/'game_data';result=mod.run(source,dest,verify_remote=False)
    assert result['scene_source_captured']==88 and result['scene_game_implemented']==0 and len(list(dest.glob('??-?*.json')))==88
def test_missing_one_region_fails_without_partial_write(tmp_path):
    source=mock_pages(tmp_path);(source/'15_08.md').unlink();dest=tmp_path/'game_data'
    with pytest.raises(FileNotFoundError):mod.run(source,dest,verify_remote=False)
    assert not dest.exists()
def test_missing_scene_heading_fails_and_does_not_write(tmp_path):
    source=mock_pages(tmp_path);p=source/'15_04.md';p.write_text(p.read_text(encoding='utf8').replace('## 04-M05','## not-a-scene'),encoding='utf8');dest=tmp_path/'game_data'
    with pytest.raises(ValueError,match='wrong order'):mod.run(source,dest,verify_remote=False)
    assert not dest.exists()
def test_out_of_order_duplicate_heading_fails(tmp_path):
    source=mock_pages(tmp_path);p=source/'15_03.md';p.write_text(p.read_text(encoding='utf8')+'\n## 03-M02 대본 재등장\n'+('more content'*12),encoding='utf8')
    with pytest.raises(ValueError,match='reappears after another ID'):mod.run(source,tmp_path/'game_data',verify_remote=False)
def test_same_scene_supplementary_sections_preserved(tmp_path):
    data=mod.extract_sections('## 01-M01 첫 대사\n오래된 장면입니다. 새봄동 생활을 여기서 시작해요.\n### 01-M01 보완\n재방문할 때의 다른 대사 내용입니다. 이 장면은 원고를 절대 삭제하면 안 됩니다. 원문의 다른 고유한 행동도 모두 유지합니다.\n## 01-M02 다른 장소\n그다음은 새로운 게임 플레이 정보가 있습니다. 원본 대사를 변경하지 않으며 이동과 선택의 연속성을 보존합니다. 이 장면의 플레이어 조작과 결과를 서로 다르게 적어 놓았습니다.\n',['01-M01','01-M02'],'01')
    assert '재방문할 때의 다른 대사' in data['01-M01'] and '01-M02' not in data['01-M01']
