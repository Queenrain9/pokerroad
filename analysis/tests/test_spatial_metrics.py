import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
DATA=ROOT/'game/data'

def load(name):
    return json.loads((DATA/name).read_text(encoding='utf8'))

def test_spatial_metrics_cover_all_manifest_anchors_without_rewriting_source_manifest_positions():
    manifest=load('world_manifest.json')
    spatial=load('spatial_metrics_v1.json')
    assert spatial['schema_version']==1
    assert set(spatial['regions'])=={f'{i:02}' for i in range(1,9)}
    total=0
    for region in manifest['regions']:
        rid=region['id']
        expected={a['id'] for a in region['anchors']}
        actual=set(spatial['regions'][rid]['anchors'])
        assert actual==expected
        x,y,w,h=spatial['regions'][rid]['bounds']
        assert w>1280 and h>720
        coords=[]
        for aid,(ax,ay) in spatial['regions'][rid]['anchors'].items():
            assert x<=ax<=x+w and y<=ay<=y+h
            coords.append((ax,ay))
        assert len(coords)==len(set(coords))
        assert all(a['world_coordinates'] is None for a in region['anchors'])
        total+=len(coords)
    assert total==60

def test_spatial_contract_does_not_claim_final_art_or_finished_maps():
    spatial=load('spatial_metrics_v1.json')
    assert spatial['visual_status']=='NO_FINAL_ART_COMPOSITION_CLAIM'
    assert spatial['physical_map_status']=='NAVIGATION_METRICS_ONLY'
    assert spatial['anchor_semantics']['anchor_position_does_not_complete_scene'] is True
    assert spatial['anchor_semantics']['arriving_at_anchor_does_not_create_match_result'] is True

def test_shared_player_and_camera_runtime_exist():
    player=(ROOT/'game/scripts/world/player_controller.gd').read_text(encoding='utf8')
    camera=(ROOT/'game/scripts/world/camera_rig.gd').read_text(encoding='utf8')
    world=(ROOT/'game/scripts/world/region_world.gd').read_text(encoding='utf8')
    assert 'extends CharacterBody2D' in player and 'set_virtual_move_vector' in player and 'bind_region' in player
    assert 'extends Camera2D' in camera and 'apply_region' in camera
    assert 'nearest_anchor' in world and 'NON_VISUAL_INTERACTION_ANCHOR' in world

def test_all_region_packed_scenes_remain_art_free_source_containers():
    for p in sorted((ROOT/'game/scenes/regions').glob('*.tscn')):
        text=p.read_text(encoding='utf8')
        assert 'Sprite2D' not in text and 'TileMap' not in text and 'Polygon2D' not in text
