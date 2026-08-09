from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
BACKEND_PATH = RUNTIME_ROOT / "auto_crafter" / "darktide" / "backend.lua"
PLANNER_PATH = RUNTIME_ROOT / "auto_crafter" / "core" / "planner.lua"
PANEL_PATH = RUNTIME_ROOT / "auto_crafter" / "darktide" / "panel.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        local function promise(value, failure)
            return {
                value = value,
                failure = failure,
                next = function(self, callback)
                    if self.failure then
                        return self
                    end

                    local ok, result = pcall(callback, self.value)

                    if not ok then
                        return promise(nil, result)
                    end

                    if type(result) == "table" and type(result.next) == "function" then
                        return result
                    end

                    return promise(result)
                end,
                catch = function(self, callback)
                    if self.failure then
                        return promise(callback(self.failure))
                    end

                    return self
                end,
            }
        end

        local crowbar_template = {
            base_stats = {
                crowbar_p1_m1_dps_stat = {display_name = "loc_stats_display_damage_stat", is_stat_trait = true},
                crowbar_p1_m1_defence_stat = {display_name = "loc_stats_display_defense_stat", is_stat_trait = true},
                crowbar_p1_m1_armor_pierce_stat = {display_name = "loc_stats_display_ap_stat", is_stat_trait = true},
                crowbar_p1_m1_first_target_stat = {display_name = "loc_stats_display_first_target_stat", is_stat_trait = true},
                crowbar_p1_m1_mobility_stat = {display_name = "loc_stats_display_mobility_stat", is_stat_trait = true},
            },
        }
        local crowbar_item = {
            name = "content/items/weapons/player/melee/crowbar_p1_m1",
            display_name = "Crowbar",
            parent_pattern = "crowbar_p1",
            slots = {"slot_primary"},
            weapon_template = "crowbar_p1_m1",
            _weapon_template = crowbar_template,
        }
        local modules = {
            ["scripts/foundation/utilities/promise"] = {
                resolved = function(value) return promise(value) end,
                rejected = function(value) return promise(nil, value) end,
            },
            ["scripts/utilities/items"] = {
                weapon_card_display_name = function(item) return item.display_name end,
                weapon_card_sub_display_name = function() return "" end,
            },
            ["scripts/backend/master_items"] = {
                get_item = function() return crowbar_item end,
                get_store_item_instance = function() error("Brunt lootChoices has no rolled item id") end,
                get_item_instance = function(gear) return gear and gear.base_stats and gear or nil end,
            },
            ["scripts/utilities/weapon/weapon_template"] = {
                weapon_template_from_item = function(item) return item and item._weapon_template end,
            },
            ["scripts/settings/ui/ui_sound_events"] = {},
        }

        function require(name)
            return modules[name]
        end

        local localized = {
            loc_stats_display_damage_stat = "Damage",
            loc_stats_display_defense_stat = "Defenses",
            loc_stats_display_ap_stat = "Penetration",
            loc_stats_display_first_target_stat = "First Target",
            loc_stats_display_mobility_stat = "Mobility",
            loc_stats_display_finesse_stat = "Finesse",
        }

        function Localize(key)
            return localized[key] or key
        end

        TestServices = {
            store = {
                get_credits_goods_store = function()
                    return promise({
                        offers = {
                            {
                                description = {lootChoices = {"crowbar_master"}},
                                offerId = "crowbar_offer",
                                price = {amount = {amount = 11600, type = "credits"}},
                                sku = {category = "weapon"},
                            },
                        },
                    })
                end,
                combined_wallets = function()
                    return promise({wallets = {{balance = {amount = 1000000, type = "credits"}}}})
                end,
                purchase_item = function()
                    return promise({
                        items = {
                            {
                                uuid = "crowbar_gear",
                                name = "content/items/weapons/player/melee/crowbar_p1_m1",
                                display_name = "Crowbar",
                                parent_pattern = "crowbar_p1",
                                rarity = 0,
                                _weapon_template = crowbar_template,
                                base_stats = {
                                    {name = "crowbar_p1_m1_dps_stat", value = 0.78},
                                    {name = "crowbar_p1_m1_defence_stat", value = 0.60},
                                },
                            },
                        },
                    })
                end,
            },
            gear = {
                fetch_gear = function() return promise({}) end,
            },
        }
        '''
    )

    backend_module = lua.execute(BACKEND_PATH.read_text(encoding="utf-8"))
    backend = backend_module.new(lua.table_from({"services": lua.globals().TestServices}))
    snapshot_promise = backend.probe_snapshot(backend)
    assert snapshot_promise.failure is None
    snapshot = snapshot_promise.value
    offer = snapshot.store.offers[1]
    assert len(offer.base_stats) == 5
    stat_keys = {offer.base_stats[index].name: offer.base_stats[index].display_name_key for index in range(1, 6)}
    assert stat_keys["crowbar_p1_m1_dps_stat"] == "loc_stats_display_damage_stat"
    assert stat_keys["crowbar_p1_m1_defence_stat"] == "loc_stats_display_defense_stat"

    purchase_promise = backend.purchase_offer(backend, lua.table_from({"offerId": "crowbar_offer"}))
    assert purchase_promise.failure is None
    purchased = purchase_promise.value["items"][1]
    assert purchased.damage == 78
    assert purchased.base_stats["crowbar_p1_m1_dps_stat"] == 78

    planner = lua.execute(PLANNER_PATH.read_text(encoding="utf-8"))

    def plan(dump_stat: str):
        return planner.build(
            snapshot,
            lua.table_from(
                {
                    "target_offer": offer,
                    "dump_stat": dump_stat,
                    "cap_by_dockets": True,
                    "docket_cap": 1000000,
                }
            ),
        )

    legacy_auto_plan = plan("auto")
    assert len(legacy_auto_plan.dump_stat_candidates) == 5
    ordered_names = [legacy_auto_plan.dump_stat_candidates[index].name for index in range(1, 6)]
    assert ordered_names == [
        "crowbar_p1_m1_dps_stat",
        "crowbar_p1_m1_mobility_stat",
        "crowbar_p1_m1_first_target_stat",
        "crowbar_p1_m1_armor_pierce_stat",
        "crowbar_p1_m1_defence_stat",
    ]
    assert legacy_auto_plan.resolved_dump_stat == "crowbar_p1_m1_dps_stat"
    assert planner.default_dump_stat(legacy_auto_plan) == "crowbar_p1_m1_dps_stat"
    defense_plan = plan("defenses")
    assert defense_plan.resolved_dump_stat == "crowbar_p1_m1_defence_stat"
    penetration_plan = plan("penetration")
    assert penetration_plan.resolved_dump_stat == "crowbar_p1_m1_armor_pierce_stat"

    lua.execute(
        '''
        TestPanelSettings = {
            value = "crowbar_p1_m1_defence_stat",
            get = function(self, _) return self.value end,
            set = function(self, _, value) self.value = value return true end,
        }
        '''
    )
    panel_module = lua.execute(PANEL_PATH.read_text(encoding="utf-8"))
    panel = panel_module.new(lua.table_from({"settings": lua.globals().TestPanelSettings}))
    panel._plan = defense_plan
    panel_options = panel._planner_dump_stat_options(panel)
    assert [panel_options[index] for index in range(1, len(panel_options) + 1)] == ordered_names
    assert "auto" not in [panel_options[index] for index in range(1, len(panel_options) + 1)]
    stat_buttons = panel._planner_dump_stat_buttons(panel)
    assert len(stat_buttons) == 5
    assert [stat_buttons[index].name for index in range(1, 6)] == ordered_names
    assert stat_buttons[1].label == "Damage"
    assert stat_buttons[2].label == "Mobility"
    grid_entry = panel._entry(
        panel,
        "",
        "",
        lua.table_from(
            {"variant": "stat_grid", "selectable": True, "stat_buttons": stat_buttons}
        ),
    )
    widget_content = lua.table_from(
        {f"stat_hotspot_{index}": lua.table_from({}) for index in range(1, 6)}
    )
    widget = lua.table_from({"content": widget_content})
    grid_entry.bind(widget)
    grid_entry.refresh(widget)
    assert grid_entry.initial_content.selectable is True
    assert widget.content.selected_stat_index == 5
    widget.content.stat_pressed_callbacks[1]()
    grid_entry.refresh(widget)
    assert lua.globals().TestPanelSettings.value == "crowbar_p1_m1_dps_stat"
    assert widget.content.selected_stat_index == 1
    assert panel._planner_dump_stat_text(panel) == "Damage"
    assert panel._planner_dump_stat_label(panel, "crowbar_p1_m1_defence_stat") == "Defenses"
    panel._plan = lua.table_from(
        {
            "dump_stat_candidates": lua.table_from(
                [
                    lua.table_from(
                        {
                            "name": "dual_shivs_p1_m1_finesse_stat",
                            "display_name_key": "loc_stats_display_finesse_stat",
                        }
                    )
                ]
            )
        }
    )
    assert panel._planner_dump_stat_label(panel, "dual_shivs_p1_m1_finesse_stat") == "Finesse"

    print("Auto Crafter weapon stat catalogue and display-label tests passed.")


if __name__ == "__main__":
    main()
