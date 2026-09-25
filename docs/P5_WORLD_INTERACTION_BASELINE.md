# P5.2 world interaction baseline — physical proximity → route → source scene

Date: 2026-09-25

This checkpoint connects the P5 spatial anchor skeleton to the real runtime without inventing finished environment art or bypassing story/travel rules.

## Implemented

- `WorldInteractionController` binds GameState, GameRuntime, RegionHost and the shared player.
- A player must be physically inside the interaction radius of an anchor before that anchor can be inspected or committed.
- Non-adjacent markers cannot teleport persistent world state.
- Entering a nearby anchor still delegates to `TraversalService`; physical proximity does not bypass logical route rules.
- Current-anchor interaction exposes only source scenes explicitly bound to that physical anchor.
- Scene opening from the world therefore requires both: canonical runtime binding + physical current-anchor proximity.

## Region-specific route acceptance now exercised through the physical interaction seam

- 01: P0→P1 normal nearby travel commits; standing near P3 from P0 remains blocked.
- 03: F2→F3 requires explicit `WORK_LIFT` or `EXTERNAL_STAIRS` choice.
- 04: H1→H2 rejects the wrong tide route and accepts the matching safe route.
- 05: E3→E3B exposes explicit zero-fee `BOARD_FREE_NIGHT_BUS` after missed-train context.
- 08: C2→C3 rejects `REGISTERED_PLAYER_ONLY` when player Q/registration is absent while `PUBLIC_SPECTATOR` stays available.

## Integrity boundary

- The interaction controller does not write PLAYER_Q, tournament rank, NPC event result or tower clear state.
- Merely standing at an anchor never completes a scene or creates poker results.
- Physical map art and full internal collision remain unfinished; this is the verified interaction seam on top of positioned navigation anchors.

## Verified acceptance

Baseline commit: `31f86c42215e1c8c9db2f0f2c6d8334ee96d1c5e`

- Core/source QA: **104 passed**
- Exact five-card exhaustive classification: **2,598,960 / 2,598,960**
- Production main boot: PASS
- Godot core: **31**
- P3 regression: **48**
- P4 system contracts: **37**
- P5 world runtime: **56**
- Eight-region scene runtime: **186**
- P5 spatial runtime: **153**
- P5 world interaction: **28**

All native suites above passed on Godot 4.4.1 Linux headless. Windows/iPhone/Android remain separate device gates.

## Next

Build actual invisible collision/route geometry and region-specific gates on all eight roots, then promote physical source scenes one by one only after reach→interact→play→exit regression passes.