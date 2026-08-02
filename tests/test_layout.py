from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
LAYOUT_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_layout.lua"
LOCALIZATION_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_localization.lua"


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

        function callback(fn, ...)
            local bound = {...}
            local bound_count = select("#", ...)

            return function(...)
                local arguments = {}
                local call_count = select("#", ...)

                for i = 1, bound_count do
                    arguments[#arguments + 1] = bound[i]
                end

                for i = 1, call_count do
                    arguments[#arguments + 1] = select(i, ...)
                end

                local unpack_values = table.unpack or unpack

				return fn(unpack_values(arguments, 1, bound_count + call_count))
            end
        end

		TestText = {}
		TestItems = {}
		TestMasterItems = {}
		TestTraitDescriptions = {
			gadget_innate_health_increase = "+19% Max Health",
			gadget_innate_toughness_increase = "+16% Toughness",
			gadget_innate_max_wounds_increase = "+1 Wound(s)",
			gadget_stamina_increase = "+2 Max Stamina",
			gadget_cooldown_reduction = "+4% Combat Ability Regeneration",
			gadget_stamina_regeneration = "+12% Stamina Regeneration",
			gadget_sprint_cost_reduction = "+15% Sprint Efficiency",
			gadget_block_cost_reduction = "+12% Block Efficiency",
			gadget_corruption_resistance = "+15% Corruption Resistance",
			gadget_flame_resistance = "+20% Bomber Resistance",
			gadget_damage_reduction_vs_gunners = "+20% Damage Resistance (Gunners)",
			gadget_permanent_damage_resistance = "+20% Corruption Resistance (Grimoires)",
			gadget_mission_reward_gear_instead_of_weapon_increase = "+15% chance of Curio as Mission Reward (instead of Weapon)",
			gadget_toughness_regen_delay = "+30% Toughness Regeneration Speed",
			gadget_mission_credits_increase = "+8% Ordo Dockets (Mission Rewards)",
			gadget_revive_speed_increase = "+10% Revive Speed (Ally)",
		}
		TestTraitByMasterId = {
			["content/items/traits/test_health"] = "gadget_innate_health_increase",
			["content/items/traits/test_toughness"] = "gadget_innate_toughness_increase",
			["content/items/traits/test_wounds"] = "gadget_innate_max_wounds_increase",
			["content/items/traits/test_stamina"] = "gadget_stamina_increase",
			["content/items/perks/test_ability_regen"] = "gadget_cooldown_reduction",
			["content/items/perks/test_stamina_regeneration"] = "gadget_stamina_regeneration",
			["content/items/perks/test_sprint_efficiency"] = "gadget_sprint_cost_reduction",
			["content/items/perks/test_block_efficiency"] = "gadget_block_cost_reduction",
			["content/items/perks/test_corruption_resistance"] = "gadget_corruption_resistance",
			["content/items/perks/test_gunners"] = "gadget_damage_reduction_vs_gunners",
			["content/items/perks/test_grimoires"] = "gadget_permanent_damage_resistance",
			["content/items/perks/test_curio_reward"] = "gadget_mission_reward_gear_instead_of_weapon_increase",
			["content/items/perks/test_toughness_regen"] = "gadget_toughness_regen_delay",
			["content/items/perks/test_ordo_dockets"] = "gadget_mission_credits_increase",
			["content/items/perks/test_revive_speed"] = "gadget_revive_speed_increase",
		}

		function TestText.text_width(ui_renderer, text, style, optional_size, use_max_extents)
			return #text * style.font_size * 0.6
		end

		function TestText.crop_text_width(ui_renderer, text, style, maximum_width)
			local suffix = "..."
			local character_width = style.font_size * 0.6
			local maximum_characters = math.max(0, math.floor(maximum_width / character_width) - #suffix)

			return string.sub(text, 1, maximum_characters) .. suffix
		end

		function TestItems.weapon_lore_mark_name(item)
			return item and item.test_mark or "n/a"
		end

		function TestItems.weapon_lore_pattern_name(item)
			return item and item.test_pattern or "n/a"
		end

		function TestItems.is_weapon(item_type)
			return item_type == "WEAPON_MELEE" or item_type == "WEAPON_RANGED"
		end

		function TestItems.trait_description(item, rarity, value)
			local trait_id = item.trait or item.name

			return TestTraitDescriptions[trait_id] or string.format("%s rank %s", trait_id, tostring(rarity))
		end

		function TestItems.trait_textures(item, rarity)
			return item.icon, "frame/rank_" .. tostring(rarity)
		end

		function TestMasterItems.get_item(item_id)
			return {
				name = item_id,
				trait = TestTraitByMasterId[item_id] or item_id,
				icon = "icon/" .. item_id,
			}
		end

		function require(path)
			if path == "scripts/utilities/ui/text" then
				return TestText
			end

			if path == "scripts/utilities/items" then
				return TestItems
			end

			if path == "scripts/backend/master_items" then
				return TestMasterItems
			end

			error("Unexpected test require: " .. tostring(path))
		end

        captured_render_context = nil
        Managers = { ui = {} }

        function Managers.ui:load_item_icon(item, on_loaded, render_context, dummy_profile, prioritize)
            captured_render_context = render_context
            on_loaded(2, 3, 4, "test_render_target")
            return 77
        end

        test_mod = {
            settings = {
				columns = 3,
				enable_grid_layout = true,
				expand_inventory_window = true,
				expand_curio_inventory_window = true,
				curio_target_card_width = 190,
                grid_spacing = 10,
                card_height = 110,
				automatic_card_height = true,
                icon_darkness = 25,
				append_mark_to_name = true,
                show_pattern_mark = false,
                show_rarity_name = false,
                show_rarity_tag = true,
				show_weapon_blessings = true,
				blessing_icon_spacing = 3,
                compact_favorite_marker = true,
				favorite_marker_position = "above_rating",
				curio_display_profile = "primary",
				show_curio_quality = false,
				curio_stat_compression = "heavy",
				simplify_curio_primary_stat_text = true,
				curio_health_color_r = 235,
				curio_health_color_g = 85,
				curio_health_color_b = 85,
				curio_toughness_color_r = 105,
				curio_toughness_color_g = 200,
				curio_toughness_color_b = 235,
				curio_wound_color_r = 190,
				curio_wound_color_g = 105,
				curio_wound_color_b = 230,
				curio_stamina_color_r = 235,
				curio_stamina_color_g = 205,
				curio_stamina_color_b = 80,
                item_name_font_size = 16,
                secondary_text_font_size = 13,
                expertise_font_size = 20,
				minimum_item_name_font_size = 12,
                enable_melee_inventory = true,
                enable_ranged_inventory = false,
                enable_curio_inventory = true,
            }
        }

        function test_mod:get(setting_id)
            return self.settings[setting_id]
        end

		function test_mod:localize(localization_id)
			local values = {
				curio_resistance_gunners = "Gunners Resistance",
				curio_resistance_grimoires = "Grimoire Resistance",
				curio_reward_chance = "Curio as Reward",
				curio_toughness_regeneration = "Toughness Regen",
				curio_ordo_dockets = "Ordo Dockets",
				curio_revive_speed = "Revive Speed",
				curio_dr_gunners = "Gunners DR",
				curio_dr_grimoires = "Grim Corruption DR",
				curio_heavy_ability_regen = "Ability Regen",
				curio_heavy_toughness_regen = "Tough Regen",
				curio_heavy_corruption_dr = "Corruption DR",
				curio_heavy_block = "Block",
				curio_heavy_sprint = "Sprint",
				curio_heavy_stamina_regen = "Stamina Regen",
			}

			return values[localization_id] or localization_id
		end

        sentinel_unload = function() end
        sentinel_update = function() end
		sentinel_init = function(parent, widget, element, callback_name, secondary_callback_name, ui_renderer)
			widget.content.element = element
			widget.content.display_name = element.test_display_name
			widget.content.sub_display_name = element.test_sub_display_name
		end
		sentinel_update_data = function(parent, widget, element)
			widget.content.element = element
			widget.content.display_name = element.test_display_name
			widget.content.sub_display_name = element.test_sub_display_name
		end
        test_blueprint = {
            size = { 586, 110 },
			init = sentinel_init,
			update_data = sentinel_update_data,
            unload_icon = sentinel_unload,
            update = sentinel_update,
            pass_template = {
                { style_id = "icon", style = { material_values = {} } },
                { style_id = "loading", style = {} },
                { style_id = "display_name", style = {} },
                { style_id = "sub_display_name", style = {} },
                { style_id = "rarity_name", style = {} },
                { style_id = "item_level", style = {} },
                { style_id = "rarity_tag", style = {} },
                { style_id = "equipped_icon", style = {} },
                { style_id = "favorite_icon", value = "Favorite", style = {} },
                { style_id = "salvage_icon", style = {} },
                { style_id = "salvage_circle", style = {} },
                { style_id = "inner_shadow", style = { size = {} } },
                { style_id = "inner_highlight", style = { size = {} } },
                { style_id = "required_level_background", style = { offset = {} } },
                { style_id = "required_level", style = { offset = {} } },
                { style_id = "warning_message_background", style = { offset = {} } },
                { style_id = "warning_message", style = { offset = {} } },
                {
                    value = "content/ui/materials/symbols/new_item_indicator",
                    style = {},
                },
            },
        }
		raw_test_blueprint = table.clone(test_blueprint)
        """
    )

    layout = lua.execute(LAYOUT_PATH.read_text(encoding="utf-8"))
    globals_ = lua.globals()
    mod = globals_.test_mod
    blueprint = globals_.test_blueprint

    def blueprint_pass(target_blueprint, style_id):
        for index in range(1, len(target_blueprint.pass_template) + 1):
            candidate = target_blueprint.pass_template[index]

            if candidate.style_id == style_id:
                return candidate

        raise AssertionError(f"Missing pass: {style_id}")

    item_size = layout.item_size(mod, 640)
    assert (item_size[1], item_size[2]) == (206, 110)
    assert layout.card_height(mod) == 110

    mod.settings.curio_display_profile = "detailed"
    mod.settings.secondary_text_font_size = 20
    assert layout.card_height(mod) == 119
    mod.settings.automatic_card_height = False
    mod.settings.card_height = 175
    assert layout.card_height(mod) == 175
    mod.settings.automatic_card_height = True
    mod.settings.card_height = 110
    mod.settings.curio_display_profile = "primary"
    mod.settings.secondary_text_font_size = 13

    assert layout.grid_expansion(mod, 596) == 0

    mod.settings.columns = 5
    assert layout.grid_expansion(mod, 596) == 44
    assert layout.grid_expansion(mod, 596, "curio") == 394

    view_definitions = lua.table_from(
        {
            "grid_settings": lua.table_from(
                {
                    "grid_size": lua.table_from([596, 860]),
                    "mask_size": lua.table_from([680, 860]),
                }
            ),
            "scenegraph_definition": lua.table_from(
                {
                    "weapon_stats_pivot": lua.table_from(
                        {"position": lua.table_from([-1140, 60, 3])}
                    ),
                    "weapon_actions_pivot": lua.table_from(
                        {"position": lua.table_from([-560, 40, 3])}
                    ),
                    "equip_button": lua.table_from(
                        {"position": lua.table_from([857, -90, 1])}
                    ),
                }
            ),
        }
    )
    expanded_definitions, expansion = layout.expanded_view_definitions(
        mod, view_definitions
    )

    assert expansion == 44
    assert view_definitions.grid_settings.grid_size[1] == 596
    assert expanded_definitions.grid_settings.grid_size[1] == 640
    assert expanded_definitions.grid_settings.mask_size[1] == 724
    assert expanded_definitions.scenegraph_definition.weapon_stats_pivot.position[1] == -1096
    assert expanded_definitions.scenegraph_definition.weapon_actions_pivot.position[1] == -516
    assert expanded_definitions.scenegraph_definition.equip_button.position[1] == 901
    assert tuple(layout.item_size(mod, 640)[index] for index in (1, 2)) == (120, 110)

    curio_view = lua.table_from(
        {"_selected_slot": lua.table_from({"name": "slot_attachment_1"})}
    )
    curio_definitions, curio_expansion = layout.expanded_view_definitions(
        mod, view_definitions, curio_view
    )
    assert curio_expansion == 394
    assert curio_definitions.grid_settings.grid_size[1] == 990
    assert tuple(layout.item_size(mod, 990)[index] for index in (1, 2)) == (190, 110)

    mod.settings.expand_curio_inventory_window = False
    assert layout.grid_expansion(mod, 596, "curio") == 44
    mod.settings.expand_curio_inventory_window = True

    mod.settings.expand_inventory_window = False
    assert layout.grid_expansion(mod, 596) == 0
    assert tuple(layout.item_size(mod, 596)[index] for index in (1, 2)) == (111, 110)

    mod.settings.columns = 3
    mod.settings.expand_inventory_window = True

    mod.settings.enable_grid_layout = False
    assert layout.grid_expansion(mod, 596) == 0
    native_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    native_size = layout.configure_item_blueprint(mod, native_blueprint, 596)
    assert (native_size[1], native_size[2]) == (586, 110)
    assert blueprint_pass(native_blueprint, "icon").style.size is None
    assert blueprint_pass(native_blueprint, "better_inventory_curio_stat_1")
    native_grid = lua.table_from(
        {"_menu_settings": lua.table_from({"grid_spacing": lua.table_from([4, 4])})}
    )
    layout.configure_grid(mod, native_grid)
    assert (
        native_grid._menu_settings.grid_spacing[1],
        native_grid._menu_settings.grid_spacing[2],
    ) == (4, 4)
    mod.settings.enable_grid_layout = True

    assert layout.is_enabled_for_view(mod, lua.table_from({"_selected_slot": lua.table_from({"name": "slot_primary"})}))
    assert not layout.is_enabled_for_view(mod, lua.table_from({"_selected_slot": lua.table_from({"name": "slot_secondary"})}))
    assert layout.is_enabled_for_view(mod, lua.table_from({"_selected_slot": lua.table_from({"name": "slot_attachment_2"})}))
    assert not layout.is_enabled_for_view(mod, lua.table_from({"_selected_slot": lua.table_from({"name": "slot_gear_head"})}))

    layout.configure_item_blueprint(mod, blueprint, 640)

    assert (blueprint.size[1], blueprint.size[2]) == (206, 110)
    assert lua.eval("test_blueprint.unload_icon == sentinel_unload")
    assert lua.eval("test_blueprint.update == sentinel_update")

    icon_pass = blueprint.pass_template[1]
    assert (icon_pass.style.size[1], icon_pass.style.size[2]) == (206, 110)
    assert tuple(icon_pass.style.color[index] for index in range(1, 5)) == (255, 191, 191, 191)

    rarity_name_pass = blueprint.pass_template[5]
    assert rarity_name_pass.visibility_function() is False

    pattern_name_pass = blueprint.pass_template[4]
    weapon_content = lua.table_from(
        {
            "element": lua.table_from(
                {"item": lua.table_from({"item_type": "WEAPON_MELEE"})}
            )
        }
    )
    curio_content = lua.table_from(
        {
            "element": lua.table_from(
                {"item": lua.table_from({"item_type": "GADGET"})}
            )
        }
    )
    assert pattern_name_pass.visibility_function(weapon_content) is False
    assert pattern_name_pass.visibility_function(curio_content) is False

    favorite_pass = blueprint_pass(blueprint, "favorite_icon")
    assert favorite_pass.style.horizontal_alignment == "right"
    assert favorite_pass.style.vertical_alignment == "top"
    assert (favorite_pass.style.offset[1], favorite_pass.style.offset[2]) == (-8, 7)

    favorite_pass.change_function(lua.table_from({"equipped": True}), favorite_pass.style, None, 0)
    assert favorite_pass.style.offset[2] == 33

    name_style = blueprint.pass_template[3].style
    name_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from({"display_name": name_style}),
        }
    )
    name_element = lua.table_from(
        {"test_display_name": "A Very Long Weapon Name That Cannot Fit"}
    )

    blueprint.init(None, name_widget, name_element, None, None, lua.table_from({}), None, blueprint)

    assert name_widget.style.display_name.word_wrap is False
    assert name_widget.style.display_name.font_size == 12
    assert name_widget.content.display_name.endswith("...")
    assert name_widget.content.better_inventory_full_display_name == name_element.test_display_name

    short_name_element = lua.table_from({"test_display_name": "Short Name"})
    test_grid = lua.table_from({"_ui_resource_renderer": lua.table_from({})})
    blueprint.update_data(test_grid, name_widget, short_name_element)

    assert name_widget.style.display_name.font_size == 16
    assert name_widget.content.display_name == "Short Name"

    narrow_weapon_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(
                {
                    "display_name": lua.table_from(
                        {
                            "font_size": 16,
                            "size": lua.table_from([72, 25]),
                        }
                    )
                }
            ),
        }
    )
    narrow_weapon_element = lua.table_from(
        {
            "test_display_name": "Combat Blade",
            "test_sub_display_name": "Catachan • Mk VI",
            "item": lua.table_from(
                {
                    "item_type": "WEAPON_MELEE",
                    "test_mark": "Mk VI",
                    "test_pattern": "Catachan",
					"traits": lua.table_from(
						[
							lua.table_from({"id": "blessing_one", "rarity": 3, "value": 0.5}),
							lua.table_from({"id": "blessing_two", "rarity": 4, "value": 0.8}),
						]
					),
                }
            ),
        }
    )

    blueprint.init(
        None,
        narrow_weapon_widget,
        narrow_weapon_element,
        None,
        None,
        lua.table_from({}),
        None,
        blueprint,
    )

    assert narrow_weapon_widget.content.better_inventory_full_display_name == "Combat Blade Mk VI"
    assert narrow_weapon_widget.content.display_name.endswith(" Mk VI")
    assert narrow_weapon_widget.content.sub_display_name == "Catachan"

    first_blessing_pass = blueprint_pass(blueprint, "better_inventory_blessing_1")
    second_blessing_pass = blueprint_pass(blueprint, "better_inventory_blessing_2")

    assert first_blessing_pass.visibility_function(narrow_weapon_widget.content)
    assert second_blessing_pass.visibility_function(narrow_weapon_widget.content)

    first_blessing_pass.change_function(
        narrow_weapon_widget.content, first_blessing_pass.style
    )
    second_blessing_pass.change_function(
        narrow_weapon_widget.content, second_blessing_pass.style
    )

    assert first_blessing_pass.style.material_values.icon == "icon/blessing_one"
    assert first_blessing_pass.style.material_values.frame == "frame/rank_3"
    assert second_blessing_pass.style.material_values.icon == "icon/blessing_two"
    assert second_blessing_pass.style.material_values.frame == "frame/rank_4"
    assert (
        second_blessing_pass.style.offset[1] - first_blessing_pass.style.offset[1]
        == first_blessing_pass.style.size[1] + 3
    )

    curio_stat_pass = blueprint_pass(blueprint, "better_inventory_curio_stat_1")
    curio_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(
                {
                    "display_name": blueprint_pass(blueprint, "display_name").style,
                    "better_inventory_curio_stat_1": curio_stat_pass.style,
                }
            ),
        }
    )
    curio_element = lua.table_from(
        {
            "test_display_name": "Mechanicus Icon",
            "test_sub_display_name": "Transcendent",
            "item": lua.table_from(
                {
                    "item_type": "GADGET",
                    "traits": lua.table_from(
                        [
                            lua.table_from(
                                {
									"id": "content/items/traits/test_health",
                                    "rarity": 4,
                                    "value": 0.7,
                                }
                            )
                        ]
                    ),
                    "perks": lua.table_from(
                        [
                            lua.table_from(
                                {
									"id": "content/items/perks/test_stamina_regeneration",
                                    "rarity": 4,
                                    "value": 0.5,
                                }
                            ),
                            lua.table_from(
                                {
									"id": "content/items/perks/test_sprint_efficiency",
                                    "rarity": 4,
                                    "value": 0.5,
                                }
                            ),
                            lua.table_from(
                                {
									"id": "content/items/perks/test_gunners",
                                    "rarity": 4,
                                    "value": 0.5,
                                }
                            ),
                        ]
                    ),
                }
            ),
        }
    )

    blueprint.init(
        None,
        curio_widget,
        curio_element,
        None,
        None,
        lua.table_from({}),
        None,
        blueprint,
    )

    assert curio_widget.content.better_inventory_curio_stat_1 == "+19% Health"
    assert curio_widget.content.better_inventory_curio_stat_2 == "+12% Stamina Regen"
    assert curio_stat_pass.visibility_function(curio_widget.content)

    curio_stat_pass.change_function(curio_widget.content, curio_stat_pass.style)
    assert tuple(curio_stat_pass.style.text_color[index] for index in range(1, 5)) == (
        255,
        235,
        85,
        85,
    )

    mod.settings.curio_health_color_r = 12
    mod.settings.curio_health_color_g = 34
    mod.settings.curio_health_color_b = 56
    blueprint.update_data(test_grid, curio_widget, curio_element)
    curio_stat_pass.change_function(curio_widget.content, curio_stat_pass.style)
    assert tuple(curio_stat_pass.style.text_color[index] for index in range(1, 5)) == (
        255,
        12,
        34,
        56,
    )
    mod.settings.curio_health_color_r = 235
    mod.settings.curio_health_color_g = 85
    mod.settings.curio_health_color_b = 85

    mod.settings.simplify_curio_primary_stat_text = False
    full_primary_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, full_primary_blueprint, 640)
    full_primary_style = blueprint_pass(
        full_primary_blueprint, "better_inventory_curio_stat_1"
    ).style
    full_primary_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(
                {
                    "display_name": blueprint_pass(
                        full_primary_blueprint, "display_name"
                    ).style,
                    "better_inventory_curio_stat_1": full_primary_style,
                }
            ),
        }
    )
    full_primary_blueprint.init(
        None,
        full_primary_widget,
        curio_element,
        None,
        None,
        lua.table_from({}),
        None,
        full_primary_blueprint,
    )
    assert full_primary_widget.content.better_inventory_curio_stat_1 == "+19% Max Health"
    mod.settings.simplify_curio_primary_stat_text = True

    primary_color_expectations = {
        "content/items/traits/test_toughness": (255, 105, 200, 235),
        "content/items/traits/test_wounds": (255, 190, 105, 230),
        "content/items/traits/test_stamina": (255, 235, 205, 80),
    }

    for trait_id, expected_color in primary_color_expectations.items():
        curio_element.item.traits[1].id = trait_id
        blueprint.update_data(test_grid, curio_widget, curio_element)
        curio_stat_pass.change_function(curio_widget.content, curio_stat_pass.style)
        assert tuple(
            curio_stat_pass.style.text_color[index] for index in range(1, 5)
        ) == expected_color

    curio_element.item.traits[1].id = "content/items/traits/test_wounds"
    blueprint.update_data(test_grid, curio_widget, curio_element)
    assert curio_widget.content.better_inventory_curio_stat_1 == "+1 Wound"
    curio_element.item.traits[1].id = "content/items/traits/test_stamina"
    blueprint.update_data(test_grid, curio_widget, curio_element)
    assert curio_widget.content.better_inventory_curio_stat_1 == "+2 Stamina"

    mod.settings.curio_display_profile = "detailed"
    detailed_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, detailed_blueprint, 640)

    detailed_styles = {
        "display_name": blueprint_pass(detailed_blueprint, "display_name").style,
    }

    for index in range(1, 5):
        style_id = f"better_inventory_curio_stat_{index}"
        detailed_styles[style_id] = blueprint_pass(detailed_blueprint, style_id).style
        assert detailed_styles[style_id].word_wrap is False
        assert (
            detailed_styles[style_id].size[1]
            > detailed_styles[style_id].better_inventory_max_text_width
        )

    detailed_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(detailed_styles),
        }
    )
    detailed_blueprint.init(
        None,
        detailed_widget,
        curio_element,
        None,
        None,
        lua.table_from({}),
        None,
        detailed_blueprint,
    )

    assert not blueprint_pass(detailed_blueprint, "display_name").visibility_function(
        detailed_widget.content
    )
    assert not blueprint_pass(detailed_blueprint, "item_level").visibility_function(
        detailed_widget.content
    )
    assert not blueprint_pass(
        detailed_blueprint, "sub_display_name"
    ).visibility_function(detailed_widget.content)

    for index in range(1, 5):
        stat_pass = blueprint_pass(
            detailed_blueprint, f"better_inventory_curio_stat_{index}"
        )
        assert stat_pass.visibility_function(detailed_widget.content)

    assert (
        detailed_widget.content.better_inventory_full_curio_stat_4
        == "+20% Gunners DR"
    )

    heavy_perk_expectations = {
        "content/items/perks/test_ability_regen": "+4% Ability Regen",
        "content/items/perks/test_toughness_regen": "+30% Tough Regen",
        "content/items/perks/test_corruption_resistance": "+15% Corruption DR",
        "content/items/perks/test_grimoires": "+20% Grim Corruption DR",
        "content/items/perks/test_block_efficiency": "+12% Block",
        "content/items/perks/test_sprint_efficiency": "+15% Sprint",
        "content/items/perks/test_stamina_regeneration": "+12% Stamina Regen",
        "content/items/perks/test_curio_reward": "15% Curio as Reward",
        "content/items/perks/test_ordo_dockets": "+8% Ordo Dockets",
        "content/items/perks/test_revive_speed": "+10% Revive Speed",
    }

    for trait_id, expected_text in heavy_perk_expectations.items():
        curio_element.item.perks[3].id = trait_id
        detailed_blueprint.update_data(test_grid, detailed_widget, curio_element)
        actual_text = detailed_widget.content.better_inventory_full_curio_stat_4
        assert actual_text == expected_text, f"{trait_id}: expected {expected_text!r}, got {actual_text!r}"

    curio_element.item.perks[3].id = "content/items/perks/test_gunners"
    detailed_blueprint.update_data(test_grid, detailed_widget, curio_element)

    mod.settings.curio_stat_compression = "compression"
    compression_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, compression_blueprint, 640)
    compression_styles = {
        "display_name": blueprint_pass(compression_blueprint, "display_name").style,
    }
    for index in range(1, 5):
        style_id = f"better_inventory_curio_stat_{index}"
        compression_styles[style_id] = blueprint_pass(compression_blueprint, style_id).style
    compression_widget = lua.table_from(
        {"content": lua.table_from({}), "style": lua.table_from(compression_styles)}
    )
    compression_blueprint.init(
        None,
        compression_widget,
        curio_element,
        None,
        None,
        lua.table_from({}),
        None,
        compression_blueprint,
    )
    assert (
        compression_widget.content.better_inventory_full_curio_stat_4
        == "+20% Gunners Resistance"
    )

    mod.settings.columns = 5
    mod.settings.curio_stat_compression = "none"
    narrow_detailed_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, narrow_detailed_blueprint, 640)
    narrow_detailed_styles = {
        "display_name": blueprint_pass(
            narrow_detailed_blueprint, "display_name"
        ).style,
    }

    for index in range(1, 5):
        style_id = f"better_inventory_curio_stat_{index}"
        narrow_detailed_styles[style_id] = blueprint_pass(
            narrow_detailed_blueprint, style_id
        ).style

    narrow_detailed_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(narrow_detailed_styles),
        }
    )
    narrow_detailed_blueprint.init(
        None,
        narrow_detailed_widget,
        curio_element,
        None,
        None,
        lua.table_from({}),
        None,
        narrow_detailed_blueprint,
    )
    assert (
        narrow_detailed_widget.content.better_inventory_full_curio_stat_4
        == "+20% Damage Resistance (Gunners)"
    )
    assert narrow_detailed_widget.content.better_inventory_curio_stat_4.endswith(
        "..."
    )
    assert "\n" not in narrow_detailed_widget.content.better_inventory_curio_stat_4
    mod.settings.columns = 3
    mod.settings.curio_stat_compression = "heavy"

    mod.settings.curio_display_profile = "primary"
    mod.settings.show_curio_quality = True
    quality_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, quality_blueprint, 640)
    assert blueprint_pass(
        quality_blueprint, "sub_display_name"
    ).visibility_function(curio_content)
    mod.settings.show_curio_quality = False

    mod.settings.favorite_marker_position = "bottom_left"
    bottom_favorite_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, bottom_favorite_blueprint, 640)
    bottom_favorite_pass = blueprint_pass(
        bottom_favorite_blueprint, "favorite_icon"
    )
    assert bottom_favorite_pass.style.horizontal_alignment == "left"
    assert bottom_favorite_pass.style.vertical_alignment == "bottom"
    assert (bottom_favorite_pass.style.offset[1], bottom_favorite_pass.style.offset[2]) == (
        12,
        -5,
    )
    mod.settings.favorite_marker_position = "above_rating"

    widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(
                {"icon": lua.table_from({"material_values": lua.table_from({})})}
            ),
        }
    )
    element = lua.table_from({"item": lua.table_from({"gear_id": "test-gear"})})

    blueprint.load_icon(None, widget, element, None, None, True)

    assert widget.content.icon_load_id == 77
    assert (globals_.captured_render_context.size[1], globals_.captured_render_context.size[2]) == (206, 110)
    assert widget.style.icon.material_values.render_target == "test_render_target"
    assert widget.style.icon.material_values.grid_index == 1

    grid = lua.table_from({"_menu_settings": lua.table_from({})})
    layout.configure_grid(mod, grid)
    assert (grid._menu_settings.grid_spacing[1], grid._menu_settings.grid_spacing[2]) == (10, 10)

    # DMF formats every localized value through string.format. Literal percent
    # signs therefore need to be escaped as %% in the source string.
    localization = lua.execute(LOCALIZATION_PATH.read_text(encoding="utf-8"))
    format_string = lua.eval("string.format")

    for _, localized_values in localization.items():
        format_string(localized_values["en"])

    print("BetterInventory layout behavior tests passed.")


if __name__ == "__main__":
    main()
