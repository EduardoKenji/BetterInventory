from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


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
    lua.execute(
        """
        injected_character_calls = 0
        injected_archetype_calls = 0
        injected_character_id = function()
            injected_character_calls = injected_character_calls + 1
            return "injected-character"
        end
        injected_archetype = function()
            injected_archetype_calls = injected_archetype_calls + 1
            return "psyker"
        end
        """
    )
    injected = context_module.new(
        lua.table_from(
            {
                "current_character_id": lua.globals().injected_character_id,
                "current_archetype": lua.globals().injected_archetype,
            }
        )
    )
    assert injected.current_character_id(injected) == "injected-character"
    assert lua.globals().injected_character_calls == 1
    assert lua.globals().injected_archetype_calls == 0
    assert injected.current_archetype(injected) == "psyker"
    assert lua.globals().injected_character_calls == 1
    assert lua.globals().injected_archetype_calls == 1

    injected_identity = injected.current_identity(injected)
    assert injected_identity.character_id == "injected-character"
    assert injected_identity.archetype == "psyker"
    assert lua.globals().injected_character_calls == 2
    assert lua.globals().injected_archetype_calls == 2

    # Psych Ward opens Brunt from character selection without a hub game-mode
    # object. That live vendor view is sufficient runtime authority, but a
    # destroyed/wrong view or active matchmaking still fails closed.
    lua.execute(
        """
        Managers.state.game_mode = nil
        matchmaking_active = false
        Managers.party_immaterium = {
            is_in_matchmaking = function() return matchmaking_active end,
        }
        psych_ward_brunt_view = {__class_name = "CreditsGoodsVendorView"}
        wrong_view = {__class_name = "OtherVendorView"}
        """
    )
    brunt_view = lua.globals().psych_ward_brunt_view
    assert context.is_morningstar(context) is False
    assert context.is_valid_brunt_view(context, brunt_view) is True
    assert context.is_runtime_valid(context, brunt_view) is True
    assert context.is_runtime_valid(context, lua.globals().wrong_view) is False

    brunt_view["_destroyed"] = True
    assert context.is_runtime_valid(context, brunt_view) is False
    brunt_view["_destroyed"] = False
    lua.globals().matchmaking_active = True
    assert context.is_runtime_valid(context, brunt_view) is False

    print("Auto Crafter atomic character-context tests passed.")


if __name__ == "__main__":
    main()
