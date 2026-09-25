# P5 M25-M32 playable batch

Authority: Notion 15-05 / 15-06 v4.2 and the matching implementation mappings. GitHub stores executable bindings; canonical source text and source hashes remain unchanged.

| Scene | Physical target | Play loop | Completion |
| --- | --- | --- | --- |
| 05-M01 | E2 registration desk | Narae separately reviews her qualifier result and the anonymous temporary account reservation, then files the objection herself | record reviewed + Narae objection submitted → 05-M02 |
| 05-M02 | E3 / E3B / E4 | A-line last train, B-line walking exit, or free night bus; a missed train keeps the safe E3B fallback open without real-time waiting | physically reach E4 and confirm event entrance → 05-M03 |
| 05-M03 | E4 night event | Full view, summary, or bulletin reveals Doyun's real identity and provisional proxy reservation only | DOYUN_RESERVED_ID_KNOWN → 05-M04; no seat restoration/proxy cancellation/Q mutation |
| 05-M04 | E4 practice table | Optional real player-vs-Doyun TournamentDirector match, Ian review-only route, or no-match route | independent match result / NO_MATCH / NOT_ENTERED → 05-M05 |
| 05-M05 | E4→E6 | Cha Yugyeong introduction and Palace public-event news; tower is optional, public regular transit remains free | representative/news + departure choice → physical transition to 06 G0 |
| 06-M01 | G0 palace gate | Public-entry intent or free spectator route; Eunsol enters through public registration without a recommendation-fetch quest | court access selected → 06-M02 |
| 06-M02 | G3 public court | Player public match is a separate TournamentDirector event; Eunsol vs recommended master/local NPCs is an independent engine replay | player/observe/summary decision + independent Eunsol record → 06-M03 |
| 06-M03 | G3→G5 pavilion tower | Wolin introduction and free lobby/viewpoint visit; optional tower challenge is exposed but not required | Wolin intro + physical lobby visit → 06-M04 |

Runtime and route additions in this batch:
- Region 05 E3→E4 now explicitly distinguishes `TAKE_LAST_TRAIN` and `B_LINE_WALK`; only the train route is gated by the last-train state.
- `WorldInteractionController` derives the authored `R05_LAST_TRAIN_AVAILABLE` flag into traversal context, while the free E3→E3B→E4 night-bus fallback remains explicit.
- `r06_eunsol_independent` is now an actual engine replay with authored NPC identities, but no forced winner because the canonical script does not preset Eunsol's result.
- The existing 05-M03 semantic binding is promoted to PLAYABLE without applying later seat-restoration or proxy-cancellation facts.

Targeted verification:
- `game/tests_main_25_32_e2e.gd`: physical station traversal, B-line fallback, Doyun identity observation, Region 06 transit, Eunsol observation, and Wolin lobby reach.
- `game/tests_main_25_32_poker.gd`: B-line vs missed-last-train route contract, real Doyun practice, Palace public match save/restore, Eunsol independent replay, and no fabricated qualification.
- Both suites run in GitHub Godot Native QA and in `tools/run_godot_qa_windows.ps1`.

Current playable mainline after this batch: **32/88 story scenes** with **33/88 runtime bindings** total; `08-M03` remains the one semantic/non-playable forward binding.
