# 🎲 PokerRoad — 여덟 개의 탑

Godot mobile poker RPG production repository.

## Source of Truth

- **Notion**: story, dialogue, world facts, scene intent, design decisions, canonical 15 v4.2 script.
- **GitHub**: executable implementation, imported runtime data, tests, QA/build scripts, maps/scenes/assets.

## Current verified state — 2026-09-25

- Canonical Notion v4.2 mirror: **8/8 region files**, **88 unique scene IDs** (M48 / S16 / T8 / R16).
- Generated source records: **88/88 imported and fingerprint-verified**.
- Structural contracts are implemented for **competition/tournament/Q/AI**, **save/interruption recovery**, and **8-region camera/space/control/poker-UI semantics**.
- **P5 common runtime now boots in Godot**: source-backed SceneRunner, WorldRuntime, poker-event→RESULT→WORLD flow, observation flow, and runtime save/resume are connected.
- Production runtime bindings authored against canonical source: **4/88** (`01-M01`, `01-M02`, `05-M03`, `08-M03`). These are semantic bindings, not claims that physical scenes are finished.
- Production region PackedScene containers: **8/8 registered and mountable** from the actual main entrypoint.
- P5 spatial baseline: **8/8 region bounds + 60/60 canonical anchor coordinates**, shared CharacterBody2D player runtime, Camera2D limits/smoothing, nonvisual interaction markers, and mobile virtual-move input API are connected to the real main boot.
- P5 world interaction baseline: physical proximity is now required before anchor travel or source-scene opening; direct-route validation, explicit forest/tide/bus/city gate choices, safe-return behavior and no-teleport guards are wired through the existing TraversalService.
- P5 route geometry: **8/8 regions active**. All canonical direct edges have nonvisual walk corridors or explicit physical transit portals, with collision walls at corridors, gates, and world bounds. The player is constrained to the current anchor's walkable route. Final buildings, environment details, and art remain unfinished.
- Playable fully implemented story scenes: **0/88**. Source capture/runtime binding is not the same as physical scene implementation.
- GitHub Core QA: **104 passed** + exact **2,598,960** five-card exhaustive classification.
- Godot 4.4.1 Windows headless: production main boot PASS; core **31**, P3 regression **48**, P4 system-contract **37**, P5 world-runtime **56**, eight-region scene **142**, spatial-runtime **153**, world-interaction **30**, route geometry **441**, physical movement **7** checks PASS. Linux CI runs the same native suites after push.
- **Windows device play QA and iPhone/Android builds: NOT TESTED**. Final environment details, art, per-NPC AI tuning, complete 88-scene bindings and mobile builds remain incomplete.

The canonical script files live under `source/original_notion_v4_2`. Runtime bindings live in `game/data/scene_bindings_v1.json` and are rejected if the stored source hash no longer matches the canonical imported scene.

The eight production region scene containers live under `game/scenes/regions/`. They still contain no disposable placeholder art. Navigation coordinates are centralized in `game/data/spatial_metrics_v1.json`; source-manifest `world_coordinates` remain untouched. `RouteGeometry` derives the physical corridor and transit layout from the canonical traversal graph at runtime.

Use `tools/run_godot_qa_windows.ps1` on a Windows machine with Godot 4 installed for the next native environment gate.

No disposable one-region/menu-only poker prototype is used as the product entrypoint. All 8 regions and optional S16/T8/R16 remain production scope.
