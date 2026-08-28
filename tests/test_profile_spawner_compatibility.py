from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_profile_spawner_compatibility.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    compatibility = lua.execute(MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH))
    globals_ = lua.globals()

    lua.execute(
        """
        healthy_loader = { id = "healthy" }
        healthy_spawner = {
            _single_item_profile_loader = healthy_loader,
            _reference_name = "LobbyView_healthy",
            _item_definitions = {},
            reset_count = 0,
            reset = function(self)
                self.reset_count = self.reset_count + 1
                self._single_item_profile_loader = { id = "replacement" }
            end,
        }
        destroyed_spawner = {
            _single_item_profile_loader = nil,
            _reference_name = "LobbyView_destroyed",
            _item_definitions = {},
            reset_count = 0,
            reset = function(self)
                self.reset_count = self.reset_count + 1
                self._single_item_profile_loader = { id = "reinitialized" }
            end,
        }
        unavailable_reset_spawner = { _single_item_profile_loader = nil }
        """
    )

    assert compatibility.prepare_reused_spawner(globals_.healthy_spawner) is False
    assert globals_.healthy_spawner.reset_count == 0
    assert globals_.healthy_spawner._single_item_profile_loader.id == "healthy"
    assert compatibility.prepare_reused_spawner(globals_.destroyed_spawner) is True
    assert globals_.destroyed_spawner.reset_count == 1
    assert globals_.destroyed_spawner._single_item_profile_loader.id == "reinitialized"
    assert compatibility.prepare_reused_spawner(globals_.unavailable_reset_spawner) is False
    assert compatibility.prepare_reused_spawner(None) is False

    lua.execute(
        """
        captured_spawn_hook = nil
        test_mod = {
            hook = function(self, target, method, callback)
                assert(target == test_profile_spawner_class)
                assert(method == "spawn_profile")
                captured_spawn_hook = callback
            end,
        }
        test_profile_spawner_class = { spawn_profile = function() end }
        """
    )

    assert compatibility.install(globals_.test_mod, globals_.test_profile_spawner_class) is True
    assert globals_.captured_spawn_hook is not None
    assert compatibility.install(None, globals_.test_profile_spawner_class) is False
    assert compatibility.install(globals_.test_mod, lua.table_from({})) is False

    lua.execute(
        """
        hook_reused_spawner = {
            _single_item_profile_loader = nil,
            _reference_name = "LobbyView_hook",
            _item_definitions = {},
            reset_count = 0,
            reset = function(self)
                self.reset_count = self.reset_count + 1
                self._single_item_profile_loader = { id = "hook-loader" }
            end,
        }
        original_call_count = 0
        original_loader_id = nil
        original_argument_count = nil
        original_argument_one = nil
        original_argument_two = "not-cleared"
        original_argument_three = nil
        hook_result_one, hook_result_two, hook_result_three = captured_spawn_hook(
            function(self, ...)
                original_call_count = original_call_count + 1
                original_loader_id = self._single_item_profile_loader and self._single_item_profile_loader.id
                original_argument_count = select("#", ...)
                original_argument_one, original_argument_two, original_argument_three = ...
                return "first", nil, "third"
            end,
            hook_reused_spawner,
            "profile",
            nil,
            "future-argument"
        )
        """
    )

    assert globals_.hook_reused_spawner.reset_count == 1
    assert globals_.original_call_count == 1
    assert globals_.original_loader_id == "hook-loader"
    assert globals_.original_argument_count == 3
    assert globals_.original_argument_one == "profile"
    assert globals_.original_argument_two is None
    assert globals_.original_argument_three == "future-argument"
    assert globals_.hook_result_one == "first"
    assert globals_.hook_result_two is None
    assert globals_.hook_result_three == "third"

    print("BetterInventory UI profile-spawner lifecycle compatibility tests passed.")


if __name__ == "__main__":
    main()
