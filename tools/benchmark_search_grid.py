import json
from pathlib import Path

from lupa import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_search_integration.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        stub_query = {normalize = function(value) return string.lower(tostring(value or "")) end}
        stub_index = {
            new = function() return {} end,
            project = function() return {}, true end,
            invalidate = function() return true end,
            invalidate_all = function() return true end,
            rarity_aliases = function() return {} end,
            release = function() return true end,
        }
        stub_runtime = {
            new = function(dependencies)
                benchmark_runtime = {dependencies = dependencies, states = {}}
                return benchmark_runtime
            end,
        }
        stub_discard = {
            equipped_gear_ids = function() return {} end,
            is_perfect_roll_weapon = function() return false end,
        }
        function get_mod()
            return {io_dofile = function(_, path)
                if string.find(path, "search_query", 1, true) then return stub_query end
                if string.find(path, "search_index", 1, true) then return stub_index end
                if string.find(path, "search_runtime", 1, true) then return stub_runtime end
                if string.find(path, "discard_policy", 1, true) then return stub_discard end
                error(path)
            end}
        end
        function require(path)
            if path == "scripts/utilities/items" then return {is_item_id_favorited = function() return false end} end
            if path == "scripts/backend/master_items" then return {} end
            if path == "scripts/utilities/profile_utils" then return {get_profile_presets = function() return {} end} end
            if path == "scripts/settings/item/rarity_settings" then return {} end
            error(path)
        end
        benchmark_mod = {get = function(_, key)
            if key == "inventory_search_non_match_behavior" then return "dim" end
            if key == "enable_inventory_search" then return true end
            return false
        end}
        '''
    )
    integration = lua.execute(MODULE.read_text(encoding="utf-8"), name=str(MODULE))
    lua.globals().Integration = integration
    result = lua.execute(
        r'''
        local facade = {
            begin_view_session = function() end,
            register_view_session_cleanup = function() end,
        }
        Integration.install(facade, benchmark_mod, {}, function() end, "global")

        local shared_spacing = {is_external = true, widget_type = "spacing_vertical", entry_id = "bottom"}
        local source = {shared_spacing}
        local alignments = {{entry_id = "top"}}
        local widgets_by_id = {top = {alignment_widget = {}}}
        local original_widgets = {}

        for index = 1, 128 do
            local entry_id = "item-" .. tostring(index)
            local entry = {
                entry_id = entry_id,
                item = {gear_id = entry_id},
                native_rank = index,
                search_rank = 0,
            }
            local widget = {entry_id = entry_id, content = {element = entry}}
            source[#source + 1] = entry
            alignments[#alignments + 1] = {entry_id = entry_id}
            widgets_by_id[entry_id] = {widget = widget, alignment_widget = {}}
            original_widgets[index] = widget
        end

        source[#source + 1] = shared_spacing
        alignments[#alignments + 1] = {entry_id = "bottom"}
        widgets_by_id.bottom = {alignment_widget = {}}

        local grid_state = {_selected_grid_index = 1}
        local item_grid = {
            _grid = grid_state,
            _grid_layout = source,
            _all_grid_alignment_widgets = alignments,
            _widgets_by_entry_id = widgets_by_id,
            selected_grid_widget = function() return original_widgets[1] end,
            update_grid_layout = function(self, layout)
                local reordered_widgets = {}
                local reordered_alignments = {}
                self._visible_grid_layout = layout
                for index = 1, #layout do
                    local record = self._widgets_by_entry_id[layout[index].entry_id]
                    if record.alignment_widget then reordered_alignments[#reordered_alignments + 1] = record.alignment_widget end
                    if record.widget then reordered_widgets[#reordered_widgets + 1] = record.widget end
                end
                self._grid_widgets = reordered_widgets
                self._grid_alignment_widgets = reordered_alignments
                self._grid._widgets = reordered_widgets
                self._grid._alignment_list = reordered_alignments
                self._grid._selected_grid_index = 1
            end,
        }
        local view = {
            _item_grid = item_grid,
            _selected_sort_option_index = 1,
            _sort_options = {{sort_function = function(left, right)
                if left.search_rank ~= right.search_rank then return left.search_rank > right.search_rank end
                return left.native_rank < right.native_rank
            end}},
        }

        benchmark_runtime.dependencies.reorder(view)
        collectgarbage("collect")
        local retained_before = collectgarbage("count")
        collectgarbage("stop")
        local allocated_before = collectgarbage("count")
        local started = os.clock()
        for query = 1, 1000 do
            for index = 2, 129 do
                local entry = source[index]
                entry.search_rank = (entry.native_rank + query) % 7 == 0 and 1 or 0
            end
            benchmark_runtime.dependencies.reorder(view)
        end
        local elapsed = os.clock() - started
        local allocated_after = collectgarbage("count")
        collectgarbage("restart")
        collectgarbage("collect")
        local retained_after = collectgarbage("count")
        local identity_preserved = true
        for index = 1, #item_grid._grid_widgets do
            local widget = item_grid._grid_widgets[index]
            if widgets_by_id[widget.entry_id].widget ~= widget then identity_preserved = false break end
        end
        return {
            average_commit_us = elapsed * 1000000 / 1000,
            identity_preserved = identity_preserved,
            retained_kb = retained_after - retained_before,
            transient_kb = allocated_after - allocated_before,
            visible_entries = #item_grid._visible_grid_layout,
        }
        '''
    )
    print(json.dumps({key: round(value, 3) if isinstance(value, float) else value for key, value in result.items()}, sort_keys=True))


if __name__ == "__main__":
    main()
