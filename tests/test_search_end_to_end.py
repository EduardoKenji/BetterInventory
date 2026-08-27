from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"


def load(lua: LuaRuntime, name: str):
    path = RUNTIME_ROOT / name
    return lua.execute(path.read_text(encoding="utf-8"), name=str(path))


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        Utf8 = {
            lower = function(value) return string.lower(value) end,
            string_length = function(value) return #value end,
        }
        math.clamp = math.clamp or function(value, minimum, maximum)
            return math.max(minimum, math.min(maximum, value))
        end
        test_items = {
            expertise_level = function(item) return item.expertise end,
            total_stats_value = function() return 380 end,
            trait_description = function(master_item)
                return master_item and master_item.description or ""
            end,
            is_item_id_favorited = function() return false end,
        }
        function require(path)
            if path == "scripts/utilities/items" then return test_items end
            error(path)
        end
        '''
    )
    query = load(lua, "BetterInventory_search_query.lua")
    index = load(lua, "BetterInventory_search_index.lua")
    runtime = load(lua, "BetterInventory_search_runtime.lua")
    sorting = load(lua, "BetterInventory_feature_sorting.lua")
    lua.globals().Query = query
    lua.globals().Index = index
    lua.globals().Runtime = runtime
    lua.globals().Sorting = sorting

    result = lua.execute(
        r'''
        local master = {
            uncanny = {
                display_name = "Uncanny Strike",
                description = "Uncanny Strike",
                trait = "blessing_uncanny_strike",
            },
            flak = {
                display_name = "Damage vs Flak Armoured Enemies",
                description = "+25% Damage vs Flak Armoured Enemies",
                trait = "weapon_trait_melee_common_wield_increased_armored_damage",
            },
        }
        local master_items = {get_item = function(id) return master[id] end}
        local rarity = {}
        for value = 1, 6 do rarity[value] = {display_name = "rarity_" .. tostring(value)} end
        local view = {
            __class_name = "InventoryWeaponsView",
            family = "inventory",
            _item_grid = {_all_grid_widgets = {}},
            _offer_items_layout = {
                {
                    item = {
                        gear_id = "native-first",
                        display_name = "Combat Sword Mk I",
                        expertise = 500,
                        item_type = "WEAPON_MELEE",
                        rarity = 5,
                        traits = {},
                        perks = {},
                    },
                },
                {
                    item = {
                        gear_id = "searched-shovel",
                        display_name = "Sapper Shovel Mk I",
                        expertise = 1,
                        item_type = "WEAPON_MELEE",
                        rarity = 5,
                        traits = {{id = "uncanny", rarity = 4, value = 1}},
                        perks = {{id = "flak", rarity = 4, value = 1}},
                    },
                },
            },
        }
        for index_value = 1, #view._offer_items_layout do
            view._item_grid._all_grid_widgets[index_value] = {
                content = {alpha_multiplier = 1, entry = view._offer_items_layout[index_value]},
            }
        end

        local search = Runtime.new({
            character_id = function() return "operative" end,
            mode = function() return "dim" end,
            new_index = function()
                active_index = Index.new({
                    items = test_items,
                    localize = function(value) return value end,
                    master_items = master_items,
                    normalize = Query.normalize,
                    rarity_settings = rarity,
                })
                return active_index
            end,
            present = function(target)
                local options = target._sort_options or {}
                local option = options[target._selected_sort_option_index or 1]
                target:_sort_grid_layout(option and option.sort_function)
                return true
            end,
            prioritize_equipped = function() return true end,
            project = Index.project,
            query = Query,
            rarity_aliases = Index.rarity_aliases,
            release_index = Index.release,
            view_family = function(target) return target.family end,
        })
        Runtime.capture_presentation(search, view, "slot_primary", "WEAPON_MELEE", "Primary Weapon")
        Runtime.update(search, view, 1)

        local manager = Sorting.new_comparator_manager({
            begin_view_session = function() end,
            contracts = {
                safe_call = function(callback, ...) return true, callback(...) end,
                safe_method = function() return false, nil end,
            },
            is_armoury_sort_view = function() return false end,
            is_sortable_view = function() return true end,
            perfect_roll_dump_stat_value = function() return nil end,
            register_view_session_cleanup = function() end,
            search_rank = function(target, entry) return Runtime.rank(search, target, entry) end,
        })
        local mod = {get = function() return false end}
        view._sort_options = {{
            sort_function = function(left, right)
                return left.item.expertise > right.item.expertise
            end,
        }}
        manager.configure(mod, view)
        -- Reproduce ItemSorting replacing the option table while leaving
        -- Darktide's convenience pointer on its old, unwrapped comparator.
        view._selected_sort_option_index = 1
        view._selected_sort_option = {
            sort_function = function(left, right)
                return left.item.expertise > right.item.expertise
            end,
        }
        view._sort_grid_layout = function(self, sort_function)
            table.sort(self._item_grid._visible_grid_layout, sort_function)
        end

        local function first_for(query_text, timestamp)
            Runtime.set_query(search, view, query_text, timestamp)
            view._item_grid._visible_grid_layout = {
                view._offer_items_layout[1],
                view._offer_items_layout[2],
            }
            Runtime.update(search, view, timestamp + 0.08)
            local first = view._item_grid._visible_grid_layout[1]
            return first.item.gear_id, Runtime.rank(search, view, first)
        end

        local name_first, name_rank = first_for("shovel", 2)
        local perk_first, perk_rank = first_for("flak", 3)
        local blessing_first, blessing_rank = first_for("uncanny", 4)
        local builds = active_index.metrics.builds
        local hits = active_index.metrics.hits
        Runtime.release(search, view)
        local retained_cache_entries = 0
        for _ in pairs(active_index.cache) do retained_cache_entries = retained_cache_entries + 1 end

        return {
            blessing_first = blessing_first,
            blessing_rank = blessing_rank,
            builds = builds,
            hits = hits,
            name_first = name_first,
            name_rank = name_rank,
            perk_first = perk_first,
            perk_rank = perk_rank,
            retained_cache_entries = retained_cache_entries,
        }
        '''
    )

    assert result.name_first == "searched-shovel" and result.name_rank > 0
    assert result.perk_first == "searched-shovel" and result.perk_rank > 0
    assert result.blessing_first == "searched-shovel" and result.blessing_rank > 0
    assert result.builds == 2
    assert result.hits >= 6
    assert result.retained_cache_entries == 0

    print("BetterInventory production search end-to-end tests passed.")


if __name__ == "__main__":
    main()
