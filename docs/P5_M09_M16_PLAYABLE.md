# P5 M09-M16 playable batch

Authority: Notion 15-02 / 15-03 v4.2 and the matching 16-02 / 16-03 implementation mappings. GitHub stores executable bindings; the verbatim source and hashes remain unchanged.

| Scene | Physical target | Play loop | Completion |
| --- | --- | --- | --- |
| 02-M02 | K2/K3 river broadcast screen | Full broadcast, summary, or defer to pier; Ian's separate NPC event is engine-replayed | Independent Ian record + `IAN_NPC_RIVER_RESULT` → 02-M03 |
| 02-M03 | K3 pier | Player registration with reserved match ID, free spectator boarding, or next public boat | `R02_ON_BOAT` → 02-M04 |
| 02-M04 | K3 moving boat table | Registered player enters real TournamentDirector event; spectator observes Yunharu's separate engine replay | Player WIN/LOSS/WITHDRAW or VIEW kept separate → 02-M05 |
| 02-M05 | K3 lookout | Optional real Ian practice match, or skip to forest/tower information | Ian result / NOT_ENTERED + tower intro/reunion → 02-M06 |
| 02-M06 | K5 public bus | Landscape or Doyun motive boards free public transport; staying leaves scene open | Region 03 unlock + physical transition to F0 |
| 03-M01 | F0 then F2 | Miro route guidance, then physically reach and inspect the upper-route sign | Guide + F2 sign → 03-M02 |
| 03-M02 | F2 then F3 | Choose work lift or external stairs, use the real route gate, then confirm F3 arrival | Physical ascent arrival → 03-M03 |
| 03-M03 | F4 showcase | Full/summary/result-board observation plus read response; Doyun NPC showcase engine-replayed | Doyun first seen + read response → 03-M04 |

The common runner now supports `requires_anchor` for choices and `FLAGS_ALL` completion so one authored scene can span multiple physical anchors without scene-specific hardcoding.

Targeted verification:
- `game/tests_main_09_16_e2e.gd`: physical reach → interact → action → state → exit, save/reload, duplicate-completion prevention.
- `game/tests_main_09_16_poker.gd`: reserved boat match identity, mid-hand restore, separate Ian practice, independent Yunharu replay, no fabricated national qualification.

Normal CI no longer runs the 2,598,960-combination exhaustive classifier on every content push. That classifier remains available through manual Core QA dispatch with `exhaustive=true`.
