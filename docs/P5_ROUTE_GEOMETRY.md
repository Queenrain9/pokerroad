# P5.2 eight-region route geometry and physical gates

Date: 2026-09-25

This checkpoint extends the existing Godot production world. The canonical
Notion v4.2 source and generated world/traversal data are unchanged.

## Runtime

- All eight RegionWorld instances now create nonvisual `PhysicalRoutes` with
  `StaticBody2D` collision at world bounds, both sides of each walk corridor,
  and each directed transit threshold. Geometry follows the 60 positioned
  canonical anchors and direct edges in `traversal_graph_dev.json`.
- `RouteGeometry` permits movement on the current anchor plaza and its direct
  walk corridors. The shared `CharacterBody2D` is stopped at their edges.
  Walking to a destination still needs a nearby interaction to commit its
  anchor; crossing into a later route without that step is blocked.
- Edges requiring a player choice become entrance portals on the source side.
  The destination is not physically reachable on foot. The world interaction
  controller checks proximity to that entrance, applies `TraversalService`
  rules, then moves the player to the destination anchor only after a valid
  choice. This covers the forest upper floor, port tide path, station train
  and free bus, Central City public versus registered entrance, and all
  optional tower entrances. Return portals preserve the safe route back.
- A direct jump to a distant anchor, standing on the far side of a gate, or
  an invalid route choice cannot commit travel. The optional tower entrance
  now has an explicit choice token instead of accepting an arbitrary string.
- `physical_map_status=ROUTE_GEOMETRY_ACTIVE` describes this playable route
  layer. It does not mean the finished buildings, interiors, art, or the 88
  story scenes are complete.

## Verification

The new native route suite checks all eight mounted regions, 60 plazas, every
direct edge, portal entrance and destination separation, and engine collision
shapes. A separate native physics suite moves the real player with virtual
input to verify corridor confinement and reachability. The world interaction
suite also tests that skipping a forest entrance cannot enter the upper floor.
Both suites are included in the Godot Native QA workflow.

Local Windows Godot 4.4.1 headless verification: production boot PASS and
native suites **31 + 48 + 37 + 56 + 142 + 153 + 30 + 441 + 7 = 945 checks**
PASS. Python structural/source QA: **104 passed**; exact five-card exhaustive
classification: **2,598,960 / 2,598,960**. Linux CI is pending for this
commit; no mobile device test is claimed.

The next content step is M48 end-to-end scene binding in region order, with
each scene counted as implemented only after reach, interaction, play, state
change, exit, save, and replay checks succeed.
