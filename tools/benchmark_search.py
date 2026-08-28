import json
import sys
from pathlib import Path

from lupa import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / "scripts" / "mods" / "BetterInventory"


def load(lua: LuaRuntime, name: str):
    path = RUNTIME / name
    return lua.execute(path.read_text(encoding="utf-8"), name=str(path))


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        Utf8 = {
            lower = function(value) return string.lower(value) end,
            string_length = function(value) return #value end,
        }
        '''
    )
    query = load(lua, "BetterInventory_search_query.lua")
    index = load(lua, "BetterInventory_search_index.lua")
    runtime = load(lua, "BetterInventory_search_runtime.lua")
    lua.globals().Query = query
    lua.globals().Index = index
    lua.globals().Runtime = runtime
    lua.globals().BENCHMARK_MODE = sys.argv[1] if len(sys.argv) > 1 else "dim"
    result = lua.execute(
        r'''
        local master = {
            blessing = {display_name = "Uncanny Strike", trait = "blessing_uncanny"},
            flak = {display_name = "Damage vs Flak Armoured Enemies", trait = "weapon_trait_melee_common_wield_increased_armored_damage"},
            unyielding = {display_name = "Damage vs Unyielding Enemies", trait = "weapon_trait_melee_common_wield_increased_resistant_damage"},
        }
        local master_items = {get_item = function(id) return master[id] end}
        local items = {
            expertise_level = function(item) return item.expertise end,
            is_item_id_favorited = function() return false end,
            total_stats_value = function() return 380 end,
            trait_description = function(item)
                if item.trait == "blessing_uncanny" then
                    return string.rep("expanded blessing description ", 12)
                elseif string.find(item.trait, "armored", 1, true) then
                    return "+25% Damage vs Flak Armoured Enemies"
                end
                return "+25% Damage vs Unyielding Enemies"
            end,
        }
        local rarity = {}
        for value = 1, 6 do rarity[value] = {display_name = "rarity_" .. tostring(value)} end
        local function new_index()
			benchmark_index = Index.new({
                compact_perk_search_terms = function(id, description)
                    if string.find(id or "", "armored", 1, true) then
                        return "+25% Flak Damage", "+25% Flak Dmg"
                    elseif string.find(id or "", "resistant", 1, true) then
                        return "+25% Unyielding Damage", "+25% Unyielding Dmg"
                    end
                    return description, description
                end,
                items = items,
                localize = function(value) return value end,
                master_items = master_items,
                normalize = Query.normalize,
                rarity_settings = rarity,
			})

			return benchmark_index
        end
        local view = {
            character = "benchmark",
            family = "inventory",
            _item_grid = {_all_grid_widgets = {}},
            _offer_items_layout = {},
        }
        for item_number = 1, 128 do
            local item = {
                gear_id = "gear-" .. tostring(item_number),
                id = "weapon-" .. tostring(item_number),
                display_name = item_number % 2 == 0 and "Sapper Shovel" or "Combat Blade",
                expertise = 500,
                item_type = "WEAPON_MELEE",
                rarity = 5,
                base_stats = {
                    {name = "damage", value = 0.8},
                    {name = "finesse", value = 0.8},
                    {name = "mobility", value = 0.6},
                },
                traits = {{id = "blessing", rarity = 4, value = 1}},
                perks = {
                    {id = "flak", rarity = 4, value = 1},
                    {id = "unyielding", rarity = 4, value = 1},
                },
            }
            local entry = {item = item}
            view._offer_items_layout[item_number] = entry
            view._item_grid._all_grid_widgets[item_number] = {
                content = {alpha_multiplier = 1, entry = entry},
            }
        end
        local search = Runtime.new({
            character_id = function(target) return target.character end,
            mode = function() return BENCHMARK_MODE end,
            new_index = new_index,
            present = function() return true end,
            prioritize_equipped = function() return true end,
            project = Index.project,
            query = Query,
            rarity_aliases = Index.rarity_aliases,
            release_index = Index.release,
            view_family = function(target) return target.family end,
        })
        local terms = {"flak", "unyielding", "shovel", "uncanny", "perk:flak", "500", "surgi"}
        collectgarbage("collect")
        local projection_before = collectgarbage("count")
        Runtime.capture_presentation(search, view, "slot", "weapon", "Weapons")
		collectgarbage("stop")
		local warm_total_seconds = 0
		local warm_max_seconds = 0
		for frame = 1, 8 do
			local warm_started = os.clock()
			Runtime.update(search, view, frame / 60)
			local warm_seconds = os.clock() - warm_started
			warm_total_seconds = warm_total_seconds + warm_seconds
			warm_max_seconds = math.max(warm_max_seconds, warm_seconds)
		end
		local cached_before_collection = 0
		for _ in pairs(benchmark_index.cache) do cached_before_collection = cached_before_collection + 1 end
		collectgarbage("restart")
        collectgarbage("collect")
        local retained_before = collectgarbage("count")
		local cached_after_projection = 0
		for _ in pairs(benchmark_index.cache) do cached_after_projection = cached_after_projection + 1 end

		collectgarbage("stop")
		local compile_allocated_before = collectgarbage("count")
		local compile_started = os.clock()
		for iteration = 1, 400 do
			Query.compile(terms[(iteration - 1) % #terms + 1])
		end
		local compile_seconds = os.clock() - compile_started
		local compile_allocated_after = collectgarbage("count")
		collectgarbage("restart")
		collectgarbage("collect")

        collectgarbage("stop")
        local allocated_before = collectgarbage("count")
        local started = os.clock()
        for iteration = 1, 400 do
            Runtime.set_query(search, view, terms[(iteration - 1) % #terms + 1], iteration)
        end
        local query_seconds = os.clock() - started
        local allocated_after = collectgarbage("count")
		local settle_started = os.clock()
		Runtime.update(search, view, 400.08)
		local settle_seconds = os.clock() - settle_started
		local settled_allocated_after = collectgarbage("count")
		local index_hits_after_settle = benchmark_index.metrics.hits
		local gated_idle_started = os.clock()
		for frame = 1, 6000 do
			if view._better_inventory_search_needs_update then
				Runtime.update(search, view, 900 + frame / 60)
			end
		end
		local gated_idle_seconds = os.clock() - gated_idle_started
        local idle_started = os.clock()
        for frame = 1, 6000 do Runtime.update(search, view, 1000 + frame / 60) end
        local idle_seconds = os.clock() - idle_started
		collectgarbage("restart")
		collectgarbage("collect")
		local settled_series_retained_before = collectgarbage("count")
		collectgarbage("stop")
		local settled_series_allocated_before = collectgarbage("count")
		local settled_series_started = os.clock()
		for iteration = 1, 100 do
			local timestamp = 1200 + iteration
			Runtime.set_query(search, view, terms[(iteration - 1) % #terms + 1] .. " " .. tostring(iteration), timestamp)
			Runtime.update(search, view, timestamp + 0.08)
		end
		local settled_series_seconds = os.clock() - settled_series_started
		local settled_series_allocated_after = collectgarbage("count")
		collectgarbage("restart")
		collectgarbage("collect")
		local settled_series_retained_after = collectgarbage("count")
        collectgarbage("restart")
        Runtime.release(search, view)
        collectgarbage("collect")
        local retained_after = collectgarbage("count")
        return {
			compile_400_queries_ms = compile_seconds * 1000,
			compile_transient_kb = compile_allocated_after - compile_allocated_before,
			idle_6000_frames_ms = idle_seconds * 1000,
			idle_average_us = idle_seconds * 1000000 / 6000,
			production_gated_idle_6000_frames_ms = gated_idle_seconds * 1000,
			index_builds = benchmark_index.metrics.builds,
			cached_after_projection = cached_after_projection,
			cached_before_collection = cached_before_collection,
			index_hits_after_settle = index_hits_after_settle,
            projection_retained_kb = retained_before - projection_before,
			query_burst_400_changes_ms = query_seconds * 1000,
			query_burst_transient_kb = allocated_after - allocated_before,
			settle_once_ms = settle_seconds * 1000,
			settle_once_transient_kb = settled_allocated_after - allocated_after,
			settled_100_queries_ms = settled_series_seconds * 1000,
			settled_query_average_ms = settled_series_seconds * 10,
			settled_100_queries_transient_kb = settled_series_allocated_after - settled_series_allocated_before,
			settled_100_queries_retained_kb = settled_series_retained_after - settled_series_retained_before,
			warm_128_max_slice_ms = warm_max_seconds * 1000,
			warm_128_total_ms = warm_total_seconds * 1000,
            retained_after_release_kb = retained_after - retained_before,
        }
        '''
    )
    print(
        json.dumps(
            {key: round(value, 3) for key, value in result.items()},
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
