local Text = require("scripts/utilities/ui/text")
local Items = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")
local RankSettings = require("scripts/settings/item/rank_settings")
local WeaponStats = require("scripts/utilities/weapon_stats")

local Layout = {}
local INVENTORY_CANVAS_WIDTH = 1920
local INVENTORY_EDGE_MARGIN = 16
local WEAPON_ACTIONS_PANEL_WIDTH = 420
local WEAPON_STATS_PANEL_WIDTH = 530
local MINIMUM_CARD_WIDTH = 120
local MAXIMUM_WEAPON_EXTRA_WIDTH = 120
local ARMOURY_MINIMUM_CARD_WIDTH = 190
local ARMOURY_MAXIMUM_CARD_WIDTH = 230
local BLESSING_MATERIAL = "content/ui/materials/icons/traits/traits_container"
local DEFAULT_PERK_RANK_MATERIAL = "content/ui/materials/icons/perks/perk_level_01"
local DEFAULT_PERK_RANK_SIZE = 17
local DEFAULT_BLESSING_ICON_SIZE = 36
local PERK_RANK_GAP = 3
local STORE_FOOTER_HEIGHT = 34
local NATIVE_SINGLE_COLUMN_CONTENT_GAP = 12
local WEAPON_PERK_COUNT = 2
local WEAPON_BLESSING_COUNT = 2
local QUICK_LOOK_CARD_DUMP_STAT_ID = "better_inventory_quick_look_card_dump_stat"
local QUICK_LOOK_CARD_HIGHLIGHT_COLOR = {
	255,
	255,
	94,
	132,
}
local QUICK_LOOK_CARD_BASE_STATS_POSITION_MAP = {
	1,
	5,
	3,
	4,
	2,
}
local QUICK_LOOK_CARD_PROJECTED_VALUES_CACHE = setmetatable({}, {
	__mode = "k",
})
local CURIO_PRIMARY_COLOR_DEFINITIONS = {
	gadget_innate_health_increase = {
		prefix = "curio_health_color",
		default = {
			235,
			85,
			85,
		},
	},
	gadget_innate_toughness_increase = {
		prefix = "curio_toughness_color",
		default = {
			105,
			200,
			235,
		},
	},
	gadget_innate_max_wounds_increase = {
		prefix = "curio_wound_color",
		default = {
			190,
			105,
			230,
		},
	},
	gadget_stamina_increase = {
		prefix = "curio_stamina_color",
		default = {
			235,
			205,
			80,
		},
	},
}
local COMPACT_CURIO_LABELS = {
	gadget_cooldown_reduction = {
		heavy_localization_id = "curio_heavy_ability_regen",
		required_terms = {
			"Combat Ability Regeneration",
		},
	},
	gadget_damage_reduction_vs_flamers = {
		localization_id = "curio_resistance_flamers",
		heavy_localization_id = "curio_dr_flamers",
		required_terms = {
			"Damage Resistance",
		},
	},
	gadget_damage_reduction_vs_snipers = {
		localization_id = "curio_resistance_snipers",
		heavy_localization_id = "curio_dr_snipers",
		required_terms = {
			"Damage Resistance",
		},
	},
	gadget_damage_reduction_vs_grenadiers = {
		localization_id = "curio_resistance_grenadiers",
		heavy_localization_id = "curio_dr_grenadiers",
		required_terms = {
			"Damage Resistance",
		},
	},
	gadget_damage_reduction_vs_hounds = {
		localization_id = "curio_resistance_hounds",
		heavy_localization_id = "curio_dr_hounds",
		required_terms = {
			"Damage Resistance",
		},
	},
	gadget_damage_reduction_vs_mutants = {
		localization_id = "curio_resistance_mutants",
		heavy_localization_id = "curio_dr_mutants",
		required_terms = {
			"Damage Resistance",
		},
	},
	gadget_damage_reduction_vs_gunners = {
		localization_id = "curio_resistance_gunners",
		heavy_localization_id = "curio_dr_gunners",
		required_terms = {
			"Damage Resistance",
		},
	},
	gadget_damage_reduction_vs_bombers = {
		localization_id = "curio_resistance_bombers",
		heavy_localization_id = "curio_dr_bombers",
		required_terms = {
			"Damage Resistance",
		},
	},
	gadget_permanent_damage_resistance = {
		localization_id = "curio_resistance_grimoires",
		heavy_localization_id = "curio_dr_grimoires",
		required_terms = {
			"Corruption Resistance",
			"Grimoire",
		},
	},
	gadget_corruption_resistance = {
		heavy_localization_id = "curio_heavy_corruption_dr",
		required_terms = {
			"Corruption Resistance",
		},
	},
	gadget_block_cost_reduction = {
		heavy_localization_id = "curio_heavy_block",
		required_terms = {
			"Block Efficiency",
		},
	},
	gadget_sprint_cost_reduction = {
		heavy_localization_id = "curio_heavy_sprint",
		required_terms = {
			"Sprint Efficiency",
		},
	},
	gadget_stamina_regeneration = {
		heavy_localization_id = "curio_heavy_stamina_regen",
		required_terms = {
			"Stamina Regeneration",
		},
	},
	gadget_mission_reward_gear_instead_of_weapon_increase = {
		localization_id = "curio_reward_chance",
		required_terms = {
			"Curio as Mission Reward",
		},
	},
	gadget_toughness_regen_delay = {
		localization_id = "curio_toughness_regeneration",
		heavy_localization_id = "curio_heavy_toughness_regen",
		required_terms = {
			"Toughness Regeneration",
		},
	},
	gadget_mission_credits_increase = {
		localization_id = "curio_ordo_dockets",
		required_terms = {
			"Ordo Dockets",
		},
	},
	gadget_revive_speed_increase = {
		localization_id = "curio_revive_speed",
		required_terms = {
			"Revive Speed",
		},
	},
}
local COMPACT_WEAPON_PERK_LABELS = {}

local function register_weapon_perk_labels(ids, localization_id, heavy_localization_id)
	for i = 1, #ids do
		COMPACT_WEAPON_PERK_LABELS[ids[i]] = {
			localization_id = localization_id,
			heavy_localization_id = heavy_localization_id,
		}
	end
end

register_weapon_perk_labels({
	"weapon_trait_melee_common_wield_increased_unarmored_damage",
	"weapon_trait_ranged_common_wield_increased_unarmored_damage",
}, "weapon_perk_unarmoured_damage", "weapon_perk_unarmoured_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_melee_common_wield_increased_armored_damage",
	"weapon_trait_ranged_common_wield_increased_armored_damage",
}, "weapon_perk_flak_damage", "weapon_perk_flak_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_melee_common_wield_increased_resistant_damage",
	"weapon_trait_ranged_common_wield_increased_resistant_damage",
}, "weapon_perk_unyielding_damage", "weapon_perk_unyielding_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_melee_common_wield_increased_berserker_damage",
	"weapon_trait_ranged_common_wield_increased_berserker_damage",
}, "weapon_perk_maniacs_damage", "weapon_perk_maniacs_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_melee_common_wield_increased_super_armor_damage",
	"weapon_trait_ranged_common_wield_increased_super_armor_damage",
}, "weapon_perk_carapace_damage", "weapon_perk_carapace_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_melee_common_wield_increased_disgustingly_resilient_damage",
	"weapon_trait_ranged_common_wield_increased_disgustingly_resilient_damage",
}, "weapon_perk_infested_damage", "weapon_perk_infested_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_increase_crit_chance",
}, "weapon_perk_melee_crit_chance", "weapon_perk_melee_crit_chance_heavy")
register_weapon_perk_labels({
	"weapon_trait_increase_crit_damage",
}, "weapon_perk_melee_crit_damage", "weapon_perk_melee_crit_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_increase_stamina",
	"weapon_trait_ranged_increase_stamina",
}, "weapon_perk_stamina", "weapon_perk_stamina")
register_weapon_perk_labels({
	"weapon_trait_increase_damage_hordes",
}, "weapon_perk_horde_melee_damage", "weapon_perk_horde_melee_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_increase_damage_elites",
}, "weapon_perk_elites_melee_damage", "weapon_perk_elites_melee_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_increase_damage_specials",
}, "weapon_perk_specialist_melee_damage", "weapon_perk_specialist_melee_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_increase_weakspot_damage",
}, "weapon_perk_melee_weakspot_damage", "weapon_perk_melee_weakspot_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_ranged_increase_crit_chance",
}, "weapon_perk_ranged_crit_chance", "weapon_perk_ranged_crit_chance_heavy")
register_weapon_perk_labels({
	"weapon_trait_ranged_increase_crit_damage",
}, "weapon_perk_ranged_crit_damage", "weapon_perk_ranged_crit_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_ranged_increase_damage_hordes",
}, "weapon_perk_horde_ranged_damage", "weapon_perk_horde_ranged_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_ranged_increase_damage_elites",
}, "weapon_perk_elites_ranged_damage", "weapon_perk_elites_ranged_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_ranged_increase_damage_specials",
}, "weapon_perk_specialist_ranged_damage", "weapon_perk_specialist_ranged_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_ranged_increase_weakspot_damage",
}, "weapon_perk_ranged_weakspot_damage", "weapon_perk_ranged_weakspot_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_increase_damage",
}, "weapon_perk_melee_damage", "weapon_perk_melee_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_ranged_increase_damage",
}, "weapon_perk_ranged_damage", "weapon_perk_ranged_damage_heavy")
register_weapon_perk_labels({
	"weapon_trait_increase_finesse",
}, "weapon_perk_melee_finesse", "weapon_perk_finesse_heavy")
register_weapon_perk_labels({
	"weapon_trait_ranged_increase_finesse",
}, "weapon_perk_ranged_finesse", "weapon_perk_finesse_heavy")
register_weapon_perk_labels({
	"weapon_trait_increase_power",
}, "weapon_perk_melee_power", "weapon_perk_power_heavy")
register_weapon_perk_labels({
	"weapon_trait_ranged_increase_power",
}, "weapon_perk_ranged_power", "weapon_perk_power_heavy")
register_weapon_perk_labels({
	"weapon_trait_increase_impact",
}, "weapon_perk_melee_impact", "weapon_perk_impact_heavy")
register_weapon_perk_labels({
	"weapon_trait_reduced_block_cost",
}, "weapon_perk_block_efficiency", "weapon_perk_block_heavy")
register_weapon_perk_labels({
	"weapon_trait_reduce_sprint_cost",
}, "weapon_perk_sprint_efficiency", "weapon_perk_sprint_heavy")
register_weapon_perk_labels({
	"weapon_trait_ranged_increased_reload_speed",
}, "weapon_perk_reload_speed", "weapon_perk_reload_heavy")
local CURIO_PRIMARY_SIMPLIFICATIONS = {
	gadget_innate_health_increase = {
		find = "Max Health",
		replace = "Health",
	},
	gadget_stamina_increase = {
		find = "Max Stamina",
		replace = "Stamina",
	},
	gadget_innate_max_wounds_increase = {
		find = "Wound(s)",
		replace = "Wound",
	},
}
local DEFAULT_CURIO_PRIMARY_COLOR = {
	255,
	220,
	230,
	210,
}
local DEFAULT_CURIO_SECONDARY_COLOR = {
	255,
	220,
	230,
	210,
}
local DEFAULT_WEAPON_PERK_COLOR = {
	255,
	190,
	210,
	180,
}
local DEFAULT_WEAPON_BLESSING_TEXT_COLOR = {
	255,
	105,
	200,
	235,
}

local SLOT_SETTING_BY_NAME = {
	slot_primary = "enable_melee_inventory",
	slot_secondary = "enable_ranged_inventory",
}

local function setting(mod, setting_id, fallback)
	local value = mod:get(setting_id)

	if value == nil then
		return fallback
	end

	return value
end

local function numeric_setting(mod, setting_id, fallback, minimum, maximum)
	local value = tonumber(setting(mod, setting_id, fallback)) or fallback

	if minimum then
		value = math.max(minimum, value)
	end

	if maximum then
		value = math.min(maximum, value)
	end

	return value
end

local function curio_primary_font_size(mod)
	return numeric_setting(mod, "curio_primary_stat_font_size", 16, 9, 20)
end

local function curio_secondary_font_size(mod)
	return numeric_setting(mod, "curio_secondary_stat_font_size", 13, 9, 20)
end

local function curio_primary_secondary_spacing(mod)
	return numeric_setting(mod, "curio_primary_secondary_spacing", 5, 0, 20)
end

local function blessing_icon_size(mod)
	return numeric_setting(mod, "blessing_icon_size", DEFAULT_BLESSING_ICON_SIZE, 20, 48)
end

local function weapon_blessing_display_mode(mod)
	local mode = setting(mod, "weapon_blessing_display_mode", "ranked_text")

	-- Retain hot-reload compatibility with the retired checkbox until the
	-- one-time settings migration has run.
	if mode == true then
		return "icons"
	elseif mode == false then
		return "off"
	elseif mode == "icons" or mode == "text" or mode == "ranked_text" or mode == "off" then
		return mode
	end

	return "ranked_text"
end

local function separate_blessing_text_and_item_level(mod, configuration)
	local mode = setting(mod, "blessing_text_item_level_separation", "four_plus")

	if mode == "always" then
		return true
	elseif mode == "never" then
		return false
	end

	-- Threshold modes describe the actual grid being rendered. Native inventory
	-- is a single-column list, while Hadron and Armoury configurations cap the
	-- effective count through maximum_columns.
	if not setting(mod, "enable_grid_layout", true) then
		return false
	end

	configuration = configuration or {}

	local columns = Layout.columns(mod, configuration.maximum_columns)

	if mode == "five_only" then
		return columns >= 5
	end

	return columns >= 4
end

local function blessing_rank_name(rarity)
	local numeric_rarity = math.floor(tonumber(rarity) or 0)
	local rank = RankSettings[numeric_rarity]

	return rank and rank.display_name ~= "n/a" and rank.display_name or ""
end

local function weapon_perk_rank_icon_size(mod)
	return numeric_setting(mod, "weapon_perk_rank_icon_size", DEFAULT_PERK_RANK_SIZE, 12, 32)
end

local function item_from_element(element)
	return element and (element.real_item or element.item)
end

local function item_from_content(content)
	return content and item_from_element(content.element)
end

local function is_curio(item)
	return item and item.item_type == "GADGET"
end

local function is_weapon(item)
	return item and Items.is_weapon(item.item_type)
end

local function clamped_color_channel(mod, setting_id, fallback)
	local value = tonumber(setting(mod, setting_id, fallback)) or fallback

	return math.floor(math.max(0, math.min(255, value)) + 0.5)
end

local function curio_primary_color(mod, trait_id)
	local definition = CURIO_PRIMARY_COLOR_DEFINITIONS[trait_id]

	if not definition then
		return DEFAULT_CURIO_PRIMARY_COLOR
	end

	local prefix = definition.prefix
	local defaults = definition.default

	return {
		255,
		clamped_color_channel(mod, prefix .. "_r", defaults[1]),
		clamped_color_channel(mod, prefix .. "_g", defaults[2]),
		clamped_color_channel(mod, prefix .. "_b", defaults[3]),
	}
end

local function compact_curio_description(mod, data, compression_mode)
	local definition = data and COMPACT_CURIO_LABELS[data.id]
	local description = data and data.description

	if compression_mode == "none" or not definition or type(description) ~= "string" or description == "" then
		return description or ""
	end

	for i = 1, #definition.required_terms do
		if not string.find(description, definition.required_terms[i], 1, true) then
			return description
		end
	end

	local amount = string.match(description, "^%s*([^%s]+)")

	if not amount then
		return description
	end

	local localization_id

	if compression_mode == "heavy" then
		localization_id = definition.heavy_localization_id or definition.localization_id
	else
		localization_id = definition.localization_id
	end

	if not localization_id then
		return description
	end

	return string.format("%s %s", amount, mod:localize(localization_id))
end

local function configured_text_color(mod, prefix, fallback, opacity_setting_id)
	local opacity = opacity_setting_id and tonumber(setting(mod, opacity_setting_id, 100)) or 100
	local alpha = math.floor(math.max(0, math.min(100, opacity)) * 255 / 100 + 0.5)

	return {
		alpha,
		clamped_color_channel(mod, prefix .. "_r", fallback[2]),
		clamped_color_channel(mod, prefix .. "_g", fallback[3]),
		clamped_color_channel(mod, prefix .. "_b", fallback[4]),
	}
end

local function single_line_text(value)
	if type(value) ~= "string" then
		return ""
	end

	-- Enhanced Descriptions decorates localized trait strings with Darktide's
	-- rich-text tags. Those tags are not visible glyphs, but they must not take
	-- part in numeric parsing or compact-card width measurements.
	value = string.gsub(value, "{#[^}]*}", "")
	value = string.gsub(value, "%s+", " ")
	value = string.gsub(value, "^%s+", "")
	value = string.gsub(value, "%s+$", "")

	return value
end

local function compact_weapon_perk_description(mod, data, compression_mode)
	local definition = data and COMPACT_WEAPON_PERK_LABELS[data.id]
	local description = data and data.description

	if compression_mode == "none" or not definition or type(description) ~= "string" or description == "" then
		return description or ""
	end

	local amount = string.match(description, "([%+%-]?%d+%.?%d*%%?)")

	if not amount then
		return description
	end

	if not string.match(amount, "^[%+%-]") then
		amount = "+" .. amount
	end

	local localization_id = compression_mode == "heavy" and definition.heavy_localization_id or definition.localization_id

	return string.format("%s %s", amount, mod:localize(localization_id))
end

local function leading_plus_sign_description(description, remove_plus_sign)
	if not remove_plus_sign or type(description) ~= "string" then
		return description or ""
	end

	local stripped_description = string.gsub(description, "^(%s*)%+", "%1", 1)

	return stripped_description
end

local function simplified_curio_primary_description(data, enabled)
	local description = data and data.description

	if not enabled or type(description) ~= "string" or description == "" then
		return description or ""
	end

	local simplification = CURIO_PRIMARY_SIMPLIFICATIONS[data.id]

	if not simplification then
		return description
	end

	local first, last = string.find(description, simplification.find, 1, true)

	if not first then
		return description
	end

	return string.sub(description, 1, first - 1) .. simplification.replace .. string.sub(description, last + 1)
end

local function pass_by_style_id(pass_template, style_id)
	for i = 1, #pass_template do
		local pass = pass_template[i]

		if pass.style_id == style_id then
			return pass
		end
	end
end

local function is_quick_look_card_pass(pass)
	return type(pass and pass.style_id) == "string" and string.sub(pass.style_id, 1, 4) == "qlc_"
end

local function has_quick_look_card_passes(pass_template)
	for index = 1, #(pass_template or {}) do
		if is_quick_look_card_pass(pass_template[index]) then
			return true
		end
	end

	return false
end

local function quick_look_card_stat_kind_and_index(pass)
	if type(pass and pass.style_id) ~= "string" then
		return
	end

	local kind, index = string.match(pass.style_id, "^qlc_stats_(title)_(%d)$")

	if not kind then
		kind, index = string.match(pass.style_id, "^qlc_stats_(value)_(%d)$")
	end

	index = tonumber(index)

	if index and index >= 1 and index <= 5 then
		return kind, index
	end
end

local function quick_look_card_projected_max_values(item)
	if type(Items.preview_stats_change) ~= "function" or type(Items.max_expertise_level) ~= "function" or type(Items.expertise_level) ~= "function" then
		return
	end

	local current_expertise = Items.expertise_level(item, true)
	local maximum_expertise = tonumber(Items.max_expertise_level())

	current_expertise = tonumber(current_expertise)

	if not current_expertise or not maximum_expertise then
		return
	end

	local cached = QUICK_LOOK_CARD_PROJECTED_VALUES_CACHE[item]

	if cached and cached.current_expertise == current_expertise and cached.maximum_expertise == maximum_expertise then
		return cached.values
	end

	local stats_ok, weapon_stats = pcall(WeaponStats.new, WeaponStats, item)

	if not stats_ok or type(weapon_stats) ~= "table" or type(weapon_stats.get_comparing_stats) ~= "function" then
		return
	end

	local comparing_ok, comparing_stats = pcall(weapon_stats.get_comparing_stats, weapon_stats)

	if not comparing_ok or type(comparing_stats) ~= "table" or #comparing_stats < 1 then
		return
	end

	comparing_stats = table.clone(comparing_stats)

	local preview_ok, projected_stats = pcall(Items.preview_stats_change, item, math.max(0, maximum_expertise - current_expertise), comparing_stats)

	if not preview_ok or type(projected_stats) ~= "table" then
		return
	end

	local projected_values = {}

	for index = 1, math.min(5, #comparing_stats) do
		local comparing_stat = comparing_stats[index]
		local projected_stat = type(comparing_stat) == "table" and projected_stats[comparing_stat.display_name]
		local fraction = type(projected_stat) == "table" and tonumber(projected_stat.fraction)
		local value = fraction and math.floor(fraction * 100 + 0.5) or type(projected_stat) == "table" and tonumber(projected_stat.value)
		local target_index = QUICK_LOOK_CARD_BASE_STATS_POSITION_MAP[index]

		if not fraction and value and value <= 1 then
			value = value * 100
		end

		if not value or not target_index then
			return
		end

		projected_values[target_index] = math.floor(value + 0.5)
	end

	QUICK_LOOK_CARD_PROJECTED_VALUES_CACHE[item] = {
		current_expertise = current_expertise,
		maximum_expertise = maximum_expertise,
		values = projected_values,
	}

	return projected_values
end

local function quick_look_card_lowest_stat_text(content, parenthesized)
	if not content or not is_weapon(item_from_content(content)) then
		return
	end

	local item = item_from_content(content)

	if content.better_inventory_quick_look_card_dump_stat_item == item and content.better_inventory_quick_look_card_dump_stat_resolved then
		local cached_title = content.better_inventory_quick_look_card_dump_stat_title
		local cached_value = content.better_inventory_quick_look_card_dump_stat_value

		if not cached_title or cached_value == nil then
			return
		end

		local cached_label = cached_title .. " " .. tostring(cached_value)

		return parenthesized and "(" .. cached_label .. ")" or cached_label
	end

	local projected_values = quick_look_card_projected_max_values(item)

	if not projected_values then
		return
	end

	local lowest_title
	local lowest_value
	local first_value
	local all_same = true
	local valid_count = 0

	for index = 1, 5 do
		local title = content["qlc_stats_title_" .. index]
		local numeric_value = projected_values[index]

		if type(title) == "string" and title ~= "" and numeric_value then
			valid_count = valid_count + 1

			if first_value == nil then
				first_value = numeric_value
			elseif numeric_value ~= first_value then
				all_same = false
			end

			if lowest_value == nil or numeric_value < lowest_value then
				lowest_title = single_line_text(title)
				lowest_value = numeric_value
			end
		end
	end

	if valid_count < 2 then
		return
	end

	content.better_inventory_quick_look_card_dump_stat_item = item
	content.better_inventory_quick_look_card_dump_stat_resolved = true

	if all_same or not lowest_title then
		content.better_inventory_quick_look_card_dump_stat_title = nil
		content.better_inventory_quick_look_card_dump_stat_value = nil

		return
	end

	content.better_inventory_quick_look_card_dump_stat_title = lowest_title
	content.better_inventory_quick_look_card_dump_stat_value = lowest_value

	local label = lowest_title .. " " .. tostring(lowest_value)

	return parenthesized and "(" .. label .. ")" or label
end

local function quick_look_card_grid_position(mod)
	local position = setting(mod, "quick_look_card_grid_stat_position", "above_power")

	if position == "name_left" or position == "name_right" then
		return position
	end

	return "above_power"
end

local function add_quick_look_card_grid_pass(mod, pass_template, card_width, text_left, position)
	local font_size = numeric_setting(mod, "quick_look_card_grid_font_size", 13, 8, 20)
	local bottom_padding = numeric_setting(mod, "quick_look_card_grid_bottom_padding", 26, 20, 60)
	local parenthesized = position ~= "above_power"
	local label_width = math.max(64, math.floor(font_size * 6 + 0.5))
	local style = {
		font_type = "machine_medium",
		font_size = font_size,
		text_color = table.clone(QUICK_LOOK_CARD_HIGHLIGHT_COLOR),
		drop_shadow = true,
		word_wrap = false,
		offset = {},
		size = {},
	}

	if position == "name_left" then
		style.horizontal_alignment = "left"
		style.vertical_alignment = "top"
		style.text_horizontal_alignment = "left"
		style.text_vertical_alignment = "top"
		style.offset = {
			text_left,
			7,
			12,
		}
		style.size = {
			label_width,
			25,
		}
	elseif position == "name_right" then
		style.horizontal_alignment = "right"
		style.vertical_alignment = "top"
		style.text_horizontal_alignment = "right"
		style.text_vertical_alignment = "top"
		style.offset = {
			-36,
			7,
			12,
		}
		style.size = {
			label_width,
			25,
		}
	else
		style.horizontal_alignment = "right"
		style.vertical_alignment = "bottom"
		style.text_horizontal_alignment = "right"
		style.text_vertical_alignment = "bottom"
		style.offset = {
			-8,
			-bottom_padding,
			12,
		}
		style.size = {
			card_width - 16,
			font_size + 4,
		}
	end

	pass_template[#pass_template + 1] = {
		pass_type = "text",
		style_id = QUICK_LOOK_CARD_DUMP_STAT_ID,
		value = "",
		value_id = QUICK_LOOK_CARD_DUMP_STAT_ID,
		style = style,
		visibility_function = function(content)
			local label = quick_look_card_lowest_stat_text(content, parenthesized)

			if content then
				content[QUICK_LOOK_CARD_DUMP_STAT_ID] = label or ""
			end

			return label ~= nil
		end,
	}

	return label_width
end

local function configure_native_quick_look_card_passes(pass_template)
	local positions = {
		{ 280, -43 },
		{ 360, -43 },
		{ 440, -43 },
		{ 280, -24 },
		{ 360, -24 },
	}

	for index = 1, #(pass_template or {}) do
		local pass = pass_template[index]

		if is_quick_look_card_pass(pass) then
			local kind, stat_index = quick_look_card_stat_kind_and_index(pass)

			if kind then
				local style = pass.style or {}
				local position = positions[stat_index]

				pass.style = style
				style.horizontal_alignment = "left"
				style.vertical_alignment = "bottom"
				style.text_horizontal_alignment = "left"
				style.text_vertical_alignment = "center"
				style.font_size = 14
				style.drop_shadow = true
				style.offset = {
					position[1] + (kind == "value" and 38 or 0),
					position[2],
					5,
				}
				style.size = {
					kind == "value" and 32 or 42,
					17,
				}
			else
				pass.visibility_function = function()
					return false
				end
			end
		end
	end
end

local function disable_quick_look_card_passes(pass_template)
	for index = 1, #(pass_template or {}) do
		local pass = pass_template[index]

		if is_quick_look_card_pass(pass) then
			pass.visibility_function = function()
				return false
			end
		end
	end
end

local function preserve_visibility(pass, predicate)
	if not pass then
		return
	end

	local original_visibility_function = pass.visibility_function

	pass.visibility_function = function(content, style)
		if not predicate(content, style) then
			return false
		end

		return not original_visibility_function or original_visibility_function(content, style)
	end
end

local function set_visibility(pass, visible)
	if pass then
		pass.visibility_function = function()
			return visible
		end
	end
end

local function set_height(pass, height)
	local style = pass and pass.style

	if style then
		style.size = style.size or {}
		style.size[2] = height
	end
end

local function configure_native_card_geometry(pass_template, card_height)
	for _, style_id in ipairs({
		"background",
		"background_gradient",
		"button_gradient",
		"inner_shadow",
		"inner_highlight",
		"item_level",
		"rarity_tag",
	}) do
		set_height(pass_by_style_id(pass_template, style_id), card_height)
	end

	local centered_y = card_height * 0.5 - 19

	for _, style_id in ipairs({
		"required_level_background",
		"required_level",
		"warning_message_background",
		"warning_message",
	}) do
		local pass = pass_by_style_id(pass_template, style_id)

		if pass and pass.style and pass.style.offset then
			pass.style.offset[2] = centered_y
		end
	end
end

local function resolved_trait_data(entry, include_textures, include_perk_rank, include_display_name)
	if type(entry) ~= "table" or type(entry.id) ~= "string" then
		return
	end

	local resolved, trait_item = pcall(MasterItems.get_item, entry.id)

	if not resolved or not trait_item then
		return
	end

	local description_ok, description = pcall(Items.trait_description, trait_item, entry.rarity, entry.value)
	local data = {
		description = description_ok and type(description) == "string" and single_line_text(description) or "",
		-- Inventory entries use master-item paths. The stable gameplay identifier
		-- used by gadget trait templates lives on the resolved item's `trait`
		-- field (for example, gadget_innate_health_increase).
		id = type(trait_item.trait) == "string" and trait_item.trait or entry.id,
		rarity = entry.rarity,
	}

	if include_display_name then
		local display_name_ok, display_name = pcall(Items.display_name, trait_item)

		data.display_name = display_name_ok and type(display_name) == "string" and single_line_text(display_name) or ""
	end

	if include_textures then
		local textures_ok, icon, frame = pcall(Items.trait_textures, trait_item, entry.rarity)

		if textures_ok then
			data.icon = icon
			data.frame = frame
		end
	end

	if include_perk_rank then
		local texture_ok, rank = pcall(Items.perk_textures, trait_item, entry.rarity)

		if texture_ok and type(rank) == "string" and rank ~= "" then
			data.rank = rank
		end
	end

	return data
end

local function populate_card_content(mod, widget, element, blessing_display_mode, show_weapon_perks, weapon_perk_compression, compression_mode, simplify_curio_primary)
	local content = widget and widget.content

	if not content then
		return
	end

	for i = 1, WEAPON_BLESSING_COUNT do
		content["better_inventory_blessing_" .. i] = nil
		content["better_inventory_blessing_text_" .. i] = ""
		content["better_inventory_full_blessing_text_" .. i] = nil
		content["better_inventory_blessing_rank_" .. i] = nil
		content["better_inventory_weapon_perk_" .. i] = ""
		content["better_inventory_full_weapon_perk_" .. i] = nil
		content["better_inventory_weapon_perk_rank_" .. i] = nil
	end

	for i = 1, 4 do
		content["better_inventory_curio_stat_" .. i] = ""
		content["better_inventory_full_curio_stat_" .. i] = nil
	end

	content.better_inventory_curio_primary_color = nil

	local item = item_from_element(element or content.element)

	if is_weapon(item) then
		if blessing_display_mode ~= "off" then
			local traits = item.traits
			local blessing_text_mode = blessing_display_mode == "text" or blessing_display_mode == "ranked_text"
			local blessing_ranked_text = blessing_display_mode == "ranked_text"

			for i = 1, math.min(WEAPON_BLESSING_COUNT, traits and #traits or 0) do
				local data = resolved_trait_data(traits[i], blessing_display_mode == "icons", blessing_ranked_text, blessing_text_mode)

				if blessing_display_mode == "icons" and data and data.icon and data.frame then
					content["better_inventory_blessing_" .. i] = data
				elseif blessing_text_mode and data then
					local name = data.display_name

					if name == "" or name == "-" or name == "n/a" then
						name = data.description
					end

					if name and name ~= "" then
						if blessing_ranked_text then
							content["better_inventory_blessing_text_" .. i] = single_line_text(name)
							content["better_inventory_blessing_rank_" .. i] = data.rank
						else
							local rank_name = blessing_rank_name(data.rarity)

							content["better_inventory_blessing_text_" .. i] = single_line_text(rank_name ~= "" and rank_name .. " " .. name or name)
						end
					end
				end
			end
		end

		if show_weapon_perks then
			local perks = item.perks
			local show_perk_rank = setting(mod, "show_weapon_perk_rank_symbols", true)
			local remove_perk_plus_sign = setting(mod, "remove_weapon_perk_plus_signs", false)

			for i = 1, math.min(WEAPON_PERK_COUNT, perks and #perks or 0) do
				local data = resolved_trait_data(perks[i], false, show_perk_rank)

				if data then
					local description = compact_weapon_perk_description(mod, data, weapon_perk_compression)

					content["better_inventory_weapon_perk_" .. i] = single_line_text(leading_plus_sign_description(description, remove_perk_plus_sign))
					content["better_inventory_weapon_perk_rank_" .. i] = data.rank
				end
			end
		end

		return
	end

	if not is_curio(item) then
		return
	end

	local remove_plus_sign = setting(mod, "remove_curio_stat_plus_signs", false)

	local primary_entry = item.traits and item.traits[1]
	local primary_data = resolved_trait_data(primary_entry, false)

	if primary_data then
		local primary_description = simplified_curio_primary_description(primary_data, simplify_curio_primary)

		content.better_inventory_curio_stat_1 = leading_plus_sign_description(primary_description, remove_plus_sign)
		content.better_inventory_curio_primary_color = curio_primary_color(mod, primary_data.id)
	end

	local perks = item.perks

	for i = 1, math.min(3, perks and #perks or 0) do
		local perk_data = resolved_trait_data(perks[i], false)

		if perk_data then
			local perk_description = compact_curio_description(mod, perk_data, compression_mode)

			content["better_inventory_curio_stat_" .. (i + 1)] = leading_plus_sign_description(perk_description, remove_plus_sign)
		end
	end
end

local function configure_text_pass(pass, options)
	if not pass or not pass.style then
		return
	end

	local style = pass.style

	style.horizontal_alignment = options.horizontal_alignment or "left"
	style.vertical_alignment = options.vertical_alignment or "top"
	style.text_horizontal_alignment = options.text_horizontal_alignment or "left"
	style.text_vertical_alignment = options.text_vertical_alignment or "top"
	style.font_size = options.font_size
	style.offset = options.offset
	style.size = options.size
end

local function add_blessing_pass(pass_template, index, size, x_offset, y_offset)
	local content_id = "better_inventory_blessing_" .. index

	pass_template[#pass_template + 1] = {
		pass_type = "texture",
		style_id = content_id,
		value = BLESSING_MATERIAL,
		style = {
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			material_values = {},
			size = {
				size,
				size,
			},
			offset = {
				x_offset,
				y_offset or -3,
				12,
			},
			color = {
				255,
				255,
				255,
				255,
			},
		},
		visibility_function = function(content)
			return content and content[content_id] ~= nil
		end,
		change_function = function(content, style)
			local data = content and content[content_id]
			local material_values = style and style.material_values

			if data and material_values then
				material_values.icon = data.icon
				material_values.frame = data.frame
			end
		end,
	}
end

local function add_blessing_text_pass(pass_template, index, options)
	local content_id = "better_inventory_blessing_text_" .. index
	local style = table.clone(options.base_style or {})

	style.font_size = options.font_size
	style.horizontal_alignment = "left"
	style.vertical_alignment = "bottom"
	style.text_horizontal_alignment = "left"
	style.text_vertical_alignment = "bottom"
	style.word_wrap = false
	style.offset = options.offset
	style.size = options.size
	style.better_inventory_max_text_width = options.size[1]
	style.better_inventory_preferred_font_size = options.font_size
	style.text_color = table.clone(options.text_color or DEFAULT_WEAPON_PERK_COLOR)

	pass_template[#pass_template + 1] = {
		pass_type = "text",
		style_id = content_id,
		value = "",
		value_id = content_id,
		style = style,
		visibility_function = function(content)
			return content and content[content_id] ~= nil and content[content_id] ~= ""
		end,
	}
end

local function add_weapon_perk_pass(pass_template, index, options)
	local content_id = "better_inventory_weapon_perk_" .. index
	local style = table.clone(options.base_style or {})

	style.font_size = options.font_size
	style.horizontal_alignment = "left"
	style.vertical_alignment = "bottom"
	style.text_horizontal_alignment = "left"
	style.text_vertical_alignment = "bottom"
	style.word_wrap = false
	style.offset = options.offset
	style.size = options.size
	style.better_inventory_max_text_width = options.size[1]
	style.better_inventory_preferred_font_size = options.font_size
	style.text_color = table.clone(options.text_color or DEFAULT_WEAPON_PERK_COLOR)
	style.drop_shadow = true

	pass_template[#pass_template + 1] = {
		pass_type = "text",
		style_id = content_id,
		value = "",
		value_id = content_id,
		style = style,
		visibility_function = function(content)
			return content and content[content_id] ~= nil and content[content_id] ~= ""
		end,
	}
end

local function add_weapon_perk_rank_pass(pass_template, index, options)
	local content_id = "better_inventory_weapon_perk_rank_" .. index

	pass_template[#pass_template + 1] = {
		pass_type = "texture",
		style_id = content_id,
		value = DEFAULT_PERK_RANK_MATERIAL,
		value_id = content_id,
		style = {
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			offset = options.offset,
			size = {
				options.size,
				options.size,
			},
			color = {
				255,
				255,
				255,
				255,
			},
		},
		visibility_function = function(content)
			return content and content[content_id] ~= nil and content[content_id] ~= ""
		end,
	}
end

local function add_blessing_rank_pass(pass_template, index, options)
	local content_id = "better_inventory_blessing_rank_" .. index

	pass_template[#pass_template + 1] = {
		pass_type = "texture",
		style_id = content_id,
		value = DEFAULT_PERK_RANK_MATERIAL,
		value_id = content_id,
		style = {
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			offset = options.offset,
			size = {
				options.size,
				options.size,
			},
			color = {
				255,
				255,
				255,
				255,
			},
		},
		visibility_function = function(content)
			return content and content[content_id] ~= nil and content[content_id] ~= ""
		end,
	}
end

local function add_curio_stat_pass(pass_template, index, options)
	local content_id = "better_inventory_curio_stat_" .. index
	local style = table.clone(options.base_style or {})

	style.font_size = options.font_size
	style.horizontal_alignment = "left"
	style.vertical_alignment = options.vertical_alignment
	style.text_horizontal_alignment = "left"
	style.text_vertical_alignment = options.text_vertical_alignment
	style.word_wrap = false
	style.offset = options.offset
	style.size = options.size
	style.better_inventory_max_text_width = options.max_text_width or options.size[1]
	style.text_color = table.clone(options.text_color or DEFAULT_CURIO_PRIMARY_COLOR)

	pass_template[#pass_template + 1] = {
		pass_type = "text",
		style_id = content_id,
		value = "",
		value_id = content_id,
		style = style,
		visibility_function = function(content)
			return content and content[content_id] ~= nil and content[content_id] ~= ""
		end,
		change_function = index == 1 and function(content, style)
			local color = content and content.better_inventory_curio_primary_color or DEFAULT_CURIO_PRIMARY_COLOR
			local text_color = style.text_color

			for channel = 1, 4 do
				text_color[channel] = color[channel]
			end
		end or nil,
	}
end

local function configure_favorite_marker(mod, pass_template, text_left)
	local favorite_icon = pass_by_style_id(pass_template, "favorite_icon")

	if not favorite_icon or not favorite_icon.style then
		return
	end

	local favorite_style = favorite_icon.style
	local favorite_marker_position = setting(mod, "favorite_marker_position", "above_rating")

	if setting(mod, "compact_favorite_marker", true) then
		favorite_icon.value = ""
		favorite_style.font_size = 20
		favorite_style.size = {
			30,
			28,
		}
	end

	if favorite_marker_position == "above_rating" then
		favorite_style.horizontal_alignment = "right"
		favorite_style.vertical_alignment = "top"
		favorite_style.text_horizontal_alignment = "right"
		favorite_style.text_vertical_alignment = "top"
		favorite_style.offset = {
			-8,
			7,
			16,
		}

		local original_change_function = favorite_icon.change_function

		favorite_icon.change_function = function(content, style, animations, dt)
			if original_change_function then
				original_change_function(content, style, animations, dt)
			end

			style.offset[2] = content and content.equipped and 33 or 7
		end
	else
		favorite_style.horizontal_alignment = "left"
		favorite_style.vertical_alignment = "bottom"
		favorite_style.text_horizontal_alignment = "left"
		favorite_style.text_vertical_alignment = "bottom"
		favorite_style.offset = {
			text_left,
			-5,
			16,
		}
	end
end

local function configure_equipped_highlight(mod, pass_template, card_width, card_height)
	local highlight = pass_by_style_id(pass_template, "better_inventory_equipped_highlight")

	if not highlight then
		highlight = {
			pass_type = "texture",
			style_id = "better_inventory_equipped_highlight",
			value = "content/ui/materials/frames/dropshadow_medium",
			style = {},
		}
		pass_template[#pass_template + 1] = highlight
	end

	highlight.style = highlight.style or {}
	highlight.style.horizontal_alignment = "center"
	highlight.style.vertical_alignment = "center"
	highlight.style.scale_to_material = true
	highlight.style.size = {
		card_width,
		card_height,
	}
	highlight.style.size_addition = {
		16,
		16,
	}
	highlight.style.color = {
		255,
		255,
		255,
		255,
	}
	highlight.style.offset = {
		0,
		0,
		3,
	}
	highlight.visibility_function = function(content)
		return setting(mod, "highlight_equipped_items", true) and content and content.equipped == true
	end
end

local function add_custom_content_passes(mod, pass_template, card_width, text_left, base_text_style, configuration)
	configuration = configuration or {}

	local blessing_display_mode = weapon_blessing_display_mode(mod)
	local blessing_text_mode = blessing_display_mode == "text" or blessing_display_mode == "ranked_text"
	local blessing_ranked_text = blessing_display_mode == "ranked_text"
	local show_weapon_perks = setting(mod, "show_weapon_perks", true)
	local show_weapon_perk_ranks = show_weapon_perks and setting(mod, "show_weapon_perk_rank_symbols", true)
	local detailed_curio_profile = setting(mod, "curio_display_profile", "detailed") == "detailed"
	local favorite_marker_position = setting(mod, "favorite_marker_position", "above_rating")
	local store_footer_height = configuration.store_item and STORE_FOOTER_HEIGHT or 0
	local expertise_font_size = numeric_setting(mod, "expertise_font_size", 20, 10, 28)
	local item_level_row_height = math.max(30, expertise_font_size + 10)
	local bottom_content_height = item_level_row_height
	local blessing_size
	local blessing_text_height
	local perk_rank_size = weapon_perk_rank_icon_size(mod)

	if blessing_display_mode == "icons" then
		blessing_size = blessing_icon_size(mod)
		local blessing_gap = numeric_setting(mod, "blessing_icon_spacing", 3, 0, 20)
		local blessing_spacing = blessing_size + blessing_gap
		local blessing_left = text_left + (favorite_marker_position == "bottom_left" and 24 or 0)
		local blessing_y_offset = -(store_footer_height + 3)

		for i = 1, WEAPON_BLESSING_COUNT do
			add_blessing_pass(pass_template, i, blessing_size, blessing_left + (i - 1) * blessing_spacing, blessing_y_offset)
		end
	elseif blessing_text_mode then
		local blessing_font_size = numeric_setting(mod, "secondary_text_font_size", 13, 9, 16)
		local blessing_line_height = blessing_ranked_text and math.max(blessing_font_size + 4, perk_rank_size + 1) or blessing_font_size + 4
		local blessing_vertical_spacing = numeric_setting(mod, "weapon_blessing_text_vertical_spacing", 2, 0, 20)
		local blessing_bottom_padding = numeric_setting(mod, "weapon_blessing_text_bottom_padding", 4, 0, 20)
		local blessing_line_step = blessing_line_height + blessing_vertical_spacing
		local separate_item_level = separate_blessing_text_and_item_level(mod, configuration)
		local favorite_offset = favorite_marker_position == "bottom_left" and not separate_item_level and 24 or 0
		local blessing_rank_left = text_left + favorite_offset
		local blessing_text_left = blessing_rank_left + (blessing_ranked_text and perk_rank_size + PERK_RANK_GAP or 0)
		local reserved_right = separate_item_level and 8 or 50
		local blessing_text_right = configuration.content_right or card_width - reserved_right
		local blessing_text_width = math.max(40, blessing_text_right - blessing_text_left)
		local blessing_text_color = configured_text_color(mod, "weapon_blessing_text_color", DEFAULT_WEAPON_BLESSING_TEXT_COLOR, "weapon_blessing_text_opacity")
		local reserved_bottom_row = separate_item_level and (configuration.store_item and store_footer_height or item_level_row_height) or store_footer_height

		blessing_text_height = WEAPON_BLESSING_COUNT * blessing_line_height + (WEAPON_BLESSING_COUNT - 1) * blessing_vertical_spacing

		for i = 1, WEAPON_BLESSING_COUNT do
			local y_offset = -(reserved_bottom_row + blessing_bottom_padding + (WEAPON_BLESSING_COUNT - i) * blessing_line_step)

			if blessing_ranked_text then
				add_blessing_rank_pass(pass_template, i, {
					size = perk_rank_size,
					offset = {
						blessing_rank_left,
						y_offset,
						11,
					},
				})
			end

			add_blessing_text_pass(pass_template, i, {
				base_style = base_text_style,
				font_size = blessing_font_size,
				text_color = blessing_text_color,
				offset = {
					blessing_text_left,
					y_offset,
					11,
				},
				size = {
					blessing_text_width,
					blessing_line_height,
				},
			})
		end
	end

	if configuration.store_item then
		if blessing_display_mode == "icons" then
			bottom_content_height = store_footer_height + blessing_size + 6
		elseif blessing_text_mode then
			local blessing_bottom_padding = numeric_setting(mod, "weapon_blessing_text_bottom_padding", 4, 0, 20)

			bottom_content_height = store_footer_height + blessing_text_height + blessing_bottom_padding + 3
		else
			bottom_content_height = store_footer_height
		end
	elseif blessing_display_mode == "icons" then
		bottom_content_height = math.max(bottom_content_height, blessing_size + 6)
	elseif blessing_text_mode then
		local blessing_bottom_padding = numeric_setting(mod, "weapon_blessing_text_bottom_padding", 4, 0, 20)

		if separate_blessing_text_and_item_level(mod, configuration) then
			bottom_content_height = bottom_content_height + blessing_text_height + blessing_bottom_padding + 3
		else
			bottom_content_height = math.max(bottom_content_height, blessing_text_height + blessing_bottom_padding + 3)
		end
	end

	if show_weapon_perks then
		local perk_font_size = numeric_setting(mod, "secondary_text_font_size", 13, 9, 16)
		local perk_line_height = show_weapon_perk_ranks and math.max(perk_font_size + 4, perk_rank_size + 1) or perk_font_size + 4
		local perk_vertical_spacing = numeric_setting(mod, "weapon_perk_vertical_spacing", 2, 0, 20)
		local perk_line_step = perk_line_height + perk_vertical_spacing
		local section_spacing = blessing_display_mode ~= "off" and numeric_setting(mod, "weapon_perk_blessing_spacing", 5, 0, 20) or 2
		local perk_text_left = text_left + (show_weapon_perk_ranks and perk_rank_size + PERK_RANK_GAP or 0)
		local perk_text_right = configuration.content_right or card_width - 8
		local perk_width = math.max(40, perk_text_right - perk_text_left)
		local perk_text_color = configured_text_color(mod, "weapon_perk_text_color", DEFAULT_WEAPON_PERK_COLOR, "weapon_perk_text_opacity")

		for i = 1, WEAPON_PERK_COUNT do
			local y_offset = -(bottom_content_height + section_spacing + (WEAPON_PERK_COUNT - i) * perk_line_step)

			if show_weapon_perk_ranks then
				add_weapon_perk_rank_pass(pass_template, i, {
					size = perk_rank_size,
					offset = {
						text_left,
						y_offset,
						11,
					},
				})
			end

			add_weapon_perk_pass(pass_template, i, {
				base_style = base_text_style,
				font_size = perk_font_size,
				text_color = perk_text_color,
				offset = {
					perk_text_left,
					y_offset,
					11,
				},
				size = {
					perk_width,
					perk_line_height,
				},
			})
		end
	end

	if detailed_curio_profile then
		local primary_font_size = curio_primary_font_size(mod)
		local secondary_font_size = curio_secondary_font_size(mod)
		local primary_secondary_spacing = curio_primary_secondary_spacing(mod)
		local secondary_text_color = configured_text_color(mod, "curio_secondary_text_color", DEFAULT_CURIO_SECONDARY_COLOR)
		local y_offset = 7

		for i = 1, 4 do
			if i == 2 then
				y_offset = y_offset + primary_secondary_spacing
			end

			local font_size = i == 1 and primary_font_size or secondary_font_size
			local line_height = font_size + 5
			local reserved_right = i <= 2 and 40 or 8
			local render_width = math.max(40, card_width - text_left - 4)
			local max_text_width = math.max(36, card_width - text_left - reserved_right - 4)

			add_curio_stat_pass(pass_template, i, {
				base_style = base_text_style,
				font_size = font_size,
				text_color = i == 1 and DEFAULT_CURIO_PRIMARY_COLOR or secondary_text_color,
				vertical_alignment = "top",
				text_vertical_alignment = "top",
				offset = {
					text_left,
					y_offset,
					11,
				},
				size = {
					render_width,
					line_height,
				},
				max_text_width = max_text_width,
			})

			y_offset = y_offset + line_height
		end
	else
		local primary_font_size = curio_primary_font_size(mod)
		local primary_line_height = math.max(20, primary_font_size + 5)

		add_curio_stat_pass(pass_template, 1, {
			base_style = base_text_style,
			font_size = primary_font_size,
			vertical_alignment = "bottom",
			text_vertical_alignment = "bottom",
			offset = {
				text_left,
				-(store_footer_height + math.max(31, primary_line_height + 11)),
				11,
			},
			size = {
				math.max(40, card_width - text_left - 40),
				primary_line_height,
			},
		})
	end
end

local function grid_ui_renderer(parent)
	if not parent then
		return
	end

	if parent._ui_resource_renderer then
		return parent._ui_resource_renderer
	end

	local view = parent._parent

	if view and view.ui_renderer then
		return view:ui_renderer()
	end
end

local function valid_weapon_name_part(value)
	return type(value) == "string" and value ~= "" and value ~= "n/a"
end

local function format_weapon_name(widget, element, append_mark_to_name)
	local content = widget and widget.content

	if not content then
		return
	end

	content.better_inventory_display_name_base = nil
	content.better_inventory_display_name_suffix = nil

	if not append_mark_to_name then
		return
	end

	element = element or content.element

	local item = element and (element.real_item or element.item)
	local display_name = content.display_name
	local mark_ok, mark_name = pcall(Items.weapon_lore_mark_name, item)

	mark_name = mark_ok and mark_name or nil

	if not valid_weapon_name_part(display_name) or not valid_weapon_name_part(mark_name) then
		return
	end

	local suffix = " " .. mark_name

	content.better_inventory_display_name_base = display_name
	content.better_inventory_display_name_suffix = suffix
	content.display_name = display_name .. suffix

	local pattern_ok, pattern_name = pcall(Items.weapon_lore_pattern_name, item)

	pattern_name = pattern_ok and pattern_name or nil

	content.sub_display_name = valid_weapon_name_part(pattern_name) and pattern_name or ""
end

local function format_item_level(widget, element, show_item_level_icon)
	if show_item_level_icon then
		return
	end

	local content = widget and widget.content
	local item = item_from_element(element or content and content.element)

	if not content or not item then
		return
	end

	local success, item_level, has_item_level = pcall(Items.expertise_level, item, true)

	if success then
		content.item_level = has_item_level and item_level or ""
	end
end

local function fit_display_name(parent, widget, ui_renderer, preferred_font_size, minimum_font_size)
	local content = widget and widget.content
	local style = widget and widget.style and widget.style.display_name
	local display_name = content and content.display_name

	if not style or type(display_name) ~= "string" or display_name == "" then
		return
	end

	ui_renderer = ui_renderer or grid_ui_renderer(parent)

	if not ui_renderer then
		return
	end

	local maximum_width = style.size and style.size[1]
	preferred_font_size = preferred_font_size or style.font_size

	if not maximum_width or not preferred_font_size then
		return
	end

	minimum_font_size = math.min(preferred_font_size, minimum_font_size)
	style.word_wrap = false
	style.font_size = preferred_font_size

	local measurement_size = {
		1000000,
		style.size[2] or 30,
	}
	local measured_width = Text.text_width(ui_renderer, display_name, style, measurement_size, true)

	while measured_width > maximum_width and style.font_size > minimum_font_size do
		style.font_size = style.font_size - 1
		measured_width = Text.text_width(ui_renderer, display_name, style, measurement_size, true)
	end

	content.better_inventory_full_display_name = display_name

	if measured_width > maximum_width then
		local base_name = content.better_inventory_display_name_base
		local suffix = content.better_inventory_display_name_suffix

		if base_name and suffix then
			local suffix_width = Text.text_width(ui_renderer, suffix, style, measurement_size, true)
			local maximum_base_width = maximum_width - suffix_width

			if maximum_base_width > 0 then
				local base_width = Text.text_width(ui_renderer, base_name, style, measurement_size, true)
				local fitted_base_name = base_width > maximum_base_width and Text.crop_text_width(ui_renderer, base_name, style, maximum_base_width) or base_name

				content.display_name = fitted_base_name .. suffix

				return
			end
		end

		content.display_name = Text.crop_text_width(ui_renderer, display_name, style, maximum_width)
	end
end

local function fit_curio_stats(parent, widget, ui_renderer)
	local content = widget and widget.content
	local styles = widget and widget.style

	if not content or not styles then
		return
	end

	ui_renderer = ui_renderer or grid_ui_renderer(parent)

	if not ui_renderer then
		return
	end

	local measurement_size = {
		1000000,
		30,
	}

	for i = 1, 4 do
		local content_id = "better_inventory_curio_stat_" .. i
		local style = styles[content_id]
		local value = content[content_id]
		local maximum_width = style and (style.better_inventory_max_text_width or style.size and style.size[1])

		if type(value) == "string" and value ~= "" and maximum_width then
			content["better_inventory_full_curio_stat_" .. i] = value
			measurement_size[2] = style.size[2] or 30

			if Text.text_width(ui_renderer, value, style, measurement_size, true) > maximum_width then
				content[content_id] = Text.crop_text_width(ui_renderer, value, style, maximum_width)
			end
		end
	end
end

local function fit_blessing_text(parent, widget, ui_renderer)
	local content = widget and widget.content
	local styles = widget and widget.style

	if not content or not styles then
		return
	end

	ui_renderer = ui_renderer or grid_ui_renderer(parent)

	if not ui_renderer then
		return
	end

	local measurement_size = {
		1000000,
		30,
	}

	for i = 1, WEAPON_BLESSING_COUNT do
		local content_id = "better_inventory_blessing_text_" .. i
		local style = styles[content_id]
		local value = content[content_id]
		local maximum_width = style and (style.better_inventory_max_text_width or style.size and style.size[1])

		if type(value) == "string" and value ~= "" and maximum_width then
			local preferred_font_size = style.better_inventory_preferred_font_size or style.font_size
			local minimum_font_size = math.min(preferred_font_size, 8)
			measurement_size[2] = style.size[2] or 30

			style.font_size = preferred_font_size
			content["better_inventory_full_blessing_text_" .. i] = value

			local measured_width = Text.text_width(ui_renderer, value, style, measurement_size, true)

			while measured_width > maximum_width and style.font_size > minimum_font_size do
				style.font_size = style.font_size - 1
				measured_width = Text.text_width(ui_renderer, value, style, measurement_size, true)
			end

			if measured_width > maximum_width then
				content[content_id] = Text.crop_text_width(ui_renderer, value, style, maximum_width)
			end
		end
	end
end

local function fit_weapon_perks(parent, widget, ui_renderer)
	local content = widget and widget.content
	local styles = widget and widget.style

	if not content or not styles then
		return
	end

	ui_renderer = ui_renderer or grid_ui_renderer(parent)

	if not ui_renderer then
		return
	end

	local measurement_size = {
		1000000,
		30,
	}

	for i = 1, WEAPON_PERK_COUNT do
		local content_id = "better_inventory_weapon_perk_" .. i
		local style = styles[content_id]
		local value = content[content_id]
		local maximum_width = style and (style.better_inventory_max_text_width or style.size and style.size[1])

		if type(value) == "string" and value ~= "" and maximum_width then
			local preferred_font_size = style.better_inventory_preferred_font_size or style.font_size
			local minimum_font_size = math.min(preferred_font_size, 9)
			measurement_size[2] = style.size[2] or 30

			style.font_size = preferred_font_size
			content["better_inventory_full_weapon_perk_" .. i] = value

			local measured_width = Text.text_width(ui_renderer, value, style, measurement_size, true)

			while measured_width > maximum_width and style.font_size > minimum_font_size do
				style.font_size = style.font_size - 1
				measured_width = Text.text_width(ui_renderer, value, style, measurement_size, true)
			end

			if measured_width > maximum_width then
				content[content_id] = Text.crop_text_width(ui_renderer, value, style, maximum_width)
			end
		end
	end
end

local function configure_card_content(mod, item_blueprint)
	local original_init = item_blueprint.init
	local original_update_data = item_blueprint.update_data
	local preferred_font_size = numeric_setting(mod, "item_name_font_size", 16, 10, 24)
	local minimum_font_size = numeric_setting(mod, "minimum_item_name_font_size", 12, 8, 20)
	local append_mark_to_name = setting(mod, "append_mark_to_name", true)
	local blessing_display_mode = weapon_blessing_display_mode(mod)
	local show_weapon_perks = setting(mod, "show_weapon_perks", true)
	local weapon_perk_compression = setting(mod, "weapon_perk_compression", "heavy")
	local show_item_level_icon = setting(mod, "show_item_level_icon", false)
	local compression_mode = setting(mod, "curio_stat_compression", "heavy")
	local simplify_curio_primary = setting(mod, "simplify_curio_primary_stat_text", true)

	-- Accept the retired checkbox values during the one-time settings migration
	-- and when hot-reloading from an older options schema.
	if compression_mode == true then
		compression_mode = "compression"
	elseif compression_mode == false then
		compression_mode = "none"
	end

	if original_init then
		item_blueprint.init = function(parent, widget, element, callback_name, secondary_callback_name, ui_renderer, double_click_callback, template)
			original_init(parent, widget, element, callback_name, secondary_callback_name, ui_renderer, double_click_callback, template)
			format_weapon_name(widget, element, append_mark_to_name)
			format_item_level(widget, element, show_item_level_icon)
			populate_card_content(mod, widget, element, blessing_display_mode, show_weapon_perks, weapon_perk_compression, compression_mode, simplify_curio_primary)
			fit_display_name(parent, widget, ui_renderer, preferred_font_size, math.min(preferred_font_size, minimum_font_size))
			fit_blessing_text(parent, widget, ui_renderer)
			fit_weapon_perks(parent, widget, ui_renderer)
			fit_curio_stats(parent, widget, ui_renderer)
		end
	end

	if original_update_data then
		item_blueprint.update_data = function(parent, widget, element)
			original_update_data(parent, widget, element)
			format_weapon_name(widget, element, append_mark_to_name)
			format_item_level(widget, element, show_item_level_icon)
			populate_card_content(mod, widget, element, blessing_display_mode, show_weapon_perks, weapon_perk_compression, compression_mode, simplify_curio_primary)
			fit_display_name(parent, widget, nil, preferred_font_size, math.min(preferred_font_size, minimum_font_size))
			fit_blessing_text(parent, widget, nil)
			fit_weapon_perks(parent, widget, nil)
			fit_curio_stats(parent, widget, nil)
		end
	end
end

Layout.slot_kind = function(view)
	local selected_slot = view and view._selected_slot
	local slot_name = selected_slot and selected_slot.name

	if SLOT_SETTING_BY_NAME[slot_name] then
		return slot_name
	end

	if type(slot_name) == "string" and string.match(slot_name, "^slot_attachment_") then
		return "curio"
	end
end

Layout.is_enabled_for_view = function(mod, view)
	local slot_kind = Layout.slot_kind(view)

	if slot_kind == "curio" then
		return setting(mod, "enable_curio_inventory", true)
	end

	local setting_id = SLOT_SETTING_BY_NAME[slot_kind]

	return setting_id and setting(mod, setting_id, true) or false
end

Layout.columns = function(mod, maximum_columns)
	local column_limit = math.floor(math.max(2, math.min(5, tonumber(maximum_columns) or 5)))
	local requested_columns = math.floor(numeric_setting(mod, "columns", 3, 2, 5))

	return math.max(2, math.min(column_limit, requested_columns))
end

local function weapon_extra_width_applies(mod, columns)
	local threshold = setting(mod, "weapon_extra_width_column_threshold", "four_plus")

	return columns >= (threshold == "five_only" and 5 or 4)
end

Layout.grid_expansion = function(mod, current_grid_width, slot_kind)
	current_grid_width = tonumber(current_grid_width)

	if not current_grid_width or current_grid_width <= 0 then
		return 0
	end

	if not setting(mod, "enable_grid_layout", true) or not setting(mod, "expand_inventory_window", true) then
		return 0
	end

	local columns = Layout.columns(mod)
	local spacing = numeric_setting(mod, "grid_spacing", 10, 0, 40)
	local target_card_width = MINIMUM_CARD_WIDTH

	if slot_kind == "curio" and setting(mod, "expand_curio_inventory_window", true) then
		target_card_width = numeric_setting(mod, "curio_target_card_width", 190, MINIMUM_CARD_WIDTH, 220)
	end

	local required_grid_width = target_card_width * columns + spacing * (columns - 1)
	local required_expansion = math.max(0, required_grid_width - current_grid_width)

	if slot_kind ~= "curio" and weapon_extra_width_applies(mod, columns) then
		local extra_width = numeric_setting(mod, "five_column_weapon_extra_width", 80, 0, MAXIMUM_WEAPON_EXTRA_WIDTH)

		required_expansion = required_expansion + extra_width
	end

	return required_expansion
end

Layout.armoury_grid_expansion = function(mod, current_grid_width)
	current_grid_width = tonumber(current_grid_width)

	if not current_grid_width or current_grid_width <= 0 then
		return 0
	end

	if not setting(mod, "enable_grid_layout", true) or not setting(mod, "enable_armoury_requisition_grid", true) or not setting(mod, "expand_armoury_requisition_window", true) then
		return 0
	end

	local columns = Layout.columns(mod, 3)
	local spacing = numeric_setting(mod, "grid_spacing", 10, 0, 40)
	local target_card_width = numeric_setting(mod, "armoury_requisition_target_card_width", 230, ARMOURY_MINIMUM_CARD_WIDTH, ARMOURY_MAXIMUM_CARD_WIDTH)
	local required_grid_width = target_card_width * columns + spacing * (columns - 1)

	return math.max(0, required_grid_width - current_grid_width)
end

local function maximum_safe_inventory_expansion(definitions, slot_kind)
	local scenegraph = definitions and definitions.scenegraph_definition
	local canvas = scenegraph and scenegraph.canvas
	local canvas_size = canvas and canvas.size
	local canvas_width = canvas_size and canvas_size[1] or INVENTORY_CANVAS_WIDTH
	local panel_id = slot_kind == "curio" and "weapon_stats_pivot" or "weapon_actions_pivot"
	local panel_width = slot_kind == "curio" and WEAPON_STATS_PANEL_WIDTH or WEAPON_ACTIONS_PANEL_WIDTH
	local panel = scenegraph and scenegraph[panel_id]
	local panel_position = panel and panel.position
	local panel_x = panel_position and panel_position[1]

	if type(canvas_width) ~= "number" or type(panel_x) ~= "number" then
		-- A changed scenegraph contract means there is no trustworthy screen-edge
		-- clamp. Preserve native width instead of risking an off-screen panel.
		return 0
	end

	local panel_anchor_x

	if panel.horizontal_alignment == "right" then
		panel_anchor_x = canvas_width + panel_x
	else
		panel_anchor_x = panel_x
	end

	local available_expansion = canvas_width - INVENTORY_EDGE_MARGIN - (panel_anchor_x + panel_width)

	return math.max(0, available_expansion)
end

Layout.expanded_armoury_view_definitions = function(mod, definitions, base_definitions)
	local grid_settings = definitions and definitions.grid_settings
	local grid_size = grid_settings and grid_settings.grid_size
	local current_grid_width = grid_size and grid_size[1]

	if type(current_grid_width) ~= "number" or current_grid_width <= 0 then
		return definitions, 0
	end

	local expansion = Layout.armoury_grid_expansion(mod, current_grid_width)

	if expansion <= 0 then
		return definitions, 0
	end

	local adjusted_definitions = table.clone(definitions)
	local adjusted_grid_settings = adjusted_definitions.grid_settings

	adjusted_grid_settings.grid_size[1] = adjusted_grid_settings.grid_size[1] + expansion

	if adjusted_grid_settings.mask_size and adjusted_grid_settings.mask_size[1] then
		adjusted_grid_settings.mask_size[1] = adjusted_grid_settings.mask_size[1] + expansion
	end

	local scenegraph = adjusted_definitions.scenegraph_definition
	local base_scenegraph = base_definitions and base_definitions.scenegraph_definition

	if scenegraph then
		local item_grid_pivot = scenegraph.item_grid_pivot
		local pivot_size = item_grid_pivot and item_grid_pivot.size

		if pivot_size and pivot_size[1] then
			pivot_size[1] = pivot_size[1] + expansion
		end

		for _, scenegraph_id in ipairs({
			"weapon_stats_pivot",
			"weapon_compare_stats_pivot",
			"purchase_button",
		}) do
			local node = scenegraph[scenegraph_id]

			if not node and base_scenegraph and base_scenegraph[scenegraph_id] then
				node = table.clone(base_scenegraph[scenegraph_id])
				scenegraph[scenegraph_id] = node
			end

			local position = node and node.position

			if position and position[1] then
				position[1] = position[1] + expansion
			end
		end
	end

	return adjusted_definitions, expansion
end

Layout.expanded_view_definitions = function(mod, definitions, view)
	local grid_settings = definitions and definitions.grid_settings
	local grid_size = grid_settings and grid_settings.grid_size
	local current_grid_width = grid_size and grid_size[1]

	if type(current_grid_width) ~= "number" or current_grid_width <= 0 then
		return definitions, 0
	end

	local slot_kind = Layout.slot_kind(view)
	local requested_expansion = Layout.grid_expansion(mod, current_grid_width, slot_kind)
	local safe_expansion = maximum_safe_inventory_expansion(definitions, slot_kind)
	local expansion = math.min(requested_expansion, safe_expansion)

	if expansion <= 0 then
		return definitions, 0
	end

	local adjusted_definitions = table.clone(definitions)
	local adjusted_grid_settings = adjusted_definitions.grid_settings

	adjusted_grid_settings.grid_size[1] = adjusted_grid_settings.grid_size[1] + expansion

	if adjusted_grid_settings.mask_size and adjusted_grid_settings.mask_size[1] then
		adjusted_grid_settings.mask_size[1] = adjusted_grid_settings.mask_size[1] + expansion
	end

	local scenegraph = adjusted_definitions.scenegraph_definition

	if scenegraph then
		for _, scenegraph_id in ipairs({
			"weapon_stats_pivot",
			"weapon_compare_stats_pivot",
			"weapon_actions_pivot",
			"equip_button",
			"weapon_discard_pivot",
		}) do
			local node = scenegraph[scenegraph_id]
			local position = node and node.position

			if position and position[1] then
				position[1] = position[1] + expansion
			end
		end
	end

	return adjusted_definitions, expansion
end

Layout.card_height = function(mod, configuration)
	configuration = configuration or {}

	local manual_height = numeric_setting(mod, "card_height", 110, 110, 240)

	if not setting(mod, "automatic_card_height", true) then
		return manual_height
	end

	local item_name_font_size = numeric_setting(mod, "item_name_font_size", 16, 10, 24)
	local secondary_font_size = numeric_setting(mod, "secondary_text_font_size", 13, 8, 20)
	local expertise_font_size = numeric_setting(mod, "expertise_font_size", 20, 10, 28)
	local name_row_height = math.max(25, item_name_font_size + 5)
	local secondary_row_height = math.max(22, secondary_font_size + 5)
	local bottom_region_height = math.max(expertise_font_size + 10, secondary_font_size + 15)
	local required_height = 110
	local store_footer_height = configuration.store_item and STORE_FOOTER_HEIGHT or 0

	local blessing_display_mode = weapon_blessing_display_mode(mod)
	local blessing_text_mode = blessing_display_mode == "text" or blessing_display_mode == "ranked_text"

	if blessing_display_mode == "icons" then
		local configured_blessing_size = blessing_icon_size(mod)

		if configuration.store_item then
			bottom_region_height = store_footer_height + configured_blessing_size + 6
		else
			bottom_region_height = math.max(bottom_region_height, configured_blessing_size + 6)
		end
	elseif blessing_text_mode then
		local blessing_font_size = math.max(9, math.min(16, secondary_font_size))
		local blessing_line_height = blessing_display_mode == "ranked_text" and math.max(blessing_font_size + 4, weapon_perk_rank_icon_size(mod) + 1) or blessing_font_size + 4
		local blessing_vertical_spacing = numeric_setting(mod, "weapon_blessing_text_vertical_spacing", 2, 0, 20)
		local blessing_bottom_padding = numeric_setting(mod, "weapon_blessing_text_bottom_padding", 4, 0, 20)
		local blessing_text_height = WEAPON_BLESSING_COUNT * blessing_line_height + (WEAPON_BLESSING_COUNT - 1) * blessing_vertical_spacing + blessing_bottom_padding + 3

		if configuration.store_item then
			bottom_region_height = store_footer_height + blessing_text_height
		elseif separate_blessing_text_and_item_level(mod, configuration) then
			bottom_region_height = bottom_region_height + blessing_text_height
		else
			bottom_region_height = math.max(bottom_region_height, blessing_text_height)
		end
	elseif configuration.store_item then
		bottom_region_height = math.max(bottom_region_height, store_footer_height)
	end

	if setting(mod, "show_weapon_perks", true) then
		local perk_font_size = math.max(9, math.min(16, secondary_font_size))
		local perk_line_height = setting(mod, "show_weapon_perk_rank_symbols", true) and math.max(perk_font_size + 4, weapon_perk_rank_icon_size(mod) + 1) or perk_font_size + 4
		local perk_vertical_spacing = numeric_setting(mod, "weapon_perk_vertical_spacing", 2, 0, 20)
		local section_spacing = blessing_display_mode ~= "off" and numeric_setting(mod, "weapon_perk_blessing_spacing", 5, 0, 20) or 2

		bottom_region_height = bottom_region_height + WEAPON_PERK_COUNT * perk_line_height + (WEAPON_PERK_COUNT - 1) * perk_vertical_spacing + math.max(0, section_spacing - 2)
	end

	local optional_rows = 0

	if setting(mod, "show_pattern_mark", false) then
		optional_rows = optional_rows + 1
	end

	if setting(mod, "show_rarity_name", false) then
		optional_rows = optional_rows + 1
	end

	local native_content_gap = configuration.native_single_column and NATIVE_SINGLE_COLUMN_CONTENT_GAP or 0

	required_height = math.max(required_height, 7 + name_row_height + optional_rows * secondary_row_height + bottom_region_height + 8 + native_content_gap)

	if setting(mod, "curio_display_profile", "detailed") == "detailed" then
		local primary_line_height = curio_primary_font_size(mod) + 5
		local secondary_line_height = curio_secondary_font_size(mod) + 5
		local primary_secondary_spacing = curio_primary_secondary_spacing(mod)

		required_height = math.max(required_height, 7 + primary_line_height + primary_secondary_spacing + 3 * secondary_line_height + 12 + store_footer_height)
	else
		local primary_line_height = math.max(20, curio_primary_font_size(mod) + 5)
		local quality_row_height = setting(mod, "show_curio_quality", false) and secondary_row_height or 0

		required_height = math.max(required_height, 7 + name_row_height + quality_row_height + primary_line_height + 12 + store_footer_height)
	end

	return math.max(110, math.min(240, math.ceil(required_height)))
end

Layout.item_size = function(mod, grid_width, maximum_columns, configuration)
	grid_width = tonumber(grid_width)

	if not grid_width or grid_width <= 0 then
		grid_width = MINIMUM_CARD_WIDTH * Layout.columns(mod, maximum_columns)
	end

	local columns = Layout.columns(mod, maximum_columns)
	local spacing = numeric_setting(mod, "grid_spacing", 10, 0, 40)
	local height = Layout.card_height(mod, configuration)
	local width = math.floor((grid_width - spacing * (columns - 1)) / columns)

	return {
		math.max(60, width),
		height,
	}
end

Layout.configure_grid = function(mod, item_grid)
	if not setting(mod, "enable_grid_layout", true) then
		return
	end

	local spacing = numeric_setting(mod, "grid_spacing", 10, 0, 40)
	local menu_settings = item_grid and item_grid._menu_settings

	if menu_settings then
		menu_settings.grid_spacing = {
			spacing,
			spacing,
		}
	end
end

Layout.configure_native_item_blueprint = function(mod, item_blueprint, grid_width)
	local item_size = table.clone(item_blueprint.size or {
		grid_width,
		110,
	})
	local card_width = item_size[1] or grid_width
	local pass_template = table.clone(item_blueprint.pass_template)
	local detailed_curio_profile = setting(mod, "curio_display_profile", "detailed") == "detailed"
	local show_pattern_mark = setting(mod, "show_pattern_mark", false)
	local show_curio_quality = setting(mod, "show_curio_quality", false)
	local show_curio_item_level = setting(mod, "show_curio_item_level", true)
	local quick_look_card_present = has_quick_look_card_passes(pass_template)
	local quick_look_card_integration = quick_look_card_present and setting(mod, "enable_quick_look_card_single_column_integration", true)

	if not quick_look_card_present or quick_look_card_integration then
		item_size[2] = math.max(item_size[2] or 110, Layout.card_height(mod, {
			native_single_column = true,
		}))
	end

	item_blueprint.size = item_size
	item_blueprint.pass_template = pass_template

	if not quick_look_card_present or quick_look_card_integration then
		configure_native_card_geometry(pass_template, item_size[2] or 110)
	end

	if quick_look_card_integration then
		configure_native_quick_look_card_passes(pass_template)
	end

	local display_name = pass_by_style_id(pass_template, "display_name")
	local sub_display_name = pass_by_style_id(pass_template, "sub_display_name")
	local rarity_name = pass_by_style_id(pass_template, "rarity_name")
	local item_level = pass_by_style_id(pass_template, "item_level")

	preserve_visibility(display_name, function(content)
		return not detailed_curio_profile or not is_curio(item_from_content(content))
	end)

	if sub_display_name then
		sub_display_name.visibility_function = function(content)
			local item = item_from_content(content)

			if is_curio(item) then
				return show_curio_quality and not detailed_curio_profile
			end

			return is_weapon(item) and show_pattern_mark
		end
	end

	if rarity_name then
		local show_weapon_quality = setting(mod, "show_rarity_name", false)

		rarity_name.visibility_function = function(content)
			return show_weapon_quality and is_weapon(item_from_content(content))
		end
	end

	preserve_visibility(item_level, function(content)
		return not is_curio(item_from_content(content)) or show_curio_item_level
	end)

	set_visibility(pass_by_style_id(pass_template, "rarity_tag"), setting(mod, "show_rarity_tag", true))
	configure_equipped_highlight(mod, pass_template, card_width, item_size[2] or 110)
	configure_favorite_marker(mod, pass_template, 15)

	if not quick_look_card_present or quick_look_card_integration then
		add_custom_content_passes(mod, pass_template, card_width, 15, sub_display_name and sub_display_name.style, {
			content_right = quick_look_card_integration and 260 or nil,
			native_single_column = true,
		})
	end
	configure_card_content(mod, item_blueprint)

	return item_size
end


Layout.configure_item_blueprint = function(mod, item_blueprint, grid_width, configuration)
	if not setting(mod, "enable_grid_layout", true) then
		return Layout.configure_native_item_blueprint(mod, item_blueprint, grid_width)
	end

	configuration = configuration or {}

	local item_size = Layout.item_size(mod, grid_width, configuration.maximum_columns, configuration)
	local card_width = item_size[1]
	local card_height = item_size[2]
	local pass_template = table.clone(item_blueprint.pass_template)
	local show_rarity_tag = setting(mod, "show_rarity_tag", true)
	local text_left = show_rarity_tag and 12 or 8
	local quick_look_card_present = has_quick_look_card_passes(pass_template)
	local quick_look_card_integration = quick_look_card_present and setting(mod, "enable_quick_look_card_grid_integration", true)
	local quick_look_card_position = quick_look_card_grid_position(mod)
	local quick_look_card_label_width = quick_look_card_integration and quick_look_card_position ~= "above_power" and math.max(64, math.floor(numeric_setting(mod, "quick_look_card_grid_font_size", 13, 8, 20) * 6 + 0.5)) or 0

	if quick_look_card_position ~= "above_power" and card_width < text_left + quick_look_card_label_width + 4 + 36 + 50 then
		quick_look_card_position = "above_power"
	end

	local display_name_left = text_left + (quick_look_card_integration and quick_look_card_position == "name_left" and quick_look_card_label_width + 4 or 0)
	local display_name_right_reserve = 36 + (quick_look_card_integration and quick_look_card_position == "name_right" and quick_look_card_label_width + 4 or 0)
	local text_width = math.max(50, card_width - display_name_left - display_name_right_reserve)
	local darkness = numeric_setting(mod, "icon_darkness", 25, 0, 85)
	local icon_brightness = math.floor(255 * (1 - darkness / 100))
	local curio_display_profile = setting(mod, "curio_display_profile", "detailed")
	local detailed_curio_profile = curio_display_profile == "detailed"
	local show_curio_quality = setting(mod, "show_curio_quality", false)
	local show_curio_item_level = setting(mod, "show_curio_item_level", true)

	item_blueprint.size = item_size
	item_blueprint.pass_template = pass_template
	disable_quick_look_card_passes(pass_template)

	if quick_look_card_integration then
		add_quick_look_card_grid_pass(mod, pass_template, card_width, text_left, quick_look_card_position)
	end

	local icon = pass_by_style_id(pass_template, "icon")

	if icon and icon.style then
		icon.style.horizontal_alignment = "left"
		icon.style.vertical_alignment = "top"
		icon.style.size = {
			card_width,
			card_height,
		}
		icon.style.offset = {
			0,
			0,
			4,
		}
		icon.style.uvs = {
			{
				0,
				0,
			},
			{
				1,
				1,
			},
		}
		icon.style.color = {
			255,
			icon_brightness,
			icon_brightness,
			icon_brightness,
		}
	end

	local loading = pass_by_style_id(pass_template, "loading")

	if loading and loading.style then
		loading.style.horizontal_alignment = "center"
		loading.style.vertical_alignment = "center"
		loading.style.size = {
			56,
			56,
		}
		loading.style.offset = {
			0,
			0,
			5,
		}
	end

	local display_name = pass_by_style_id(pass_template, "display_name")

	configure_text_pass(display_name, {
		font_size = numeric_setting(mod, "item_name_font_size", 16, 10, 24),
		offset = {
			display_name_left,
			7,
			8,
		},
		size = {
			text_width,
			25,
		},
	})

	if display_name and display_name.style then
		display_name.style.word_wrap = false
	end
	preserve_visibility(display_name, function(content)
		return not detailed_curio_profile or not is_curio(item_from_content(content))
	end)

	local sub_display_name = pass_by_style_id(pass_template, "sub_display_name")

	configure_text_pass(sub_display_name, {
		font_size = numeric_setting(mod, "secondary_text_font_size", 13, 8, 20),
		offset = {
			text_left,
			31,
			8,
		},
		size = {
			card_width - text_left - 8,
			22,
		},
	})
	local show_pattern_mark = setting(mod, "show_pattern_mark", false)

	if sub_display_name then
		sub_display_name.visibility_function = function(content)
			local item = item_from_content(content)

			if is_curio(item) then
				return show_curio_quality and not detailed_curio_profile
			end

			return is_weapon(item) and show_pattern_mark
		end
	end

	local rarity_name = pass_by_style_id(pass_template, "rarity_name")

	configure_text_pass(rarity_name, {
		font_size = numeric_setting(mod, "secondary_text_font_size", 13, 8, 20),
		offset = {
			text_left,
			51,
			8,
		},
		size = {
			card_width - text_left - 8,
			22,
		},
	})
	if rarity_name then
		local show_weapon_quality = setting(mod, "show_rarity_name", false)

		rarity_name.visibility_function = function(content)
			return show_weapon_quality and is_weapon(item_from_content(content))
		end
	end

	local item_level = pass_by_style_id(pass_template, "item_level")

	configure_text_pass(item_level, {
		font_size = numeric_setting(mod, "expertise_font_size", 20, 10, 28),
		horizontal_alignment = "right",
		vertical_alignment = "bottom",
		text_horizontal_alignment = "right",
		text_vertical_alignment = "bottom",
		offset = {
			-8,
			-5,
			9,
		},
		size = {
			card_width - 16,
			28,
		},
	})
	preserve_visibility(item_level, function(content)
		return not is_curio(item_from_content(content)) or show_curio_item_level
	end)

	if configuration.store_item then
		local wallet_icon = pass_by_style_id(pass_template, "wallet_icon")

		if wallet_icon and wallet_icon.style then
			wallet_icon.style.horizontal_alignment = "left"
			wallet_icon.style.vertical_alignment = "bottom"
			wallet_icon.style.size = {
				22,
				18,
			}
			wallet_icon.style.offset = {
				text_left,
				-7,
				12,
			}
		end

		configure_text_pass(pass_by_style_id(pass_template, "price_text"), {
			font_size = 16,
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			text_horizontal_alignment = "left",
			text_vertical_alignment = "bottom",
			offset = {
				text_left + 27,
				-5,
				12,
			},
			size = {
				math.max(45, card_width - text_left - 105),
				24,
			},
		})
		configure_text_pass(pass_by_style_id(pass_template, "owned_text"), {
			font_size = 14,
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			text_horizontal_alignment = "left",
			text_vertical_alignment = "bottom",
			offset = {
				text_left,
				-5,
				12,
			},
			size = {
				math.max(55, card_width - text_left - 80),
				24,
			},
		})
	end

	local rarity_tag = pass_by_style_id(pass_template, "rarity_tag")

	if rarity_tag and rarity_tag.style then
		rarity_tag.style.size = {
			5,
			card_height,
		}
	end
	set_visibility(rarity_tag, show_rarity_tag)

	local equipped_icon = pass_by_style_id(pass_template, "equipped_icon")

	if equipped_icon and equipped_icon.style then
		equipped_icon.style.size = {
			28,
			28,
		}
		equipped_icon.style.offset = {
			-2,
			2,
			16,
		}
	end

	configure_equipped_highlight(mod, pass_template, card_width, card_height)

	for i = 1, #pass_template do
		local pass = pass_template[i]

		if pass.value == "content/ui/materials/symbols/new_item_indicator" and pass.style then
			pass.style.size = {
				62,
				62,
			}
			pass.style.offset = {
				16,
				-16,
				4,
			}
			break
		end
	end

	configure_favorite_marker(mod, pass_template, text_left)

	local salvage_icon = pass_by_style_id(pass_template, "salvage_icon")
	local salvage_circle = pass_by_style_id(pass_template, "salvage_circle")

	if salvage_icon and salvage_icon.style then
		salvage_icon.style.offset = {
			card_width * 0.5 - 27,
			0,
			14,
		}
	end

	if salvage_circle and salvage_circle.style then
		salvage_circle.style.offset = {
			card_width * 0.5 - 50,
			0,
			15,
		}
	end

	local centered_y = card_height * 0.5 - 19

	for _, style_id in ipairs({
		"required_level_background",
		"required_level",
		"warning_message_background",
		"warning_message",
	}) do
		local pass = pass_by_style_id(pass_template, style_id)

		if pass and pass.style then
			pass.style.offset = pass.style.offset or {}
			pass.style.offset[2] = centered_y
		end
	end

	add_custom_content_passes(mod, pass_template, card_width, text_left, sub_display_name and sub_display_name.style, configuration)

	set_height(pass_by_style_id(pass_template, "inner_shadow"), card_height)
	set_height(pass_by_style_id(pass_template, "inner_highlight"), card_height)

	configure_card_content(mod, item_blueprint)

	return item_size
end

return Layout
