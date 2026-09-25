import json, math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LEVEL = json.loads((ROOT/"game/data/level_geometry_v1.json").read_text(encoding="utf8"))
MICRO = json.loads((ROOT/"game/data/micro_navigation_v1.json").read_text(encoding="utf8"))
SPATIAL = json.loads((ROOT/"game/data/spatial_metrics_v1.json").read_text(encoding="utf8"))
GRAPH = json.loads((ROOT/"game/data/traversal_graph_dev.json").read_text(encoding="utf8"))

RID="01"
CLEARANCE=28.0
CORRIDOR_HALF=96.0
PLAZA_R=138.0
INTERACTION_R=82.0
PORTAL_OFFSET=118.0


def rect(poly):
    xs=[p[0] for p in poly]; ys=[p[1] for p in poly]
    return (min(xs),min(ys),max(xs),max(ys))


def rect_distance(a,b):
    dx=max(a[0]-b[2], b[0]-a[2], 0.0)
    dy=max(a[1]-b[3], b[1]-a[3], 0.0)
    return math.hypot(dx,dy)


def rect_point_distance(r,p):
    dx=max(r[0]-p[0], p[0]-r[2], 0.0)
    dy=max(r[1]-p[1], p[1]-r[3], 0.0)
    return math.hypot(dx,dy)


def point_segment_distance(p,a,b):
    vx=b[0]-a[0]; vy=b[1]-a[1]
    ll=vx*vx+vy*vy
    if ll == 0: return math.dist(p,a)
    t=max(0.0,min(1.0,((p[0]-a[0])*vx+(p[1]-a[1])*vy)/ll))
    q=(a[0]+vx*t,a[1]+vy*t)
    return math.dist(p,q)


def orient(a,b,c):
    return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])


def segments_intersect(a,b,c,d):
    o1,o2,o3,o4=orient(a,b,c),orient(a,b,d),orient(c,d,a),orient(c,d,b)
    return ((o1>0 and o2<0) or (o1<0 and o2>0)) and ((o3>0 and o4<0) or (o3<0 and o4>0))


def seg_distance(a,b,c,d):
    if segments_intersect(a,b,c,d): return 0.0
    return min(point_segment_distance(a,c,d),point_segment_distance(b,c,d),
               point_segment_distance(c,a,b),point_segment_distance(d,a,b))


def rect_segment_distance(r,a,b):
    x0,y0,x1,y1=r
    if x0<=a[0]<=x1 and y0<=a[1]<=y1: return 0.0
    if x0<=b[0]<=x1 and y0<=b[1]<=y1: return 0.0
    edges=[((x0,y0),(x1,y0)),((x1,y0),(x1,y1)),((x1,y1),(x0,y1)),((x0,y1),(x0,y0))]
    return min(seg_distance(e0,e1,a,b) for e0,e1 in edges)


def point_in_rect(p,r):
    return r[0] <= p[0] <= r[2] and r[1] <= p[1] <= r[3]


anchors={k:tuple(v) for k,v in SPATIAL["regions"][RID]["anchors"].items()}
zones=MICRO["regions"][RID]["zones"]
zone_rects={z["id"]:rect(z["polygon"]) for z in zones}
owners={z["id"]:set(z["owners"]) for z in zones}
region=LEVEL["regions"][RID]
graph_region=next(x for x in GRAPH["regions"] if x["id"]==RID)


def nonportal_segments_for(source):
    out=[]
    seen=set()
    for e in graph_region["edges"]:
        if e.get("requires_player_route_choice",False): continue
        if e["from"]!=source: continue
        key=tuple(sorted((e["from"],e["to"])))
        if key in seen: continue
        seen.add(key)
        out.append((anchors[e["from"]],anchors[e["to"]]))
    return out


def walkable(source,p):
    if math.dist(p,anchors[source]) <= PLAZA_R: return True
    for zid,r in zone_rects.items():
        if source in owners[zid] and point_in_rect(p,r): return True
    for a,b in nonportal_segments_for(source):
        if point_segment_distance(p,a,b) <= CORRIDOR_HALF: return True
    return False


def test_level_geometry_counts_and_scope():
    assert LEVEL["status"]=="PROVISIONAL_BLOCKOUT_GEOMETRY_VALIDATED_NOT_FINAL_ART"
    assert set(LEVEL["regions"])=={"01"}
    assert len(region["building_footprints"])==8
    assert len(region["interaction_slots"])==12
    assert len(region["occlusion_candidates"])==5
    assert LEVEL["rules"]["minimum_walkable_clearance"]==28
    assert LEVEL["rules"]["portal_clearance_radius"]==100


def test_buildings_respect_bounds_walkable_clearance_and_routes():
    bx,by,bw,bh=SPATIAL["regions"][RID]["bounds"]
    world=(bx,by,bx+bw,by+bh)
    # Unique canonical non-portal segments.
    unique={}
    for e in graph_region["edges"]:
        if e.get("requires_player_route_choice",False): continue
        key=tuple(sorted((e["from"],e["to"])))
        unique[key]=(anchors[e["from"]],anchors[e["to"]])
    for b in region["building_footprints"]:
        r=rect(b["polygon"])
        assert world[0] <= r[0] <= r[2] <= world[2], b["id"]
        assert world[1] <= r[1] <= r[3] <= world[3], b["id"]
        for z in zones:
            assert rect_distance(r,rect(z["polygon"])) >= CLEARANCE, (b["id"],z["id"])
        for aid,p in anchors.items():
            assert rect_point_distance(r,p) >= PLAZA_R+CLEARANCE, (b["id"],aid)
        for key,(a,c) in unique.items():
            assert rect_segment_distance(r,a,c) >= CORRIDOR_HALF+CLEARANCE, (b["id"],key)


def test_portal_clearance_is_free_of_buildings_and_npcs():
    a=anchors["P3"]; b=anchors["P4"]
    vx,vy=b[0]-a[0],b[1]-a[1]
    length=math.hypot(vx,vy)
    gate=(a[0]+vx/length*PORTAL_OFFSET,a[1]+vy/length*PORTAL_OFFSET)
    for building in region["building_footprints"]:
        assert rect_point_distance(rect(building["polygon"]),gate) >= 100, building["id"]
    for slot in region["interaction_slots"]:
        if slot["target_kind"]=="NPC":
            assert rect_point_distance(rect(slot["stand_zone"]),gate) >= 100, slot["id"]


def test_every_interaction_has_reachable_approach_and_valid_radius():
    for slot in region["interaction_slots"]:
        a=rect(slot["approach_zone"]); s=rect(slot["stand_zone"])
        assert rect_distance(a,s) <= INTERACTION_R, slot["id"]
        samples=[
            (a[0],a[1]),(a[2],a[1]),(a[2],a[3]),(a[0],a[3]),
            ((a[0]+a[2])/2,(a[1]+a[3])/2)
        ]
        assert all(walkable(slot["anchor_id"],p) for p in samples), slot["id"]
        if slot["target_kind"]=="NPC":
            center=((s[0]+s[2])/2,(s[1]+s[3])/2)
            assert walkable(slot["anchor_id"],center), slot["id"]


def test_occlusion_candidates_are_visual_only_and_bounded():
    bx,by,bw,bh=SPATIAL["regions"][RID]["bounds"]
    world=(bx,by,bx+bw,by+bh)
    for item in region["occlusion_candidates"]:
        r=rect(item["polygon"])
        assert item["collision"] is False
        assert item["fade_when_player_behind"] is True
        assert world[0] <= r[0] <= r[2] <= world[2]
        assert world[1] <= r[1] <= r[3] <= world[3]
