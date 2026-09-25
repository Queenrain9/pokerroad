# P5 runtime foundation + eight-region scene containers

Date: 2026-09-25

## What is now real

The production main scene now boots a common runtime rather than a disposable poker table/menu. It creates a GameRuntime and a RegionHost, validates all eight region PackedScenes, mounts the current region, and keeps region remounting tied to persistent GameState region changes.

GameRuntime connects:
- WORLD → DIALOGUE / POKER / OBSERVE
- POKER / OBSERVE → RESULT
- RESULT → WORLD
- real TournamentDirector event instances
- event-instance persistence
- POKER mid-hand resume with exact deck/board/hole/bet/actor/tournament state
- source-scene context preserved across interruption so an event result can return to the scene that requested it.

SceneRunner never rewrites the canonical dialogue. It opens the exact imported source record, verifies the binding's stored section SHA-256, applies only explicitly authored runtime effects, and refuses to advance MAIN_CURSOR while the physical scene remains NOT_IMPLEMENTED.

## First production source-backed runtime bindings

Four real source scenes are bound as cross-region acceptance coverage:

- 01-M01: P0/P1 start acknowledgement; no poker result is created.
- 01-M02: free Bokrye tutorial can PLAY / WATCH / SKIP. PLAY enters the canonical r01_grandma_practice TournamentDirector event. WIN/LOSS/WITHDRAW map back to the tutorial result without turning a single hand into a match result.
- 05-M03: Doyun identity/provisional sponsor reservation can be learned by full view / summary / bulletin. It cannot restore Narae's seat, cancel Doyun's reservation, or alter player Q.
- 08-M03: only the affected advertised broadcast round is paused. This binding cannot apply the later seat restoration / proxy cancellation / wildcard outcome.

Status: **runtime-bound 4/88; fully playable physical story scenes 0/88**.

## Eight region PackedScene containers

All eight production region roots now exist and mount through one RegionHost:

1. Saebomdong
2. Hangang
3. Acorn Forest
4. Seagull Port
5. Last Station
6. Moon Palace
7. Sleepless Market
8. Central City

Each root validates its canonical manifest region ID, anchor identities and production capability contract. The files intentionally contain **no Sprite2D / TileMap / collision / invented positions** yet. This prevents a temporary visual mockup from quietly becoming the final physical map.

Status: **region scene containers 8/8; physical maps 0/8; final visual assets not started here.**

## Verified acceptance

Verified code baseline: `2da845f786bb1b725af386903068ee2cdc0c3ced`

- Production main Godot boot: PASS (POKERROAD_P5_RUNTIME_BOOT_OK)
- Python/source/runtime QA: **97 passed**
- Exact five-card exhaustive classification: **2,598,960 / 2,598,960**
- Godot core: **31 checks passed**
- P3 regression: **48 checks passed**
- P4 system contracts: **37 checks passed**
- P5 world runtime: **56 checks passed**
- Eight-region PackedScene suite: **58 checks passed**

Windows/iPhone/Android remain separate device gates.

## Next production gate

The next work is not another global architecture document. It is the physical world layer:
1. define final cross-region spatial/camera metrics that are still provisional,
2. build real walkable geometry/collision/portal placement for all 8 region roots,
3. connect anchors to actual interaction points,
4. promote source bindings to IMPLEMENTED only after the scene can be reached, played, exited and regression-tested in the real world,
5. then expand M48 end-to-end before S16/T8/R16 completion.
