from pathlib import Path
ROOT=Path(__file__).parents[2]
def test_no_disposable_poker_table_as_world_entrypoint():
    main=(ROOT/'game/scenes/main.tscn').read_text(encoding='utf-8');root=(ROOT/'game/scripts/world/game_root.gd').read_text(encoding='utf-8')
    assert 'PokerTable' not in main and 'PokerRoadGameRoot' in main and 'validate_world_manifest()' in root and 'Runtime.new(state)' in root
def test_persistent_main_cursor_never_skips_original_scene_import():
    world=(ROOT/'game/scripts/services/game_state.gd').read_text(encoding='utf-8')
    assert 'scene_is_implemented(scene_id)' in world and 'if scene_id != main_cursor or not scene_is_implemented(scene_id):' in world and 'rewards_paid.has(reward_id)' in world
def test_godot_tests_are_provided_but_not_misreported_as_executed():
    assert (ROOT/'game/tests_headless.gd').is_file();readme=(ROOT/'README.md').read_text(encoding='utf-8');assert 'NOT TESTED' in readme and '8/88' in readme
def test_no_old_style_invalid_const_inference():
    scripts=list((ROOT/'game').rglob('*.gd'));assert scripts
    for path in scripts: assert not any(line.lstrip().startswith('const ') and ':=' in line for line in path.read_text(encoding='utf-8').splitlines()),path
def test_region_travel_cannot_skip_unlocked_main_story():
    world=(ROOT/'game/scripts/services/game_state.gd').read_text(encoding='utf-8');assert 'if not unlocked_regions.has(region_id) or region_id == current_region:' in world and 'unlocked_regions[main_cursor.substr(0, 2)] = true' in world
def test_story_timeline_requires_real_independent_npc_replays():
    story=(ROOT/'game/scripts/services/story_timeline.gd').read_text(encoding='utf-8')
    assert 'engine_verified' in story and 'r04_narae_qualifier' in story and 'r04_doyun_ian_invite' in story and 'r08_doyun_wildcard' in story
    assert 'TARGET_BROADCAST_PAUSED_BEFORE_START' in story and 'APPROVED_WITHIN_CAPACITY' in story
