from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime
from localization_support import load_localization


PROJECT_ROOT = Path(__file__).resolve().parents[1]
LAYOUT_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_layout.lua"
LAYOUT_CONTENT_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_layout_content.lua"
LAYOUT_CARDS_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_layout_cards.lua"
LAYOUT_GEOMETRY_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_layout_geometry.lua"
LAYOUT_BLUEPRINTS_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "BetterInventory_layout_blueprints.lua"
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
		TestRankSettings = {
			[0] = { display_name = "n/a" },
			[1] = { display_name = "I" },
			[2] = { display_name = "II" },
			[3] = { display_name = "III" },
			[4] = { display_name = "IV" },
		}
		TestTraitDescriptions = {
			gadget_innate_health_increase = "+19% Max Health",
			gadget_innate_toughness_increase = "+16% Toughness",
			gadget_innate_max_wounds_increase = "+1 Wound(s)",
			gadget_stamina_increase = "+2 Max Stamina",
			gadget_health_increase = "+5% Maximum Health",
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
			weapon_trait_melee_common_wield_increased_unarmored_damage = "+25% Damage (Unarmoured Enemies)",
			weapon_trait_melee_common_wield_increased_armored_damage = "+25% Damage (Flak Armoured Enemies)",
			weapon_trait_melee_common_wield_increased_resistant_damage = "+25% Damage (Unyielding Enemies)",
			weapon_trait_melee_common_wield_increased_berserker_damage = "+25% Damage (Maniacs)",
			weapon_trait_melee_common_wield_increased_super_armor_damage = "+25% Damage (Carapace Armoured Enemies)",
			weapon_trait_melee_common_wield_increased_disgustingly_resilient_damage = "+25% Damage (Infested Enemies)",
			weapon_trait_increase_crit_chance = "+5% Melee Critical Hit Chance",
			weapon_trait_increase_crit_damage = "+10% Melee Critical Hit Damage",
			weapon_trait_increase_stamina = "+2 Stamina (Weapon is Active)",
			weapon_trait_increase_damage_hordes = "+10% Melee Damage (Groaners, Poxwalkers)",
			weapon_trait_increase_damage_elites = "+10% Melee Damage (Elites)",
			weapon_trait_increase_damage_specials = "+10% Increased Melee Damage (Specialists)",
			weapon_trait_increase_weakspot_damage = "+10% Melee Weak Spot Damage",
			weapon_trait_increase_damage = "+4% Melee Damage (Weapon is Active)",
			weapon_trait_increase_finesse = "+4% Melee Finesse (Weapon is Active)",
			weapon_trait_increase_power = "+4% Melee Power (Weapon is Active)",
			weapon_trait_increase_impact = "+8% Melee Impact",
			weapon_trait_reduced_block_cost = "+20% Block Efficiency",
			weapon_trait_reduce_sprint_cost = "+15% Sprint Efficiency",
			weapon_trait_ranged_common_wield_increased_unarmored_damage = "+25% Damage (Unarmoured Enemies)",
			weapon_trait_ranged_common_wield_increased_armored_damage = "+25% Damage (Flak Armoured Enemies)",
			weapon_trait_ranged_common_wield_increased_resistant_damage = "+25% Damage (Unyielding Enemies)",
			weapon_trait_ranged_common_wield_increased_berserker_damage = "+25% Damage (Maniacs)",
			weapon_trait_ranged_common_wield_increased_super_armor_damage = "+25% Damage (Carapace Armoured Enemies)",
			weapon_trait_ranged_common_wield_increased_disgustingly_resilient_damage = "+25% Damage (Infested Enemies)",
			weapon_trait_ranged_increase_crit_chance = "Increase Ranged Critical Strike Chance by +5%",
			weapon_trait_ranged_increase_crit_damage = "+10% Ranged Critical Hit Damage",
			weapon_trait_ranged_increase_stamina = "+2 Stamina (Weapon is Active)",
			weapon_trait_ranged_increase_weakspot_damage = "+10% Ranged Weak Spot Damage",
			weapon_trait_ranged_increase_damage = "+4% Ranged Damage (Weapon is Active)",
			weapon_trait_ranged_increase_finesse = "+4% Ranged Finesse (Weapon is Active)",
			weapon_trait_ranged_increase_power = "+4% Ranged Power (Weapon is Active)",
			weapon_trait_ranged_increase_damage_elites = "+10% Ranged Damage (Elites)",
			weapon_trait_ranged_increase_damage_hordes = "+10% Ranged Damage (Groaners, Poxwalkers)",
			weapon_trait_ranged_increase_damage_specials = "+10% Increased Ranged Damage (Specialists)",
			weapon_trait_ranged_increased_reload_speed = "+10% Reload Speed",
		}
		TestTraitByMasterId = {
			["content/items/traits/test_health"] = "gadget_innate_health_increase",
			["content/items/traits/test_toughness"] = "gadget_innate_toughness_increase",
			["content/items/traits/test_wounds"] = "gadget_innate_max_wounds_increase",
			["content/items/traits/test_stamina"] = "gadget_stamina_increase",
			["content/items/perks/test_health"] = "gadget_health_increase",
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
			["content/items/perks/test_weapon_flak"] = "weapon_trait_melee_common_wield_increased_armored_damage",
			["content/items/perks/test_weapon_maniacs"] = "weapon_trait_melee_common_wield_increased_berserker_damage",
			["content/items/perks/test_weapon_crit_chance"] = "weapon_trait_increase_crit_chance",
			["content/items/perks/test_weapon_crit_damage"] = "weapon_trait_increase_crit_damage",
			["content/items/perks/test_weapon_horde"] = "weapon_trait_increase_damage_hordes",
			["content/items/perks/test_weapon_elites"] = "weapon_trait_increase_damage_elites",
			["content/items/perks/test_weapon_specialists"] = "weapon_trait_increase_damage_specials",
			["content/items/perks/test_weapon_weakspot"] = "weapon_trait_increase_weakspot_damage",
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

		function TestText.word_wrap(ui_renderer, text, style, maximum_width)
			local maximum_characters = math.max(1, math.floor(maximum_width / (style.font_size * 0.6)))
			local rows = {}
			local row = ""

			for word in string.gmatch(text, "%S+") do
				local candidate = row == "" and word or row .. " " .. word

				if #candidate > maximum_characters and row ~= "" then
					rows[#rows + 1] = row
					row = word
				else
					row = candidate
				end
			end

			if row ~= "" then
				rows[#rows + 1] = row
			end

			return rows
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

		function TestItems.expertise_level(item, no_symbol)
			local value = tostring(item and item.expertise or 460)

			return no_symbol and value or "POWER " .. value, true
		end

		function TestItems.max_expertise_level()
			return 500
		end

		preview_stats_change_count = 0

		function TestItems.preview_stats_change(item, expertise_increase, stats)
			preview_stats_change_count = preview_stats_change_count + 1
			local projected = {}

			for index = 1, #stats do
				local stat = stats[index]
				local value = item.projected_values and item.projected_values[index] or math.floor((stat.fraction or 0) * 100 + 0.5)

				projected[stat.display_name] = {
					fraction = value / 100,
				}
			end

			return projected
		end

		TestWeaponStats = {}

		function TestWeaponStats:new(item)
			local instance = {
				item = item,
			}

			function instance:get_comparing_stats()
				local stats = {}
				local display_names = item.modifier_display_names or {
					"loc_stats_display_damage_stat",
					"loc_stats_display_warp_resist_stat",
					"loc_stats_display_cleave_damage_stat",
					"loc_stats_display_defense_stat",
					"loc_stats_display_finesse_stat",
				}

				for index = 1, 5 do
					stats[index] = {
						display_name = display_names[index],
						fraction = 0.2,
					}
				end

				return stats
			end

			return instance
		end

		function TestItems.display_name(item)
			return item and (item.display_name or item.name) or "n/a"
		end

		function TestItems.trait_description(item, rarity, value)
			local trait_id = item.trait or item.name

			return TestTraitDescriptions[trait_id] or string.format("%s rank %s", trait_id, tostring(rarity))
		end

		function TestItems.trait_textures(item, rarity)
			return item.icon, "frame/rank_" .. tostring(rarity)
		end

		function TestItems.perk_textures(item, rarity)
			return "perk/rank_" .. tostring(rarity)
		end

		function TestItems.rarity_color(item)
			return item and item.test_rarity_color or { 255, 145, 70, 40 }
		end

		function TestMasterItems.get_item(item_id)
			return {
				display_name = item_id == "blessing_one" and "Surgical" or item_id == "blessing_two" and "Weight of Fire" or item_id == "blessing_long" and "Rending Shockwave" or item_id,
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

			if path == "scripts/settings/item/rank_settings" then
				return TestRankSettings
			end

			if path == "scripts/utilities/weapon_stats" then
				return TestWeaponStats
			end

			error("Unexpected test require: " .. tostring(path))
		end

		test_name_it_mod = nil

		function get_mod(name)
			if name == "BetterInventory" then
				return test_mod
			end

			if name == "name_it" then
				return test_name_it_mod
			end
		end

			test_mod = {
			settings = {
				columns = 3,
				three_column_weapon_name_font_size = 14,
				enable_grid_layout = true,
				enable_quick_look_card_single_column_integration = true,
				enable_quick_look_card_grid_integration = true,
				character_overview_show_only_dump_stat = false,
				character_overview_dump_stat_horizontal_offset = 0,
				character_overview_dump_stat_font_scale_percent = 100,
				character_overview_dump_stat_color_r = 255,
				character_overview_dump_stat_color_g = 94,
				character_overview_dump_stat_color_b = 132,
				quick_look_card_single_column_font_size = 14,
				quick_look_card_single_column_label_value_gap = 1,
				quick_look_card_single_column_horizontal_position = 79,
				quick_look_card_single_column_vertical_position = 93,
				quick_look_card_grid_stat_position = "above_power",
				quick_look_card_grid_font_size = 13,
				quick_look_card_grid_bottom_padding = 26,
				weapon_modifier_lowest_color_r = 255,
				weapon_modifier_lowest_color_g = 94,
				weapon_modifier_lowest_color_b = 132,
				weapon_modifier_lowest_color_opacity = 80,
				expand_inventory_window = true,
				weapon_extra_width_column_threshold = "four_plus",
				five_column_weapon_extra_width = 80,
				expand_curio_inventory_window = true,
				curio_target_card_width = 190,
				enable_armoury_requisition_grid = true,
				global_store_character_photo_size_percent = 110,
				global_store_price_row_padding = 10,
				global_store_character_info_gap = 5,
				global_store_character_class_icon_size = 16,
				global_store_character_name_font_size = 16,
				global_store_compact_character_names = true,
				global_store_single_column_modifier_horizontal_position = 55,
				global_store_single_column_modifier_vertical_position = 100,
				brighten_armoury_item_levels = true,
				expand_armoury_requisition_window = true,
				armoury_requisition_target_card_width = 230,
				debug_expand_armoury_requisition_window_30_percent = false,
				debug_armoury_requisition_window_increase_percent = 30,
				debug_adjust_inventory_window_width = false,
				debug_inventory_window_width_adjustment_percent = 30,
				debug_adjust_global_store_window_width = false,
				debug_global_store_window_width_adjustment_percent = 30,
                grid_spacing = 10,
                card_height = 110,
				automatic_card_height = true,
                icon_darkness = 25,
				append_mark_to_name = true,
				force_weapon_name_single_line = false,
                show_pattern_mark = false,
                show_rarity_name = false,
				show_rarity_tag = true,
				weapon_blessing_display_mode = "icons",
				blessing_text_item_level_separation = "four_plus",
				auto_fit_long_blessing_names = true,
				truncate_long_blessing_names = false,
				blessing_icon_size = 34,
				weapon_blessing_text_vertical_spacing = 2,
				weapon_blessing_text_bottom_padding = 4,
				weapon_blessing_text_color_r = 144,
				weapon_blessing_text_color_g = 213,
				weapon_blessing_text_color_b = 255,
				weapon_blessing_text_opacity = 100,
				show_weapon_perks = false,
				weapon_perk_compression = "compression",
				show_weapon_perk_rank_symbols = false,
				weapon_perk_rank_icon_size = 18,
				single_column_weapon_name_font_size = 20,
				single_column_blessing_icons_on_right = true,
				weapon_perk_vertical_spacing = 2,
				weapon_perk_blessing_spacing = 5,
				remove_weapon_perk_plus_signs = false,
				weapon_perk_text_color_r = 190,
				weapon_perk_text_color_g = 210,
				weapon_perk_text_color_b = 180,
				weapon_perk_text_opacity = 100,
				blessing_icon_spacing = 3,
				highlight_equipped_items = true,
                compact_favorite_marker = true,
				myfavorites_show_favorite_letter = false,
				favorite_marker_position = "above_rating",
				curio_display_profile = "primary",
				show_curio_item_level = true,
				curio_primary_stat_font_size = 16,
				curio_secondary_stat_font_size = 13,
				curio_primary_secondary_spacing = 5,
				curio_secondary_text_color_r = 220,
				curio_secondary_text_color_g = 230,
				curio_secondary_text_color_b = 210,
				show_curio_quality = false,
				curio_stat_compression = "heavy",
				simplify_curio_primary_stat_text = true,
				remove_curio_stat_plus_signs = false,
				name_it_force_curio_name_in_detailed_mode = true,
				custom_item_override_weapon_information_color = true,
				custom_item_override_weapon_rarity_keyword_color = true,
				custom_item_override_weapon_information_name_color = true,
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
				show_item_level_icon = true,
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
				weapon_perk_flak_damage = "Flak Damage",
				weapon_perk_flak_damage_heavy = "Flak Dmg",
				weapon_perk_maniacs_damage = "Maniacs Damage",
				weapon_perk_maniacs_damage_heavy = "Maniac Dmg",
				weapon_perk_melee_crit_chance = "Melee Crit Chance",
				weapon_perk_melee_crit_chance_heavy = "Melee Crit",
				weapon_perk_melee_crit_damage = "Melee Crit Dmg",
				weapon_perk_melee_crit_damage_heavy = "Crit Dmg",
				weapon_perk_horde_melee_damage = "Horde Melee Dmg",
				weapon_perk_horde_melee_damage_heavy = "Horde Dmg",
				weapon_perk_elites_melee_damage = "Elites Melee Dmg",
				weapon_perk_elites_melee_damage_heavy = "Elite Dmg",
				weapon_perk_specialist_melee_damage = "Specialist Melee Dmg",
				weapon_perk_specialist_melee_damage_heavy = "Spec Dmg",
				weapon_perk_melee_weakspot_damage = "Melee Weakspot Dmg",
				weapon_perk_melee_weakspot_damage_heavy = "Weakspot Dmg",
				weapon_perk_unarmoured_damage = "Unarmoured Damage",
				weapon_perk_unarmoured_damage_heavy = "Unarmoured Dmg",
				weapon_perk_unyielding_damage = "Unyielding Damage",
				weapon_perk_unyielding_damage_heavy = "Unyielding Dmg",
				weapon_perk_carapace_damage = "Carapace Damage",
				weapon_perk_carapace_damage_heavy = "Carapace Dmg",
				weapon_perk_infested_damage = "Infested Damage",
				weapon_perk_infested_damage_heavy = "Infested Dmg",
				weapon_perk_stamina = "Stamina",
				weapon_perk_melee_damage = "Melee Damage",
				weapon_perk_melee_damage_heavy = "Melee Dmg",
				weapon_perk_ranged_damage = "Ranged Damage",
				weapon_perk_ranged_damage_heavy = "Ranged Dmg",
				weapon_perk_melee_finesse = "Melee Finesse",
				weapon_perk_ranged_finesse = "Ranged Finesse",
				weapon_perk_finesse_heavy = "Finesse",
				weapon_perk_melee_power = "Melee Power",
				weapon_perk_ranged_power = "Ranged Power",
				weapon_perk_power_heavy = "Power",
				weapon_perk_melee_impact = "Melee Impact",
				weapon_perk_impact_heavy = "Impact",
				weapon_perk_block_efficiency = "Block Efficiency",
				weapon_perk_block_heavy = "Block",
				weapon_perk_sprint_efficiency = "Sprint Efficiency",
				weapon_perk_sprint_heavy = "Sprint",
				weapon_perk_reload_speed = "Reload Speed",
				weapon_perk_reload_heavy = "Reload",
				weapon_perk_ranged_crit_chance = "Ranged Crit Chance",
				weapon_perk_ranged_crit_chance_heavy = "Ranged Crit",
				weapon_perk_ranged_crit_damage = "Ranged Crit Dmg",
				weapon_perk_ranged_crit_damage_heavy = "Crit Dmg",
				weapon_perk_horde_ranged_damage = "Horde Ranged Dmg",
				weapon_perk_horde_ranged_damage_heavy = "Horde Dmg",
				weapon_perk_elites_ranged_damage = "Elites Ranged Dmg",
				weapon_perk_elites_ranged_damage_heavy = "Elite Dmg",
				weapon_perk_specialist_ranged_damage = "Specialist Ranged Dmg",
				weapon_perk_specialist_ranged_damage_heavy = "Spec Dmg",
				weapon_perk_ranged_weakspot_damage = "Ranged Weakspot Dmg",
				weapon_perk_ranged_weakspot_damage_heavy = "Weakspot Dmg",
			}

			return values[localization_id] or localization_id
		end

		function test_mod:io_dofile(path)
			if path == "BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_content" then
				return TestLayoutContent
			end

			if path == "BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_cards" then
				return TestLayoutCards
			end

			if path == "BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_geometry" then
				return TestLayoutGeometry
			end

			if path == "BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout_blueprints" then
				return TestLayoutBlueprints
			end

			error("Unexpected test io_dofile: " .. tostring(path))
		end

		sentinel_load = function() end
		sentinel_unload = function() end
		sentinel_destroy = function() end
		sentinel_priority = function() end
		sentinel_update = function() end
		sentinel_init = function(parent, widget, element, callback_name, secondary_callback_name, ui_renderer)
			widget.content.element = element
			widget.content.display_name = element.test_display_name
			widget.content.sub_display_name = element.test_sub_display_name
			widget.content.item_level = "POWER 460"
		end
		sentinel_update_data = function(parent, widget, element)
			widget.content.element = element
			widget.content.display_name = element.test_display_name
			widget.content.sub_display_name = element.test_sub_display_name
			widget.content.item_level = "POWER 460"
		end
        test_blueprint = {
			size = { 586, 110 },
			init = sentinel_init,
			update_data = sentinel_update_data,
			load_icon = sentinel_load,
			unload_icon = sentinel_unload,
			destroy = sentinel_destroy,
			update_item_icon_priority = sentinel_priority,
			update = sentinel_update,
            pass_template = {
                {
                    style_id = "icon",
                    style = { material_values = {}, size = { 586, 110 } },
                },
                { style_id = "loading", style = {} },
                { style_id = "display_name", style = {} },
                { style_id = "sub_display_name", style = {} },
                { style_id = "rarity_name", style = {} },
                { style_id = "item_level", style = {} },
				{ style_id = "wallet_icon", style = {} },
				{ style_id = "price_text", style = {} },
				{ style_id = "owned_text", style = {} },
				{ style_id = "portrait", style = {} },
				{ style_id = "character_info_text", style = {} },
                { style_id = "rarity_tag", style = {} },
                { style_id = "equipped_icon", style = {} },
                {
                    style_id = "favorite_icon",
                    value = "Favorite",
                    value_id = "favorite_icon",
                    style = {},
                    visibility_function = function(content, style)
                        if not content or not content.favorite then
                            return false
                        end
                        style.text_color = { 255, 50, 245, 50 }
                        content.favorite_icon = "favorite glyph Favorite"
                        return true
                    end,
                },
                {
                    style_id = "myfav_hotspot",
                    style = {
                        horizontal_alignment = "left",
                        vertical_alignment = "bottom",
                        offset = { 15, -5, 16 },
                        size = { 120, 24 },
                    },
                },
                {
                    style_id = "myfav_extra_icon",
                    style = {
                        horizontal_alignment = "right",
                        vertical_alignment = "center",
                        offset = { 0, 0, 20 },
                        size = { 32, 32 },
                    },
                },
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
				{ style_id = "background", style = {} },
				{ style_id = "background_gradient", style = { size = {} } },
				{ style_id = "button_gradient", style = {} },
            },
        }
		raw_test_blueprint = table.clone(test_blueprint)
        """
    )

    lua.globals().TestLayoutContent = lua.execute(
        LAYOUT_CONTENT_PATH.read_text(encoding="utf-8"), name=str(LAYOUT_CONTENT_PATH)
    )
    lua.globals().TestLayoutCards = lua.execute(
        LAYOUT_CARDS_PATH.read_text(encoding="utf-8"), name=str(LAYOUT_CARDS_PATH)
    )
    # DMF io_dofile evaluates extracted modules independently. Cards must be
    # usable before the Layout facade loads; relying on facade-side injection
    # crashed Armoury/GlobalStore card setup with a nil columns_provider.
    assert (
        lua.globals().TestLayoutCards.grid_weapon_name_font_size(
            lua.globals().test_mod,
            lua.table_from({"store_item": True, "maximum_columns": 3}),
        )
        == 14
    )
    lua.globals().TestLayoutGeometry = lua.execute(
        LAYOUT_GEOMETRY_PATH.read_text(encoding="utf-8"), name=str(LAYOUT_GEOMETRY_PATH)
    )
    lua.globals().TestLayoutBlueprints = lua.execute(
        LAYOUT_BLUEPRINTS_PATH.read_text(encoding="utf-8"), name=str(LAYOUT_BLUEPRINTS_PATH)
    )
    layout = lua.execute(
        LAYOUT_PATH.read_text(encoding="utf-8"), name=str(LAYOUT_PATH)
    )
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

    # Corrupted/stale DMF values and a changed grid-width contract fail back to
    # bounded defaults instead of reaching math.floor/min with strings.
    mod.settings.columns = "invalid"
    mod.settings.grid_spacing = "invalid"
    mod.settings.card_height = "invalid"
    mod.settings.automatic_card_height = False
    guarded_item_size = layout.item_size(mod, "invalid")
    assert (guarded_item_size[1], guarded_item_size[2]) == (113, 110)
    mod.settings.columns = 3
    mod.settings.grid_spacing = 10
    mod.settings.card_height = 110
    mod.settings.automatic_card_height = True

    mod.settings.curio_display_profile = "detailed"
    mod.settings.curio_primary_stat_font_size = 20
    mod.settings.curio_secondary_stat_font_size = 20
    assert layout.card_height(mod) == 164
    mod.settings.automatic_card_height = False
    mod.settings.card_height = 175
    assert layout.card_height(mod) == 164
    mod.settings.automatic_card_height = True
    mod.settings.card_height = 110
    mod.settings.curio_display_profile = "primary"
    mod.settings.curio_primary_stat_font_size = 16
    mod.settings.curio_secondary_stat_font_size = 13

    store_configuration = lua.table_from(
        {"maximum_columns": 3, "store_item": True}
    )
    global_store_configuration = lua.table_from(
        {"maximum_columns": 5, "store_item": True, "global_store": True}
    )
    assert layout.card_height(mod, store_configuration) == 114
    assert layout.card_height(mod, global_store_configuration) == 144
    mod.settings.blessing_icon_size = 48
    assert layout.card_height(mod, store_configuration) == 128
    mod.settings.blessing_icon_size = 34
    mod.settings.curio_display_profile = "detailed"
    assert layout.card_height(mod, store_configuration) == 173
    mod.settings.curio_display_profile = "primary"

    mod.settings.show_weapon_perks = True
    assert layout.card_height(mod, store_configuration) == 153
    mod.settings.show_weapon_perk_rank_symbols = True
    mod.settings.weapon_perk_rank_icon_size = 32
    assert layout.card_height(mod, store_configuration) == 185
    mod.settings.weapon_perk_rank_icon_size = 18
    mod.settings.show_weapon_perk_rank_symbols = False
    mod.settings.show_weapon_perks = False

    assert layout.grid_expansion(mod, 596) == 0
    assert layout.armoury_grid_expansion(mod, 596) == 114

    armoury_definitions = lua.table_from(
        {
            "grid_settings": lua.table_from(
                {
                    "grid_size": lua.table_from([596, 860]),
                    "mask_size": lua.table_from([680, 860]),
                }
            ),
            "scenegraph_definition": lua.table_from(
                {
                    "item_grid_pivot": lua.table_from(
                        {"size": lua.table_from([640, 860])}
                    ),
                    "purchase_button": lua.table_from(
                        {"position": lua.table_from([857, -90, 1])}
                    ),
                }
            ),
        }
    )
    armoury_base_definitions = lua.table_from(
        {
            "scenegraph_definition": lua.table_from(
                {
                    "weapon_stats_pivot": lua.table_from(
                        {"position": lua.table_from([-1140, 80, 3])}
                    ),
                    "weapon_compare_stats_pivot": lua.table_from(
                        {"position": lua.table_from([-594, 80, 3])}
                    ),
                }
            )
        }
    )
    expanded_armoury, armoury_expansion = layout.expanded_armoury_view_definitions(
        mod, armoury_definitions, armoury_base_definitions
    )
    assert armoury_expansion == 114
    assert armoury_definitions.grid_settings.grid_size[1] == 596
    assert expanded_armoury.grid_settings.grid_size[1] == 710
    assert expanded_armoury.grid_settings.mask_size[1] == 794
    assert expanded_armoury.scenegraph_definition.item_grid_pivot.size[1] == 754
    assert expanded_armoury.scenegraph_definition.weapon_stats_pivot.position[1] == -1026
    assert (
        expanded_armoury.scenegraph_definition.weapon_compare_stats_pivot.position[1]
        == -480
    )
    assert expanded_armoury.scenegraph_definition.purchase_button.position[1] == 971
    assert tuple(
        layout.item_size(mod, 710, 3, store_configuration)[index]
        for index in (1, 2)
    ) == (230, 114)

    mod.settings.debug_expand_armoury_requisition_window_30_percent = True
    debug_armoury, debug_expansion = layout.expanded_armoury_view_definitions(
        mod, armoury_definitions, armoury_base_definitions
    )
    assert debug_expansion == 327
    assert debug_armoury.grid_settings.grid_size[1] == 923
    assert debug_armoury.grid_settings.mask_size[1] == 1007
    assert debug_armoury.scenegraph_definition.item_grid_pivot.size[1] == 967
    assert debug_armoury.scenegraph_definition.weapon_stats_pivot.position[1] == -813
    assert debug_armoury.scenegraph_definition.purchase_button.position[1] == 1184
    assert tuple(
        layout.item_size(mod, 923, 3, store_configuration)[index]
        for index in (1, 2)
    ) == (301, 114)

    mod.settings.debug_armoury_requisition_window_increase_percent = 10
    narrow_debug_armoury, narrow_debug_expansion = layout.expanded_armoury_view_definitions(
        mod, armoury_definitions, armoury_base_definitions
    )
    assert narrow_debug_expansion == 185
    assert narrow_debug_armoury.grid_settings.grid_size[1] == 781
    assert tuple(
        layout.item_size(mod, 781, 3, store_configuration)[index]
        for index in (1, 2)
    ) == (253, 114)

    mod.settings.debug_armoury_requisition_window_increase_percent = 100
    maximum_debug_armoury, maximum_debug_expansion = layout.expanded_armoury_view_definitions(
        mod, armoury_definitions, armoury_base_definitions
    )
    assert maximum_debug_expansion == 824
    assert maximum_debug_armoury.grid_settings.grid_size[1] == 1420
    assert tuple(
        layout.item_size(mod, 1420, 3, store_configuration)[index]
        for index in (1, 2)
    ) == (466, 114)

    mod.settings.debug_armoury_requisition_window_increase_percent = 30

    global_store_armoury, global_store_expansion = layout.expanded_armoury_view_definitions(
        mod,
        armoury_definitions,
        armoury_base_definitions,
        "enable_global_store_grid",
    )
    assert global_store_expansion == 114
    assert global_store_armoury.grid_settings.grid_size[1] == 710

    mod.settings.debug_adjust_global_store_window_width = True
    debug_global_store, debug_global_store_expansion = layout.expanded_global_store_view_definitions(
        mod, armoury_definitions, armoury_base_definitions
    )
    assert debug_global_store_expansion == 327
    assert debug_global_store.grid_settings.grid_size[1] == 923
    assert debug_global_store.scenegraph_definition.weapon_stats_pivot.position[1] == -813
    assert tuple(
        layout.item_size(mod, 923, 3, store_configuration)[index]
        for index in (1, 2)
    ) == (301, 114)

    mod.settings.debug_global_store_window_width_adjustment_percent = -25
    shrunken_global_store, shrunken_global_store_expansion = layout.expanded_global_store_view_definitions(
        mod, armoury_definitions, armoury_base_definitions
    )
    assert shrunken_global_store_expansion == -63
    assert shrunken_global_store.grid_settings.grid_size[1] == 533
    assert shrunken_global_store.scenegraph_definition.weapon_stats_pivot.position[1] == -1203
    assert tuple(
        layout.item_size(mod, 533, 3, store_configuration)[index]
        for index in (1, 2)
    ) == (171, 114)
    mod.settings.debug_adjust_global_store_window_width = False
    mod.settings.debug_global_store_window_width_adjustment_percent = 30
    mod.settings.debug_expand_armoury_requisition_window_30_percent = False

    mod.settings.expand_armoury_requisition_window = False
    assert layout.armoury_grid_expansion(mod, 596) == 0
    mod.settings.expand_armoury_requisition_window = True
    mod.settings.columns = 2
    assert layout.armoury_grid_expansion(mod, 596) == 0
    mod.settings.columns = 3

    mod.settings.melee_columns = 5
    mod.settings.ranged_columns = 4
    mod.settings.curio_columns = 5
    assert layout.columns(mod, 5, "melee") == 5
    assert layout.columns(mod, 5, "ranged") == 4
    assert layout.columns(mod, 5, "curio") == 5
    assert layout.columns(mod, 5, "slot_primary") == 5
    assert layout.columns(mod, 5, "slot_secondary") == 4
    assert layout.columns(mod, 3, "melee") == 3
    store_ranged_layout = lua.table_from(
        [lua.table_from({"item": lua.table_from({"slots": lua.table_from(["slot_secondary"])})})]
    )
    store_curio_layout = lua.table_from(
        [lua.table_from({"item": lua.table_from({"slots": lua.table_from(["slot_attachment_1"])})})]
    )
    assert layout.store_slot_kind(lua.table_from({}), store_ranged_layout) == "slot_secondary"
    assert layout.store_slot_kind(lua.table_from({}), store_curio_layout) == "curio"
    assert tuple(layout.item_size(mod, 596, 3)[index] for index in (1, 2)) == (
        192,
        110,
    )
    assert layout.grid_expansion(mod, 596, "melee") == 124
    assert layout.grid_expansion(mod, 596, "curio") == 394
    mod.settings.melee_columns = 3
    mod.settings.ranged_columns = 3
    mod.settings.curio_columns = 3
    mod.settings.melee_columns = None
    mod.settings.ranged_columns = None
    mod.settings.curio_columns = None
    mod.settings.columns = 5

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
                    "canvas": lua.table_from(
                        {"size": lua.table_from([1920, 1080])}
                    ),
                    "weapon_stats_pivot": lua.table_from(
                        {
                            "horizontal_alignment": "right",
                            "position": lua.table_from([-1140, 60, 3]),
                        }
                    ),
                    "weapon_actions_pivot": lua.table_from(
                        {
                            "horizontal_alignment": "right",
                            "position": lua.table_from([-560, 40, 3]),
                        }
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

    assert expansion == 124
    assert view_definitions.grid_settings.grid_size[1] == 596
    assert expanded_definitions.grid_settings.grid_size[1] == 720
    assert expanded_definitions.grid_settings.mask_size[1] == 804
    assert expanded_definitions.scenegraph_definition.weapon_stats_pivot.position[1] == -1016
    assert expanded_definitions.scenegraph_definition.weapon_actions_pivot.position[1] == -436
    assert expanded_definitions.scenegraph_definition.equip_button.position[1] == 981
    assert tuple(layout.item_size(mod, 720)[index] for index in (1, 2)) == (136, 110)

    mod.settings.debug_adjust_inventory_window_width = True
    debug_inventory_definitions, debug_inventory_expansion = layout.expanded_view_definitions(
        mod, view_definitions
    )
    assert debug_inventory_expansion == 340
    assert debug_inventory_definitions.grid_settings.grid_size[1] == 936
    assert debug_inventory_definitions.scenegraph_definition.weapon_stats_pivot.position[1] == -800
    assert debug_inventory_definitions.scenegraph_definition.weapon_actions_pivot.position[1] == -220
    assert tuple(layout.item_size(mod, 936)[index] for index in (1, 2)) == (179, 110)

    mod.settings.debug_inventory_window_width_adjustment_percent = -25
    shrunken_inventory_definitions, shrunken_inventory_expansion = layout.expanded_view_definitions(
        mod, view_definitions
    )
    assert shrunken_inventory_expansion == -56
    assert shrunken_inventory_definitions.grid_settings.grid_size[1] == 540
    assert shrunken_inventory_definitions.scenegraph_definition.weapon_stats_pivot.position[1] == -1196
    assert shrunken_inventory_definitions.scenegraph_definition.weapon_actions_pivot.position[1] == -616
    assert tuple(layout.item_size(mod, 540)[index] for index in (1, 2)) == (100, 110)
    mod.settings.debug_adjust_inventory_window_width = False
    mod.settings.debug_inventory_window_width_adjustment_percent = 30

    mod.settings.five_column_weapon_extra_width = 0
    assert layout.grid_expansion(mod, 596) == 44
    mod.settings.five_column_weapon_extra_width = 80

    mod.settings.columns = 4
    assert layout.grid_expansion(mod, 596) == 80
    four_column_definitions, four_column_expansion = layout.expanded_view_definitions(
        mod, view_definitions
    )
    assert four_column_expansion == 80
    assert four_column_definitions.grid_settings.grid_size[1] == 676
    assert tuple(
        layout.item_size(mod, 676)[index] for index in (1, 2)
    ) == (161, 110)
    mod.settings.weapon_extra_width_column_threshold = "five_only"
    assert layout.grid_expansion(mod, 596) == 0
    mod.settings.weapon_extra_width_column_threshold = "four_plus"
    mod.settings.columns = 5

    curio_view = lua.table_from(
        {"_selected_slot": lua.table_from({"name": "slot_attachment_1"})}
    )
    curio_definitions, curio_expansion = layout.expanded_view_definitions(
        mod, view_definitions, curio_view
    )
    assert curio_expansion == 394
    assert curio_definitions.grid_settings.grid_size[1] == 990
    assert tuple(layout.item_size(mod, 990)[index] for index in (1, 2)) == (190, 110)

    mod.settings.grid_spacing = 40
    mod.settings.curio_target_card_width = 220

    extreme_weapon_definitions, extreme_weapon_expansion = (
        layout.expanded_view_definitions(mod, view_definitions)
    )
    assert extreme_weapon_expansion == 124
    assert extreme_weapon_definitions.grid_settings.grid_size[1] == 720
    assert tuple(
        layout.item_size(mod, 720)[index] for index in (1, 2)
    ) == (112, 110)
    assert (
        1920
        + extreme_weapon_definitions.scenegraph_definition.weapon_actions_pivot.position[1]
        + 420
    ) == 1904

    extreme_curio_definitions, extreme_curio_expansion = (
        layout.expanded_view_definitions(mod, view_definitions, curio_view)
    )
    assert extreme_curio_expansion == 594
    assert extreme_curio_definitions.grid_settings.grid_size[1] == 1190
    assert tuple(
        layout.item_size(mod, 1190)[index] for index in (1, 2)
    ) == (206, 110)
    assert (
        1920
        + extreme_curio_definitions.scenegraph_definition.weapon_stats_pivot.position[1]
        + 530
    ) == 1904
    assert mod.settings.grid_spacing == 40
    assert mod.settings.curio_target_card_width == 220

    mod.settings.grid_spacing = 10
    mod.settings.curio_target_card_width = 190

    mod.settings.expand_curio_inventory_window = False
    assert layout.grid_expansion(mod, 596, "curio") == 44
    mod.settings.expand_curio_inventory_window = True

    mod.settings.expand_inventory_window = False
    assert layout.grid_expansion(mod, 596) == 0
    assert tuple(layout.item_size(mod, 596)[index] for index in (1, 2)) == (111, 110)

    mod.settings.columns = 3
    mod.settings.expand_inventory_window = True

    mod.settings.columns = 5
    vendor_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    vendor_size = layout.configure_item_blueprint(
        mod, vendor_blueprint, 596, store_configuration
    )
    assert (vendor_size[1], vendor_size[2]) == (192, 114)
    assert blueprint_pass(vendor_blueprint, "wallet_icon").style.horizontal_alignment == "left"
    assert blueprint_pass(vendor_blueprint, "price_text").style.font_size == 16
    assert blueprint_pass(vendor_blueprint, "price_text").style.offset[1] == 39
    assert blueprint_pass(vendor_blueprint, "owned_text").style.offset[1] == 12
    assert blueprint_pass(vendor_blueprint, "better_inventory_blessing_1").style.offset[2] == -37
    same_lua_value = lua.eval("function(left, right) return left == right end")
    assert same_lua_value(vendor_blueprint.load_icon, globals_.sentinel_load)
    assert same_lua_value(vendor_blueprint.unload_icon, globals_.sentinel_unload)
    assert same_lua_value(vendor_blueprint.destroy, globals_.sentinel_destroy)
    assert same_lua_value(
        vendor_blueprint.update_item_icon_priority, globals_.sentinel_priority
    )
    assert same_lua_value(vendor_blueprint.update, globals_.sentinel_update)

    # Vendor views must remain capped at three columns even if an older
    # profile still carries the retired global five-column value. Dedicated
    # Melee/Ranged/Curios settings are intentionally not consulted here.
    mod.settings.melee_columns = 5
    mod.settings.ranged_columns = 5
    mod.settings.curio_columns = 5
    global_store_capped_configuration = lua.table_from(
        {"maximum_columns": 3, "store_item": True, "global_store": True}
    )
    capped_global_store_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    capped_global_store_size = layout.configure_item_blueprint(
        mod, capped_global_store_blueprint, 596, global_store_capped_configuration
    )
    assert (capped_global_store_size[1], capped_global_store_size[2]) == (192, 144)

    mod.settings.columns = 2
    mod.settings.ranged_columns = 3
    mod.settings.curio_columns = 4
    ranged_store_configuration = lua.table_from(
        {"maximum_columns": 3, "store_item": True, "slot_kind": "slot_secondary"}
    )
    curio_store_configuration = lua.table_from(
        {"maximum_columns": 3, "store_item": True, "slot_kind": "curio"}
    )
    assert tuple(
        layout.item_size(mod, 596, 3, ranged_store_configuration)[index]
        for index in (1, 2)
    ) == (192, 114)
    assert tuple(
        layout.item_size(mod, 596, 3, curio_store_configuration)[index]
        for index in (1, 2)
    ) == (192, 114)
    mod.settings.columns = 5

    global_store_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    global_store_size = layout.configure_item_blueprint(
        mod, global_store_blueprint, 596, global_store_configuration
    )
    assert (global_store_size[1], global_store_size[2]) == (111, 144)
    assert blueprint_pass(global_store_blueprint, "wallet_icon").style.horizontal_alignment == "left"
    assert blueprint_pass(global_store_blueprint, "price_text").style.horizontal_alignment == "left"
    assert blueprint_pass(global_store_blueprint, "price_text").style.offset[1] == 39
    global_store_level = blueprint_pass(global_store_blueprint, "item_level").style
    assert global_store_level.vertical_alignment == "bottom"
    assert global_store_level.offset[2] == -40
    assert blueprint_pass(global_store_blueprint, "icon").style.size[2] == 114
    assert blueprint_pass(global_store_blueprint, "portrait").style.size[1] == 33
    assert blueprint_pass(global_store_blueprint, "portrait").style.offset[2] == -2
    assert blueprint_pass(global_store_blueprint, "character_info_text").style.font_size == 16
    assert blueprint_pass(global_store_blueprint, "character_info_text").style.offset[1] == 70
    assert blueprint_pass(global_store_blueprint, "character_info_text").style.offset[2] == -7
    assert blueprint_pass(global_store_blueprint, "character_info_text").style.size[1] == 29
    assert blueprint_pass(global_store_blueprint, "character_info_text").style.text_fit_with is True
    global_store_class_icon = blueprint_pass(global_store_blueprint, "character_class_icon_text").style
    assert global_store_class_icon.font_size == 16
    assert global_store_class_icon.size[1] == 20
    assert global_store_class_icon.offset[1] == 50
    assert global_store_class_icon.offset[2] == -7

    mod.settings.global_store_character_class_icon_size = 20
    mod.settings.global_store_character_name_font_size = 11
    resized_character_info_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    resized_character_info_size = layout.configure_item_blueprint(
        mod, resized_character_info_blueprint, 596, global_store_configuration
    )
    assert (resized_character_info_size[1], resized_character_info_size[2]) == (111, 144)
    resized_class_icon = blueprint_pass(resized_character_info_blueprint, "character_class_icon_text").style
    resized_character_name = blueprint_pass(resized_character_info_blueprint, "character_info_text").style
    assert resized_class_icon.font_size == 20
    assert resized_class_icon.size[1] == 24
    assert resized_class_icon.offset[1] == 50
    assert resized_character_name.font_size == 11
    assert resized_character_name.offset[1] == 74
    mod.settings.global_store_character_class_icon_size = 16
    mod.settings.global_store_character_name_font_size = 16

    mod.settings.global_store_compact_character_names = False
    no_compact_character_names_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, no_compact_character_names_blueprint, 596, global_store_configuration)
    assert blueprint_pass(no_compact_character_names_blueprint, "character_info_text").style.text_fit_with is False
    assert blueprint_pass(no_compact_character_names_blueprint, "character_info_text").style.size[1] == 40
    mod.settings.global_store_compact_character_names = True

    mod.settings.global_store_character_photo_size_percent = 50
    assert layout.card_height(mod, global_store_configuration) == 144
    reduced_photo_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    reduced_photo_size = layout.configure_item_blueprint(
        mod, reduced_photo_blueprint, 596, global_store_configuration
    )
    assert (reduced_photo_size[1], reduced_photo_size[2]) == (111, 144)
    assert blueprint_pass(reduced_photo_blueprint, "icon").style.size[2] == 114
    assert blueprint_pass(reduced_photo_blueprint, "portrait").style.size[1] == 15
    assert blueprint_pass(reduced_photo_blueprint, "price_text").style.offset[2] == -40
    mod.settings.global_store_character_photo_size_percent = 110

    mod.settings.global_store_character_photo_size_percent = 125
    enlarged_photo_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    enlarged_photo_size = layout.configure_item_blueprint(
        mod, enlarged_photo_blueprint, 596, global_store_configuration
    )
    assert (enlarged_photo_size[1], enlarged_photo_size[2]) == (111, 144)
    assert blueprint_pass(enlarged_photo_blueprint, "icon").style.size[2] == 114
    enlarged_portrait = blueprint_pass(enlarged_photo_blueprint, "portrait").style
    assert enlarged_portrait.size[1] == 38
    assert enlarged_portrait.offset[1] == 12
    assert enlarged_portrait.offset[2] == -2
    assert blueprint_pass(enlarged_photo_blueprint, "character_info_text").style.offset[1] == 75
    assert blueprint_pass(enlarged_photo_blueprint, "price_text").style.offset[2] == -40
    mod.settings.global_store_character_photo_size_percent = 110

    mod.settings.global_store_price_row_padding = 20
    assert layout.card_height(mod, global_store_configuration) == 154
    padded_price_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    padded_price_size = layout.configure_item_blueprint(
        mod, padded_price_blueprint, 596, global_store_configuration
    )
    assert (padded_price_size[1], padded_price_size[2]) == (111, 154)
    assert blueprint_pass(padded_price_blueprint, "icon").style.size[2] == 114
    assert blueprint_pass(padded_price_blueprint, "price_text").style.offset[2] == -50
    mod.settings.global_store_price_row_padding = 10

    mod.settings.global_store_character_info_gap = 24
    wider_info_gap_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, wider_info_gap_blueprint, 596, global_store_configuration)
    assert blueprint_pass(wider_info_gap_blueprint, "character_info_text").style.offset[1] == 89
    mod.settings.global_store_character_info_gap = 5

    mod.settings.columns = 2
    two_column_global_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    two_column_global_size = layout.configure_item_blueprint(
        mod, two_column_global_blueprint, 596, global_store_configuration
    )
    assert (two_column_global_size[1], two_column_global_size[2]) == (293, 144)
    assert blueprint_pass(two_column_global_blueprint, "icon").style.size[2] == 114
    assert blueprint_pass(two_column_global_blueprint, "item_level").style.offset[2] == -40
    assert blueprint_pass(two_column_global_blueprint, "price_text").style.offset[2] == -40
    assert blueprint_pass(two_column_global_blueprint, "better_inventory_quick_look_card_dump_stat").style.offset[2] == -66
    assert blueprint_pass(two_column_global_blueprint, "portrait").style.size[1] == 33
    assert blueprint_pass(two_column_global_blueprint, "portrait").style.offset[2] == -2
    assert blueprint_pass(two_column_global_blueprint, "character_class_icon_text").style.offset[1] == 50
    assert blueprint_pass(two_column_global_blueprint, "character_info_text").style.offset[1] == 70
    assert blueprint_pass(two_column_global_blueprint, "character_info_text").style.text_fit_with is False
    mod.settings.columns = 5

    mod.settings.show_weapon_perks = True
    vendor_perk_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    vendor_perk_size = layout.configure_item_blueprint(
        mod, vendor_perk_blueprint, 596, store_configuration
    )
    assert (vendor_perk_size[1], vendor_perk_size[2]) == (192, 153)
    assert (
        blueprint_pass(
            vendor_perk_blueprint, "better_inventory_weapon_perk_1"
        ).style.offset[2]
        == -98
    )
    assert (
        blueprint_pass(
            vendor_perk_blueprint, "better_inventory_weapon_perk_2"
        ).style.offset[2]
        == -79
    )
    mod.settings.show_weapon_perks = False

    mod.settings.curio_display_profile = "detailed"
    vendor_curio_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    vendor_curio_size = layout.configure_item_blueprint(
        mod, vendor_curio_blueprint, 596, store_configuration
    )
    assert (vendor_curio_size[1], vendor_curio_size[2]) == (192, 173)
    first_vendor_curio_line = blueprint_pass(
        vendor_curio_blueprint, "better_inventory_curio_stat_1"
    ).style
    second_vendor_curio_line = blueprint_pass(
        vendor_curio_blueprint, "better_inventory_curio_stat_2"
    ).style
    fourth_vendor_curio_line = blueprint_pass(
        vendor_curio_blueprint, "better_inventory_curio_stat_4"
    ).style
    assert first_vendor_curio_line.font_size == 16
    assert second_vendor_curio_line.font_size == 13
    assert second_vendor_curio_line.offset[2] == 73
    assert fourth_vendor_curio_line.offset[2] + fourth_vendor_curio_line.size[2] == 127
    assert fourth_vendor_curio_line.offset[2] + fourth_vendor_curio_line.size[2] < (
        vendor_curio_size[2] - 34
    )

    mod.settings.curio_primary_stat_font_size = 18
    mod.settings.curio_secondary_stat_font_size = 10
    mod.settings.curio_primary_secondary_spacing = 9
    custom_curio_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    custom_curio_size = layout.configure_item_blueprint(
        mod, custom_curio_blueprint, 596, store_configuration
    )
    assert (custom_curio_size[1], custom_curio_size[2]) == (192, 170)
    assert (
        blueprint_pass(
            custom_curio_blueprint, "better_inventory_curio_stat_1"
        ).style.font_size
        == 18
    )
    assert (
        blueprint_pass(
            custom_curio_blueprint, "better_inventory_curio_stat_2"
        ).style.font_size
        == 10
    )
    assert (
        blueprint_pass(
            custom_curio_blueprint, "better_inventory_curio_stat_2"
        ).style.offset[2]
        == 79
    )
    mod.settings.curio_primary_stat_font_size = 16
    mod.settings.curio_secondary_stat_font_size = 13
    mod.settings.curio_primary_secondary_spacing = 5
    mod.settings.curio_display_profile = "primary"
    mod.settings.columns = 3

    mod.settings.enable_grid_layout = False
    assert layout.grid_expansion(mod, 596) == 0
    native_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    native_size = layout.configure_item_blueprint(mod, native_blueprint, 596)
    assert (native_size[1], native_size[2]) == (586, 110)
    assert blueprint_pass(native_blueprint, "display_name").style.font_size == 20
    native_icon_size = blueprint_pass(native_blueprint, "icon").style.size
    assert (native_icon_size[1], native_icon_size[2]) == (586, 110)
    assert (
        blueprint_pass(native_blueprint, "better_inventory_curio_stat_1").style.font_size
        == 16
    )

    # Armoury mirror mode uses the same detailed native card content while
    # retaining the store footer reservation for its wallet and price passes.
    armoury_native_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    armoury_native_configuration = lua.table_from(
        {"native_single_column": True, "store_item": True}
    )
    armoury_native_size = layout.configure_item_blueprint(
        mod, armoury_native_blueprint, 596, armoury_native_configuration
    )
    assert armoury_native_size[2] >= native_size[2]
    assert armoury_native_size[2] == 146
    armoury_native_level = blueprint_pass(armoury_native_blueprint, "item_level").style
    assert armoury_native_level.offset[3] == 12
    assert armoury_native_level.offset[2] == -36
    armoury_native_stat = blueprint_pass(
        armoury_native_blueprint, "better_inventory_weapon_modifier_title_1"
    ).style
    assert armoury_native_stat.offset[3] == 12
    assert armoury_native_stat.offset[2] < armoury_native_size[2] - 34 - 8

    # Built-in modifier passes must exist and populate maximum-potential values
    # even when Quick Look Card contributes no blueprint passes at all.
    native_modifier_styles = {
        "display_name": blueprint_pass(native_blueprint, "display_name").style,
    }
    for index in range(1, 6):
        for prefix in (
            "better_inventory_weapon_modifier_title_",
            "better_inventory_weapon_modifier_value_",
        ):
            style_id = f"{prefix}{index}"
            native_modifier_styles[style_id] = blueprint_pass(
                native_blueprint, style_id
            ).style
    native_modifier_widget = lua.table_from(
        {"content": lua.table_from({}), "style": lua.table_from(native_modifier_styles)}
    )
    native_modifier_element = lua.table_from(
        {
            "test_display_name": "Force Sword",
            "test_sub_display_name": "Mk VI",
            "item": lua.table_from(
                {
                    "item_type": "WEAPON_MELEE",
                    "expertise": 260,
                    "projected_values": lua.table_from([80, 60, 80, 80, 80]),
                }
            ),
        }
    )
    native_blueprint.init(
        None,
        native_modifier_widget,
        native_modifier_element,
        None,
        None,
        lua.table_from({}),
        None,
        native_blueprint,
    )
    assert tuple(
        native_modifier_widget.content[
            f"better_inventory_weapon_modifier_title_{index}"
        ]
        for index in range(1, 6)
    ) == ("DMG", "FIN", "CLVD", "DEF", "WRES")
    assert tuple(
        native_modifier_widget.content[
            f"better_inventory_weapon_modifier_value_{index}"
        ]
        for index in range(1, 6)
    ) == ("80", "80", "80", "80", "60")

    # Ammo stays compact in every managed blueprint, including views that use
    # the shared native single-column formatter (inventory, vendors, Hadron,
    # GlobalStore, and character overview).
    ammo_modifier_element = lua.eval(
        """
        {
            test_display_name = "Ammo Weapon",
            test_sub_display_name = "Mk I",
            item = {
                item_type = "WEAPON_RANGED",
                expertise = 260,
                projected_values = { 60, 80, 80, 80, 80 },
                modifier_display_names = {
                    "loc_stats_display_ammo_stat",
                    "loc_stats_display_warp_resist_stat",
                    "loc_stats_display_cleave_damage_stat",
                    "loc_stats_display_defense_stat",
                    "loc_stats_display_finesse_stat"
                }
            }
        }
        """
    )
    ammo_modifier_widget = lua.table_from(
        {"content": lua.table_from({}), "style": lua.table_from(native_modifier_styles)}
    )
    native_blueprint.init(
        None,
        ammo_modifier_widget,
        ammo_modifier_element,
        None,
        None,
        lua.table_from({}),
        None,
        native_blueprint,
    )
    assert ammo_modifier_widget.content.better_inventory_weapon_modifier_title_1 == "AMM"

    standalone_low_title_pass = blueprint_pass(
        native_blueprint, "better_inventory_weapon_modifier_title_5"
    )
    standalone_low_title_pass.change_function(
        native_modifier_widget.content,
        standalone_low_title_pass.style,
    )
    assert tuple(
        standalone_low_title_pass.style.text_color[index] for index in range(1, 5)
    ) == (204, 255, 94, 132)

    mod.settings.weapon_modifier_lowest_color_r = 12
    mod.settings.weapon_modifier_lowest_color_g = 34
    mod.settings.weapon_modifier_lowest_color_b = 56
    mod.settings.weapon_modifier_lowest_color_opacity = 50
    custom_color_native_blueprint = lua.eval("table.clone")(
        globals_.raw_test_blueprint
    )
    layout.configure_item_blueprint(mod, custom_color_native_blueprint, 596)
    custom_color_title_pass = blueprint_pass(
        custom_color_native_blueprint, "better_inventory_weapon_modifier_title_1"
    )
    custom_color_title_pass.change_function(
        lua.table_from({"better_inventory_weapon_modifier_lowest_index": 1}),
        custom_color_title_pass.style,
    )
    assert tuple(
        custom_color_title_pass.style.text_color[index] for index in range(1, 5)
    ) == (128, 12, 34, 56)
    mod.settings.weapon_modifier_lowest_color_r = 255
    mod.settings.weapon_modifier_lowest_color_g = 94
    mod.settings.weapon_modifier_lowest_color_b = 132
    mod.settings.weapon_modifier_lowest_color_opacity = 80

    # Unknown future modifier IDs receive bounded deterministic fallbacks, and
    # colliding four-character labels are disambiguated within the same weapon.
    future_modifier_element = lua.eval(
        """
        {
            test_display_name = "Future Weapon",
            test_sub_display_name = "Mk I",
            item = {
                item_type = "WEAPON_MELEE",
                expertise = 260,
                projected_values = { 60, 60, 80, 80, 80 },
                modifier_display_names = {
                    "loc_stats_display_alpha_stat",
                    "loc_stats_display_alpha2_stat",
                    "loc_stats_display_gamma_stat",
                    "loc_stats_display_delta_stat",
                    "loc_stats_display_epsilon_stat"
                }
            }
        }
        """
    )
    future_modifier_widget = lua.table_from(
        {"content": lua.table_from({}), "style": lua.table_from(native_modifier_styles)}
    )
    native_blueprint.init(
        None,
        future_modifier_widget,
        future_modifier_element,
        None,
        None,
        lua.table_from({}),
        None,
        native_blueprint,
    )
    first_future_label = (
        future_modifier_widget.content.better_inventory_weapon_modifier_title_1
    )
    tied_future_label = (
        future_modifier_widget.content.better_inventory_weapon_modifier_title_5
    )
    assert first_future_label == "ALPH"
    assert tied_future_label == "ALP2"
    assert len(first_future_label) <= 4 and len(tied_future_label) <= 4
    native_equipped_highlight = blueprint_pass(
        native_blueprint, "better_inventory_equipped_highlight"
    )
    assert native_equipped_highlight.visibility_function(
        lua.table_from({"equipped": True})
    ) is True
    native_grid = lua.table_from(
        {"_menu_settings": lua.table_from({"grid_spacing": lua.table_from([4, 4])})}
    )
    layout.configure_grid(mod, native_grid)
    assert (
        native_grid._menu_settings.grid_spacing[1],
        native_grid._menu_settings.grid_spacing[2],
    ) == (4, 4)

    # Native single-column cards must reserve a real vertical region for all
    # four default perk/blessing rows instead of laying them over the name.
    mod.settings.weapon_blessing_display_mode = "ranked_text"
    mod.settings.show_weapon_perks = True
    mod.settings.show_weapon_perk_rank_symbols = True
    native_detailed_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    native_detailed_size = layout.configure_item_blueprint(
        mod, native_detailed_blueprint, 596
    )
    assert (native_detailed_size[1], native_detailed_size[2]) == (586, 146)
    native_detailed_icon_size = blueprint_pass(
        native_detailed_blueprint, "icon"
    ).style.size
    assert (native_detailed_icon_size[1], native_detailed_icon_size[2]) == (586, 110)
    for style_id in (
        "background",
        "background_gradient",
        "button_gradient",
        "inner_shadow",
        "inner_highlight",
        "item_level",
        "rarity_tag",
    ):
        assert blueprint_pass(native_detailed_blueprint, style_id).style.size[2] == 146
    native_first_perk = blueprint_pass(
        native_detailed_blueprint, "better_inventory_weapon_perk_1"
    ).style
    assert native_detailed_size[2] + native_first_perk.offset[2] >= 60

    # The native weapon-name control grows card geometry by the same delta, so
    # larger names never consume the perk/blessing rows below them.
    mod.settings.single_column_weapon_name_font_size = 22
    large_name_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    large_name_size = layout.configure_item_blueprint(mod, large_name_blueprint, 596)
    assert (large_name_size[1], large_name_size[2]) == (586, 148)
    assert blueprint_pass(large_name_blueprint, "display_name").style.font_size == 22
    mod.settings.single_column_weapon_name_font_size = 20

    # In native mode BetterInventory keeps only Quick Look Card's five modifier
    # stats, then renders its own perks, blessings and primary item power.
    qlc_native_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    qlc_native_pass = lua.table_from(
        {
            "style_id": "qlc_stats_title_1",
            "style": lua.table_from({}),
            # Models Quick Look Card being installed while its own modifier
            # toggle (or the whole mod) is disabled.
            "visibility_function": lua.eval("function() return false end"),
        }
    )
    qlc_native_blueprint.pass_template[len(qlc_native_blueprint.pass_template) + 1] = (
        qlc_native_pass
    )
    for hidden_style_id in (
        "qlc_baseLevel",
        "qlc_trait_level_1",
        "qlc_weapon_perk_title_1",
    ):
        qlc_native_blueprint.pass_template[
            len(qlc_native_blueprint.pass_template) + 1
        ] = lua.table_from(
            {
                "style_id": hidden_style_id,
                "style": lua.table_from({}),
                "visibility_function": lua.eval("function() return true end"),
            }
        )
    qlc_native_size = layout.configure_item_blueprint(mod, qlc_native_blueprint, 596)
    assert (qlc_native_size[1], qlc_native_size[2]) == (586, 146)
    qlc_stat_style = blueprint_pass(
        qlc_native_blueprint, "qlc_stats_title_1"
    ).style
    qlc_value_style = blueprint_pass(
        qlc_native_blueprint, "better_inventory_weapon_modifier_value_1"
    ).style
    assert blueprint_pass(
        qlc_native_blueprint, "qlc_stats_title_1"
    ).visibility_function() is False
    assert blueprint_pass(
        qlc_native_blueprint, "qlc_stats_title_1"
    ).visibility_function(
        lua.table_from({"better_inventory_weapon_modifier_title_1": "DMG"})
    ) is True
    assert (
        blueprint_pass(qlc_native_blueprint, "qlc_stats_title_1").value_id
        == "better_inventory_weapon_modifier_title_1"
    )
    assert not any(
        qlc_native_blueprint.pass_template[index].style_id
        == "better_inventory_weapon_modifier_title_1"
        for index in range(1, len(qlc_native_blueprint.pass_template) + 1)
    )
    assert (qlc_stat_style.offset[1], qlc_stat_style.offset[2]) == (277, 102)
    assert (qlc_stat_style.size[1], qlc_stat_style.size[2]) == (42, 17)
    assert qlc_value_style.offset[1] - qlc_stat_style.offset[1] >= qlc_stat_style.size[1] + 1
    for index in range(1, 6):
        title_style = (
            qlc_stat_style
            if index == 1
            else blueprint_pass(
                qlc_native_blueprint,
                f"better_inventory_weapon_modifier_title_{index}",
            ).style
        )
        value_style = blueprint_pass(
            qlc_native_blueprint,
            f"better_inventory_weapon_modifier_value_{index}",
        ).style
        assert value_style.offset[1] - title_style.offset[1] >= title_style.size[1] + 1

    mod.settings.quick_look_card_single_column_label_value_gap = 0
    tight_gap_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, tight_gap_blueprint, 596)
    tight_title_style = blueprint_pass(
        tight_gap_blueprint, "better_inventory_weapon_modifier_title_2"
    ).style
    tight_value_style = blueprint_pass(
        tight_gap_blueprint, "better_inventory_weapon_modifier_value_2"
    ).style
    assert tight_value_style.offset[1] - tight_title_style.offset[1] == tight_title_style.size[1]
    mod.settings.quick_look_card_single_column_label_value_gap = 1
    assert qlc_stat_style.font_size == 14
    assert qlc_stat_style.vertical_alignment == "top"
    assert qlc_stat_style.drop_shadow is True
    for hidden_style_id in (
        "qlc_baseLevel",
        "qlc_trait_level_1",
        "qlc_weapon_perk_title_1",
    ):
        assert blueprint_pass(
            qlc_native_blueprint, hidden_style_id
        ).visibility_function() is False
    assert blueprint_pass(
        qlc_native_blueprint, "better_inventory_weapon_perk_1"
    ) is not None
    assert blueprint_pass(
        qlc_native_blueprint, "better_inventory_blessing_text_1"
    ) is not None
    qlc_perk_style = blueprint_pass(
        qlc_native_blueprint, "better_inventory_weapon_perk_1"
    ).style
    qlc_blessing_style = blueprint_pass(
        qlc_native_blueprint, "better_inventory_blessing_text_1"
    ).style
    assert qlc_perk_style.offset[1] + qlc_perk_style.size[1] == 260
    assert qlc_blessing_style.offset[1] + qlc_blessing_style.size[1] == 138
    assert blueprint_pass(
        qlc_native_blueprint, "better_inventory_blessing_1"
    ).style.offset[1] == 146
    assert blueprint_pass(
        qlc_native_blueprint, "better_inventory_blessing_2"
    ).style.offset[1] == 183

    # Position percentages operate over the stat block's available travel area;
    # 0/100 therefore anchor it to the left/bottom edges at any card height.
    mod.settings.quick_look_card_single_column_font_size = 16
    mod.settings.quick_look_card_single_column_horizontal_position = 0
    mod.settings.quick_look_card_single_column_vertical_position = 100
    qlc_moved_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    qlc_moved_blueprint.pass_template[len(qlc_moved_blueprint.pass_template) + 1] = (
        lua.eval("table.clone")(qlc_native_pass)
    )
    layout.configure_item_blueprint(mod, qlc_moved_blueprint, 596)
    qlc_moved_style = blueprint_pass(qlc_moved_blueprint, "qlc_stats_title_1").style
    assert (qlc_moved_style.offset[1], qlc_moved_style.offset[2]) == (0, 106)
    assert (qlc_moved_style.size[1], qlc_moved_style.size[2]) == (48, 19)
    assert qlc_moved_style.font_size == 16
    mod.settings.quick_look_card_single_column_font_size = 14
    mod.settings.quick_look_card_single_column_horizontal_position = 79
    mod.settings.quick_look_card_single_column_vertical_position = 93

    # Disabling native integration restores Quick Look Card's own compact card
    # instead of applying BetterInventory's detail rows over it.
    mod.settings.enable_quick_look_card_single_column_integration = False
    qlc_unmanaged_native_blueprint = lua.eval("table.clone")(
        globals_.raw_test_blueprint
    )
    qlc_unmanaged_native_blueprint.pass_template[
        len(qlc_unmanaged_native_blueprint.pass_template) + 1
    ] = lua.eval("table.clone")(qlc_native_pass)
    qlc_unmanaged_native_size = layout.configure_item_blueprint(
        mod, qlc_unmanaged_native_blueprint, 596
    )
    assert (qlc_unmanaged_native_size[1], qlc_unmanaged_native_size[2]) == (586, 110)
    assert blueprint_pass(
        qlc_unmanaged_native_blueprint, "qlc_stats_title_1"
    ).visibility_function() is False
    assert not any(
        qlc_unmanaged_native_blueprint.pass_template[index].style_id
        == "better_inventory_weapon_perk_1"
        for index in range(
            1, len(qlc_unmanaged_native_blueprint.pass_template) + 1
        )
    )
    standalone_disabled_native_blueprint = lua.eval("table.clone")(
        globals_.raw_test_blueprint
    )
    layout.configure_item_blueprint(mod, standalone_disabled_native_blueprint, 596)
    assert not any(
        standalone_disabled_native_blueprint.pass_template[index].style_id
        == "better_inventory_weapon_modifier_title_1"
        for index in range(
            1, len(standalone_disabled_native_blueprint.pass_template) + 1
        )
    )
    mod.settings.enable_quick_look_card_single_column_integration = True

    mod.settings.weapon_blessing_display_mode = "icons"
    mod.settings.show_weapon_perks = False
    mod.settings.show_weapon_perk_rank_symbols = False
    mod.settings.enable_grid_layout = True

    standalone_grid_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, standalone_grid_blueprint, 596)
    standalone_dump_pass = blueprint_pass(
        standalone_grid_blueprint, "better_inventory_quick_look_card_dump_stat"
    )
    standalone_dump_content = lua.eval(
        """
        {
            element = {
                item = {
                    item_type = "WEAPON_MELEE",
                    expertise = 260,
                    projected_values = { 80, 60, 80, 80, 80 }
                }
            }
        }
        """
    )
    assert standalone_dump_pass.visibility_function(standalone_dump_content) is True
    assert (
        standalone_dump_content.better_inventory_quick_look_card_dump_stat
        == "WRES 60"
    )

    qlc_grid_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    qlc_grid_blueprint.pass_template[len(qlc_grid_blueprint.pass_template) + 1] = (
        lua.eval("table.clone")(qlc_native_pass)
    )
    layout.configure_item_blueprint(mod, qlc_grid_blueprint, 596)
    assert blueprint_pass(
        qlc_grid_blueprint, "qlc_stats_title_1"
    ).visibility_function() is False
    qlc_dump_pass = blueprint_pass(
        qlc_grid_blueprint, "better_inventory_quick_look_card_dump_stat"
    )
    assert qlc_dump_pass is not None
    assert qlc_dump_pass.style.font_size == 13
    assert qlc_dump_pass.style.horizontal_alignment == "right"
    assert qlc_dump_pass.style.vertical_alignment == "bottom"
    assert (qlc_dump_pass.style.offset[1], qlc_dump_pass.style.offset[2]) == (
        -8,
        -26,
    )
    assert tuple(qlc_dump_pass.style.text_color[index] for index in range(1, 5)) == (
        204,
        255,
        94,
        132,
    )

    mod.settings.weapon_modifier_lowest_color_r = 12
    mod.settings.weapon_modifier_lowest_color_g = 34
    mod.settings.weapon_modifier_lowest_color_b = 56
    mod.settings.weapon_modifier_lowest_color_opacity = 50
    custom_color_grid_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, custom_color_grid_blueprint, 596)
    custom_color_dump_pass = blueprint_pass(
        custom_color_grid_blueprint, "better_inventory_quick_look_card_dump_stat"
    )
    assert tuple(
        custom_color_dump_pass.style.text_color[index] for index in range(1, 5)
    ) == (128, 12, 34, 56)
    mod.settings.weapon_modifier_lowest_color_r = 255
    mod.settings.weapon_modifier_lowest_color_g = 94
    mod.settings.weapon_modifier_lowest_color_b = 132
    mod.settings.weapon_modifier_lowest_color_opacity = 80

    mod.settings.quick_look_card_grid_bottom_padding = 32
    qlc_lower_padding_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    qlc_lower_padding_blueprint.pass_template[
        len(qlc_lower_padding_blueprint.pass_template) + 1
    ] = lua.eval("table.clone")(qlc_native_pass)
    layout.configure_item_blueprint(mod, qlc_lower_padding_blueprint, 596)
    assert blueprint_pass(
        qlc_lower_padding_blueprint, "better_inventory_quick_look_card_dump_stat"
    ).style.offset[2] == -32
    mod.settings.quick_look_card_grid_bottom_padding = 26

    qlc_dump_content = lua.eval(
        """
        {
            element = {
                item = {
                    item_type = "WEAPON_MELEE",
                    expertise = 260,
                    projected_values = { 80, 60, 80, 80, 80 }
                }
            },
            qlc_stats_title_1 = "DMG",
            qlc_stats_value_1 = "21+",
            qlc_stats_title_2 = "FIN",
            qlc_stats_value_2 = "0+",
            qlc_stats_title_3 = "CLVD",
            qlc_stats_value_3 = "32+",
            qlc_stats_title_4 = "DEF",
            qlc_stats_value_4 = "19+",
            qlc_stats_title_5 = "WRES",
            qlc_stats_value_5 = "11+"
        }
        """
    )
    projected_calls = globals_.preview_stats_change_count
    assert qlc_dump_pass.visibility_function(qlc_dump_content) is True
    assert qlc_dump_content.better_inventory_quick_look_card_dump_stat == "WRES 60"
    assert globals_.preview_stats_change_count == projected_calls + 1
    assert qlc_dump_pass.visibility_function(qlc_dump_content) is True
    assert globals_.preview_stats_change_count == projected_calls + 1

    # Quick Look Card may provide raw English titles. Its AMMO title must pass
    # through the same shared compaction before BetterInventory renders it.
    qlc_ammo_content = lua.eval(
        """
        {
            element = {
                item = {
                    item_type = "WEAPON_RANGED",
                    expertise = 260,
                    projected_values = { 50, 80, 80, 80, 80 },
                    modifier_display_names = {
                        "loc_stats_display_ammo_stat",
                        "loc_stats_display_warp_resist_stat",
                        "loc_stats_display_cleave_damage_stat",
                        "loc_stats_display_defense_stat",
                        "loc_stats_display_finesse_stat"
                    }
                }
            },
            qlc_stats_title_1 = "AMMO",
            qlc_stats_value_1 = "50",
            qlc_stats_title_2 = "WRES",
            qlc_stats_value_2 = "80",
            qlc_stats_title_3 = "CLVD",
            qlc_stats_value_3 = "80",
            qlc_stats_title_4 = "DEF",
            qlc_stats_value_4 = "80",
            qlc_stats_title_5 = "FIN",
            qlc_stats_value_5 = "80"
        }
        """
    )
    assert qlc_dump_pass.visibility_function(qlc_ammo_content) is True
    assert qlc_ammo_content.better_inventory_quick_look_card_dump_stat == "AMM 50"

    qlc_equal_content = lua.eval(
        """
        {
            element = {
                item = {
                    item_type = "WEAPON_RANGED",
                    expertise = 320,
                    projected_values = { 80, 80, 80, 80, 80 }
                }
            },
            qlc_stats_title_1 = "DMG", qlc_stats_value_1 = "80",
            qlc_stats_title_2 = "FIN", qlc_stats_value_2 = "80",
            qlc_stats_title_3 = "CLVD", qlc_stats_value_3 = "80",
            qlc_stats_title_4 = "DEF", qlc_stats_value_4 = "80",
            qlc_stats_title_5 = "WRES", qlc_stats_value_5 = "80"
        }
        """
    )
    assert qlc_dump_pass.visibility_function(qlc_equal_content) is False
    assert qlc_equal_content.better_inventory_quick_look_card_dump_stat == ""

    mod.settings.quick_look_card_grid_stat_position = "name_right"
    mod.settings.quick_look_card_grid_font_size = 14
    qlc_name_right_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    qlc_name_right_blueprint.pass_template[
        len(qlc_name_right_blueprint.pass_template) + 1
    ] = lua.eval("table.clone")(qlc_native_pass)
    layout.configure_item_blueprint(mod, qlc_name_right_blueprint, 596)
    qlc_name_right_pass = blueprint_pass(
        qlc_name_right_blueprint, "better_inventory_quick_look_card_dump_stat"
    )
    assert qlc_name_right_pass.style.horizontal_alignment == "right"
    assert qlc_name_right_pass.style.vertical_alignment == "top"
    assert qlc_name_right_pass.style.offset[1] == -36
    assert qlc_name_right_pass.style.font_size == 14
    assert qlc_name_right_pass.visibility_function(qlc_dump_content) is True
    assert qlc_dump_content.better_inventory_quick_look_card_dump_stat == "(WRES 60)"

    mod.settings.quick_look_card_grid_stat_position = "name_left"
    qlc_name_left_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    qlc_name_left_blueprint.pass_template[
        len(qlc_name_left_blueprint.pass_template) + 1
    ] = lua.eval("table.clone")(qlc_native_pass)
    layout.configure_item_blueprint(mod, qlc_name_left_blueprint, 596)
    qlc_name_left_pass = blueprint_pass(
        qlc_name_left_blueprint, "better_inventory_quick_look_card_dump_stat"
    )
    assert qlc_name_left_pass.style.horizontal_alignment == "left"
    assert qlc_name_left_pass.style.offset[1] == 12
    assert blueprint_pass(qlc_name_left_blueprint, "display_name").style.offset[1] > 12

    # Name-side modes fall back above the power when four/five-column cards
    # cannot retain the minimum readable weapon-name width.
    mod.settings.columns = 5
    qlc_narrow_name_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    qlc_narrow_name_blueprint.pass_template[
        len(qlc_narrow_name_blueprint.pass_template) + 1
    ] = lua.eval("table.clone")(qlc_native_pass)
    layout.configure_item_blueprint(mod, qlc_narrow_name_blueprint, 596)
    qlc_narrow_name_pass = blueprint_pass(
        qlc_narrow_name_blueprint, "better_inventory_quick_look_card_dump_stat"
    )
    assert qlc_narrow_name_pass.style.horizontal_alignment == "right"
    assert qlc_narrow_name_pass.style.vertical_alignment == "bottom"
    assert (qlc_narrow_name_pass.style.offset[1], qlc_narrow_name_pass.style.offset[2]) == (
        -8,
        -26,
    )
    assert blueprint_pass(qlc_narrow_name_blueprint, "display_name").style.offset[1] == 12
    mod.settings.columns = 3

    mod.settings.enable_quick_look_card_grid_integration = False
    qlc_disabled_grid_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    qlc_disabled_grid_blueprint.pass_template[
        len(qlc_disabled_grid_blueprint.pass_template) + 1
    ] = lua.eval("table.clone")(qlc_native_pass)
    layout.configure_item_blueprint(mod, qlc_disabled_grid_blueprint, 596)
    assert not any(
        qlc_disabled_grid_blueprint.pass_template[index].style_id
        == "better_inventory_quick_look_card_dump_stat"
        for index in range(1, len(qlc_disabled_grid_blueprint.pass_template) + 1)
    )
    assert blueprint_pass(
        qlc_disabled_grid_blueprint, "qlc_stats_title_1"
    ).visibility_function() is False
    mod.settings.enable_quick_look_card_grid_integration = True
    mod.settings.quick_look_card_grid_stat_position = "above_power"
    mod.settings.quick_look_card_grid_font_size = 13

    assert layout.is_enabled_for_view(mod, lua.table_from({"_selected_slot": lua.table_from({"name": "slot_primary"})}))
    assert not layout.is_enabled_for_view(mod, lua.table_from({"_selected_slot": lua.table_from({"name": "slot_secondary"})}))
    assert layout.is_enabled_for_view(mod, lua.table_from({"_selected_slot": lua.table_from({"name": "slot_attachment_2"})}))
    assert not layout.is_enabled_for_view(mod, lua.table_from({"_selected_slot": lua.table_from({"name": "slot_gear_head"})}))

    layout.configure_item_blueprint(mod, blueprint, 640)

    assert (blueprint.size[1], blueprint.size[2]) == (206, 110)
    assert lua.eval("test_blueprint.load_icon == sentinel_load")
    assert lua.eval("test_blueprint.unload_icon == sentinel_unload")
    assert lua.eval("test_blueprint.destroy == sentinel_destroy")
    assert lua.eval("test_blueprint.update_item_icon_priority == sentinel_priority")
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
    assert favorite_pass.style.word_wrap is False

    myfavorites_hotspot = blueprint_pass(blueprint, "myfav_hotspot")
    assert myfavorites_hotspot.style.horizontal_alignment == "right"
    assert myfavorites_hotspot.style.vertical_alignment == "top"
    assert tuple(myfavorites_hotspot.style.offset[index] for index in range(1, 4)) == (-8, 7, 17)
    assert tuple(myfavorites_hotspot.style.size[index] for index in range(1, 3)) == (30, 28)
    myfavorites_extra_icon = blueprint_pass(blueprint, "myfav_extra_icon")
    assert tuple(myfavorites_extra_icon.style.offset[index] for index in range(1, 4)) == (0, 0, 20)

    myfavorites_content = lua.table_from({"favorite": True})
    assert favorite_pass.visibility_function(myfavorites_content, favorite_pass.style) is True
    assert myfavorites_content.favorite_icon == favorite_pass.value
    assert tuple(favorite_pass.style.text_color[index] for index in range(1, 5)) == (255, 50, 245, 50)

    mod.settings.myfavorites_show_favorite_letter = True
    letter_favorite_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, letter_favorite_blueprint, 640)
    letter_favorite_pass = blueprint_pass(letter_favorite_blueprint, "favorite_icon")
    letter_favorite_content = lua.table_from({"favorite": True})
    assert letter_favorite_pass.visibility_function(
        letter_favorite_content, letter_favorite_pass.style
    ) is True
    assert letter_favorite_content.favorite_icon.endswith("\nF")
    assert letter_favorite_pass.style.size[2] == 48
    assert blueprint_pass(
        letter_favorite_blueprint, "myfav_hotspot"
    ).style.size[2] == 48
    mod.settings.myfavorites_show_favorite_letter = False

    # Enhanced Character Selection can expose item blueprints before their
    # favorite pass receives an explicit size. With compact markers disabled,
    # preserve MyFavorites' own hotspot dimensions instead of indexing nil.
    mod.settings.compact_favorite_marker = False
    sizeless_favorite_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    assert blueprint_pass(sizeless_favorite_blueprint, "favorite_icon").style.size is None
    layout.configure_item_blueprint(mod, sizeless_favorite_blueprint, 640)
    sizeless_myfavorites_hotspot = blueprint_pass(
        sizeless_favorite_blueprint, "myfav_hotspot"
    )
    assert tuple(
        sizeless_myfavorites_hotspot.style.size[index] for index in range(1, 3)
    ) == (120, 24)
    assert tuple(
        sizeless_myfavorites_hotspot.style.offset[index] for index in range(1, 4)
    ) == (-8, 7, 17)
    mod.settings.compact_favorite_marker = True

    runtime_myfavorites_hotspot_style = lua.eval("table.clone")(
        myfavorites_hotspot.style
    )
    equipped_content = lua.table_from(
        {
            "equipped": True,
            "better_inventory_myfavorites_hotspot_style": runtime_myfavorites_hotspot_style,
        }
    )
    favorite_pass.change_function(equipped_content, favorite_pass.style, None, 0)
    assert favorite_pass.style.offset[2] == 33
    assert myfavorites_hotspot.style.offset[2] == 7
    assert runtime_myfavorites_hotspot_style.offset[2] == 33
    assert myfavorites_hotspot.style.offset[2] == 7

    # Equipped Icon+ extends the equipped-icon visibility pass for items in
    # inactive loadouts. BetterInventory must honor that result when placing
    # the favorite marker, while leaving normal unequipped cards unchanged.
    equipped_icon_pass = blueprint_pass(blueprint, "equipped_icon")
    equipped_icon_pass.visibility_function = lua.eval(
        "function(content) return content and content.inactive_loadout_equipped == true end"
    )
    inactive_equipped_content = lua.table_from(
        {
            "equipped": False,
            "inactive_loadout_equipped": True,
            "better_inventory_equipped_icon_visible": True,
            "better_inventory_myfavorites_hotspot_style": runtime_myfavorites_hotspot_style,
        }
    )
    favorite_pass.change_function(
        inactive_equipped_content,
        favorite_pass.style,
        None,
        0,
    )
    assert favorite_pass.style.offset[2] == 33
    assert runtime_myfavorites_hotspot_style.offset[2] == 33
    inactive_unequipped_content = lua.table_from(
        {
            "equipped": False,
            "inactive_loadout_equipped": False,
            "better_inventory_equipped_icon_visible": False,
            "better_inventory_myfavorites_hotspot_style": runtime_myfavorites_hotspot_style,
        }
    )
    favorite_pass.change_function(
        inactive_unequipped_content,
        favorite_pass.style,
        None,
        0,
    )
    assert favorite_pass.style.offset[2] == 7
    assert runtime_myfavorites_hotspot_style.offset[2] == 7

    # A compatibility callback must fail closed if a third-party pass throws
    # (or if Darktide invokes the change callback without item content).
    equipped_icon_pass.visibility_function = lua.eval(
        "function(content) error('simulated Equipped Icon+ failure') end"
    )
    favorite_pass.change_function(None, favorite_pass.style, None, 0)
    assert favorite_pass.style.offset[2] == 7
    assert runtime_myfavorites_hotspot_style.offset[2] == 7

    equipped_highlight = blueprint_pass(
        blueprint, "better_inventory_equipped_highlight"
    )
    assert equipped_highlight.value == "content/ui/materials/frames/dropshadow_medium"
    assert (
        equipped_highlight.style.size[1],
        equipped_highlight.style.size[2],
    ) == (206, 110)
    assert (
        equipped_highlight.style.size_addition[1],
        equipped_highlight.style.size_addition[2],
    ) == (16, 16)
    assert equipped_highlight.visibility_function(
        lua.table_from({"equipped": True})
    ) is True
    assert equipped_highlight.visibility_function(
        lua.table_from({"equipped": False})
    ) is False
    mod.settings.highlight_equipped_items = False
    # Active setting changes rebuild view composition. Existing blueprints keep
    # their captured hot-path value; rebuilt blueprints see the new setting.
    assert equipped_highlight.visibility_function(
        lua.table_from({"equipped": True})
    ) is True
    highlight_disabled_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, highlight_disabled_blueprint, 640)
    assert blueprint_pass(
        highlight_disabled_blueprint, "better_inventory_equipped_highlight"
    ).visibility_function(lua.table_from({"equipped": True})) is False
    mod.settings.highlight_equipped_items = True

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

    mod.settings.columns = 4
    four_column_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, four_column_blueprint, 640)
    assert blueprint_pass(four_column_blueprint, "display_name").style.font_size == 16
    armoury_three_column_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, armoury_three_column_blueprint, 640, store_configuration)
    assert blueprint_pass(armoury_three_column_blueprint, "display_name").style.font_size == 14
    armoury_item_level_style = blueprint_pass(armoury_three_column_blueprint, "item_level").style
    assert tuple(armoury_item_level_style.text_color[index] for index in range(1, 5)) == (255, 220, 230, 210)
    assert armoury_item_level_style.offset[3] == 11
    mod.settings.brighten_armoury_item_levels = False
    dim_armoury_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, dim_armoury_blueprint, 640, store_configuration)
    assert blueprint_pass(dim_armoury_blueprint, "item_level").style.text_color is None
    assert blueprint_pass(dim_armoury_blueprint, "item_level").style.offset[3] == 9
    mod.settings.brighten_armoury_item_levels = True
    mod.settings.columns = 3

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
    assert (first_blessing_pass.style.size[1], first_blessing_pass.style.size[2]) == (34, 34)

    mod.settings.blessing_icon_size = 42
    large_blessing_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, large_blessing_blueprint, 640)
    large_blessing_pass = blueprint_pass(large_blessing_blueprint, "better_inventory_blessing_1")
    assert (large_blessing_pass.style.size[1], large_blessing_pass.style.size[2]) == (42, 42)
    mod.settings.blessing_icon_size = 34

    mod.settings.weapon_blessing_display_mode = "text"
    mod.settings.columns = 5
    text_blessing_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, text_blessing_blueprint, 640)
    text_blessing_styles = {
        "display_name": blueprint_pass(text_blessing_blueprint, "display_name").style,
    }
    for index in range(1, 3):
        style_id = f"better_inventory_blessing_text_{index}"
        text_blessing_styles[style_id] = blueprint_pass(
            text_blessing_blueprint, style_id
        ).style
    text_blessing_widget = lua.table_from(
        {"content": lua.table_from({}), "style": lua.table_from(text_blessing_styles)}
    )
    text_blessing_blueprint.init(
        None,
        text_blessing_widget,
        narrow_weapon_element,
        None,
        None,
        lua.table_from({}),
        None,
        text_blessing_blueprint,
    )
    assert text_blessing_widget.content.better_inventory_blessing_text_1 == "III Surgical"
    assert text_blessing_widget.content.better_inventory_blessing_text_2 == "IV Weight of Fire"
    assert text_blessing_widget.content.better_inventory_full_blessing_text_1 == "III Surgical"
    assert text_blessing_widget.content.better_inventory_full_blessing_text_2 == "IV Weight of Fire"
    first_text_style = text_blessing_styles["better_inventory_blessing_text_1"]
    second_text_style = text_blessing_styles["better_inventory_blessing_text_2"]
    assert tuple(first_text_style.text_color[index] for index in range(1, 5)) == (
        255,
        144,
        213,
        255,
    )
    assert first_text_style.size[1] == 100
    assert second_text_style.offset[2] == -34
    assert first_text_style.offset[2] == -53
    mod.settings.show_weapon_perks = True
    assert layout.card_height(mod) == 152
    mod.settings.show_weapon_perks = False
    mod.settings.columns = 3
    compact_text_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, compact_text_blueprint, 640)
    compact_text_style = blueprint_pass(
        compact_text_blueprint, "better_inventory_blessing_text_2"
    ).style
    assert compact_text_style.size[1] == 144
    assert compact_text_style.offset[2] == -4

    mod.settings.columns = 4
    four_column_text_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, four_column_text_blueprint, 640)
    four_column_text_style = blueprint_pass(
        four_column_text_blueprint, "better_inventory_blessing_text_2"
    ).style
    assert four_column_text_style.size[1] == 132
    assert four_column_text_style.offset[2] == -34

    mod.settings.weapon_blessing_text_vertical_spacing = 6
    mod.settings.weapon_blessing_text_color_r = 12
    mod.settings.weapon_blessing_text_color_g = 34
    mod.settings.weapon_blessing_text_color_b = 56
    spaced_blessing_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    spaced_blessing_size = layout.configure_item_blueprint(
        mod, spaced_blessing_blueprint, 640
    )
    spaced_blessing_1 = blueprint_pass(
        spaced_blessing_blueprint, "better_inventory_blessing_text_1"
    ).style
    spaced_blessing_2 = blueprint_pass(
        spaced_blessing_blueprint, "better_inventory_blessing_text_2"
    ).style
    assert spaced_blessing_2.offset[2] - spaced_blessing_1.offset[2] == 23
    assert tuple(spaced_blessing_1.text_color[index] for index in range(1, 5)) == (
        255,
        12,
        34,
        56,
    )
    assert spaced_blessing_size[2] == 117
    mod.settings.weapon_blessing_text_vertical_spacing = 2
    mod.settings.weapon_blessing_text_color_r = 144
    mod.settings.weapon_blessing_text_color_g = 213
    mod.settings.weapon_blessing_text_color_b = 255

    mod.settings.weapon_blessing_text_opacity = 50
    translucent_blessing_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, translucent_blessing_blueprint, 640)
    translucent_blessing_style = blueprint_pass(
        translucent_blessing_blueprint, "better_inventory_blessing_text_1"
    ).style
    assert tuple(
        translucent_blessing_style.text_color[index] for index in range(1, 5)
    ) == (128, 144, 213, 255)
    mod.settings.weapon_blessing_text_opacity = 100

    mod.settings.weapon_blessing_text_bottom_padding = 6
    padded_blessing_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    padded_blessing_size = layout.configure_item_blueprint(
        mod, padded_blessing_blueprint, 640
    )
    padded_blessing_1 = blueprint_pass(
        padded_blessing_blueprint, "better_inventory_blessing_text_1"
    ).style
    padded_blessing_2 = blueprint_pass(
        padded_blessing_blueprint, "better_inventory_blessing_text_2"
    ).style
    assert padded_blessing_1.offset[2] == first_text_style.offset[2] - 2
    assert padded_blessing_2.offset[2] == second_text_style.offset[2] - 2
    assert padded_blessing_size[2] == 115
    mod.settings.weapon_blessing_text_bottom_padding = 4

    mod.settings.weapon_blessing_display_mode = "ranked_text"
    mod.settings.weapon_perk_rank_icon_size = 18
    ranked_text_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, ranked_text_blueprint, 640)
    assert not any(
        ranked_text_blueprint.pass_template[index].style_id
        == "better_inventory_blessing_1"
        for index in range(1, len(ranked_text_blueprint.pass_template) + 1)
    )
    ranked_text_styles = {
        "display_name": blueprint_pass(ranked_text_blueprint, "display_name").style,
    }
    for index in range(1, 3):
        style_id = f"better_inventory_blessing_text_{index}"
        ranked_text_styles[style_id] = blueprint_pass(
            ranked_text_blueprint, style_id
        ).style
    ranked_text_widget = lua.table_from(
        {"content": lua.table_from({}), "style": lua.table_from(ranked_text_styles)}
    )
    ranked_text_blueprint.init(
        None,
        ranked_text_widget,
        narrow_weapon_element,
        None,
        None,
        lua.table_from({}),
        None,
        ranked_text_blueprint,
    )
    assert ranked_text_widget.content.better_inventory_blessing_text_1 == "Surgical"
    assert ranked_text_widget.content.better_inventory_blessing_text_2 == "Weight of Fire"
    assert ranked_text_widget.content.better_inventory_blessing_rank_1 == "perk/rank_3"
    assert ranked_text_widget.content.better_inventory_blessing_rank_2 == "perk/rank_4"
    first_rank_pass = blueprint_pass(ranked_text_blueprint, "better_inventory_blessing_rank_1")
    first_rank_text = blueprint_pass(ranked_text_blueprint, "better_inventory_blessing_text_1")
    assert first_rank_pass.visibility_function(ranked_text_widget.content)
    assert (first_rank_pass.style.size[1], first_rank_pass.style.size[2]) == (18, 18)
    assert first_rank_text.style.offset[1] == first_rank_pass.style.offset[1] + 21
    assert first_rank_text.style.size[1] == four_column_text_style.size[1] - 21
    assert layout.card_height(mod) == 117

    # Native ranked-text cards keep tier symbols before each name and render the
    # two full framed blessing icons side by side in the reserved right area.
    mod.settings.enable_grid_layout = False
    mod.settings.single_column_blessing_icons_on_right = True
    right_icon_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, right_icon_blueprint, 596)
    right_icon_styles = {
        "display_name": blueprint_pass(right_icon_blueprint, "display_name").style,
    }
    for index in range(1, 3):
        for prefix in (
            "better_inventory_blessing_text_",
            "better_inventory_blessing_rank_",
        ):
            style_id = f"{prefix}{index}"
            right_icon_styles[style_id] = blueprint_pass(
                right_icon_blueprint, style_id
            ).style
    right_icon_widget = lua.table_from(
        {"content": lua.table_from({}), "style": lua.table_from(right_icon_styles)}
    )
    right_icon_blueprint.init(
        None,
        right_icon_widget,
        narrow_weapon_element,
        None,
        None,
        lua.table_from({}),
        None,
        right_icon_blueprint,
    )
    for index in range(1, 3):
        text_style = right_icon_styles[f"better_inventory_blessing_text_{index}"]
        rank_style = right_icon_styles[f"better_inventory_blessing_rank_{index}"]
        assert text_style.offset[1] == rank_style.offset[1] + rank_style.size[1] + 3

        icon_pass = blueprint_pass(
            right_icon_blueprint, f"better_inventory_blessing_{index}"
        )
        assert icon_pass.visibility_function(right_icon_widget.content)
        icon_pass.change_function(right_icon_widget.content, icon_pass.style)
        expected_name = "one" if index == 1 else "two"
        assert icon_pass.style.material_values.icon == f"icon/blessing_{expected_name}"
        assert icon_pass.style.material_values.frame == f"frame/rank_{index + 2}"
        assert tuple(icon_pass.style.size[position] for position in range(1, 3)) == (
            34,
            34,
        )

    first_side_icon = blueprint_pass(
        right_icon_blueprint, "better_inventory_blessing_1"
    ).style
    second_side_icon = blueprint_pass(
        right_icon_blueprint, "better_inventory_blessing_2"
    ).style
    assert first_side_icon.offset[1] == 146
    assert second_side_icon.offset[1] == 183
    assert first_side_icon.offset[2] == second_side_icon.offset[2] == -4
    assert second_side_icon.offset[1] + second_side_icon.size[1] <= 260

    mod.settings.single_column_blessing_icons_on_right = False
    no_side_icon_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, no_side_icon_blueprint, 596)
    assert not any(
        no_side_icon_blueprint.pass_template[index].style_id
        == "better_inventory_blessing_1"
        for index in range(1, len(no_side_icon_blueprint.pass_template) + 1)
    )
    assert blueprint_pass(
        no_side_icon_blueprint, "better_inventory_blessing_rank_1"
    ) is not None
    mod.settings.single_column_blessing_icons_on_right = True
    mod.settings.enable_grid_layout = True

    long_blessing_element = lua.eval("table.clone")(narrow_weapon_element)
    long_blessing_element.item.traits[2].id = "blessing_long"
    mod.settings.columns = 3
    mod.settings.auto_fit_long_blessing_names = True
    mod.settings.truncate_long_blessing_names = False
    auto_fit_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, auto_fit_blueprint, 640)
    auto_fit_styles = {
        "display_name": blueprint_pass(auto_fit_blueprint, "display_name").style,
        "better_inventory_blessing_text_1": blueprint_pass(
            auto_fit_blueprint, "better_inventory_blessing_text_1"
        ).style,
        "better_inventory_blessing_text_2": blueprint_pass(
            auto_fit_blueprint, "better_inventory_blessing_text_2"
        ).style,
    }
    auto_fit_widget = lua.table_from(
        {"content": lua.table_from({}), "style": lua.table_from(auto_fit_styles)}
    )
    auto_fit_blueprint.init(
        None,
        auto_fit_widget,
        long_blessing_element,
        None,
        None,
        lua.table_from({}),
        None,
        auto_fit_blueprint,
    )
    auto_fit_style = auto_fit_styles["better_inventory_blessing_text_2"]
    assert auto_fit_widget.content.better_inventory_blessing_text_2 == "Rending Shockwave"
    assert auto_fit_widget.content.better_inventory_full_blessing_text_2 == "Rending Shockwave"
    assert auto_fit_style.font_size < 13
    assert auto_fit_style.word_wrap is False

    mod.settings.auto_fit_long_blessing_names = False
    mod.settings.truncate_long_blessing_names = True
    truncated_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, truncated_blueprint, 640)
    truncated_styles = {
        "display_name": blueprint_pass(truncated_blueprint, "display_name").style,
        "better_inventory_blessing_text_1": blueprint_pass(
            truncated_blueprint, "better_inventory_blessing_text_1"
        ).style,
        "better_inventory_blessing_text_2": blueprint_pass(
            truncated_blueprint, "better_inventory_blessing_text_2"
        ).style,
    }
    truncated_widget = lua.table_from(
        {"content": lua.table_from({}), "style": lua.table_from(truncated_styles)}
    )
    truncated_blueprint.init(
        None,
        truncated_widget,
        long_blessing_element,
        None,
        None,
        lua.table_from({}),
        None,
        truncated_blueprint,
    )
    truncated_style = truncated_styles["better_inventory_blessing_text_2"]
    assert truncated_widget.content.better_inventory_blessing_text_2.endswith("...")
    assert truncated_widget.content.better_inventory_full_blessing_text_2 == "Rending Shockwave"
    assert truncated_style.font_size == 13
    assert truncated_style.word_wrap is False

    mod.settings.truncate_long_blessing_names = False
    wrapping_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, wrapping_blueprint, 640)
    wrapping_styles = {
        "display_name": blueprint_pass(wrapping_blueprint, "display_name").style,
        "better_inventory_blessing_text_1": blueprint_pass(
            wrapping_blueprint, "better_inventory_blessing_text_1"
        ).style,
        "better_inventory_blessing_text_2": blueprint_pass(
            wrapping_blueprint, "better_inventory_blessing_text_2"
        ).style,
    }
    wrapping_widget = lua.table_from(
        {"content": lua.table_from({}), "style": lua.table_from(wrapping_styles)}
    )
    wrapping_blueprint.init(
        None,
        wrapping_widget,
        long_blessing_element,
        None,
        None,
        lua.table_from({}),
        None,
        wrapping_blueprint,
    )
    wrapping_style = wrapping_styles["better_inventory_blessing_text_2"]
    assert wrapping_widget.content.better_inventory_blessing_text_2 == "Rending Shockwave"
    assert wrapping_style.font_size == 13
    assert wrapping_style.word_wrap is True

    mod.settings.auto_fit_long_blessing_names = True
    mod.settings.columns = 3

    mod.settings.weapon_blessing_display_mode = "text"
    assert layout.card_height(mod, store_configuration) == 117
    mod.settings.weapon_blessing_display_mode = "off"
    assert layout.card_height(mod, store_configuration) == 110
    mod.settings.weapon_blessing_display_mode = "icons"

    mod.settings.show_item_level_icon = False
    no_power_icon_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, no_power_icon_blueprint, 640)
    no_power_icon_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(
                {
                    "display_name": blueprint_pass(
                        no_power_icon_blueprint, "display_name"
                    ).style,
                }
            ),
        }
    )
    no_power_icon_blueprint.init(
        None,
        no_power_icon_widget,
        narrow_weapon_element,
        None,
        None,
        lua.table_from({}),
        None,
        no_power_icon_blueprint,
    )
    assert no_power_icon_widget.content.item_level == "460"
    mod.settings.show_item_level_icon = True

    narrow_weapon_element.item.perks = lua.table_from(
        [
            lua.table_from(
                {
                    "id": "content/items/perks/test_weapon_flak",
                    "rarity": 4,
                    "value": 0.8,
                }
            ),
            lua.table_from(
                {
                    "id": "content/items/perks/test_weapon_maniacs",
                    "rarity": 4,
                    "value": 0.8,
                }
            ),
        ]
    )
    mod.settings.show_weapon_perks = True
    perk_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    perk_size = layout.configure_item_blueprint(mod, perk_blueprint, 640)
    assert (perk_size[1], perk_size[2]) == (206, 119)
    perk_styles = {
        "display_name": blueprint_pass(perk_blueprint, "display_name").style,
        "better_inventory_weapon_perk_1": blueprint_pass(
            perk_blueprint, "better_inventory_weapon_perk_1"
        ).style,
        "better_inventory_weapon_perk_2": blueprint_pass(
            perk_blueprint, "better_inventory_weapon_perk_2"
        ).style,
    }
    assert tuple(
        perk_styles["better_inventory_weapon_perk_1"].text_color[index]
        for index in range(1, 5)
    ) == (255, 190, 210, 180)
    perk_widget = lua.table_from(
        {"content": lua.table_from({}), "style": lua.table_from(perk_styles)}
    )
    perk_blueprint.init(
        None,
        perk_widget,
        narrow_weapon_element,
        None,
        None,
        lua.table_from({}),
        None,
        perk_blueprint,
    )
    assert perk_widget.content.better_inventory_full_weapon_perk_1 == "+25% Flak Damage"
    assert perk_widget.content.better_inventory_full_weapon_perk_2 == "+25% Maniacs Damage"
    assert "\n" not in perk_widget.content.better_inventory_weapon_perk_1
    assert perk_styles["better_inventory_weapon_perk_1"].drop_shadow is True

    baseline_perk_1_y = perk_styles["better_inventory_weapon_perk_1"].offset[2]
    baseline_perk_2_y = perk_styles["better_inventory_weapon_perk_2"].offset[2]
    mod.settings.weapon_perk_vertical_spacing = 7
    mod.settings.weapon_perk_blessing_spacing = 12
    spaced_perk_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    spaced_perk_size = layout.configure_item_blueprint(mod, spaced_perk_blueprint, 640)
    spaced_perk_1 = blueprint_pass(
        spaced_perk_blueprint, "better_inventory_weapon_perk_1"
    ).style
    spaced_perk_2 = blueprint_pass(
        spaced_perk_blueprint, "better_inventory_weapon_perk_2"
    ).style
    assert spaced_perk_2.offset[2] - spaced_perk_1.offset[2] == 24
    assert spaced_perk_2.offset[2] == baseline_perk_2_y - 7
    assert spaced_perk_1.offset[2] == baseline_perk_1_y - 12
    assert spaced_perk_size[2] == 131
    mod.settings.weapon_perk_vertical_spacing = 2
    mod.settings.weapon_perk_blessing_spacing = 5

    globals_.TestTraitDescriptions.weapon_trait_melee_common_wield_increased_berserker_damage = "+25% Damage\n(Maniacs)"
    perk_blueprint.update_data(test_grid, perk_widget, narrow_weapon_element)
    assert "\n" not in perk_widget.content.better_inventory_weapon_perk_2
    globals_.TestTraitDescriptions.weapon_trait_melee_common_wield_increased_berserker_damage = "+25% Damage (Maniacs)"

    mod.settings.weapon_perk_text_color_r = 12
    mod.settings.weapon_perk_text_color_g = 34
    mod.settings.weapon_perk_text_color_b = 56
    custom_perk_color_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, custom_perk_color_blueprint, 640)
    custom_perk_color_style = blueprint_pass(
        custom_perk_color_blueprint, "better_inventory_weapon_perk_1"
    ).style
    assert tuple(
        custom_perk_color_style.text_color[index] for index in range(1, 5)
    ) == (255, 12, 34, 56)
    mod.settings.weapon_perk_text_color_r = 190
    mod.settings.weapon_perk_text_color_g = 210
    mod.settings.weapon_perk_text_color_b = 180

    mod.settings.weapon_perk_text_opacity = 25
    translucent_perk_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, translucent_perk_blueprint, 640)
    translucent_perk_style = blueprint_pass(
        translucent_perk_blueprint, "better_inventory_weapon_perk_1"
    ).style
    assert tuple(
        translucent_perk_style.text_color[index] for index in range(1, 5)
    ) == (64, 190, 210, 180)
    mod.settings.weapon_perk_text_opacity = 100

    standard_weapon_perk_expectations = {
        "weapon_trait_melee_common_wield_increased_unarmored_damage": "+25% Unarmoured Damage",
        "weapon_trait_melee_common_wield_increased_armored_damage": "+25% Flak Damage",
        "weapon_trait_melee_common_wield_increased_resistant_damage": "+25% Unyielding Damage",
        "weapon_trait_melee_common_wield_increased_berserker_damage": "+25% Maniacs Damage",
        "weapon_trait_melee_common_wield_increased_super_armor_damage": "+25% Carapace Damage",
        "weapon_trait_melee_common_wield_increased_disgustingly_resilient_damage": "+25% Infested Damage",
        "weapon_trait_increase_crit_chance": "+5% Melee Crit Chance",
        "weapon_trait_increase_crit_damage": "+10% Melee Crit Dmg",
        "weapon_trait_increase_stamina": "+2 Stamina",
        "weapon_trait_increase_weakspot_damage": "+10% Melee Weakspot Dmg",
        "weapon_trait_increase_damage": "+4% Melee Damage",
        "weapon_trait_increase_finesse": "+4% Melee Finesse",
        "weapon_trait_increase_power": "+4% Melee Power",
        "weapon_trait_increase_impact": "+8% Melee Impact",
        "weapon_trait_reduced_block_cost": "+20% Block Efficiency",
        "weapon_trait_increase_damage_elites": "+10% Elites Melee Dmg",
        "weapon_trait_increase_damage_hordes": "+10% Horde Melee Dmg",
        "weapon_trait_increase_damage_specials": "+10% Specialist Melee Dmg",
        "weapon_trait_reduce_sprint_cost": "+15% Sprint Efficiency",
        "weapon_trait_ranged_common_wield_increased_unarmored_damage": "+25% Unarmoured Damage",
        "weapon_trait_ranged_common_wield_increased_armored_damage": "+25% Flak Damage",
        "weapon_trait_ranged_common_wield_increased_resistant_damage": "+25% Unyielding Damage",
        "weapon_trait_ranged_common_wield_increased_berserker_damage": "+25% Maniacs Damage",
        "weapon_trait_ranged_common_wield_increased_super_armor_damage": "+25% Carapace Damage",
        "weapon_trait_ranged_common_wield_increased_disgustingly_resilient_damage": "+25% Infested Damage",
        "weapon_trait_ranged_increase_crit_chance": "+5% Ranged Crit Chance",
        "weapon_trait_ranged_increase_crit_damage": "+10% Ranged Crit Dmg",
        "weapon_trait_ranged_increase_stamina": "+2 Stamina",
        "weapon_trait_ranged_increase_weakspot_damage": "+10% Ranged Weakspot Dmg",
        "weapon_trait_ranged_increase_damage": "+4% Ranged Damage",
        "weapon_trait_ranged_increase_finesse": "+4% Ranged Finesse",
        "weapon_trait_ranged_increase_power": "+4% Ranged Power",
        "weapon_trait_ranged_increase_damage_elites": "+10% Elites Ranged Dmg",
        "weapon_trait_ranged_increase_damage_hordes": "+10% Horde Ranged Dmg",
        "weapon_trait_ranged_increase_damage_specials": "+10% Specialist Ranged Dmg",
        "weapon_trait_ranged_increased_reload_speed": "+10% Reload Speed",
    }

    for perk_id, expected_text in standard_weapon_perk_expectations.items():
        narrow_weapon_element.item.perks[1].id = perk_id
        perk_blueprint.update_data(test_grid, perk_widget, narrow_weapon_element)
        assert (
            perk_widget.content.better_inventory_full_weapon_perk_1 == expected_text
        ), perk_id

    mod.settings.weapon_perk_compression = "heavy"
    heavy_perk_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, heavy_perk_blueprint, 640)
    heavy_perk_styles = {
        "display_name": blueprint_pass(heavy_perk_blueprint, "display_name").style,
        "better_inventory_weapon_perk_1": blueprint_pass(
            heavy_perk_blueprint, "better_inventory_weapon_perk_1"
        ).style,
        "better_inventory_weapon_perk_2": blueprint_pass(
            heavy_perk_blueprint, "better_inventory_weapon_perk_2"
        ).style,
    }
    heavy_perk_widget = lua.table_from(
        {"content": lua.table_from({}), "style": lua.table_from(heavy_perk_styles)}
    )
    narrow_weapon_element.item.perks[1].id = "weapon_trait_increase_damage_specials"
    heavy_perk_blueprint.init(
        None,
        heavy_perk_widget,
        narrow_weapon_element,
        None,
        None,
        lua.table_from({}),
        None,
        heavy_perk_blueprint,
    )
    heavy_weapon_perk_expectations = {
        "weapon_trait_melee_common_wield_increased_unarmored_damage": "+25% Unarmoured Dmg",
        "weapon_trait_melee_common_wield_increased_armored_damage": "+25% Flak Dmg",
        "weapon_trait_melee_common_wield_increased_resistant_damage": "+25% Unyielding Dmg",
        "weapon_trait_melee_common_wield_increased_berserker_damage": "+25% Maniac Dmg",
        "weapon_trait_melee_common_wield_increased_super_armor_damage": "+25% Carapace Dmg",
        "weapon_trait_melee_common_wield_increased_disgustingly_resilient_damage": "+25% Infested Dmg",
        "weapon_trait_increase_crit_chance": "+5% Melee Crit",
        "weapon_trait_increase_crit_damage": "+10% Crit Dmg",
        "weapon_trait_increase_stamina": "+2 Stamina",
        "weapon_trait_increase_weakspot_damage": "+10% Weakspot Dmg",
        "weapon_trait_increase_damage": "+4% Melee Dmg",
        "weapon_trait_increase_finesse": "+4% Finesse",
        "weapon_trait_increase_power": "+4% Power",
        "weapon_trait_increase_impact": "+8% Impact",
        "weapon_trait_reduced_block_cost": "+20% Block",
        "weapon_trait_increase_damage_elites": "+10% Elite Dmg",
        "weapon_trait_increase_damage_hordes": "+10% Horde Dmg",
        "weapon_trait_increase_damage_specials": "+10% Spec Dmg",
        "weapon_trait_reduce_sprint_cost": "+15% Sprint",
        "weapon_trait_ranged_common_wield_increased_unarmored_damage": "+25% Unarmoured Dmg",
        "weapon_trait_ranged_common_wield_increased_armored_damage": "+25% Flak Dmg",
        "weapon_trait_ranged_common_wield_increased_resistant_damage": "+25% Unyielding Dmg",
        "weapon_trait_ranged_common_wield_increased_berserker_damage": "+25% Maniac Dmg",
        "weapon_trait_ranged_common_wield_increased_super_armor_damage": "+25% Carapace Dmg",
        "weapon_trait_ranged_common_wield_increased_disgustingly_resilient_damage": "+25% Infested Dmg",
        "weapon_trait_ranged_increase_crit_chance": "+5% Ranged Crit",
        "weapon_trait_ranged_increase_crit_damage": "+10% Crit Dmg",
        "weapon_trait_ranged_increase_stamina": "+2 Stamina",
        "weapon_trait_ranged_increase_weakspot_damage": "+10% Weakspot Dmg",
        "weapon_trait_ranged_increase_damage": "+4% Ranged Dmg",
        "weapon_trait_ranged_increase_finesse": "+4% Finesse",
        "weapon_trait_ranged_increase_power": "+4% Power",
        "weapon_trait_ranged_increase_damage_elites": "+10% Elite Dmg",
        "weapon_trait_ranged_increase_damage_hordes": "+10% Horde Dmg",
        "weapon_trait_ranged_increase_damage_specials": "+10% Spec Dmg",
        "weapon_trait_ranged_increased_reload_speed": "+10% Reload",
    }

    for perk_id, expected_text in heavy_weapon_perk_expectations.items():
        narrow_weapon_element.item.perks[1].id = perk_id
        heavy_perk_blueprint.update_data(
            test_grid, heavy_perk_widget, narrow_weapon_element
        )
        assert (
            heavy_perk_widget.content.better_inventory_full_weapon_perk_1
            == expected_text
        ), perk_id

    assert set(standard_weapon_perk_expectations) == set(
        heavy_weapon_perk_expectations
    )
    assert len(standard_weapon_perk_expectations) == 36

    mod.settings.weapon_perk_compression = "none"
    uncompressed_perk_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, uncompressed_perk_blueprint, 640)
    uncompressed_perk_styles = {
        "display_name": blueprint_pass(
            uncompressed_perk_blueprint, "display_name"
        ).style,
        "better_inventory_weapon_perk_1": blueprint_pass(
            uncompressed_perk_blueprint, "better_inventory_weapon_perk_1"
        ).style,
        "better_inventory_weapon_perk_2": blueprint_pass(
            uncompressed_perk_blueprint, "better_inventory_weapon_perk_2"
        ).style,
    }
    uncompressed_perk_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(uncompressed_perk_styles),
        }
    )
    narrow_weapon_element.item.perks[1].id = "content/items/perks/test_weapon_flak"
    uncompressed_perk_blueprint.init(
        None,
        uncompressed_perk_widget,
        narrow_weapon_element,
        None,
        None,
        lua.table_from({}),
        None,
        uncompressed_perk_blueprint,
    )
    assert (
        uncompressed_perk_widget.content.better_inventory_full_weapon_perk_1
        == "+25% Damage (Flak Armoured Enemies)"
    )

    globals_.TestTraitDescriptions.weapon_trait_melee_common_wield_increased_armored_damage = "{#color(218, 64, 64)}+25%{#reset()} Damage\n    (Flak Armoured Enemies)"
    uncompressed_perk_blueprint.update_data(
        test_grid, uncompressed_perk_widget, narrow_weapon_element
    )
    assert (
        uncompressed_perk_widget.content.better_inventory_full_weapon_perk_1
        == "+25% Damage (Flak Armoured Enemies)"
    )
    assert "\n" not in uncompressed_perk_widget.content.better_inventory_weapon_perk_1

    mod.settings.weapon_perk_compression = "heavy"
    heavy_perk_blueprint.update_data(
        test_grid, heavy_perk_widget, narrow_weapon_element
    )
    assert (
        heavy_perk_widget.content.better_inventory_full_weapon_perk_1
        == "+25% Flak Dmg"
    )
    assert "218" not in heavy_perk_widget.content.better_inventory_weapon_perk_1
    globals_.TestTraitDescriptions.weapon_trait_melee_common_wield_increased_armored_damage = "+25% Damage (Flak Armoured Enemies)"

    mod.settings.weapon_perk_compression = "compression"
    mod.settings.show_weapon_perk_rank_symbols = True
    mod.settings.remove_weapon_perk_plus_signs = True
    narrow_weapon_element.item.perks[1].rarity = 4
    narrow_weapon_element.item.perks[2].rarity = 3
    ranked_perk_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    ranked_perk_size = layout.configure_item_blueprint(mod, ranked_perk_blueprint, 640)
    assert (ranked_perk_size[1], ranked_perk_size[2]) == (206, 123)
    ranked_perk_text_1 = blueprint_pass(
        ranked_perk_blueprint, "better_inventory_weapon_perk_1"
    )
    ranked_perk_rank_1 = blueprint_pass(
        ranked_perk_blueprint, "better_inventory_weapon_perk_rank_1"
    )
    assert ranked_perk_rank_1.pass_type == "texture"
    assert (ranked_perk_rank_1.style.size[1], ranked_perk_rank_1.style.size[2]) == (
        18,
        18,
    )
    assert ranked_perk_text_1.style.offset[1] - ranked_perk_rank_1.style.offset[1] == 21
    assert ranked_perk_text_1.style.offset[2] == ranked_perk_rank_1.style.offset[2]
    ranked_perk_styles = {
        "display_name": blueprint_pass(
            ranked_perk_blueprint, "display_name"
        ).style,
        "better_inventory_weapon_perk_1": ranked_perk_text_1.style,
        "better_inventory_weapon_perk_2": blueprint_pass(
            ranked_perk_blueprint, "better_inventory_weapon_perk_2"
        ).style,
    }
    ranked_perk_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(ranked_perk_styles),
        }
    )
    ranked_perk_blueprint.init(
        None,
        ranked_perk_widget,
        narrow_weapon_element,
        None,
        None,
        lua.table_from({}),
        None,
        ranked_perk_blueprint,
    )
    assert ranked_perk_widget.content.better_inventory_full_weapon_perk_1 == "25% Flak Damage"
    assert ranked_perk_widget.content.better_inventory_full_weapon_perk_2 == "25% Maniacs Damage"
    assert ranked_perk_widget.content.better_inventory_weapon_perk_rank_1 == "perk/rank_4"
    assert ranked_perk_widget.content.better_inventory_weapon_perk_rank_2 == "perk/rank_3"
    assert ranked_perk_rank_1.visibility_function(ranked_perk_widget.content) is True

    mod.settings.weapon_perk_rank_icon_size = 30
    large_rank_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    large_rank_size = layout.configure_item_blueprint(mod, large_rank_blueprint, 640)
    large_rank_pass = blueprint_pass(large_rank_blueprint, "better_inventory_weapon_perk_rank_1")
    assert (large_rank_size[1], large_rank_size[2]) == (206, 147)
    assert (large_rank_pass.style.size[1], large_rank_pass.style.size[2]) == (30, 30)
    mod.settings.weapon_perk_rank_icon_size = 18

    mod.settings.weapon_perk_compression = "compression"
    mod.settings.show_weapon_perk_rank_symbols = False
    mod.settings.remove_weapon_perk_plus_signs = False
    mod.settings.show_weapon_perks = False

    curio_stat_pass = blueprint_pass(blueprint, "better_inventory_curio_stat_1")
    curio_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(
                {
                    "display_name": blueprint_pass(blueprint, "display_name").style,
					"better_inventory_curio_stat_1": curio_stat_pass.style,
					"rarity_tag": lua.table_from(
						{"color": lua.table_from([255, 1, 2, 3]), "default_color": lua.table_from([255, 4, 5, 6])}
					),
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
    assert tuple(curio_widget.style.rarity_tag.color[index] for index in range(1, 5)) == (255, 145, 70, 40)

    curio_element.item.test_rarity_color = lua.table_from([255, 30, 40, 50])
    blueprint.update_data(test_grid, curio_widget, curio_element)
    assert tuple(curio_widget.style.rarity_tag.color[index] for index in range(1, 5)) == (255, 30, 40, 50)

    # Enhanced Descriptions spells these modifiers as "Maximum". The setting
    # applies to both the innate line and supported secondary Curio perks.
    globals_.TestTraitDescriptions.gadget_innate_toughness_increase = (
        "+17% Maximum Toughness"
    )
    curio_element.item.traits[1].id = "content/items/traits/test_toughness"
    curio_element.item.perks[1].id = "content/items/perks/test_health"
    blueprint.update_data(test_grid, curio_widget, curio_element)
    assert curio_widget.content.better_inventory_curio_stat_1 == "+17% Toughness"
    assert curio_widget.content.better_inventory_curio_stat_2 == "+5% Health"

    globals_.TestTraitDescriptions.gadget_innate_toughness_increase = "+16% Toughness"
    curio_element.item.traits[1].id = "content/items/traits/test_health"
    curio_element.item.perks[1].id = (
        "content/items/perks/test_stamina_regeneration"
    )
    blueprint.update_data(test_grid, curio_widget, curio_element)

    mod.settings.remove_curio_stat_plus_signs = True
    blueprint.update_data(test_grid, curio_widget, curio_element)
    assert curio_widget.content.better_inventory_curio_stat_1 == "19% Health"
    assert curio_widget.content.better_inventory_curio_stat_2 == "12% Stamina Regen"
    mod.settings.remove_curio_stat_plus_signs = False
    blueprint.update_data(test_grid, curio_widget, curio_element)
    assert curio_widget.content.better_inventory_curio_stat_1 == "+19% Health"
    assert curio_widget.content.better_inventory_curio_stat_2 == "+12% Stamina Regen"

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
    curio_element.item.perks[1].id = "content/items/perks/test_health"
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
    assert (
        full_primary_widget.content.better_inventory_curio_stat_2
        == "+5% Maximum Health"
    )
    curio_element.item.perks[1].id = (
        "content/items/perks/test_stamina_regeneration"
    )
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

    assert tuple(
        detailed_styles["better_inventory_curio_stat_2"].text_color[index]
        for index in range(1, 5)
    ) == (255, 220, 230, 210)

    mod.settings.curio_secondary_text_color_r = 21
    mod.settings.curio_secondary_text_color_g = 43
    mod.settings.curio_secondary_text_color_b = 65
    custom_curio_color_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, custom_curio_color_blueprint, 640)
    custom_curio_secondary_style = blueprint_pass(
        custom_curio_color_blueprint, "better_inventory_curio_stat_2"
    ).style
    assert tuple(
        custom_curio_secondary_style.text_color[index] for index in range(1, 5)
    ) == (255, 21, 43, 65)
    mod.settings.curio_secondary_text_color_r = 220
    mod.settings.curio_secondary_text_color_g = 230
    mod.settings.curio_secondary_text_color_b = 210

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
    assert blueprint_pass(detailed_blueprint, "item_level").visibility_function(
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

    # Detailed Curios reserve a two-line name area above all four stat rows even
    # when Name It is absent. Name It migration is owned by the customization
    # module, so layout rendering only consumes BetterInventory records.
    globals_.test_name_it_mod = lua.execute(
        """
        return {
            is_enabled = function() return true end,
            get_custom_name = function(item, is_sub)
                if item and item.item_type == "GADGET" then
					return item.test_custom_name or "First Curio"
                end

                if item and item.item_type == "WEAPON_MELEE" and not is_sub then
                    return "Custom Blade"
                end
            end,
        }
        """
    )
    name_it_curio_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    name_it_curio_size = layout.configure_item_blueprint(mod, name_it_curio_blueprint, 640)
    name_it_title_pass = blueprint_pass(
        name_it_curio_blueprint, "better_inventory_name_it_curio_name"
    )
    name_it_primary_pass = blueprint_pass(
        name_it_curio_blueprint, "better_inventory_curio_stat_1"
    )
    assert name_it_curio_size[2] >= 139
    assert name_it_title_pass.style.word_wrap is True
    assert name_it_title_pass.style.text_fit_with is False
    assert tuple(
        name_it_title_pass.style.text_color[index] for index in range(1, 5)
    ) == (
        255,
        220,
        230,
        210,
    )
    assert name_it_title_pass.style.size[2] >= 40
    assert name_it_primary_pass.style.offset[2] == 7 + name_it_title_pass.style.size[2]

    name_it_curio_styles = {
        "display_name": blueprint_pass(name_it_curio_blueprint, "display_name").style,
        "better_inventory_name_it_curio_name": name_it_title_pass.style,
    }
    for index in range(1, 5):
        style_id = f"better_inventory_curio_stat_{index}"
        name_it_curio_styles[style_id] = blueprint_pass(
            name_it_curio_blueprint, style_id
        ).style
    name_it_curio_widget = lua.table_from(
        {"content": lua.table_from({}), "style": lua.table_from(name_it_curio_styles)}
    )
    name_it_curio_blueprint.init(
        None,
        name_it_curio_widget,
        curio_element,
        None,
        None,
        lua.table_from({}),
        None,
        name_it_curio_blueprint,
    )
    assert name_it_curio_widget.content.display_name == "Mechanicus Icon"
    assert name_it_curio_widget.content.better_inventory_name_it_curio_name_text == "Mechanicus Icon"
    assert name_it_title_pass.visibility_function(name_it_curio_widget.content) is True

    long_name_it_curio_item = lua.eval("table.clone")(curio_element.item)
    long_name_it_curio_item.test_custom_name = "Guardian of the Hateful Reliquary"
    long_name_it_curio_element = lua.table_from(
        {
            "test_display_name": "Guardian of the Hateful Reliquary",
            "item": long_name_it_curio_item,
        }
    )
    name_it_curio_blueprint.init(
        None,
        name_it_curio_widget,
        long_name_it_curio_element,
        None,
        None,
        lua.table_from({}),
        None,
        name_it_curio_blueprint,
    )
    assert name_it_curio_widget.content.display_name == "Guardian of the Hateful Reliquary"
    assert (
        name_it_curio_widget.content.better_inventory_name_it_curio_name_text.count("\n")
        == 1
    )

    character_overview_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_native_item_blueprint(
        mod,
        character_overview_blueprint,
        193,
        lua.table_from({"character_overview": True}),
    )
    assert all(
        character_overview_blueprint.pass_template[index].style_id
        != "better_inventory_name_it_curio_name"
        for index in range(1, len(character_overview_blueprint.pass_template) + 1)
    )

    # Character Overview can replace its five maximum-potential modifier rows
    # with the same single dump-stat label used by grid and Armoury cards.
    mod.settings.character_overview_show_only_dump_stat = True
    mod.settings.character_overview_dump_stat_horizontal_offset = -45
    mod.settings.character_overview_dump_stat_font_scale_percent = 150
    mod.settings.character_overview_dump_stat_color_r = 10
    mod.settings.character_overview_dump_stat_color_g = 20
    mod.settings.character_overview_dump_stat_color_b = 30
    dump_only_overview_blueprint = lua.eval("table.clone")(
        globals_.raw_test_blueprint
    )
    dump_only_overview_blueprint.pass_template[
        len(dump_only_overview_blueprint.pass_template) + 1
    ] = lua.table_from(
        {
            "pass_type": "text",
            "style_id": "better_inventory_quick_look_card_dump_stat",
            "value_id": "better_inventory_quick_look_card_dump_stat",
            "style": lua.table_from({}),
            "visibility_function": lua.eval("function() return false end"),
        }
    )
    layout.configure_native_item_blueprint(
        mod,
        dump_only_overview_blueprint,
        193,
        lua.table_from({"character_overview": True}),
    )
    overview_dump_pass = blueprint_pass(
        dump_only_overview_blueprint,
        "better_inventory_quick_look_card_dump_stat",
    )
    assert overview_dump_pass is not None
    assert overview_dump_pass.style.horizontal_alignment == "right"
    assert overview_dump_pass.style.vertical_alignment == "bottom"
    assert overview_dump_pass.style.text_horizontal_alignment == "center"
    assert overview_dump_pass.style.offset[1] == -46
    assert overview_dump_pass.style.size[1] == 66
    assert (
        overview_dump_pass.style.offset[1]
        - overview_dump_pass.style.size[1] * 0.5
        == -79
    )
    assert overview_dump_pass.style.font_size == 20
    assert overview_dump_pass.style.size[2] == 24
    assert tuple(
        overview_dump_pass.style.text_color[index] for index in range(1, 5)
    ) == (255, 10, 20, 30)
    assert sum(
        dump_only_overview_blueprint.pass_template[index].style_id
        == "better_inventory_quick_look_card_dump_stat"
        for index in range(1, len(dump_only_overview_blueprint.pass_template) + 1)
    ) == 1
    assert all(
        not str(dump_only_overview_blueprint.pass_template[index].style_id).startswith(
            "better_inventory_weapon_modifier_"
        )
        for index in range(1, len(dump_only_overview_blueprint.pass_template) + 1)
    )
    overview_dump_content = lua.eval(
        """
        {
            element = {
                item = {
                    item_type = "WEAPON_RANGED",
                    expertise = 320,
                    projected_values = { 80, 80, 60, 80, 80 }
                }
            }
        }
        """
    )
    assert overview_dump_pass.visibility_function(overview_dump_content) is True
    assert overview_dump_content.better_inventory_quick_look_card_dump_stat == "CLVD 60"
    mod.settings.character_overview_show_only_dump_stat = False
    mod.settings.character_overview_dump_stat_horizontal_offset = 0
    mod.settings.character_overview_dump_stat_font_scale_percent = 100
    mod.settings.character_overview_dump_stat_color_r = 255
    mod.settings.character_overview_dump_stat_color_g = 94
    mod.settings.character_overview_dump_stat_color_b = 132

    name_it_weapon_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, name_it_weapon_blueprint, 640)
    name_it_weapon_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(
                {
                    "display_name": blueprint_pass(
                        name_it_weapon_blueprint, "display_name"
                    ).style,
                }
            ),
        }
    )
    name_it_weapon_blueprint.init(
        None,
        name_it_weapon_widget,
        narrow_weapon_element,
        None,
        None,
        lua.table_from({}),
        None,
        name_it_weapon_blueprint,
    )
    assert name_it_weapon_widget.content.display_name.endswith(" Mk VI")

    # With BetterInventory customization disabled, Name It owns naming and its
    # values remain visible in BetterInventory-rendered grid cards.
    mod.settings.enable_custom_item_name_and_colors = False
    name_it_weapon_blueprint.init(
        None,
        name_it_weapon_widget,
        narrow_weapon_element,
        None,
        None,
        lua.table_from({}),
        None,
        name_it_weapon_blueprint,
    )
    assert name_it_weapon_widget.content.display_name == "Custom Blade"
    name_it_curio_blueprint.init(
        None,
        name_it_curio_widget,
        curio_element,
        None,
        None,
        lua.table_from({}),
        None,
        name_it_curio_blueprint,
    )
    assert name_it_curio_widget.content.display_name == "First Curio"
    mod.settings.enable_custom_item_name_and_colors = True

    better_inventory_name_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, better_inventory_name_blueprint, 640)
    better_inventory_name_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(
                {
                    "display_name": blueprint_pass(
                        better_inventory_name_blueprint, "display_name"
                    ).style,
                }
            ),
        }
    )
    better_inventory_name_blueprint.init(
        None,
        better_inventory_name_widget,
        narrow_weapon_element,
        None,
        None,
        lua.table_from({}),
        None,
        better_inventory_name_blueprint,
    )
    assert better_inventory_name_widget.content.display_name.endswith(" Mk VI")
    globals_.test_name_it_mod = None

    # BetterInventory's standalone record supplies the name and both colors
    # when Name It is absent.
    layout.set_item_customization_provider(
        lua.execute(
            """
            preserve_test_shading = true
            return {
                get = function(_, gear_id)
                    if gear_id == "custom-weapon" then
                        return {
                            name = "Emerald Blade",
                            name_color = { 255, 10, 20, 30 },
                            background_color = { 255, 40, 50, 60 },
                            background_preserve_shading = preserve_test_shading,
                        }
                    elseif gear_id == "single-line-weapon" then
                        return {
                            name = "John Darktide\\nHelbore Lasgun",
                        }
                    end
                end,
            }
            """
        )
    )
    custom_weapon_element = lua.eval("table.clone")(narrow_weapon_element)
    custom_weapon_element.item.gear_id = "custom-weapon"
    custom_weapon_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, custom_weapon_blueprint, 640)
    blueprint_pass(custom_weapon_blueprint, "display_name").style.text_color = lua.table_from([255, 220, 230, 210])
    blueprint_pass(custom_weapon_blueprint, "background").style.color = lua.table_from([255, 1, 2, 3])
    blueprint_pass(custom_weapon_blueprint, "background_gradient").style.color = lua.table_from([255, 4, 5, 6])
    blueprint_pass(custom_weapon_blueprint, "rarity_tag").style.color = lua.table_from([255, 200, 10, 10])
    custom_weapon_styles = {
        "display_name": blueprint_pass(custom_weapon_blueprint, "display_name").style,
        "background": blueprint_pass(custom_weapon_blueprint, "background").style,
        "background_gradient": blueprint_pass(custom_weapon_blueprint, "background_gradient").style,
        "rarity_tag": blueprint_pass(custom_weapon_blueprint, "rarity_tag").style,
    }
    custom_weapon_widget = lua.table_from(
        {"content": lua.table_from({}), "style": lua.table_from(custom_weapon_styles)}
    )
    custom_weapon_blueprint.init(
        None,
        custom_weapon_widget,
        custom_weapon_element,
        None,
        None,
        lua.table_from({}),
        None,
        custom_weapon_blueprint,
    )
    assert custom_weapon_widget.content.display_name == "Emerald Blade"
    assert tuple(custom_weapon_widget.style.display_name.text_color[index] for index in range(1, 5)) == (255, 10, 20, 30)
    assert tuple(custom_weapon_widget.style.background.color[index] for index in range(1, 5)) == (255, 1, 2, 3)
    assert tuple(custom_weapon_widget.style.background_gradient.color[index] for index in range(1, 5)) == (255, 40, 50, 60)
    assert tuple(custom_weapon_widget.style.rarity_tag.color[index] for index in range(1, 5)) == (255, 40, 50, 60)

    # The opt-in title policy normalizes line breaks, shrinks only to the
    # configured minimum, and truncates the custom base while preserving Mark.
    mod.settings.force_weapon_name_single_line = True
    single_line_weapon_element = lua.eval("table.clone")(narrow_weapon_element)
    single_line_weapon_element.item.gear_id = "single-line-weapon"
    single_line_weapon_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, single_line_weapon_blueprint, 640)
    single_line_name_style = blueprint_pass(
        single_line_weapon_blueprint, "display_name"
    ).style
    single_line_name_style.size[1] = 145
    single_line_weapon_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from({"display_name": single_line_name_style}),
        }
    )
    single_line_weapon_blueprint.init(
        None,
        single_line_weapon_widget,
        single_line_weapon_element,
        None,
        None,
        lua.table_from({}),
        None,
        single_line_weapon_blueprint,
    )
    assert "\n" not in single_line_weapon_widget.content.display_name
    assert single_line_weapon_widget.content.display_name.endswith("\u00a0Mk\u00a0VI")
    assert " " not in single_line_weapon_widget.content.display_name
    assert "..." in single_line_weapon_widget.content.display_name
    assert single_line_weapon_widget.style.display_name.font_size == 12
    assert single_line_weapon_widget.content.better_inventory_full_display_name == (
        "John Darktide Helbore Lasgun Mk VI"
    )
    mod.settings.force_weapon_name_single_line = False

    globals_.preserve_test_shading = False
    layout.apply_item_customization_style(mod, custom_weapon_widget, custom_weapon_element)
    assert tuple(custom_weapon_widget.style.background.color[index] for index in range(1, 5)) == (255, 40, 50, 60)

    # Reusing a Character Overview card for another gear ID must discard the
    # first item's custom colors and rebuild from the card's native baseline.
    replacement_weapon_element = lua.eval("table.clone")(narrow_weapon_element)
    replacement_weapon_element.item.gear_id = "replacement-weapon"
    custom_weapon_blueprint.update_data(
        None, custom_weapon_widget, replacement_weapon_element
    )
    assert tuple(
        custom_weapon_widget.style.display_name.text_color[index]
        for index in range(1, 5)
    ) == (255, 220, 230, 210)
    assert tuple(
        custom_weapon_widget.style.background.color[index] for index in range(1, 5)
    ) == (255, 1, 2, 3)
    assert tuple(
        custom_weapon_widget.style.background_gradient.color[index]
        for index in range(1, 5)
    ) == (255, 4, 5, 6)

    # The same reused widget can then acquire the original item's overrides
    # again without treating the previous custom color as its native baseline.
    custom_weapon_blueprint.update_data(
        None, custom_weapon_widget, custom_weapon_element
    )
    assert tuple(
        custom_weapon_widget.style.background_gradient.color[index]
        for index in range(1, 5)
    ) == (255, 40, 50, 60)

    # Weapon information always keeps its native background/shader; only the
    # gradient tint and optional rarity keyword receive the custom color.
    weapon_information_widget = lua.table_from(
        {
            "content": lua.table_from({"sub_display_name": "Maccabian Mk IV"}),
            "style": lua.table_from(
                {
                    "background": lua.table_from(
                        {"color": lua.table_from([255, 7, 8, 9])}
                    ),
                    "gradient_background": lua.table_from(
                        {"color": lua.table_from([255, 11, 12, 13])}
                    ),
                    "rarity_name": lua.table_from(
                        {"text_color": lua.table_from([255, 14, 15, 16])}
                    ),
                }
            )
        }
    )
    weapon_title_widget = lua.table_from(
        {
            "content": lua.table_from({"weapon_display_name": "Dueling Sword"}),
            "style": lua.table_from(
                {
                    "weapon_display_name": lua.table_from(
                        {"text_color": lua.table_from([255, 17, 18, 19])}
                    )
                }
            )
        }
    )
    weapon_stats = lua.table_from(
        {
            "_grid_widgets": lua.table_from([weapon_information_widget]),
            "_widgets_by_name": lua.table_from(
                {"grid_divider_top_weapon": weapon_title_widget}
            ),
        }
    )
    assert layout.apply_weapon_information_customization(
        mod, weapon_stats, custom_weapon_element.item
    ) is True
    assert tuple(weapon_information_widget.style.background.color[index] for index in range(1, 5)) == (255, 7, 8, 9)
    assert tuple(weapon_information_widget.style.gradient_background.color[index] for index in range(1, 5)) == (255, 40, 50, 60)
    assert tuple(weapon_information_widget.style.rarity_name.text_color[index] for index in range(1, 5)) == (255, 40, 50, 60)
    assert tuple(weapon_title_widget.style.weapon_display_name.text_color[index] for index in range(1, 5)) == (255, 10, 20, 30)
    assert weapon_title_widget.content.weapon_display_name == "Emerald Blade"
    mod.settings.custom_item_override_weapon_information_color = False
    layout.apply_weapon_information_customization(mod, weapon_stats, custom_weapon_element.item)
    assert tuple(weapon_information_widget.style.gradient_background.color[index] for index in range(1, 5)) == (255, 11, 12, 13)
    assert tuple(weapon_information_widget.style.rarity_name.text_color[index] for index in range(1, 5)) == (255, 40, 50, 60)
    mod.settings.custom_item_override_weapon_rarity_keyword_color = False
    layout.apply_weapon_information_customization(mod, weapon_stats, custom_weapon_element.item)
    assert tuple(weapon_information_widget.style.rarity_name.text_color[index] for index in range(1, 5)) == (255, 14, 15, 16)
    mod.settings.custom_item_override_weapon_information_name_color = False
    layout.apply_weapon_information_customization(mod, weapon_stats, custom_weapon_element.item)
    assert tuple(weapon_title_widget.style.weapon_display_name.text_color[index] for index in range(1, 5)) == (255, 17, 18, 19)
    layout.set_item_customization_provider(None)

    mod.settings.show_curio_item_level = False
    hidden_curio_level_blueprint = lua.eval("table.clone")(globals_.raw_test_blueprint)
    layout.configure_item_blueprint(mod, hidden_curio_level_blueprint, 640)
    hidden_curio_level_widget = lua.table_from(
        {
            "content": lua.table_from({}),
            "style": lua.table_from(
                {
                    "display_name": blueprint_pass(
                        hidden_curio_level_blueprint, "display_name"
                    ).style,
                }
            ),
        }
    )
    hidden_curio_level_blueprint.init(
        None,
        hidden_curio_level_widget,
        curio_element,
        None,
        None,
        lua.table_from({}),
        None,
        hidden_curio_level_blueprint,
    )
    assert not blueprint_pass(
        hidden_curio_level_blueprint, "item_level"
    ).visibility_function(hidden_curio_level_widget.content)
    assert blueprint_pass(
        hidden_curio_level_blueprint, "item_level"
    ).visibility_function(narrow_weapon_widget.content)

    mod.settings.enable_grid_layout = False
    native_hidden_curio_level_blueprint = lua.eval("table.clone")(
        globals_.raw_test_blueprint
    )
    layout.configure_item_blueprint(mod, native_hidden_curio_level_blueprint, 640)
    assert not blueprint_pass(
        native_hidden_curio_level_blueprint, "item_level"
    ).visibility_function(hidden_curio_level_widget.content)

    mod.settings.show_curio_item_level = True
    native_visible_curio_level_blueprint = lua.eval("table.clone")(
        globals_.raw_test_blueprint
    )
    layout.configure_item_blueprint(mod, native_visible_curio_level_blueprint, 640)
    assert blueprint_pass(
        native_visible_curio_level_blueprint, "item_level"
    ).visibility_function(detailed_widget.content)
    mod.settings.enable_grid_layout = True

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
        "content/items/perks/test_curio_reward": "+15% Curio as Reward",
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
    bottom_myfavorites_hotspot = blueprint_pass(
        bottom_favorite_blueprint, "myfav_hotspot"
    )
    assert bottom_myfavorites_hotspot.style.horizontal_alignment == "left"
    assert bottom_myfavorites_hotspot.style.vertical_alignment == "bottom"
    assert tuple(
        bottom_myfavorites_hotspot.style.offset[index] for index in range(1, 4)
    ) == (12, -5, 17)
    mod.settings.favorite_marker_position = "above_rating"

    grid = lua.table_from({"_menu_settings": lua.table_from({})})
    layout.configure_grid(mod, grid)
    assert (grid._menu_settings.grid_spacing[1], grid._menu_settings.grid_spacing[2]) == (10, 10)

    # DMF formats every localized value through string.format. Literal percent
    # signs therefore need to be escaped as %% in the source string.
    localization = load_localization(lua, LOCALIZATION_PATH)
    format_string = lua.eval("string.format")

    for _, localized_values in localization.items():
        format_string(localized_values["en"])
        format_string(localized_values["zh-cn"])

    print("BetterInventory layout behavior tests passed.")


if __name__ == "__main__":
    main()
