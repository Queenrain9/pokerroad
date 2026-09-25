# P5.1 spatial baseline — eight-region navigation metrics

Date: 2026-09-25

This checkpoint follows the P5 common runtime. It establishes the physical-world engineering coordinate system without pretending that final environment art or complete maps exist.

## Implemented

- Shared reference viewport: 1280×720 landscape.
- Shared player runtime: CharacterBody2D, 260 world-units/sec baseline, 18-unit collision radius, 82-unit interaction radius.
- Shared camera runtime: Camera2D, per-region bounds, 1.0 zoom baseline, position smoothing.
- Mobile-ready input seam: player exposes a virtual move Vector2 API in addition to keyboard input.
- All **8/8 regions** have explicit world bounds.
- All **60/60 canonical manifest anchors** have unique, in-bounds production navigation coordinates.
- RegionWorld creates one **nonvisual Marker2D** per canonical anchor at runtime; these markers are interaction/navigation infrastructure, not art.
- Production main boot mounts the current region, spawns the real player at GameState.current_anchor, activates the shared camera, and remounts/repositions on region change.

## Integrity rules

- Canonical Notion/manifest story data is not rewritten.
- `world_manifest.json` anchor `world_coordinates` remain null; runtime spatial coordinates live in the separate spatial contract so story-source identity and implementation layout are not conflated.
- Reaching an anchor does not auto-complete a scene, create a match result, or bypass route-choice rules.
- No Sprite2D, TileMap, Polygon2D or placeholder environment art was added to the eight region PackedScenes.
- `physical_map_status` remains NOT_IMPLEMENTED. Current state is **navigation metrics + positioned anchor skeleton**, not finished walkable environment geometry.

## Verified acceptance

Baseline commit: `b064de8255529bc47bbd2273d03cf09a0e344ac6`

GitHub Actions on that commit:
- Core/source QA: **101 passed**
- Exact five-card exhaustive classification: **2,598,960 / 2,598,960**
- Production main Godot boot: PASS (`POKERROAD_P5_SPATIAL_BOOT_OK`)
- Godot core: **31**
- P3 regression: **48**
- P4 system contracts: **37**
- P5 world runtime: **56**
- Eight-region scene runtime: **186**
- P5 spatial runtime: **153**

All listed native suites passed on Godot 4.4.1 Linux headless. Windows/iPhone/Android remain untested device gates.

## Next physical-world work

1. Add actual collision/route geometry to all eight region roots without introducing disposable final-looking art.
2. Connect the 60 anchor markers to proximity interaction and route-choice resolution.
3. Implement region-specific physical constraints: forest vertical transfer, port tide routes, station last-train/free-night-bus branch, city public/registered gates.
4. Only after a source-bound scene is physically reachable, playable, exits correctly, and passes regression may its `game_implementation_status` move to IMPLEMENTED.
5. Expand the main route M48 end-to-end before completing S16/T8/R16.