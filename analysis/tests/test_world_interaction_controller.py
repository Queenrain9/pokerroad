from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def test_world_interaction_controller_requires_physical_proximity_and_traversal_service():
    s=(ROOT/'game/scripts/world/world_interaction_controller.gd').read_text(encoding='utf8')
    assert 'nearest_interactable_anchor' in s
    assert 'TraversalService.plan_step' in s
    assert 'runtime.world_runtime.travel_to_anchor' in s
    assert 'scene interaction requires physical proximity to current anchor' in s

def test_game_root_exposes_interaction_bridge_without_embedding_story_rules():
    s=(ROOT/'game/scripts/world/game_root.gd').read_text(encoding='utf8')
    assert 'WorldInteractionController' not in s  # implementation is loaded by file, not copied into root logic
    assert 'world_interaction_controller.gd' in s
    assert 'inspect_world_interaction' in s and 'confirm_world_interaction' in s and 'open_nearby_scene' in s

def test_interaction_controller_does_not_mutate_match_or_q_directly():
    s=(ROOT/'game/scripts/world/world_interaction_controller.gd').read_text(encoding='utf8')
    for forbidden in ['player_q =','player_events[','npc_events[','final_rank','TOWER_CLEAR']:
        assert forbidden not in s
