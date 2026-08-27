import json
import sys
from pathlib import Path

from lupa import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_search_ui.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        Utf8 = {string_length = function(value) return #(value or "") end}
        table.clone = function(value) return value end
        function require(path)
            if path == "scripts/managers/ui/ui_widget" then
                return {create_definition = function() return {} end}
            elseif path == "scripts/ui/pass_templates/text_input_pass_templates" then
                return {simple_input_field = {}}
            end
            error(path)
        end
        '''
    )
    search_ui = lua.execute(MODULE.read_text(encoding="utf-8"), name=str(MODULE))
    lua.globals().SearchUI = search_ui
    lua.globals().BENCHMARK_FRAMES = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
    result = lua.execute(
        r'''
        local settings = {
            enable_inventory_search = true,
            inventory_search_focus_keybind = "off",
        }
        local mod = {
            get = function(_, key) return settings[key] end,
            localize = function(_, key) return key end,
        }
        local Features = {
            search_set_query = function() error("settled field must not resubmit") end,
        }
        local view = {
            _using_cursor_navigation = true,
            _widgets_by_name = {
                better_inventory_search_input = {
                    content = {
                        hotspot = {},
                        input_text = "shovel",
                        is_writing = false,
                    },
                    visible = true,
                },
            },
        }
        local input_service = {
            has = function() return false end,
            get = function() error("disabled actions must not be read") end,
        }
        SearchUI.update(mod, Features, view, 1)
        collectgarbage("collect")
        collectgarbage("stop")
        local allocated_before = collectgarbage("count")
        local started = os.clock()
        for frame = 1, BENCHMARK_FRAMES do
            SearchUI.update(mod, Features, view, frame)
            SearchUI.handle_view_input(mod, view, input_service)
            if view._better_inventory_search_needs_update then
                error("settled view unexpectedly requested runtime work")
            end
        end
        local elapsed = os.clock() - started
        local allocated_after = collectgarbage("count")
        collectgarbage("restart")
        SearchUI.release(view)
        collectgarbage("collect")
        return {
            average_us = elapsed * 1000000 / BENCHMARK_FRAMES,
            frames = BENCHMARK_FRAMES,
            total_ms = elapsed * 1000,
            transient_kb = allocated_after - allocated_before,
        }
        '''
    )
    print(json.dumps({key: round(value, 3) for key, value in result.items()}, sort_keys=True))


if __name__ == "__main__":
    main()
