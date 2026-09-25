import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
AUDIT=json.loads((ROOT/'docs/NOTION_SOURCE_REMOTE_AUDIT.json').read_text(encoding='utf8'))
MANIFEST=json.loads((ROOT/'game/data/world_manifest.json').read_text(encoding='utf8'))

def fnv1a32(raw:bytes)->str:
    h=2166136261
    for b in raw:h=((h^b)*16777619)&0xffffffff
    return f"{h:08x}"

def test_all_eight_canonical_source_files_match_remote_fingerprints():
    for row in AUDIT['regions']:
        p=ROOT/'source/original_notion_v4_2'/f"15_{row['id']}.md"
        raw=p.read_bytes()
        assert len(raw)==row['source_utf8_bytes']
        assert fnv1a32(raw)==row['fnv32']

def test_all_88_generated_records_verify_their_own_sha256_and_filename():
    import hashlib
    files=sorted((ROOT/'game/data/original_scenes').glob('??-?*.json'))
    assert len(files)==88
    for p in files:
        d=json.loads(p.read_text(encoding='utf8'))
        assert d['scene_id']==p.stem
        assert hashlib.sha256(d['verbatim_source_markdown'].encode('utf8')).hexdigest()==d['source_section_sha256']
        assert d['source_import_status']=='ORIGINAL_TEXT_CAPTURED'

def test_import_status_and_playable_status_are_independent():
    assert len(MANIFEST['scenes'])==88
    assert all(s['source_import_status']=='IMPORTED' for s in MANIFEST['scenes'])
    implemented=[s for s in MANIFEST['scenes'] if s['game_implementation_status']=='IMPLEMENTED']
    assert len(implemented)==32 and all(s['player_action_bindings'] for s in implemented)
    assert all(s['player_action_bindings']==[] for s in MANIFEST['scenes'] if s not in implemented)

def test_verbatim_source_page_copies_equal_canonical_mirror():
    copies=ROOT/'game/data/source_pages_verbatim'
    for row in AUDIT['regions']:
        name=f"15_{row['id']}.md"
        assert (copies/name).read_bytes()==(ROOT/'source/original_notion_v4_2'/name).read_bytes()

def test_source_import_audit_reports_88_captured_and_zero_implemented():
    a=json.loads((ROOT/'game/data/source_import_audit.json').read_text(encoding='utf8'))
    assert a['scene_source_captured']==88
    assert a['scene_game_implemented']==0
    assert a['source_flag_advanced_in_manifest'] is True
