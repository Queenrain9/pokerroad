# 🎲 PokerRoad — 여덟 개의 탑

Godot mobile poker RPG production repository.

## Source of Truth

- **Notion**: story, dialogue, world facts, scene intent, design decisions, canonical 15 v4.2 script.
- **GitHub**: executable implementation, imported runtime data, tests, QA/build scripts, maps/scenes/assets.

## Current verified state — 2026-09-25

- Canonical Notion v4.2 mirror: **8/8 region files**, **88 unique scene IDs** (M48 / S16 / T8 / R16).
- Generated source records: **88/88 imported and fingerprint-verified**.
- Playable Godot scene implementation: **0/88**. Source capture is not gameplay implementation.
- GitHub Core QA: Python/structural/source checks + exact **2,598,960** five-card exhaustive classification.
- Godot Native QA: **Godot 4.4.1 Linux headless PASSED** — core suite 31 checks + P3 regression suite 48 checks.
- **Windows/iPhone/Android: NOT TESTED**. Physical maps, final visual assets, NPC poker AI, full tournament/save implementation, and mobile builds remain incomplete.

The canonical script files live under source/original_notion_v4_2. Automation imports them into game/data/original_scenes while preserving provenance and keeping game_implementation_status=NOT_IMPLEMENTED.

Use tools/run_godot_qa_windows.ps1 on a Windows machine with Godot 4 installed for the next native environment check.

No disposable one-region/menu-only poker prototype is used as the product entrypoint. All 8 regions and optional S16/T8/R16 remain production scope.
