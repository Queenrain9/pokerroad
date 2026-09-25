import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MICRO = ROOT / "game/data/micro_navigation_v1.json"
SPATIAL = ROOT / "game/data/spatial_metrics_v1.json"


def _load(path):
    return json.loads(path.read_text(encoding="utf8"))


def test_saebom_micro_navigation_is_scoped_and_explicit():
    data = _load(MICRO)
    assert data["schema_version"] == 1
    assert data["status"] == "PROVISIONAL_LEVEL_GEOMETRY_NOT_FINAL_ART"
    assert set(data["regions"]) == {"01"}
    zones = data["regions"]["01"]["zones"]
    assert len(zones) == 12
    ids = {z["id"] for z in zones}
    assert ids == {
        "P0_START_COURT", "P0_PLAYGROUND", "P0_PLAYGROUND_NECK", "P0_ENDHOUSE_LANE",
        "P1_SUPER_COURT", "P1_RESIDENT_POCKET", "P2_SHOP_COURT",
        "P3_EVENT_FRONT", "P3_BACK_ALLEY", "P4_TOWER_PLAZA",
        "P5_APPROACH", "P5_BUS_PLAZA",
    }


def test_saebom_micro_navigation_preserves_canonical_anchor_authority():
    data = _load(MICRO)
    spatial = _load(SPATIAL)
    bounds = spatial["regions"]["01"]["bounds"]
    width, height = bounds[2], bounds[3]
    anchors = set(spatial["regions"]["01"]["anchors"])
    for zone in data["regions"]["01"]["zones"]:
        assert zone["owners"]
        assert set(zone["owners"]) <= anchors
        assert len(zone["polygon"]) >= 3
        for x, y in zone["polygon"]:
            assert 0 <= x <= width
            assert 0 <= y <= height
    by_id = {z["id"]: z for z in data["regions"]["01"]["zones"]}
    assert by_id["P0_ENDHOUSE_LANE"]["owners"] == ["P0"]
    assert set(by_id["P5_APPROACH"]["owners"]) == {"P3", "P5"}
    assert by_id["P4_TOWER_PLAZA"]["owners"] == ["P4"]
    rules = data["rules"]
    assert rules["story_anchor_positions_unchanged"] is True
    assert rules["zones_do_not_complete_scenes"] is True
    assert rules["zones_do_not_change_current_anchor"] is True
    assert rules["final_building_footprints_not_defined"] is True


def test_saebom_physical_paths_bend_without_changing_anchor_graph():
    data = _load(MICRO)
    spatial = _load(SPATIAL)
    region = data["regions"]["01"]
    paths = region["physical_paths"]
    assert len(paths) == 4
    expected = {("P0","P1"),("P1","P2"),("P2","P3"),("P3","P5")}
    assert {(p["from"],p["to"]) for p in paths} == expected
    anchors = spatial["regions"]["01"]["anchors"]
    for path in paths:
        assert path["points"][0] == anchors[path["from"]]
        assert path["points"][-1] == anchors[path["to"]]
        assert len(path["points"]) >= 4
        assert path["half_width"] == 96
    p3_p5 = next(p for p in paths if p["id"] == "R_P3_P5")
    direct_y = (anchors["P3"][1] + anchors["P5"][1]) / 2
    assert max(abs(point[1] - direct_y) for point in p3_p5["points"][1:-1]) >= 80
    rules = data["rules"]
    assert rules["physical_paths_preserve_anchor_endpoints"] is True
    assert rules["physical_paths_do_not_change_story_graph"] is True
