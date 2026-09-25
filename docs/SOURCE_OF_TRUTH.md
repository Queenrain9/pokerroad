# Source of Truth split

- **Notion**: canonical story/dialogue/world facts/scene intent/design decisions/15 v4.2 script.
- **GitHub**: Godot source, imported runtime data, tests, QA/build scripts, maps/scenes/assets, implementation status.

Story conflict → preserve Notion intent unless superseded by a newer explicit decision. Implementation/progress conflict → repository evidence wins.

`Notion 15-01..15-08 v4.2` → `source/original_notion_v4_2/15_XX.md` → `tools/import_original_scenes.py` → `game/data/original_scenes/*.json` → Godot bindings.

Imported source data is not the same as a playable implemented scene.
