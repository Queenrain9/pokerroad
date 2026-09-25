import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
REGION_DIR=ROOT/'game/scenes/regions'
EXPECTED={
    '01':'01_saebomdong.tscn','02':'02_hangang.tscn','03':'03_acorn_forest.tscn',
    '04':'04_seagull_port.tscn','05':'05_last_station.tscn','06':'06_moon_palace.tscn',
    '07':'07_sleepless_market.tscn','08':'08_central_city.tscn'
}

def test_all_eight_region_packed_scenes_exist_with_exact_ids():
    assert {p.name for p in REGION_DIR.glob('*.tscn')}==set(EXPECTED.values())
    for region_id,name in EXPECTED.items():
        text=(REGION_DIR/name).read_text(encoding='utf8')
        assert 'res://scripts/world/region_world.gd' in text
        assert f'region_id = "{region_id}"' in text

def test_region_scenes_do_not_smuggle_placeholder_visual_maps():
    forbidden=('Sprite2D','TileMap','TileMapLayer','CollisionShape2D','Polygon2D','TextureRect')
    for p in REGION_DIR.glob('*.tscn'):
        text=p.read_text(encoding='utf8')
        assert not any(token in text for token in forbidden), p
        assert 'position =' not in text, p

def test_region_host_registers_every_region_and_game_root_mounts_it():
    host=(ROOT/'game/scripts/world/region_host.gd').read_text(encoding='utf8')
    for region_id,name in EXPECTED.items():
        assert f'"{region_id}":"res://scenes/regions/{name}"' in host
    root=(ROOT/'game/scripts/world/game_root.gd').read_text(encoding='utf8')
    assert 'validate_all_region_scenes' in root and 'mount_region(state.current_region, state)' in root
    assert '_on_world_changed' in root

def test_region_world_keeps_physical_and_visual_status_honest():
    script=(ROOT/'game/scripts/world/region_world.gd').read_text(encoding='utf8')
    assert '"physical_map_status":"ROUTE_GEOMETRY_ACTIVE"' in script
    assert '"visual_asset_status":"FIRST_SPACE_3_4_PROTOTYPE"' in script
    assert 'else "NOT_STARTED"' in script
    visual=(ROOT/'game/scripts/world/saebom_first_space_visual.gd').read_text(encoding='utf8')
    assert 'ForegroundOcclusion' in visual and 'P0' in visual and 'P1' in visual
    assert 'world_coordinates' not in script
