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
                trait_category = function() return "crowbar_traits" end,
                trait_description = function(item, rarity)
                    return string.format(item.trait_text, rarity)
                end,
            },
            ["scripts/backend/master_items"] = {
                get_item = function(name)
                    if name == "perk_flak" then
                        return {name = name, display_name = "internal/perk/path", trait_text = "+25%% Damage vs Flak Armoured (T%d)"}
                    end

                    return crowbar_item
                end,
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
            crafting = {
                get_item_crafting_metadata = function()
                    return promise({perks = {
                        [1] = {rarity = 1, perks = {"perk_flak"}},
                        [4] = {rarity = 4, perks = {"perk_flak"}},
                    }})
                end,
                trait_sticker_book = function() return promise({}) end,
            },
            mastery = {
                get_mastery_by_pattern = function()
                    return promise({current_xp = 0, mastery_level = 0, milestones = {{level = 1, xpLimit = 100}}})
                end,
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

    catalog_promise = backend.discover_weapon_catalog(backend, offer)
    assert catalog_promise.failure is None
    assert catalog_promise.value.perk_count == 1
    assert catalog_promise.value.perks[1].display_name == "+25% Damage vs Flak Armoured (T4)"
    assert catalog_promise.value.perks[1].tier == 4

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
    assert penetration_plan.estimate.base_level_min == 290
    assert penetration_plan.estimate.base_level_max == 330
    assert penetration_plan.estimate.dockets_floor == 11600
    assert penetration_plan.estimate.dockets_cap == 1000000
    assert penetration_plan.estimate.purchase_count_cap == 86

    rarity_costs = lua.table_from(
        {
            str(rarity): lua.table_from(
                [
                    lua.table_from({"type": "plasteel", "amount": 10}),
                    lua.table_from({"type": "diamantine", "amount": 2}),
                ]
            )
            for rarity in range(5)
        }
    )
    expertise_costs = lua.table_from(
        {
            str(bucket): lua.table_from(
                [lua.table_from({"type": "plasteel", "amount": 1})]
            )
            for bucket in range(290, 501, 10)
        }
    )
    snapshot.crafting_costs = lua.table_from(
        {
            "available": True,
            "weapon": lua.table_from(
                {
                    "baseItemLevelSpan": lua.table_from({"min": 1, "max": 380}),
                    "costScalingSpan": lua.table_from({"min": 1, "max": 1}),
                    "rarityUpgrade": lua.table_from(
                        {"startCost": rarity_costs}
                    ),
                    "addExpertise": lua.table_from(
                        {"startCost": expertise_costs}
                    ),
                }
            ),
        }
    )
    material_plan = plan("penetration")
    assert material_plan.estimate.plasteel_min == 210
    assert material_plan.estimate.plasteel_max == 250
    assert material_plan.estimate.diamantine_min == 8
    assert material_plan.estimate.diamantine_max == 8
    assert material_plan.estimate.phases.consecrate.plasteel_min == 40
    assert material_plan.estimate.phases.expertise.plasteel_min == 170

    snapshot.crafting_costs.sacrifice_mastery = lua.table_from(
        {
            "sacrifice_muiltiplier": 1,
            "minimumExpertiseLevel": 0,
            "baseReward": 0,
            "masteryXpPerExpertiseLevel": 10,
        }
    )
    mastery_plan = planner.build(
        snapshot,
        lua.table_from(
            {
                "target_offer": offer,
                "dump_stat": "penetration",
                "cap_by_dockets": True,
                "docket_cap": 1000000,
                "level_mastery_20": True,
                "trait_catalog": lua.table_from(
                    {
                        "mastery": lua.table_from(
                            {
                                "current_xp": 0,
                                "milestones": lua.table_from(
                                    [
                                        lua.table_from(
                                            {"level": level, "xpLimit": level * 500}
                                        )
                                        for level in range(1, 21)
                                    ]
                                ),
                            }
                        )
                    }
                ),
            }
        ),
    )
    assert mastery_plan.estimate.phases.mastery.count_min == 30
    assert mastery_plan.estimate.phases.mastery.count_max == 34
    assert mastery_plan.estimate.phases.mastery.dockets_min == 348000
    assert mastery_plan.estimate.phases.mastery.dockets_max == 394400

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

    lua.execute(
        '''
        TraitSettings = {
            values = {
                auto_crafter_perk_1_target = "keep",
                auto_crafter_perk_2_target = "stale_trait",
                auto_crafter_blessing_1_target = "keep",
                auto_crafter_blessing_2_target = "keep",
            },
            get = function(self, key) return self.values[key] end,
            set = function(self, key, value) self.values[key] = value return true end,
        }
        '''
    )
    trait_panel = panel_module.new(lua.table_from({"settings": lua.globals().TraitSettings}))
    trait_panel._plan = lua.table_from(
        {
            "trait_catalog": lua.table_from(
                {
                    "available": True,
                    "parent_pattern": "crowbar_p1",
                    "perks": lua.table_from(
                        [
                            lua.table_from(
                                {
                                    "id": "perk_damage_t4",
                                    "display_name": "+25% Damage vs Flak Armoured Enemies",
                                    "display_name_key": "loc_stats_display_damage_stat",
                                    "tier": 4,
                                }
                            )
                        ]
                    ),
                    "blessings": lua.table_from(
                        [
                            lua.table_from(
                                {
                                    "id": "blessing_power",
                                    "display_name_key": "loc_stats_display_finesse_stat",
                                }
                            )
                        ]
                    ),
                }
            )
        }
    )
    perk_options = trait_panel._trait_target_options(trait_panel, "auto_crafter_perk_1_target")
    assert [perk_options[index].value for index in range(1, len(perk_options) + 1)] == [
        "keep",
        "auto",
        "perk:perk_damage_t4:4",
    ]
    assert perk_options[3].label == "+25% Damage vs Flak Armoured Enemies"
    trait_panel._step_trait_target(trait_panel, "auto_crafter_perk_1_target", 1)
    assert lua.globals().TraitSettings["values"].auto_crafter_perk_1_target == "auto"
    trait_panel._step_trait_target(trait_panel, "auto_crafter_perk_1_target", 1)
    assert lua.globals().TraitSettings["values"].auto_crafter_perk_1_target == "perk:perk_damage_t4:4"
    trait_panel._reconcile_trait_targets(trait_panel)
    assert lua.globals().TraitSettings["values"].auto_crafter_perk_2_target == "keep"

    lua.execute("RenderCalls = 0")
    trait_panel.render = lua.eval("function() RenderCalls = RenderCalls + 1 return true end")
    trait_panel.set_phase(trait_panel, "plan_preview")
    assert lua.globals().RenderCalls == 0
    assert trait_panel._layout_pending is True
    assert trait_panel._layout_defer_frames == 1

    panel_source = PANEL_PATH.read_text(encoding="utf-8")
    assert "length_scrolled" in panel_source
    assert "restore_scroll_offset" in panel_source
    assert "set_scrollbar_progress" in panel_source
    assert 'add_checkbox("auto_crafter_change_perks"' in panel_source
    assert 'self:_setting("auto_crafter_level_mastery_20", false) == true and self:_setting("auto_crafter_change_perks", false) == true' in panel_source
    backend_source = BACKEND_PATH.read_text(encoding="utf-8")
    assert "Items.trait_description" in backend_source
    assert "tier == maximum_tier" in backend_source

    print("Auto Crafter weapon stat catalogue and display-label tests passed.")


if __name__ == "__main__":
    main()
