# P5 first eight main scenes: playable slice

Authority: Notion 15-01 and 15-02 v4.2 are the script and dialogue source. This document describes the GitHub implementation. Original source text and section hashes remain in `game/data/original_scenes`.

| Scene | Reach and interact | Action | State and exit |
| --- | --- | --- | --- |
| 01-M01 | P0, board / supermarket visitor | Read board or ask directions; exploring first leaves the scene open | `START_ACK`, return P0, unlock 01-M02 |
| 01-M02 | P1, Bokrye's free table | Actual free TournamentDirector match, observe, or skip | `TUTORIAL_RESULT`; result/observation separated from official records; return P1, unlock 01-M03 |
| 01-M03 | P3, Haechan's registration desk | Register for a free official local match, reserving a match ID, or choose audience admission | `R01_REGISTRATION`; return P3, unlock 01-M04 |
| 01-M04 | P3, public event tent | Registered player enters the real local TournamentDirector event; spectator uses OBSERVE/result. Ian's separate NPC event is replayed through the engine and recorded once | Final player match result or `NOT_ENTERED`, independent Ian record; return P3, unlock 01-M05 |
| 01-M05 | P3, Ian behind arcade | Discuss challenge, viewing, or future practice | `IAN_RIVER_SCHEDULE` and travel motive; return P3, unlock 01-M06 |
| 01-M06 | P4, tower staff | Learn about Bokrye's tower, inspect free lobby, reserve interest, or leave for later | `TOWER_INTRO_SEEN`; return P4, unlock 01-M07. T01 itself remains optional future work |
| 01-M07 | P5, regular riverside bus | Choose challenge, observation, or Ian; staying postpones departure | Boarding at physical P5 unlocks 02 and mounts K0; no fee or tower victory required |
| 02-M01 | K0, Dohae at riverside stop | Pick pier, day walk, or free practice/work first | `R02_RIVER_SEEN`, route preference; return K0, unlock 02-M02 |

The shared `SceneRunner` handles source hash checks, choices and completion. `WorldInteractionController` requires the player to reach the current physical anchor; `GameRuntime` runs poker, observation, results and save recovery. The production entrypoint exposes movement, proximity interaction, choices, poker actions, and save/resume. Original prose is retained as source data; the interface currently presents the authored dialogue lines for this slice. Wayfinding visuals are functional navigation aids, not final environment art.

The main scene ledger advances only after the source-backed completion condition is met. `tests_first_eight_e2e.gd` walks the physical routes and checks all eight scenes through world-control recovery and save reload. `tests_first_eight_poker.gd` checks reserved event identity, real cards, mid-hand resume, final tournament rank, independent NPC replay, and replay prevention. The optional S/T/R and 02-M02 onward remain outside this slice.
