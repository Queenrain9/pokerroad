# 🎲 PokerRoad — 여덟 개의 탑

Godot mobile poker RPG production repository.

## Source of Truth

- **Notion**: story, dialogue, world facts, scene intent, design decisions, canonical 15 v4.2 script.
- **GitHub**: executable implementation, imported runtime data, tests, QA/build scripts, maps/scenes/assets.

The repository contains the verbatim 8-region Notion v4.2 source mirror under source/original_notion_v4_2 with **88 unique scene IDs: M48 / S16 / T8 / R16**. Automation imports those texts into game/data/original_scenes without treating source capture as gameplay implementation.

**Playable scene implementation remains 0/88.** Physical maps, final visual assets, NPC poker AI, full tournament/save implementation, and mobile builds are not complete.

Python/source QA is automated with GitHub Actions. Godot 4 native parser/headless execution is **NOT TESTED by this repository commit yet**; use tools/run_godot_qa_windows.ps1 on a machine with Godot 4 installed.

No disposable one-region/menu-only poker prototype is used as the product entrypoint. All 8 regions and optional S16/T8/R16 remain production scope.
