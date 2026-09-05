from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime

ROOT = Path(__file__).resolve().parents[1] / "scripts/mods/BetterInventory/auto_crafter"


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    path = ROOT / "games_lantern/clipboard_host.lua"
    lua.globals().ClipboardHost = lua.execute(path.read_text(encoding="utf-8"), name=str(path))
    lua.execute("""
        assert(select(2, ClipboardHost.read()) == "clipboard_unavailable")
        Clipboard = {}
        assert(select(2, ClipboardHost.read()) == "clipboard_empty")
        Clipboard.get = function() error("unavailable native method") end
        Clipboard.get_text = function() return "copied build" end
        assert(ClipboardHost.read() == "copied build")
        Clipboard.get_text = nil
        Clipboard.read = function() return "alternate bridge" end
        assert(ClipboardHost.read() == "alternate bridge")
        package.preload["scripts/settings/ui/ui_workspace_settings"] = function() return {screen={}} end
        package.preload["scripts/managers/ui/ui_widget"] = function()
            return {create_definition=function(passes) return passes end}
        end
        draws, updates = 0, 0
        function class()
            return {super={
                init=function(self)
                    self._widgets_by_name={status={content={},style={text={size={736,104}}}}}
                    self._ui_scenegraph={status={size={760,112}}}
                end,
                update=function() updates=updates+1 end,
                draw=function() draws=draws+1 end,
            }}
        end
        mode, matchmaking = "hub", false
        Managers = {
            state={game_mode={game_mode_name=function() return mode end}},
            party_immaterium={is_in_matchmaking=function() return matchmaking end},
        }
        revision = 1
        AutoCrafterHelperHudState = {
            enabled=function() return true end,
            presentation=function() return "crafting", 6, revision end,
        }
    """)
    path = ROOT / "darktide/hud_element.lua"
    lua.globals().Hud = lua.execute(path.read_text(encoding="utf-8"), name=str(path))
    lua.execute("""
        local h = {}
        Hud.init(h)
        Hud.draw(h)
        assert(draws == 0)
        Hud.update(h)
        Hud.draw(h)
        assert(draws == 1 and h._visible)
        assert(h._widgets_by_name.status.content.text == "crafting")
        assert(h._ui_scenegraph.status.size[2] == 164)
        Hud.update(h)
        assert(updates == 2)
        matchmaking = true
        Hud.update(h)
        Hud.draw(h)
        assert(not h._visible and draws == 1)
        matchmaking, mode = false, "mission"
        Hud.update(h)
        assert(not h._visible)
        mode, revision = "hub_singleplay", 2
        Hud.update(h)
        assert(h._visible)
        AutoCrafterHelperHudState = nil
        Hud.update(h)
        assert(not h._visible and h._widgets_by_name.status.content.text == "")
    """)
    print("Clipboard host and real HUD lifecycle boundaries passed.")


if __name__ == "__main__":
    main()
