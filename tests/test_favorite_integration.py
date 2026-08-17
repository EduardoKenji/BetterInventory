from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_favorite_integration.lua"
)
RUNTIME_PATH = MODULE_PATH.with_name("BetterInventory_runtime.lua")
AUTO_CRAFTER_ROOT = MODULE_PATH.parent / "auto_crafter"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r"""
        function math.clamp(value, minimum, maximum)
            return math.max(minimum, math.min(maximum, value))
        end

        favorite_calls = {}
        TestItems = {
            set_item_id_as_favorite = function(gear_id, state)
                table.insert(favorite_calls, {gear_id = gear_id, state = state})
            end,
        }

        local color_values = {
            orange = {255, 255, 128, 0},
            lawn_green = {255, 124, 252, 0},
            deep_sky_blue = {255, 0, 191, 255},
            blue_violet = {255, 138, 43, 226},
            deep_pink = {255, 255, 20, 147},
        }
        Color = setmetatable({}, {
            __index = function(_, color_name)
                return function()
                    return color_values[color_name]
                end
            end,
        })

        myfavorites_settings = {
            favorite_item_list = {},
            color_definition_1 = "orange",
            color_definition_2 = "lawn_green",
            color_definition_3 = "deep_sky_blue",
            color_definition_4 = "blue_violet",
            color_definition_5 = "deep_pink",
        }
        myfavorites = {
            enabled = true,
            is_enabled = function(self) return self.enabled end,
            get = function(self, setting_id) return myfavorites_settings[setting_id] end,
            set = function(self, setting_id, value) myfavorites_settings[setting_id] = value end,
        }
        globalstore = {
            character_avatar_data = {
                ["armoury-global-offer"] = {character_id = "armoury-owner"},
            },
            character_avatar_data_contracts = {
                ["melk-global-offer"] = {character_id = "melk-owner"},
            },
        }
        save_records = {}
        save_queue_calls = 0
        Managers = {
            save = {
                character_data = function(self, character_id)
                    save_records[character_id] = save_records[character_id] or {}
                    return save_records[character_id]
                end,
                queue_save = function(self)
                    save_queue_calls = save_queue_calls + 1
                end,
            },
        }

        settings = {
            armoury_auto_favorite_purchased_items = false,
            melk_auto_favorite_purchased_items = false,
            melk_mystery_auto_favorite_purchased_items = false,
            automatic_curio_favorite_purchased_curios = false,
            auto_crafter_myfavorites_color = 3,
        }
        test_mod = {
            get = function(self, setting_id) return settings[setting_id] end,
            localize = function(self, localization_id) return localization_id end,
            hook_safe = function(self, class, method_name, callback)
                local original = class[method_name]
                class[method_name] = function(instance, ...)
                    local result = original(instance, ...)
                    callback(instance, ...)
                    return result
                end
            end,
        }

        function get_mod(mod_name)
            if mod_name == "MyFavorites" then
                return myfavorites
            elseif mod_name == "GlobalStore" then
                return globalstore
            end
        end

        function require(path)
            if path == "scripts/utilities/items" then
                return TestItems
            end
            error("unexpected require: " .. tostring(path))
        end
        """
    )

    module = lua.execute(MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH))
    globals_ = lua.globals()

    assert module.is_myfavorites_available() is True
    preview = module.color_preview(globals_.test_mod, 3)
    assert "{#color(0,191,255)}" in preview
    assert "auto_crafter_myfavorites_color_3" in preview
    assert "■" in preview
    globals_.myfavorites_settings.color_definition_5 = "missing-color"
    assert module.color_preview(globals_.test_mod, 5) == "auto_crafter_myfavorites_color_5"

    purchase_items = lua.execute(
        'return {{uuid = "curio-a"}, {gear_id = "weapon-b"}, {uuid = "curio-a"}, {item = {gearId = "weapon-c"}}, "direct-item"}'
    )
    assert module.favorite_purchase_items(
        globals_.test_mod,
        purchase_items,
        "automatic_curio_favorite_purchased_curios",
    ) == 0
    assert len(globals_.favorite_calls) == 0
    globals_.settings.automatic_curio_favorite_purchased_curios = True
    assert module.favorite_purchase_items(
        globals_.test_mod,
        purchase_items,
        "automatic_curio_favorite_purchased_curios",
    ) == 4
    assert [globals_.favorite_calls[index].gear_id for index in range(1, 5)] == [
        "curio-a",
        "weapon-b",
        "weapon-c",
        "direct-item",
    ]

    globals_.myfavorites_settings.favorite_item_list = False
    assert module.apply_auto_crafter_color(globals_.test_mod, "crafted-weapon") is True
    assert globals_.myfavorites_settings.favorite_item_list["crafted-weapon"] == 3
    globals_.settings.auto_crafter_myfavorites_color = 1
    assert module.apply_auto_crafter_color(globals_.test_mod, "crafted-weapon") is True
    assert globals_.myfavorites_settings.favorite_item_list["crafted-weapon"] is None

    armoury_class, brunt_class, melk_class, melk_goods_class = lua.execute(
        r"""
        local function vendor_class()
            return {
                _on_purchase_complete = function(self, items)
                    self.native_completions = (self.native_completions or 0) + 1
                end,
            }
        end
        return vendor_class(), vendor_class(), vendor_class(), vendor_class()
        """
    )
    module.install_manual_purchase_hooks(
        globals_.test_mod,
        lua.table_from(
            {
                "armoury": armoury_class,
                "melk_limited": melk_class,
                "melk_mystery": melk_goods_class,
            }
        ),
    )
    module.install_manual_purchase_hooks(
        globals_.test_mod,
        lua.table_from(
            {
                "armoury": armoury_class,
                "melk_limited": melk_class,
                "melk_mystery": melk_goods_class,
            }
        ),
    )
    globals_.settings.armoury_auto_favorite_purchased_items = True
    globals_.settings.melk_auto_favorite_purchased_items = True
    armoury_instance = lua.table_from({})
    brunt_instance = lua.table_from({})
    melk_instance = lua.table_from({})
    melk_goods_instance = lua.table_from({})
    armoury_class._on_purchase_complete(armoury_instance, lua.execute('return {items = {{uuid = "armoury-item"}}}'))
    brunt_class._on_purchase_complete(brunt_instance, lua.execute('return {{uuid = "brunt-item"}}'))
    melk_class._on_purchase_complete(melk_instance, lua.execute('return {{uuid = "melk-item"}}'))
    melk_goods_class._on_purchase_complete(melk_goods_instance, lua.execute('return {{uuid = "melk-goods-item"}}'))
    assert armoury_instance.native_completions == 1
    assert brunt_instance.native_completions == 1
    assert melk_instance.native_completions == 1
    assert melk_goods_instance.native_completions == 1
    assert [globals_.favorite_calls[index].gear_id for index in range(5, 7)] == [
        "armoury-item",
        "melk-item",
    ]

    armoury_global_instance = lua.table_from(
        {
            "_optional_store_service": "get_all_characters_store_custom",
            "_previewed_offer": lua.table_from({"offerId": "armoury-global-offer"}),
        }
    )
    melk_global_instance = lua.table_from(
        {
            "_optional_store_service": "get_all_characters_marks_store_custom",
            "_previewed_offer": lua.table_from({"offerId": "melk-global-offer"}),
        }
    )
    unresolved_global_instance = lua.table_from(
        {
            "_optional_store_service": "get_all_characters_store_custom",
            "_previewed_offer": lua.table_from({"offerId": "missing-global-offer"}),
        }
    )
    unrelated_armoury_instance = lua.table_from(
        {"_optional_store_service": "third_party_credits_store"}
    )
    unrelated_melk_instance = lua.table_from(
        {"_optional_store_service": "third_party_marks_store"}
    )
    armoury_class._on_purchase_complete(
        armoury_global_instance, lua.execute('return {{uuid = "armoury-global-item"}}')
    )
    melk_class._on_purchase_complete(
        melk_global_instance, lua.execute('return {{uuid = "melk-global-item"}}')
    )
    armoury_class._on_purchase_complete(
        unresolved_global_instance, lua.execute('return {{uuid = "unresolved-global-item"}}')
    )
    armoury_class._on_purchase_complete(
        unrelated_armoury_instance, lua.execute('return {{uuid = "unrelated-armoury-item"}}')
    )
    melk_class._on_purchase_complete(
        unrelated_melk_instance, lua.execute('return {{uuid = "unrelated-melk-item"}}')
    )
    assert len(globals_.favorite_calls) == 6
    assert globals_.save_records["armoury-owner"].favorite_items["armoury-global-item"] is True
    assert globals_.save_records["melk-owner"].favorite_items["melk-global-item"] is True
    assert globals_.save_queue_calls == 2
    assert armoury_global_instance.native_completions == 1
    assert melk_global_instance.native_completions == 1
    assert unresolved_global_instance.native_completions == 1
    assert unrelated_armoury_instance.native_completions == 1
    assert unrelated_melk_instance.native_completions == 1

    globals_.settings.melk_mystery_auto_favorite_purchased_items = True
    melk_goods_class._on_purchase_complete(melk_goods_instance, lua.execute('return {{uuid = "melk-mystery-item"}}'))
    assert melk_goods_instance.native_completions == 2
    assert globals_.favorite_calls[7].gear_id == "melk-mystery-item"

    globals_.myfavorites.enabled = False
    assert module.is_myfavorites_available() is False
    assert module.apply_auto_crafter_color(globals_.test_mod, "disabled-item") is False

    runtime_source = RUNTIME_PATH.read_text(encoding="utf-8")
    assert "armoury = CreditsVendorView" in runtime_source
    assert "armoury = {" not in runtime_source
    assert "melk_limited = MarksVendorView" in runtime_source
    assert "melk_mystery = MarksGoodsVendorView" in runtime_source
    assert '"get_all_characters_store_custom"' in MODULE_PATH.read_text(encoding="utf-8")
    assert '"get_all_characters_marks_store_custom"' in MODULE_PATH.read_text(encoding="utf-8")

    # Manual-vendor preferences must never enter Auto Crafter's backend purchase
    # pipeline. Only its own favorite_result setting may favorite an exact,
    # authoritatively revalidated result; rejected rolls remain discardable.
    auto_crafter_source = "\n".join(
        path.read_text(encoding="utf-8") for path in AUTO_CRAFTER_ROOT.rglob("*.lua")
    )
    for setting_id in (
        "armoury_auto_favorite_purchased_items",
        "melk_auto_favorite_purchased_items",
        "melk_mystery_auto_favorite_purchased_items",
    ):
        assert setting_id not in auto_crafter_source


if __name__ == "__main__":
    main()
