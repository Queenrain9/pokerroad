# P5 M17-M24 playable batch

Authority: Notion 15-03 / 15-04 v4.2 and the matching implementation mappings. GitHub stores executable bindings; canonical source text and source hashes remain unchanged.

| Scene | Physical target | Play loop | Completion |
| --- | --- | --- | --- |
| 03-M04 | F3/F5 upper village and Solgae lobby | Doyun direct practice can run as a separate real TournamentDirector match, or remain NOT_ENTERED; Solgae introduction stays independent of tower victory | Doyun decision + Solgae intro → 03-M05 |
| 03-M05 | F4 poster / F6 public transit | Read only the announced Ian/Doyun appearance, then choose match/coast motive or stay in forest | Public departure choice → physical transition to 04 H0 |
| 04-M01 | H1 fish market/tide board | Narae gives the safety brief without forcing casino play or reward | Safety guidance → 04-M02 |
| 04-M02 | H1→H2→H3→H4 | Establish actual tide, traverse the safe route gate, identify the boat directly or via rescue-team recovery, then read the all-safe report | CREW_SAFE + report, one-time rescue reward → 04-M03 |
| 04-M03 | H5 cafe/official qualifier | Cafe practice, player official qualifier, and Narae's independent qualifier are three distinct records; paid player entry requires explicit confirmation | Cafe decision + official decision, Narae engine replay → 04-M04 |
| 04-M04 | H6 spectator stand | Player predicts/watches/reads the board only; Doyun vs Ian is an independent engine-replayed NPC event with canonical participants and Doyun final rank 1 | Observation decision + NPC result → 04-M05 |
| 04-M05 | H5 results board | Narae receives the account-based final-seat notice without revealing the later proxy identity | NARAE_NOTICE_04=RECEIVED → 04-M06 |
| 04-M06 | H8 regular railway | Leave for Ian's next match or Narae's registration inquiry; staying keeps the scene open | Public departure choice → physical transition to 05 E0 |

Runtime additions in this batch:
- One-time authored rewards are supported through `GRANT_REWARD`.
- Tide traversal can derive its established LOW/HIGH state from canonical story flags rather than requiring test-only context injection.
- Paid events have an explicit confirm/cancel state in the playable UI; fees are charged only after confirmation.
- Player official engine results update `PLAYER_Q` through the existing Qualification service and remain `PENDING` while review status is `ENGINE_RANK_ONLY`.
- Independent NPC events can use authored participant identities and a canonical required final rank. The engine searches deterministic replay seeds until that authored outcome is reproduced; no player result is fabricated.

Targeted verification:
- `game/tests_main_17_24_e2e.gd`: physical F3→F6→harbor traversal, tide-gated rescue, one-time reward, Narae qualifier, Doyun/Ian invite, and H8→E0 region transition.
- `game/tests_main_17_24_poker.gd`: Doyun direct practice, explicit 40-chip official-entry confirmation, mid-hand save/restore without double charge, PENDING qualification review, Narae independent qualifier, and Doyun/Ian canonical NPC replay.
- Both suites run in GitHub Godot Native QA and in `tools/run_godot_qa_windows.ps1`.

Current playable mainline after this batch: **24/88 story scenes** with **26/88 runtime bindings** total; `05-M03` and `08-M03` remain semantic/non-playable bindings.
