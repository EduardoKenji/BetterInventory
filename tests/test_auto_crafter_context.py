from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CONTEXT_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "auto_crafter"
    / "darktide"
    / "context.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        """
        player_character_id = "character-old"
        profile_character_id = "character-old"
        profile_archetype = "veteran"
        test_player = {
            character_id = function() return player_character_id end,
            profile = function()
                return {
                    character_id = profile_character_id,
                    archetype = {name = profile_archetype},
                }
            end,
        }
        Managers = {
            player = {
                local_player = function() return test_player end,
            },
            state = {
                game_mode = {
                    game_mode_name = function() return "hub" end,
                },
            },
        }
        """
    )
    context_module = lua.execute(
        CONTEXT_PATH.read_text(encoding="utf-8"), name=str(CONTEXT_PATH)
    )
    context = context_module.new()

    identity = context.current_identity(context)
    assert identity.stable is True
    assert identity.character_id == "character-old"
    assert identity.archetype == "veteran"

    # InstantCharacterChange can replace profile before HumanPlayer's exposed
    # character ID settles. Mixed snapshots must never be treated as one valid
    # character or produce a false Games Lantern archetype mismatch.
    lua.globals().profile_character_id = "character-new"
    lua.globals().profile_archetype = "broker"
    identity = context.current_identity(context)
    assert identity.stable is False
    assert identity.reason == "character_context_settling"
    assert context.current_character_id(context) is None
    assert context.current_archetype(context) is None

    lua.globals().player_character_id = "character-new"
    identity = context.current_identity(context)
    assert identity.stable is True
    assert identity.character_id == "character-new"
    assert identity.archetype == "broker"
    assert context.current_character_id(context) == "character-new"
    assert context.current_archetype(context) == "broker"

    # A partially rebuilt player/profile object is unavailable, not a stable
    # identity. Imports and mutations must wait instead of guessing a class.
    lua.globals().profile_archetype = None
    identity = context.current_identity(context)
    assert identity.stable is False
    assert identity.reason == "character_context_unavailable"
    assert context.current_character_id(context) is None
    assert context.current_archetype(context) is None

    # Dependency seams used by tests/compatibility hosts remain supported.
    injected = context_module.new(
        lua.table_from(
            {
                "current_character_id": lua.eval(
                    'function() return "injected-character" end'
                ),
                "current_archetype": lua.eval('function() return "psyker" end'),
            }
        )
    )
    assert injected.current_character_id(injected) == "injected-character"
    assert injected.current_archetype(injected) == "psyker"

    print("Auto Crafter atomic character-context tests passed.")


if __name__ == "__main__":
    main()
