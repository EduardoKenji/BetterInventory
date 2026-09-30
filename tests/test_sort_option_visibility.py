from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / "scripts/mods/BetterInventory"


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    path = RUNTIME / "BetterInventory_feature_sort_options.lua"
    lua.globals().Options = lua.execute(path.read_text(encoding="utf-8"), name=str(path))
    domains_path = RUNTIME / "BetterInventory_feature_domains.lua"
    lua.globals().Domains = lua.execute(domains_path.read_text(encoding="utf-8"), name=str(domains_path))
    lua.execute('''
        localize_calls = 0
        Localize = function(key, _, args)
            localize_calls = localize_calls+1
            return key .. (args and ":" .. args.sort_name or "")
        end
        settings = {}
        mod = {get=function(_, key) return settings[key] end}
        local definitions = {modded_methods={inventory={}, store={}}}
        Options.configure({sorting={definitions=function() return definitions end}})
        options = {}
        local native = {
            {"level_desc", "item_power", "high_low"}, {"level_asc", "item_power", "low_high"},
            {"rarity_desc", "rarity", "high_low"}, {"rarity_asc", "rarity", "low_high"},
            {"price_asc", "item_price", "low_high"}, {"price_desc", "item_price", "high_low"},
            {"name_asc", "name", "increasing_letters"}, {"name_desc", "name", "decreasing_letters"},
        }
        for _, row in ipairs(native) do
            options[#options+1] = {id=row[1], display_name=Localize(
                "loc_inventory_item_grid_sort_title_format_" .. row[3], true,
                {sort_name=Localize("loc_inventory_item_grid_sort_title_" .. row[2])}),
                sort_function=function() end}
            settings["sort_option_" .. row[1]] = true
        end
        for _, id in ipairs({"category", "category_mark", "base_level_desc", "base_level_asc"}) do
            local option = {id=id, display_name="localized custom " .. id, sort_function=function() end}
            options[#options+1] = option
            definitions.modded_methods.inventory[#definitions.modded_methods.inventory+1] = option
            settings["sort_option_" .. id] = true
        end
        grid = {_sort_options=options, _active_sort_index=1}
        -- All-on defaults preserve native arguments; missing settings are enabled too.
        assert(Options.next_index(mod, grid, nil) == nil)
        assert(Options.next_index(mod, grid, 99) == 99)
        for i=1,#options do assert(Options.is_visible(mod, options, i)) end
        assert(Options.is_visible(mod, {{display_name="unknown"}}, 1))
        settings.sort_option_name_asc = nil
        assert(Options.is_visible(mod, options, 7))
        for _, option in ipairs(options) do settings["sort_option_" .. option.id] = false end
        settings.sort_option_name_asc, settings.sort_option_rarity_desc = true, true
        assert(Options.next_index(mod, grid, 1) == 3)
        grid._active_sort_index = 3
        assert(Options.next_index(mod, grid) == 7)
        grid._active_sort_index = 7
        assert(Options.next_index(mod, grid) == 3)
        assert(Options.next_index(mod, grid, 7) == 7)
        assert(Options.next_index(mod, grid, 99) == 3)
        for i=1,#options do assert(Options.is_visible(mod, options, i) == (i == 3 or i == 7)) end
        assert(not Options.any_visible(mod, options, 9, 12))
        -- Selecting only a custom choice still uses its original index.
        settings.sort_option_name_asc, settings.sort_option_rarity_desc = false, false
        settings.sort_option_category_mark = true
        assert(Options.next_index(mod, grid, 1) == 10)
        settings.sort_option_category_mark = false
        -- All hidden: one safe fallback; no empty list or endless cycle.
        for i=1,#options do assert(Options.is_visible(mod, options, i) == (i == 7)) end
        assert(Options.next_index(mod, grid, 1) == 7)
        local no_name = {options[1], options[3]}
        assert(Options.is_visible(mod, no_name, 1) and not Options.is_visible(mod, no_name, 2))
        assert(Options.next_index(mod, {_sort_options={}}, nil) == nil)
        options[13] = {display_name="unknown extension", sort_function=function() end}
        assert(Options.next_index(mod, grid, 1) == 13)
        assert(not Options.is_visible(mod, options, 7))
        options[13] = nil
        -- Obsolete master settings must not override individual choices.
        settings.customize_sort_options = false
        assert(Options.next_index(mod, grid, 1) == 7 and #options == 12)
        assert(settings.sort_option_name_asc == false)
    ''')

    # Execute the installed hook, including unsupported/auxiliary grid guards.
    lua.execute('''
        ViewElementGrid = {_cb_on_sort_button_pressed=function() end}
        mod.hook = function(_, _, method, fn) sort_hook = fn end
        native_calls = 0
        native = function(target, index, sentinel)
            native_calls = native_calls+1
            assert(sentinel == "forwarded")
            passed_index = index
            return "native result", 42
        end
    ''')
    lua.globals().Options.install(lua.globals().mod, lua.globals().ViewElementGrid, lua.globals().Domains.grid_scope.resolve)
    lua.execute('''
        local view = {__class_name="InventoryWeaponsView", _item_grid=grid}
        grid._parent = view
        local a,b = sort_hook(native, grid, nil, "forwarded")
        assert(a == "native result" and b == 42 and passed_index == 7)
        for _, class in ipairs({"InventoryWeaponsView", "CreditsVendorView",
            "MarksVendorView", "CraftingMechanicusModifyView"}) do
            view.__class_name = class
            sort_hook(native, grid, 1, "forwarded")
            assert(passed_index == 7)
        end
        view.__class_name = "CosmeticsView"
        sort_hook(native, grid, 1, "forwarded")
        assert(passed_index == 1)
        view.__class_name = "InventoryWeaponsView"
        local auxiliary = {_parent=view, _sort_options=options}
        sort_hook(native, auxiliary, 1, "forwarded")
        assert(passed_index == 1)
        assert(grid._sort_options == options and #options == 12)
        assert(options[7].id == "name_asc" and type(options[7].sort_function) == "function")
    ''')
    print("Sort visibility, native indices, fallback and runtime scope checks passed.")


if __name__ == "__main__":
    main()
