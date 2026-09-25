# P3 cross-region production contract

This is a pre-implementation contract, not evidence of finished maps/UI/scenes.

**Common loop:** RegionWorld physical location/floor/collision → player movement and proximity interaction → canonical v4.2 dialogue/choices/fail/revisit → player match OR independent NPC watch/result OR region-specific environment action → owner-specific result/world state/one-time reward → return to the correct world anchor. Discovering a place early does not auto-complete its story scene. Cancelling/losing optional S/T/R must preserve MAIN_CURSOR.

**Eight-region checks:** 01 neighborhood + separate giant tower + free bus; 02 moving cruise world with fixed poker HUD; 03 real upper/lower tree levels and explicit stairs/lift choice; 04 tide-dependent safe walking routes and lighthouse/rescue; 05 missed last train → real free night-bus route; 06 same-world day/night palace, not time travel; 07 market/free activities and bonus stamps separate from main acknowledgement; 08 public spectators vs Q=YES+registered players, only the advertised broadcast round paused before start, separate wildcard/showmatch/tower spaces.

**Persistent records stay separate:** HAND_RESULT / MATCH_RESULT / OFFICIAL_EVENT_RANK / PLAYER_Q / OFFICIAL_REGISTRATION / TOWER_CLEAR / NPC_EVENT_EVIDENCE / VIEWED_FULL / LEARNED_BULLETIN / WORLD_PHASE / MAIN_CURSOR / OPTIONAL_STATUS / REWARD_RECEIPT. Engine rank alone must not self-certify Q.

**Still provisional:** exact camera projection, pixel/non-pixel style, character/building/furniture ratios, final mobile orientation/safe-area layout, 8-seat poker UI sizes, event field sizes/cutoffs/blinds/antes/AI/duration/economy, and in-progress-hand save/restore policy. Existing 19-E and 20 numeric values remain development assumptions until tested.
