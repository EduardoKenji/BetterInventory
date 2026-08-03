from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
FEATURES_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_features.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r"""
        function table.clone(value)
            if type(value) ~= "table" then
                return value
            end

            local copy = {}

            for key, child in pairs(value) do
                copy[table.clone(key)] = table.clone(child)
            end

            return setmetatable(copy, getmetatable(value))
        end

        Color = setmetatable({}, {
            __index = function()
                return function(alpha)
                    return {alpha or 255, 200, 210, 190}
                end
            end,
        })
		function math.clamp(value, minimum, maximum)
			return math.max(minimum, math.min(maximum, value))
		end
		function Localize(value)
			return value
		end

		TestItems = {
			favorites = {},
			expertise_level = function(item)
				if item.unreadable then
					error("legacy item has no readable expertise data")
				end

				-- Match Darktide's real two-value API: the second result reports
				-- whether the item carried a baseItemLevel value.
				return tostring(item.expertise or item.level or 0), true
			end,
			max_expertise_level = function()
				return 500
			end,
			preview_stats_change = function(item, expertise_increase, stats)
				local result = {}

				for index = 1, #stats do
					local stat = stats[index]
					local projected_value = item.projected_values and item.projected_values[index] or math.floor((stat.fraction or 0) * 100 + 0.5)

					result[stat.display_name] = {
						value = projected_value,
					}
				end

				return result
			end,
			is_weapon = function(item_type)
				return item_type == "WEAPON_MELEE" or item_type == "WEAPON_RANGED"
			end,
            is_item_id_favorited = function(gear_id)
                return TestItems.favorites[gear_id] == true
            end,
			total_stats_value = function(item)
				return item.total_stats
			end,
        }
		TestRaritySettings = {}
		for index = 1, 5 do
			TestRaritySettings[index] = {
				color = {255, 100 + index, 110 + index, 120 + index},
				display_name = "rarity_" .. index,
			}
		end
        TestUIWidget = {
            create_definition = function(pass_template, scenegraph_id, content)
                content.hotspot = content.hotspot or {}

                return {
                    pass_template = pass_template,
                    scenegraph_id = scenegraph_id,
                    content = content,
                }
            end,
        }
        TestSoundEvents = {
            default_mouse_hover = "hover",
            default_click = "click",
        }
		captured_popup = nil
		captured_discard_ids = nil
		captured_notification = nil
		Managers = {
			event = {
				trigger = function(self, event_name, payload, secondary_payload)
					if event_name == "event_show_ui_popup" then
						captured_popup = payload
					elseif event_name == "event_discard_items" then
						captured_discard_ids = payload
					elseif event_name == "event_add_notification_message" and payload == "custom" then
						captured_notification = secondary_payload
					end
				end,
			},
		}
        function require(path)
            if path == "scripts/utilities/items" then
                return TestItems
			elseif path == "scripts/settings/item/rarity_settings" then
				return TestRaritySettings
            elseif path == "scripts/managers/ui/ui_widget" then
                return TestUIWidget
            elseif path == "scripts/settings/ui/ui_sound_events" then
                return TestSoundEvents
            end

            error("Unexpected test require: " .. tostring(path))
        end

        test_mod = {
            settings = {
                prioritize_equipped_favorites = true,
            },
            get = function(self, setting_id)
                return self.settings[setting_id]
            end,
            set = function(self, setting_id, value)
                self.settings[setting_id] = value
            end,
            localize = function(self, localization_id)
                return localization_id
            end,
        }
        test_layout = {
            slot_kind = function(view)
                return view.slot_kind
            end,
        }
        """
    )
    features = lua.execute(FEATURES_PATH.read_text(encoding="utf-8"))
    globals_ = lua.globals()
    mod = globals_.test_mod
    layout = globals_.test_layout

    definitions = lua.table_from(
        {
            "scenegraph_definition": lua.table_from({}),
            "widget_definitions": lua.table_from({}),
            "grid_settings": lua.table_from(
                {"grid_size": lua.table_from([620, 860])}
            ),
        }
    )
    view = lua.execute(
        r"""
        return {
            __class_name = "InventoryWeaponsView",
            slot_kind = "curio",
        }
        """
    )
    adjusted = features.add_inventory_sort_toggle_definition(mod, layout, definitions, view)
    toggle_id = "better_inventory_sort_priority"
    sort_label_id = "better_inventory_sort_label"
    assert adjusted.scenegraph_definition[toggle_id].parent == "weapon_stats_pivot"
    assert adjusted.scenegraph_definition[sort_label_id].position[2] == 500
    assert adjusted.scenegraph_definition[toggle_id].position[1] == 15
    assert adjusted.scenegraph_definition[toggle_id].position[2] == 528
    assert (
        adjusted.widget_definitions[sort_label_id].content.label
        == "inventory_sorting_inventory_label"
    )
    assert (
        adjusted.widget_definitions[toggle_id].content.label
        == "prioritize_equipped_favorites_inventory_label"
    )

    view._ui_scenegraph = adjusted.scenegraph_definition
    view._set_scenegraph_position = lua.eval(
        """
        function(self, scenegraph_id, x, y)
            local position = self._ui_scenegraph[scenegraph_id].position

            position[1] = x
            position[2] = y
            self.position_set_with_view_api = true
            self._update_scenegraph = true
        end
        """
    )
    view._weapon_stats = lua.table_from(
        {
            "_menu_settings": lua.table_from(
                {"grid_size": lua.table_from([530, 920])}
            ),
            "_ui_scenegraph": lua.table_from(
                {
                    "grid_background_pivot": lua.table_from(
                        {"position": lua.table_from([0, 13, 0])}
                    ),
                    "grid_background": lua.table_from(
                        {
                            "position": lua.table_from([0, 0, 0]),
                            "size": lua.table_from([530, 430]),
                        }
                    ),
                    "grid_divider_bottom": lua.table_from(
                        {
                            "position": lua.table_from([0, 16, 0]),
                            "size": lua.table_from([530, 36]),
                        }
                    ),
                    "grid_divider_bottom_weapon": lua.table_from(
                        {
                            "position": lua.table_from([0, 0, 0]),
                            "size": lua.table_from([530, 36]),
                        }
                    )
                }
            ),
            "grid_length": lua.eval("function() return 475 end"),
        }
    )
    features.update_inventory_sort_toggle(mod, layout, view)
    assert adjusted.scenegraph_definition[sort_label_id].position[1] == 0
    assert adjusted.scenegraph_definition[sort_label_id].position[2] == 474
    assert adjusted.scenegraph_definition[toggle_id].position[1] == 15
    assert adjusted.scenegraph_definition[toggle_id].position[2] == 502
    assert view.position_set_with_view_api is True
    assert view._update_scenegraph is True

    melee_view = lua.execute(
        r"""
        return {
            __class_name = "InventoryWeaponsView",
            slot_kind = "slot_primary",
        }
        """
    )
    melee_definitions = features.add_inventory_sort_toggle_definition(
        mod, layout, definitions, melee_view
    )
    assert (
        melee_definitions.scenegraph_definition[toggle_id].parent
        == "weapon_compare_stats_pivot"
    )
    melee_view._ui_scenegraph = melee_definitions.scenegraph_definition
    melee_view._weapon_options_element = lua.table_from(
        {
            "_menu_settings": lua.table_from(
                {"grid_size": lua.table_from([420, 270])}
            )
        }
    )
    features.update_inventory_sort_toggle(mod, layout, melee_view)
    assert melee_definitions.scenegraph_definition[sort_label_id].position[1] == 20
    assert melee_definitions.scenegraph_definition[sort_label_id].position[2] == 285
    assert melee_definitions.scenegraph_definition[toggle_id].position[1] == 35
    assert melee_definitions.scenegraph_definition[toggle_id].position[2] == 313

    ranged_view = lua.execute(
        r"""
        return {
            __class_name = "InventoryWeaponsView",
            slot_kind = "slot_secondary",
        }
        """
    )
    ranged_definitions = features.add_inventory_sort_toggle_definition(
        mod, layout, definitions, ranged_view
    )
    assert (
        ranged_definitions.scenegraph_definition[toggle_id].parent
        == "weapon_compare_stats_pivot"
    )

    sortable_view = lua.execute(
        r"""
        return {
            __class_name = "InventoryWeaponsView",
            slot_kind = "curio",
            is_item_equipped_in_any_slot = function(self, item)
                return item.equipped == true
            end,
            _sort_options = {
                {
                    sort_function = function(left, right)
                        return left.item.rating > right.item.rating
                    end,
                },
            },
        }
        """
    )
    globals_.TestItems.favorites.favorite = True
    features.configure_inventory_sort_options(mod, layout, sortable_view)
    sorted_ids = lua.execute(
        r"""
        local view, ordinary, favorite, equipped = ...
        local entries = {ordinary, favorite, equipped}

        table.sort(entries, view._sort_options[1].sort_function)

        return entries[1].item.gear_id, entries[2].item.gear_id, entries[3].item.gear_id
        """,
        sortable_view,
        lua.table_from(
            {"item": lua.table_from({"gear_id": "ordinary", "rating": 100, "slots": lua.table_from(["slot_attachment_1"])})}
        ),
        lua.table_from(
            {"item": lua.table_from({"gear_id": "favorite", "rating": 10, "slots": lua.table_from(["slot_attachment_1"])})}
        ),
        lua.table_from(
            {
                "item": lua.table_from(
                    {"gear_id": "equipped", "rating": 1, "equipped": True, "slots": lua.table_from(["slot_attachment_1"])}
                )
            }
        ),
    )
    assert sorted_ids == ("equipped", "favorite", "ordinary")

    mod.settings.prioritize_equipped_favorites = False
    rating_first = lua.execute(
        r"""
        local view, high, low = ...
        return view._sort_options[1].sort_function(high, low)
        """,
        sortable_view,
        lua.table_from({"item": lua.table_from({"gear_id": "high", "rating": 100})}),
        lua.table_from(
            {
                "item": lua.table_from(
                    {"gear_id": "low", "rating": 1, "equipped": True, "slots": lua.table_from(["slot_attachment_1"])}
                )
            }
        ),
    )
    assert rating_first is True

    mod.settings.prioritize_equipped_favorites = True
    sortable_view._widgets_by_name = lua.table_from(
        {toggle_id: adjusted.widget_definitions[toggle_id]}
    )
    melee_view._widgets_by_name = lua.table_from(
        {toggle_id: melee_definitions.widget_definitions[toggle_id]}
    )
    sortable_view._selected_sort_option_index = 1
    sortable_view._sort_grid_layout = lua.eval(
        "function(self, sort_function) self.resorted = sort_function ~= nil end"
    )
    melee_view._sort_options = sortable_view._sort_options
    melee_view._selected_sort_option_index = 1
    melee_view._sort_grid_layout = lua.eval(
        "function(self, sort_function) self.resorted = sort_function ~= nil end"
    )
    features.bind_inventory_sort_toggle(mod, layout, sortable_view)
    features.bind_inventory_sort_toggle(mod, layout, melee_view)
    sortable_view._widgets_by_name[toggle_id].content.hotspot.pressed_callback()
    assert mod.settings.prioritize_equipped_favorites is False
    assert sortable_view.resorted is True
    assert melee_view.resorted is True
    assert sortable_view._widgets_by_name[toggle_id].content.checked is False
    assert melee_view._widgets_by_name[toggle_id].content.checked is False

    mod.settings.prioritize_equipped_favorites = True
    features.sync_inventory_sort_setting(mod, layout)
    assert sortable_view._widgets_by_name[toggle_id].content.checked is True
    assert melee_view._widgets_by_name[toggle_id].content.checked is True

    sortable_view.resorted = False
    sortable_view._discard_items_element = lua.table_from({})
    mod.settings.prioritize_equipped_favorites = False
    features.sync_inventory_sort_setting(mod, layout)
    assert sortable_view._widgets_by_name[toggle_id].content.checked is False
    assert sortable_view.resorted is False

    sortable_view._discard_items_element = None
    features.resort_inventory(mod, layout, sortable_view)
    assert sortable_view.resorted is True

    mod.settings.prioritize_equipped_favorites = True
    features.sync_inventory_sort_setting(mod, layout)

    mod.settings.quick_discard_rarity = 1
    mod.settings.quick_discard_max_item_level = 500
    mod.settings.quick_discard_include_melee = True
    mod.settings.quick_discard_include_ranged = True
    mod.settings.quick_discard_include_curios = True
    mod.settings.quick_discard_protect_perfect_weapons = True
    mod.settings.quick_discard_protect_high_level_curios = True
    mod.settings.quick_discard_curio_protection_level = 410
    mod.settings.quick_discard_show_type_breakdown = True
    mod.settings.quick_discard_show_summary_notification = True
    mod.settings.quick_discard_mode = "manual"
    mod.settings.quick_discard_skip_automatic_confirmation = False
    quick_discard_view = lua.execute(
        r"""
        return {
            __class_name = "InventoryWeaponsView",
            slot_kind = "slot_primary",
            is_item_equipped_in_any_slot = function(self, item)
                return item.equipped == true
            end,
            _offer_items_layout = {},
        }
        """
    )
    quick_discard_view._offer_items_layout = lua.table_from(
        [
            lua.table_from(
                {
                    "item": lua.table_from(
                        {
                            "gear_id": "eligible",
                            "item_type": "WEAPON_MELEE",
                            "level": 300,
                            "rarity": 1,
                            "total_stats": 300,
                            "base_stats": lua.table_from([1, 2, 3, 4, 5]),
                            "slots": lua.table_from(["slot_primary"]),
                        }
                    )
                }
            ),
            lua.table_from(
                {
                    "item": lua.table_from(
                        {
                            "gear_id": "perfect",
                            "item_type": "WEAPON_MELEE",
                            "level": 500,
                            "rarity": 1,
                            "total_stats": 380,
                            "base_stats": lua.table_from(
                                [
                                    lua.table_from({"value": 0.8}),
                                    lua.table_from({"value": 0.8}),
                                    lua.table_from({"value": 0.8}),
                                    lua.table_from({"value": 0.8}),
                                    lua.table_from({"value": 0.6}),
                                ]
                            ),
                            "slots": lua.table_from(["slot_primary"]),
                        }
                    )
                }
            ),
            lua.table_from(
                {
                    "item": lua.table_from(
                        {
                            "gear_id": "equipped_candidate",
                            "item_type": "WEAPON_MELEE",
                            "level": 250,
                            "rarity": 1,
                            "total_stats": 250,
                            "equipped": True,
                            "slots": lua.table_from(["slot_primary"]),
                        }
                    )
                }
            ),
        ]
    )
    candidates = features.quick_discard_candidates(mod, layout, quick_discard_view)
    assert len(candidates) == 1
    assert candidates[1].gear_id == "eligible"
    assert features.is_perfect_roll_weapon(quick_discard_view._offer_items_layout[2].item) is True
    anomalous_perfect_roll = lua.table_from(
        {
            "item_type": "WEAPON_MELEE",
            "total_stats": 380,
            "base_stats": lua.table_from(
                [
                    lua.table_from({"value": 0.7975}),
                    lua.table_from({"value": 0.7975}),
                    lua.table_from({"value": 0.7975}),
                    lua.table_from({"value": 0.7975}),
                    lua.table_from({"value": 0.61}),
                ]
            ),
        }
    )
    assert features.is_perfect_roll_weapon(anomalous_perfect_roll) is True
    anomalous_62_perfect_roll = lua.table_from(
        {
            "item_type": "WEAPON_RANGED",
            "total_stats": 380,
            "base_stats": lua.table_from(
                [
                    lua.table_from({"value": 0.795}),
                    lua.table_from({"value": 0.795}),
                    lua.table_from({"value": 0.795}),
                    lua.table_from({"value": 0.795}),
                    lua.table_from({"value": 0.62}),
                ]
            ),
        }
    )
    assert features.is_perfect_roll_weapon(anomalous_62_perfect_roll) is True
    nonperfect_380_roll = lua.table_from(
        {
            "item_type": "WEAPON_MELEE",
            "total_stats": 380,
            "base_stats": lua.table_from(
                [
                    lua.table_from({"value": 0.79}),
                    lua.table_from({"value": 0.79}),
                    lua.table_from({"value": 0.79}),
                    lua.table_from({"value": 0.79}),
                    lua.table_from({"value": 0.64}),
                ]
            ),
        }
    )
    assert features.is_perfect_roll_weapon(nonperfect_380_roll) is False

    underpowered_perfect_roll = lua.table_from(
        {
            "item_type": "WEAPON_MELEE",
            "expertise": 330,
            "total_stats": 280,
            "projected_values": lua.table_from([80, 80, 80, 80, 60]),
            "base_stats": lua.table_from(
                [
                    lua.table_from({"name": "damage", "value": 0.6}),
                    lua.table_from({"name": "mobility", "value": 0.6}),
                    lua.table_from({"name": "finesse", "value": 0.6}),
                    lua.table_from({"name": "penetration", "value": 0.6}),
                    lua.table_from({"name": "defence", "value": 0.4}),
                ]
            ),
        }
    )
    assert features.is_perfect_roll_weapon(underpowered_perfect_roll) is True

    underpowered_nonperfect_roll = lua.table_from(
        {
            "item_type": "WEAPON_RANGED",
            "expertise": 330,
            "total_stats": 280,
            "projected_values": lua.table_from([80, 80, 79, 79, 62]),
            "base_stats": underpowered_perfect_roll.base_stats,
        }
    )
    assert features.is_perfect_roll_weapon(underpowered_nonperfect_roll) is False

    features.request_quick_discard(mod, layout, quick_discard_view)
    assert quick_discard_view._better_inventory_discard_pending is True
    assert globals_.captured_popup.title_text_unlocalized == "quick_discard_confirmation_title"
    globals_.TestItems.favorites.eligible = True
    globals_.captured_popup.options[1].callback()
    assert quick_discard_view._better_inventory_discard_pending is False
    assert globals_.captured_discard_ids is None

    globals_.TestItems.favorites.eligible = False
    globals_.captured_notification = None
    features.request_quick_discard(mod, layout, quick_discard_view)
    globals_.captured_popup.options[1].callback()
    assert globals_.captured_discard_ids[1] == "eligible"
    assert globals_.captured_notification.line_1 == "quick_discard_notification_title"
    assert "- 1 rarity_1 quick_discard_notification_items" in globals_.captured_notification.line_2
    assert "{#color(101,111,121)}" in globals_.captured_notification.line_2

    globals_.captured_notification = None
    mod.settings.quick_discard_show_summary_notification = False
    features.request_quick_discard(mod, layout, quick_discard_view)
    globals_.captured_popup.options[1].callback()
    assert globals_.captured_notification is None
    mod.settings.quick_discard_show_summary_notification = True

    quick_discard_view._parent = lua.table_from(
        {
            "_inventory_items": lua.table_from(
                {
                    "global_melee": lua.table_from(
                        {
                            "gear_id": "global_melee",
                            "item_type": "WEAPON_MELEE",
                            "level": 300,
                            "rarity": 1,
                            "total_stats": 300,
                            "slots": lua.table_from(["slot_primary"]),
                        }
                    ),
                    "global_ranged": lua.table_from(
                        {
                            "gear_id": "global_ranged",
                            "item_type": "WEAPON_RANGED",
                            "level": 300,
                            "rarity": 1,
                            "total_stats": 300,
                            "slots": lua.table_from(["slot_secondary"]),
                        }
                    ),
                    "global_curio": lua.table_from(
                        {
                            "gear_id": "global_curio",
                            "item_type": "GADGET",
                            "level": 300,
                            "rarity": 1,
                            "slots": lua.table_from(["slot_trinket_1"]),
                        }
                    ),
                }
            )
        }
    )
    global_candidates = features.quick_discard_candidates(mod, layout, quick_discard_view)
    assert len(global_candidates) == 3
    features.request_quick_discard(mod, layout, quick_discard_view)
    confirmation_description = globals_.captured_popup.description_text_unlocalized
    assert "quick_discard_summary_melee_singular" in confirmation_description
    assert "quick_discard_summary_ranged_singular" in confirmation_description
    assert "quick_discard_summary_curio_singular" in confirmation_description
    globals_.captured_popup.options[2].callback()
    mod.settings.quick_discard_show_type_breakdown = False
    features.request_quick_discard(mod, layout, quick_discard_view)
    assert (
        "quick_discard_summary_melee_singular"
        not in globals_.captured_popup.description_text_unlocalized
    )
    globals_.captured_popup.options[2].callback()
    mod.settings.quick_discard_show_type_breakdown = True

    mod.settings.enable_experimental_quick_discard = True
    experimental_definitions = features.add_inventory_sort_toggle_definition(
        mod, layout, definitions, quick_discard_view
    )
    curio_experimental_definitions = features.add_inventory_sort_toggle_definition(
        mod, layout, definitions, view
    )
    assert experimental_definitions.scenegraph_definition["better_inventory_quick_discard"] is not None
    assert experimental_definitions.scenegraph_definition["better_inventory_discard_protection"] is not None
    assert experimental_definitions.scenegraph_definition["better_inventory_discard_curio_protection"] is not None
    assert experimental_definitions.scenegraph_definition["better_inventory_discard_curio_level"] is not None
    assert experimental_definitions.scenegraph_definition["better_inventory_discard_label"] is not None
    assert experimental_definitions.scenegraph_definition["better_inventory_discard_max_level"] is not None
    assert experimental_definitions.scenegraph_definition["better_inventory_discard_melee"] is not None
    assert experimental_definitions.scenegraph_definition["better_inventory_discard_ranged"] is not None
    assert experimental_definitions.scenegraph_definition["better_inventory_discard_curio"] is not None
    assert experimental_definitions.scenegraph_definition["better_inventory_discard_mode"] is not None
    assert experimental_definitions.scenegraph_definition["better_inventory_discard_skip_confirmation"] is not None
    assert experimental_definitions.scenegraph_definition["better_inventory_quick_discard"].size[1] == 405
    assert curio_experimental_definitions.scenegraph_definition["better_inventory_quick_discard"].size[1] == 405
    assert curio_experimental_definitions.scenegraph_definition["better_inventory_discard_max_level"].size[1] == 405
    assert curio_experimental_definitions.scenegraph_definition["better_inventory_discard_label"].size[1] == 530
    assert (
        experimental_definitions.scenegraph_definition["better_inventory_quick_discard"].position[1]
        == experimental_definitions.scenegraph_definition[toggle_id].position[1]
    )
    assert (
        experimental_definitions.widget_definitions["better_inventory_discard_label"].content.label
        == "inventory_manual_discard_management_inventory_label"
    )
    quick_discard_passes = experimental_definitions.widget_definitions[
        "better_inventory_quick_discard"
    ].pass_template
    rarity_hotspot_pass = next(
        quick_discard_passes[index]
        for index in range(1, len(quick_discard_passes) + 1)
        if quick_discard_passes[index].content_id == "rarity_hotspot"
    )
    nested_visible_content = lua.eval("{parent = {visible = true}}")
    assert rarity_hotspot_pass.visibility_function(nested_visible_content) is True

    quick_discard_view._ui_scenegraph = experimental_definitions.scenegraph_definition
    quick_discard_view._widgets_by_name = experimental_definitions.widget_definitions
    quick_discard_view._weapon_options_element = lua.table_from(
        {"_menu_settings": lua.table_from({"grid_size": lua.table_from([420, 300])})}
    )
    features.bind_inventory_sort_toggle(mod, layout, quick_discard_view)
    assert (
        quick_discard_view._widgets_by_name[
            "better_inventory_discard_skip_confirmation"
        ].content.visible
        is False
    )
    quick_discard_view._widgets_by_name[
        "better_inventory_discard_mode"
    ].content.hotspot.pressed_callback()
    assert mod.settings.quick_discard_mode == "automatic"
    assert (
        quick_discard_view._widgets_by_name[
            "better_inventory_discard_label"
        ].content.label
        == "inventory_automated_discard_management_inventory_label"
    )
    assert (
        quick_discard_view._widgets_by_name[
            "better_inventory_discard_skip_confirmation"
        ].content.visible
        is True
    )
    quick_discard_view._widgets_by_name[
        "better_inventory_discard_skip_confirmation"
    ].content.hotspot.pressed_callback()
    assert mod.settings.quick_discard_skip_automatic_confirmation is True
    quick_discard_view._widgets_by_name[
        "better_inventory_discard_max_level"
    ].content.decrease_hotspot.pressed_callback()
    assert mod.settings.quick_discard_max_item_level == 490
    assert (
        quick_discard_view._widgets_by_name[
            "better_inventory_discard_max_level"
        ].content.value
        == "490"
    )
    quick_discard_view._widgets_by_name[
        "better_inventory_discard_ranged"
    ].content.hotspot.pressed_callback()
    assert mod.settings.quick_discard_include_ranged is False
    assert (
        quick_discard_view._widgets_by_name[
            "better_inventory_discard_ranged"
        ].content.checked
        is False
    )

    quick_discard_view._better_inventory_grid_expansion = 80
    quick_discard_view._weapon_stats = view._weapon_stats
    quick_discard_view._discard_items_element = lua.table_from({})
    features.update_inventory_sort_toggle(mod, layout, quick_discard_view)
    assert quick_discard_view._widgets_by_name[sort_label_id].content.visible is True
    assert quick_discard_view._widgets_by_name[toggle_id].content.visible is True
    assert quick_discard_view._widgets_by_name["better_inventory_discard_label"].content.visible is False
    assert quick_discard_view._widgets_by_name["better_inventory_quick_discard"].content.visible is False
    assert quick_discard_view._widgets_by_name["better_inventory_discard_max_level"].content.visible is False
    assert quick_discard_view._ui_scenegraph[sort_label_id].position[1] == -646
    assert quick_discard_view._ui_scenegraph[sort_label_id].position[2] == 474
    assert quick_discard_view._ui_scenegraph[toggle_id].position[1] == -631
    assert quick_discard_view._ui_scenegraph[toggle_id].position[2] == 502

    quick_discard_view._discard_items_element = None
    features.update_inventory_sort_toggle(mod, layout, quick_discard_view)
    assert quick_discard_view._widgets_by_name["better_inventory_discard_label"].content.visible is True
    assert quick_discard_view._widgets_by_name["better_inventory_quick_discard"].content.visible is True
    assert quick_discard_view._ui_scenegraph[sort_label_id].position[1] == 20

    # The scalable-panel prototype must retain the legacy widgets as a fallback,
    # present the same synchronized controls inside one managed grid, collapse
    # sections by rebuilding rows, and reduce to Sorting in native discard mode.
    mod.settings.enable_inventory_options_panel_prototype = True
    mod.settings.quick_discard_mode = "manual"

    # Reclaim only the oversized Curio preview header in this inventory view.
    curio_stats_grid, curio_stats_blueprints = lua.execute(
        r"""
        local parent = {__class_name = "InventoryWeaponsView"}
        local weapon_stats = {
            _parent = parent,
            _item = {item_type = "GADGET"},
        }

        parent._weapon_stats = weapon_stats

        return weapon_stats, {
            gadget_header = {
                size = {518, 250},
                pass_template = {
                    {style_id = "icon", style = {size = {466, 180}, offset = {0, 30, 3}}},
                    {style_id = "loading", style = {size = {80, 80}, offset = {0, 10, 3}}},
                    {style_id = "gradient_background", style = {size = {518, 125}, offset = {0, 0, 1}}},
                },
            },
        }
        """
    )
    compact_curio_blueprints = features.compact_inventory_curio_stats_blueprints(
        mod, curio_stats_grid, curio_stats_blueprints
    )
    assert compact_curio_blueprints.gadget_header.size[2] == 190
    assert compact_curio_blueprints.gadget_header.pass_template[1].style.size[2] == 125
    assert compact_curio_blueprints.gadget_header.pass_template[1].style.offset[2] == 20
    assert compact_curio_blueprints.gadget_header.pass_template[2].style.size[1] == 60
    assert compact_curio_blueprints.gadget_header.pass_template[3].style.size[2] == 95
    assert curio_stats_blueprints.gadget_header.size[2] == 250

    prototype_view = lua.execute(
        r"""
        local scenegraph, widgets, weapon_stats = ...

        return {
            __class_name = "InventoryWeaponsView",
            slot_kind = "slot_primary",
            _better_inventory_grid_expansion = 80,
            _ui_scenegraph = scenegraph,
            _widgets_by_name = widgets,
            _weapon_stats = weapon_stats,
            _weapon_options_element = {
                _menu_settings = {
                    grid_size = {420, 300},
                },
            },
            _scenegraph_world_position = function(self, scenegraph_id)
                return {100, 60, 3}
            end,
            _add_element = function(self, class, reference_name, layer, settings)
                local panel = {
                    _parent = self,
                    menu_settings = settings,
                    visible = false,
                }

                function panel:disable_input(disabled)
                    self.input_disabled = disabled
                end

                function panel:set_visibility(visible)
                    self.visible = visible
                end

                function panel:set_pivot_offset(x, y)
                    self.pivot_x = x
                    self.pivot_y = y
                end

                function panel:update_grid_height(grid_height, mask_height)
                    self.grid_height = grid_height
                    self.mask_height = mask_height
                end

                function panel:present_grid_layout(layout, blueprints)
                    self.layout = layout
                    self.widgets = {}

                    for index = 1, #layout do
                        local entry = layout[index]
                        local content = {}
                        local style = {}

                        for pass_index = 1, #entry.pass_template do
                            local pass = entry.pass_template[pass_index]

                            if pass.content_id then
                                content[pass.content_id] = table.clone(pass.content or {})
                            end

                            if pass.style_id then
                                style[pass.style_id] = table.clone(pass.style or {})
                            end
                        end

                        local widget = {
                            content = content,
                            style = style,
                        }

                        blueprints[entry.widget_type].init(self, widget, entry)
                        self.widgets[entry.control_id] = widget
                    end
                end

                self.prototype_panel = panel

                return panel
            end,
            _remove_element = function(self)
                self.prototype_panel_removed = true
            end,
        }
        """,
        experimental_definitions.scenegraph_definition,
        experimental_definitions.widget_definitions,
        view._weapon_stats,
    )
    fake_view_element_grid = lua.table_from({})
    assert (
        features.setup_inventory_options_panel(
            mod, layout, prototype_view, fake_view_element_grid
        )
        is True
    )
    features.bind_inventory_sort_toggle(mod, layout, prototype_view)
    prototype_panel = prototype_view.prototype_panel
    assert prototype_panel.visible is True
    assert prototype_panel.input_disabled is False
    # Managed ViewElementGrid rows render through an off-screen resource target.
    # Sharing the parent renderer makes the terminal frame visible while leaving
    # that target blank when the inventory view already owns another masked grid.
    assert prototype_panel.menu_settings.use_parent_ui_renderer is None
    assert len(prototype_panel.layout) == 10
    assert prototype_panel.grid_height == 360
    assert prototype_panel.pivot_x == 120
    assert prototype_panel.pivot_y == 375
    assert prototype_view._widgets_by_name[sort_label_id].content.visible is False
    assert prototype_view._widgets_by_name[toggle_id].content.visible is False

    # Mode changes that add/remove the standalone confirmation row are deferred
    # until the next safe view update. The separate checkbox must remain clickable.
    prototype_panel.widgets[
        "better_inventory_discard_mode"
    ].content.hotspot.pressed_callback()
    assert mod.settings.quick_discard_mode == "automatic"
    assert len(prototype_panel.layout) == 10
    features.update_inventory_sort_toggle(mod, layout, prototype_view)
    assert len(prototype_panel.layout) == 11
    skip_widget = prototype_panel.widgets[
        "better_inventory_discard_skip_confirmation"
    ]
    assert skip_widget.content.checked is True
    skip_widget.content.hotspot.pressed_callback()
    assert mod.settings.quick_discard_skip_automatic_confirmation is False
    assert skip_widget.content.checked is False
    prototype_panel.widgets[
        "better_inventory_discard_mode"
    ].content.hotspot.pressed_callback()
    features.update_inventory_sort_toggle(mod, layout, prototype_view)
    assert mod.settings.quick_discard_mode == "manual"
    assert len(prototype_panel.layout) == 10

    prototype_panel.widgets[
        "better_inventory_discard_header"
    ].content.hotspot.pressed_callback()
    # Collapse/expand only changes state during the grid's draw callback. The
    # structural rebuild is deferred to the following safe view update.
    assert len(prototype_panel.layout) == 10
    features.update_inventory_sort_toggle(mod, layout, prototype_view)
    assert len(prototype_panel.layout) == 3
    assert prototype_panel.grid_height == 182
    prototype_panel.widgets[
        "better_inventory_sort_header"
    ].content.hotspot.pressed_callback()
    assert len(prototype_panel.layout) == 3
    features.update_inventory_sort_toggle(mod, layout, prototype_view)
    assert len(prototype_panel.layout) == 2
    assert prototype_panel.grid_height == 136
    prototype_panel.widgets[
        "better_inventory_sort_header"
    ].content.hotspot.pressed_callback()
    features.update_inventory_sort_toggle(mod, layout, prototype_view)
    assert len(prototype_panel.layout) == 3

    prototype_view._discard_items_element = lua.table_from({})
    features.update_inventory_sort_toggle(mod, layout, prototype_view)
    assert len(prototype_panel.layout) == 2
    assert prototype_panel.widgets["better_inventory_discard_header"] is None
    assert prototype_panel.pivot_x == -546
    assert prototype_panel.pivot_y == 534

    prototype_view._discard_items_element = None
    mod.settings.enable_inventory_options_panel_prototype = False
    features.update_inventory_sort_toggle(mod, layout, prototype_view)
    assert prototype_panel.visible is False
    assert prototype_view._widgets_by_name[sort_label_id].content.visible is True
    assert prototype_view._widgets_by_name[toggle_id].content.visible is True
    mod.settings.enable_inventory_options_panel_prototype = True

    automatic_inventory = lua.table_from(
        {
            "auto_eligible": lua.table_from(
                {
                    "gear_id": "auto_eligible",
                    "item_type": "WEAPON_MELEE",
                    "level": 300,
                    "rarity": 1,
                    "total_stats": 300,
                    "slots": lua.table_from(["slot_primary"]),
                }
            ),
            "auto_equipped": lua.table_from(
                {
                    "gear_id": "auto_equipped",
                    "item_type": "WEAPON_RANGED",
                    "level": 300,
                    "rarity": 1,
                    "total_stats": 300,
                    "slots": lua.table_from(["slot_secondary"]),
                }
            ),
            # A legacy/partially-materialized account item must fail closed
            # without preventing the rest of an automatic scan from running.
            "auto_unreadable": lua.table_from(
                {
                    "gear_id": "auto_unreadable",
                    "item_type": "WEAPON_MELEE",
                    "unreadable": True,
                    "rarity": 1,
                    "slots": lua.table_from(["slot_primary"]),
                }
            ),
        }
    )
    lua.execute(
        r"""
        local inventory = ...

        local function resolved(value)
            local promise = {}

            promise.next = function(self, callback)
                local result = callback(value)

                if type(result) == "table" and type(result.next) == "function" then
                    return result
                end

                return resolved(result)
            end
            promise.catch = function(self)
                return self
            end

            return promise
        end

        automatic_fetch_count = 0
        automatic_deleted_ids = nil
        automatic_game_mode_name = "hub"
        local profile = {
            loadout = {
                slot_secondary = {gear_id = "auto_equipped"},
            },
            loadout_item_ids = {
                slot_secondary = "auto_equipped",
            },
        }
        local player = {
            character_id = function()
                return "character-1"
            end,
            profile = function()
                return profile
            end,
        }

        Managers.state = {
            game_mode = {
                game_mode_name = function()
                    return automatic_game_mode_name
                end,
            },
        }
        Managers.player = {
            local_player = function()
                return player
            end,
        }
        Managers.data_service = {
            gear = {
                fetch_inventory = function()
                    automatic_fetch_count = automatic_fetch_count + 1

                    return resolved(inventory)
                end,
                delete_gear_batch = function(self, gear_ids)
                    automatic_deleted_ids = gear_ids

                    local result = {}

					for index = 1, #gear_ids do
						result[index] = {
							gearId = gear_ids[index],
							rewards = {},
						}
					end

					return resolved(result)
                end,
            },
        }
        """,
        automatic_inventory,
    )
    globals_.captured_popup = None
    globals_.automatic_deleted_ids = None
    mod.settings.quick_discard_mode = "automatic"
    mod.settings.quick_discard_skip_automatic_confirmation = False
    features.begin_morningstar_auto_discard(mod)
    features.update_morningstar_auto_discard(mod, 4.9)
    assert globals_.captured_popup is None
    features.update_morningstar_auto_discard(mod, 0.1)
    assert (
        globals_.captured_popup.title_text_unlocalized
        == "quick_discard_automatic_confirmation_title"
    )
    assert globals_.automatic_fetch_count == 1
    globals_.captured_notification = None
    globals_.captured_popup.options[1].callback()
    assert globals_.automatic_fetch_count == 2
    assert len(globals_.automatic_deleted_ids) == 1
    assert globals_.automatic_deleted_ids[1] == "auto_eligible"
    assert globals_.captured_notification.line_1 == "quick_discard_notification_title"
    assert "- 1 rarity_1 quick_discard_notification_items" in globals_.captured_notification.line_2
    features.update_morningstar_auto_discard(mod, 30)
    assert globals_.automatic_fetch_count == 2

    globals_.captured_popup = None
    globals_.automatic_deleted_ids = None
    mod.settings.quick_discard_skip_automatic_confirmation = True
    features.begin_morningstar_auto_discard(mod)
    features.update_morningstar_auto_discard(mod, 5)
    assert globals_.captured_popup is None
    assert globals_.automatic_fetch_count == 4
    assert globals_.automatic_deleted_ids[1] == "auto_eligible"
    features.cancel_morningstar_auto_discard()

    # The live-manager fallback must arm Automatic mode even when a hot reload
    # or unusual transition ordering misses the GameplayStateRun enter event.
    globals_.captured_popup = None
    globals_.automatic_game_mode_name = "hub_singleplay"
    mod.settings.quick_discard_skip_automatic_confirmation = False
    features.update_morningstar_auto_discard(mod, 4.9)
    assert globals_.captured_popup is None
    features.update_morningstar_auto_discard(mod, 0.1)
    assert (
        globals_.captured_popup.title_text_unlocalized
        == "quick_discard_automatic_confirmation_title"
    )
    assert globals_.automatic_fetch_count == 5
    features.cancel_morningstar_auto_discard()

    # Confirmation-enabled Automatic mode gives visible feedback even when the
    # completed scan has no eligible candidates, rather than failing silently.
    automatic_inventory["auto_eligible"] = None
    globals_.captured_popup = None
    features.update_morningstar_auto_discard(mod, 5)
    assert globals_.automatic_fetch_count == 6
    assert globals_.captured_popup.title_text_unlocalized == "quick_discard_nothing_title"
    assert (
        globals_.captured_popup.description_text_unlocalized
        == "quick_discard_automatic_nothing_description"
    )
    features.cancel_morningstar_auto_discard()

    features.unregister_inventory_view(melee_view)
    mod.settings.prioritize_equipped_favorites = False
    features.sync_inventory_sort_setting(mod, layout)
    assert sortable_view._widgets_by_name[toggle_id].content.checked is False
    assert melee_view._widgets_by_name[toggle_id].content.checked is True


if __name__ == "__main__":
    main()
