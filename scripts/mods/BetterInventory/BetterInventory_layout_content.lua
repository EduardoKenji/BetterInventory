local Content = {}
local columns
local item_customization_provider

local Items = require("scripts/utilities/items")
local RankSettings = require("scripts/settings/item/rank_settings")
local WeaponStats = require("scripts/utilities/weapon_stats")

local BLESSING_MATERIAL = "content/ui/materials/icons/traits/traits_container"
local DEFAULT_PERK_RANK_MATERIAL = "content/ui/materials/icons/perks/perk_level_01"
local DEFAULT_PERK_RANK_SIZE = 17
local DEFAULT_BLESSING_ICON_SIZE = 36
local PERK_RANK_GAP = 3
local GLOBAL_STORE_CHARACTER_PHOTO_BASE_SIZE = 30
local GLOBAL_STORE_CHARACTER_PHOTO_MIN_PERCENT = 50
local GLOBAL_STORE_CHARACTER_PHOTO_DEFAULT_PERCENT = 110
-- Keep the established layout available while allowing a small amount of
-- additional growth. At 125%, the original 100% size sits at 80% of the slider.
local GLOBAL_STORE_CHARACTER_PHOTO_MAX_PERCENT = 125
local GLOBAL_STORE_CHARACTER_ROW_HEIGHT = 30
local GLOBAL_STORE_CHARACTER_INFO_GAP_DEFAULT = 5
local GLOBAL_STORE_CHARACTER_INFO_GAP_MIN = 0
local GLOBAL_STORE_CHARACTER_INFO_GAP_MAX = 40
local GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_DEFAULT = 16
local GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_MIN = 8
local GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_MAX = 24
local GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_DEFAULT = 16
local GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_MIN = 8
local GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_MAX = 20
local GLOBAL_STORE_CHARACTER_NAME_FIT_SAFETY_MARGIN = 6
local GLOBAL_STORE_PRICE_ROW_PADDING_DEFAULT = 10
local GLOBAL_STORE_PRICE_ROW_PADDING_MIN = 5
local GLOBAL_STORE_PRICE_ROW_PADDING_MAX = 20
local NATIVE_SINGLE_COLUMN_CONTENT_GAP = 12
local CURIO_NAME_LINE_GAP = 3
local COLUMN_SETTING_BY_SLOT = {
	melee = "melee_columns",
	ranged = "ranged_columns",
	curio = "curio_columns",
	-- Inventory and vendor views expose the native slot names. Keep these
	-- aliases alongside the semantic names used by the settings UI so both
	-- paths resolve the same per-category column value.
	slot_primary = "melee_columns",
	slot_secondary = "ranged_columns",
}
local WEAPON_PERK_COUNT = 2
local WEAPON_BLESSING_COUNT = 2
local BLESSING_TEXT_WIDTH_SAFETY_MARGIN = 4
local MINIMUM_AUTO_FIT_BLESSING_FONT_SIZE = 8
local QUICK_LOOK_CARD_DUMP_STAT_ID = "better_inventory_quick_look_card_dump_stat"
local WEAPON_MODIFIER_TITLE_PREFIX = "better_inventory_weapon_modifier_title_"
local WEAPON_MODIFIER_VALUE_PREFIX = "better_inventory_weapon_modifier_value_"

local function global_store_character_photo_percent(mod)
	local value = tonumber(mod:get("global_store_character_photo_size_percent")) or GLOBAL_STORE_CHARACTER_PHOTO_DEFAULT_PERCENT

	return math.max(GLOBAL_STORE_CHARACTER_PHOTO_MIN_PERCENT, math.min(GLOBAL_STORE_CHARACTER_PHOTO_MAX_PERCENT, value))
end

local function global_store_character_photo_size(mod)
	return math.max(12, math.floor(GLOBAL_STORE_CHARACTER_PHOTO_BASE_SIZE * global_store_character_photo_percent(mod) / 100 + 0.5))
end

local function global_store_price_row_padding(mod)
	local value = tonumber(mod:get("global_store_price_row_padding")) or GLOBAL_STORE_PRICE_ROW_PADDING_DEFAULT

	return math.max(GLOBAL_STORE_PRICE_ROW_PADDING_MIN, math.min(GLOBAL_STORE_PRICE_ROW_PADDING_MAX, value))
end

local function global_store_character_info_gap(mod)
	local value = tonumber(mod:get("global_store_character_info_gap")) or GLOBAL_STORE_CHARACTER_INFO_GAP_DEFAULT

	return math.max(GLOBAL_STORE_CHARACTER_INFO_GAP_MIN, math.min(GLOBAL_STORE_CHARACTER_INFO_GAP_MAX, value))
end

local function global_store_character_class_icon_size(mod)
	local value = tonumber(mod:get("global_store_character_class_icon_size")) or GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_DEFAULT

	return math.max(GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_MIN, math.min(GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_MAX, value))
end

local function global_store_character_name_font_size(mod)
	local value = tonumber(mod:get("global_store_character_name_font_size")) or GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_DEFAULT

	return math.max(GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_MIN, math.min(GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_MAX, value))
end

local function global_store_extra_height(mod, configuration)
	if not configuration or configuration.global_store ~= true or type(columns) ~= "function" then
		return 0
	end

	return GLOBAL_STORE_CHARACTER_ROW_HEIGHT + math.max(0, global_store_price_row_padding(mod) - GLOBAL_STORE_PRICE_ROW_PADDING_DEFAULT)
end

Content.global_store_character_photo_size = global_store_character_photo_size
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
local WEAPON_MODIFIER_TITLE_COLOR = {
	255,
	250,
	250,
	250,
}
local WEAPON_MODIFIER_VALUE_COLOR = {
	255,
	250,
	189,
	73,
}
local WEAPON_MODIFIER_LABELS = {
	loc_glossary_term_melee_damage = { "weapon_modifier_melee_damage", "MELE" },
	loc_stats_display_ammo_stat = { "weapon_modifier_ammo", "AMM" },
	loc_stats_display_ap_stat = { "weapon_modifier_penetration", "PEN" },
	loc_stats_display_burn_stat = { "weapon_modifier_burn", "BURN" },
	loc_stats_display_charge_speed = { "weapon_modifier_charge_rate", "CHRG" },
	loc_stats_display_cleave_damage_stat = { "weapon_modifier_cleave_damage", "CLVD" },
	loc_stats_display_cleave_targets_stat = { "weapon_modifier_cleave_targets", "CLVT" },
	loc_stats_display_control_stat_melee = { "weapon_modifier_crowd_control", "CC" },
	loc_stats_display_control_stat_ranged = { "weapon_modifier_collateral", "CLTR" },
	loc_stats_display_crit_stat = { "weapon_modifier_critical_bonus", "CRIT" },
	loc_stats_display_damage_stat = { "weapon_modifier_damage", "DMG" },
	loc_stats_display_defense_stat = { "weapon_modifier_defences", "DEF" },
	loc_stats_display_explosion_ap_stat = { "weapon_modifier_blast_penetration", "PENB" },
	loc_stats_display_explosion_damage_stat = { "weapon_modifier_blast_damage", "BLSD" },
	loc_stats_display_explosion_stat = { "weapon_modifier_blast_radius", "BLSR" },
	loc_stats_display_finesse_stat = { "weapon_modifier_finesse", "FIN" },
	loc_stats_display_first_saw_damage = { "weapon_modifier_shredder", "SHRD" },
	loc_stats_display_first_target_stat = { "weapon_modifier_first_target", "FRST" },
	loc_stats_display_flame_size_stat = { "weapon_modifier_cloud_radius", "CLDR" },
	loc_stats_display_heat_management = { "weapon_modifier_thermal_resistance", "TRES" },
	loc_stats_display_mobility_stat = { "weapon_modifier_mobility", "MOB" },
	loc_stats_display_power_output = { "weapon_modifier_power_output", "PWR" },
	loc_stats_display_power_stat = { "weapon_modifier_stopping_power", "STPW" },
	loc_stats_display_range_stat = { "weapon_modifier_range", "RNGE" },
	loc_stats_display_reload_speed_stat = { "weapon_modifier_reload_speed", "RLD" },
	loc_stats_display_stability_stat = { "weapon_modifier_stability", "STB" },
	loc_stats_display_vent_speed = { "weapon_modifier_quell_speed", "QUEL" },
	loc_stats_display_warp_resist_stat = { "weapon_modifier_warp_resistance", "WRES" },
	loc_stats_display_heat_management_powersword_2h = { "weapon_modifier_heat_management", "HTMG" },
	loc_stats_display_arc_stat = { "weapon_modifier_arc_efficiency", "ARC" },
	loc_stats_display_cleave_damage_and_targets_stat = { "weapon_modifier_cleave_efficiency", "CLVE" },
}
local QUICK_LOOK_CARD_PROJECTED_VALUES_CACHE = setmetatable({}, {
	__mode = "k",
})

Content.clear_runtime_caches = function()
	-- Darktide's gear service can keep item tables alive for the process lifetime,
	-- so weak keys alone do not retire projected records after their UI closes.
	QUICK_LOOK_CARD_PROJECTED_VALUES_CACHE = setmetatable({}, {
		__mode = "k",
	})
end
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
local CURIO_HEALTH_SIMPLIFICATIONS = {
	{
		find = "Maximum Health",
		replace = "Health",
	},
	{
		find = "Max Health",
		replace = "Health",
	},
}
local CURIO_TOUGHNESS_SIMPLIFICATIONS = {
	{
		find = "Maximum Toughness",
		replace = "Toughness",
	},
	{
		find = "Max Toughness",
		replace = "Toughness",
	},
}
local CURIO_STAT_SIMPLIFICATIONS = {
	-- Enhanced Descriptions uses "Maximum" for innate Health/Toughness and
	-- secondary Health while vanilla commonly uses "Max". Match by stable
	-- trait ID so unrelated prose is never rewritten.
	gadget_innate_health_increase = CURIO_HEALTH_SIMPLIFICATIONS,
	gadget_health_increase = CURIO_HEALTH_SIMPLIFICATIONS,
	gadget_innate_toughness_increase = CURIO_TOUGHNESS_SIMPLIFICATIONS,
	gadget_toughness_increase = CURIO_TOUGHNESS_SIMPLIFICATIONS,
	gadget_stamina_increase = {
		{
			find = "Maximum Stamina",
			replace = "Stamina",
		},
		{
			find = "Max Stamina",
			replace = "Stamina",
		},
	},
	gadget_innate_max_wounds_increase = {
		{
			find = "Wound(s)",
			replace = "Wound",
		},
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
local DEFAULT_ARMOURY_ITEM_LEVEL_COLOR = {
	255,
	220,
	230,
	210,
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

local function enabled_name_it_mod()
	local resolver = rawget(_G, "get_mod")

	if type(resolver) ~= "function" then
		return
	end

	local ok, name_it = pcall(resolver, "name_it")

	if not ok or type(name_it) ~= "table" then
		return
	end

	if type(name_it.is_enabled) == "function" then
		local enabled_ok, enabled = pcall(name_it.is_enabled, name_it)

		if enabled_ok and enabled == false then
			return
		end
	end

	return name_it
end

local function fallback_name_it_name(mod, item, is_sub)
	if setting(mod, "enable_custom_item_name_and_colors", true) ~= false then
		return
	end

	local name_it = enabled_name_it_mod()

	if not name_it or type(name_it.get_custom_name) ~= "function" then
		return
	end

	local ok, custom_name = pcall(name_it.get_custom_name, item, is_sub)

	return ok and type(custom_name) == "string" and custom_name ~= "" and custom_name or nil
end

local function name_it_curio_title_enabled(mod, configuration)
	return not (configuration and configuration.character_overview) and setting(mod, "name_it_force_curio_name_in_detailed_mode", true)
end

local function curio_name_font_size(mod, configuration)
	local fallback = configuration and configuration.native_single_column and 20 or 16
	local setting_id = configuration and configuration.native_single_column and "single_column_weapon_name_font_size" or "item_name_font_size"
	local value = tonumber(setting(mod, setting_id, fallback)) or fallback

	return math.max(10, math.min(24, value))
end

local function curio_name_title_height(mod, configuration)
	return math.max(40, 2 * (curio_name_font_size(mod, configuration) + CURIO_NAME_LINE_GAP))
end

Content.set_item_customization_provider = function(provider)
	item_customization_provider = provider
end

local function item_customization(mod, item)
	if setting(mod, "enable_custom_item_name_and_colors", true) == false or type(item_customization_provider) ~= "table" or type(item_customization_provider.get) ~= "function" then
		return
	end

	local gear_id = item and item.gear_id

	return gear_id and item_customization_provider.get(mod, gear_id) or nil
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

columns = function(mod, maximum_columns, slot_kind)
	local column_limit = math.floor(math.max(2, math.min(5, tonumber(maximum_columns) or 5)))
	local setting_id = COLUMN_SETTING_BY_SLOT[slot_kind]
	local configured_columns = setting_id and tonumber(mod:get(setting_id))

	if not setting_id or configured_columns == nil then
		setting_id = "columns"
	end

	local requested_columns = math.floor(numeric_setting(mod, setting_id, 3, 2, 5))

	return math.max(2, math.min(column_limit, requested_columns))
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

	local columns = columns(mod, configuration.maximum_columns, configuration.slot_kind)

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

local function configured_text_color(mod, prefix, fallback, opacity_setting_id, default_opacity)
	local opacity = opacity_setting_id and tonumber(setting(mod, opacity_setting_id, default_opacity or 100)) or 100
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

local function simplified_curio_description(data, enabled, description)
	description = description or data and data.description

	if not enabled or type(description) ~= "string" or description == "" then
		return description or ""
	end

	local simplifications = CURIO_STAT_SIMPLIFICATIONS[data.id]

	if not simplifications then
		return description
	end

	for i = 1, #simplifications do
		local simplification = simplifications[i]
		local first, last = string.find(description, simplification.find, 1, true)

		if first then
			return string.sub(description, 1, first - 1) .. simplification.replace .. string.sub(description, last + 1)
		end
	end

	return description
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

local function weapon_modifier_pass_kind_and_index(pass)
	local kind, index = quick_look_card_stat_kind_and_index(pass)

	if kind then
		return kind, index
	end

	if type(pass and pass.style_id) ~= "string" then
		return
	end

	local title_index = string.match(pass.style_id, "^" .. WEAPON_MODIFIER_TITLE_PREFIX .. "(%d)$")

	if title_index then
		return "title", tonumber(title_index)
	end

	local value_index = string.match(pass.style_id, "^" .. WEAPON_MODIFIER_VALUE_PREFIX .. "(%d)$")

	if value_index then
		return "value", tonumber(value_index)
	end
end

local function fallback_weapon_modifier_label(display_name)
	local body = type(display_name) == "string" and (string.match(display_name, "display_(.+)_stat$") or string.match(display_name, "display_(.+)$") or string.match(display_name, "([^_]+)$")) or "stat"
	local words = {}

	for word in string.gmatch(body, "[%w]+") do
		words[#words + 1] = string.upper(word)
	end

	if #words == 1 then
		return string.sub(words[1], 1, 4)
	elseif #words > 1 then
		local initials = ""

		for index = 1, math.min(4, #words) do
			initials = initials .. string.sub(words[index], 1, 1)
		end

		return initials
	end

	return "STAT"
end

local function compact_weapon_modifier_label(label)
	if type(label) ~= "string" then
		return label
	end

	label = single_line_text(label)

	-- Quick Look Card can supply its own English title instead of using our
	-- localization path. Normalize both sources so AMMO never wraps on any
	-- BetterInventory-managed card or view.
	return string.upper(label) == "AMMO" and "AMM" or label
end

local function localized_weapon_modifier_label(mod, display_name)
	local definition = WEAPON_MODIFIER_LABELS[display_name]

	if not definition then
		return compact_weapon_modifier_label(fallback_weapon_modifier_label(display_name))
	end

	local localization_id = definition[1]
	local fallback = definition[2]
	local localized_ok, localized = pcall(mod.localize, mod, localization_id)

	if not localized_ok or type(localized) ~= "string" or localized == "" or localized == localization_id or localized == "<" .. localization_id .. ">" then
		return compact_weapon_modifier_label(fallback)
	end

	return compact_weapon_modifier_label(localized)
end

local function unique_weapon_modifier_label(label, used_labels)
	if not used_labels[label] then
		used_labels[label] = true
		return label
	end

	for suffix = 2, 9 do
		local candidate = string.sub(label, 1, math.max(1, 4 - #tostring(suffix))) .. tostring(suffix)

		if not used_labels[candidate] then
			used_labels[candidate] = true
			return candidate
		end
	end

	return label
end

local function projected_weapon_modifier_records(mod, item)
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
		return cached.records
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

	local projected_records = {}
	local used_labels = {}

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

		local display_name = type(comparing_stat.display_name) == "string" and comparing_stat.display_name or type(comparing_stat.name) == "string" and comparing_stat.name or "stat_" .. index
		local label = unique_weapon_modifier_label(localized_weapon_modifier_label(mod, display_name), used_labels)

		projected_records[target_index] = {
			display_name = display_name,
			title = label,
			value = math.floor(value + 0.5),
		}
	end

	QUICK_LOOK_CARD_PROJECTED_VALUES_CACHE[item] = {
		current_expertise = current_expertise,
		maximum_expertise = maximum_expertise,
		records = projected_records,
	}

	return projected_records
end

local function populate_weapon_modifier_content(mod, content, item)
	content.better_inventory_weapon_modifier_lowest_index = nil

	for index = 1, 5 do
		content[WEAPON_MODIFIER_TITLE_PREFIX .. index] = ""
		content[WEAPON_MODIFIER_VALUE_PREFIX .. index] = ""
	end

	local records = projected_weapon_modifier_records(mod, item)

	if not records then
		return
	end

	local first_value
	local lowest_value
	local lowest_index
	local all_same = true

	for index = 1, 5 do
		local record = records[index]

		if record then
			content[WEAPON_MODIFIER_TITLE_PREFIX .. index] = record.title
			content[WEAPON_MODIFIER_VALUE_PREFIX .. index] = tostring(record.value)

			if first_value == nil then
				first_value = record.value
			elseif record.value ~= first_value then
				all_same = false
			end

			if lowest_value == nil or record.value < lowest_value then
				lowest_value = record.value
				lowest_index = index
			end
		end
	end

	if not all_same then
		content.better_inventory_weapon_modifier_lowest_index = lowest_index
	end
end

local function quick_look_card_lowest_stat_text(mod, content, parenthesized)
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

	local projected_records = projected_weapon_modifier_records(mod, item)

	if not projected_records then
		return
	end

	local lowest_title
	local lowest_value
	local first_value
	local all_same = true
	local valid_count = 0

	for index = 1, 5 do
		local record = projected_records[index]
		local quick_look_card_title = content["qlc_stats_title_" .. index]
		local title = type(quick_look_card_title) == "string" and quick_look_card_title ~= "" and compact_weapon_modifier_label(quick_look_card_title) or record and record.title
		local numeric_value = record and record.value

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

local function localized_item_name(item, fallback)
	local localization_id = item and item.display_name
	local localize = rawget(_G, "Localize")

	if type(localization_id) == "string" and type(localize) == "function" then
		local ok, value = pcall(localize, localization_id)

		if ok and type(value) == "string" and value ~= "" then
			return value
		end
	end

	return fallback
end

local function append_weapon_mark(content, item)
	local display_name = content and content.display_name
	local mark_ok, mark_name = pcall(Items.weapon_lore_mark_name, item)

	mark_name = mark_ok and mark_name or nil

	if not valid_weapon_name_part(display_name) or not valid_weapon_name_part(mark_name) then
		return false
	end

	local suffix = " " .. mark_name
	local base_name = display_name

	if #display_name > #suffix and string.sub(display_name, -#suffix) == suffix then
		base_name = string.sub(display_name, 1, #display_name - #suffix)
	else
		content.display_name = display_name .. suffix
	end

	content.better_inventory_display_name_base = base_name
	content.better_inventory_display_name_suffix = suffix

	return true
end

local function format_item_name(mod, widget, element, append_mark_to_name, force_weapon_name_single_line)
	local content = widget and widget.content

	if not content then
		return
	end

	content.better_inventory_display_name_base = nil
	content.better_inventory_display_name_suffix = nil
	content.better_inventory_name_it_curio_title = nil
	content.better_inventory_name_it_curio_name_text = nil
	content.better_inventory_name_it_curio_full_name = nil
	content.better_inventory_fitted_name_it_curio_name = nil
	content.better_inventory_name_it_curio_source_name = nil

	element = element or content.element

	local item = element and (element.real_item or element.item)
	local customization = item_customization(mod, item)
	local internal_name = customization and customization.name
	local internal_name_target = customization and customization.name_target
	local external_name = fallback_name_it_name(mod, item, false)
	local external_sub_name = fallback_name_it_name(mod, item, true)
	local preserve_custom_mark = append_mark_to_name and force_weapon_name_single_line

	if is_curio(item) then
		content.display_name = external_name or internal_name or localized_item_name(item, content.display_name)
		content.better_inventory_name_it_curio_title = setting(mod, "curio_display_profile", "detailed") == "detailed" and setting(mod, "name_it_force_curio_name_in_detailed_mode", true)
		content.better_inventory_name_it_curio_name_text = content.display_name
		content.better_inventory_name_it_curio_source_name = content.display_name

		return
	end

	if not is_weapon(item) then
		return
	end

	if type(internal_name) == "string" and internal_name ~= "" then
		if internal_name_target == "sub" then
			local family_ok, family_name = pcall(Items.weapon_lore_family_name, item)

			if family_ok and valid_weapon_name_part(family_name) then
				content.display_name = family_name
			end

			content.sub_display_name = internal_name

			if preserve_custom_mark then
				append_weapon_mark(content, item)
			end

			return
		end

		content.display_name = internal_name
		content.sub_display_name = ""

		if preserve_custom_mark then
			append_weapon_mark(content, item)
		end

		return
	end

	if external_name then
		content.display_name = external_name
		content.sub_display_name = ""

		if preserve_custom_mark then
			append_weapon_mark(content, item)
		end

		return
	elseif external_sub_name then
		local family_ok, family_name = pcall(Items.weapon_lore_family_name, item)

		if family_ok and valid_weapon_name_part(family_name) then
			content.display_name = family_name
		end

		content.sub_display_name = external_sub_name

		if preserve_custom_mark then
			append_weapon_mark(content, item)
		end

		return
	end

	local family_ok, family_name = pcall(Items.weapon_lore_family_name, item)

	if family_ok and valid_weapon_name_part(family_name) then
		content.display_name = family_name
	end

	if not append_mark_to_name then
		return
	end

	if not append_weapon_mark(content, item) then
		return
	end

	local pattern_ok, pattern_name = pcall(Items.weapon_lore_pattern_name, item)

	pattern_name = pattern_ok and pattern_name or nil

	content.sub_display_name = valid_weapon_name_part(pattern_name) and pattern_name or ""
end

local function apply_custom_color(style, color, field_name)
	if type(style) ~= "table" or type(style[field_name]) ~= "table" then
		return
	end

	local backup_id = "better_inventory_original_" .. field_name

	style[backup_id] = style[backup_id] or table.clone(style[field_name])
	style[field_name] = table.clone(type(color) == "table" and color or style[backup_id])
end

local function restore_custom_color(style, field_name)
	if type(style) ~= "table" then
		return
	end

	local backup_id = "better_inventory_original_" .. field_name
	local original_color = style[backup_id]

	if type(original_color) == "table" then
		style[field_name] = table.clone(original_color)
		style[backup_id] = nil
	end
end

local function restore_item_customization_style(widget)
	local style = widget and widget.style

	if type(style) ~= "table" then
		return
	end

	for _, style_id in ipairs({ "display_name", "better_inventory_name_it_curio_name" }) do
		local text_style = style[style_id]

		restore_custom_color(text_style, "text_color")
		restore_custom_color(text_style, "default_color")
		restore_custom_color(text_style, "hover_color")
	end

	restore_custom_color(style.background, "color")
	restore_custom_color(style.background_gradient, "color")
	restore_custom_color(style.rarity_tag, "color")
end

local function apply_item_customization_style(mod, widget, element)
	local content = widget and widget.content
	local style = widget and widget.style
	local item = item_from_element(element or content and content.element)
	local customization = item_customization(mod, item)
	local name_color = customization and customization.name_color
	local background_color = customization and customization.background_color
	local preserve_shading = customization and customization.background_preserve_shading

	if not style then
		return
	end

	for _, style_id in ipairs({ "display_name", "better_inventory_name_it_curio_name" }) do
		local text_style = style[style_id]

		apply_custom_color(text_style, name_color, "text_color")
		apply_custom_color(text_style, name_color, "default_color")
		apply_custom_color(text_style, name_color, "hover_color")
	end

	if preserve_shading == nil then
		preserve_shading = setting(mod, "custom_item_preserve_card_shading", true)
	end

	-- Darktide composes equipment cards from a fixed dark base plus a colored
	-- gradient. Preserve that base by default; the per-item flag can opt back
	-- into the former full-card paint behavior.
	apply_custom_color(style.background, background_color and not preserve_shading and background_color or nil, "color")
	apply_custom_color(style.background_gradient, background_color, "color")
	apply_custom_color(style.rarity_tag, background_color, "color")
end

local function synchronize_rarity_tag_color(widget, element)
	local content = widget and widget.content
	local style = widget and widget.style
	local rarity_tag = style and style.rarity_tag

	if not rarity_tag then
		return
	end

	local item = item_from_element(element or content and content.element)
	local rarity_color

	if item then
		local ok, resolved_color = pcall(Items.rarity_color, item)
		rarity_color = ok and resolved_color or nil
	end

	if type(rarity_color) == "table" then
		rarity_tag.color = table.clone(rarity_color)
		rarity_tag.better_inventory_original_color = table.clone(rarity_color)
	elseif rarity_tag.default_color then
		rarity_tag.color = table.clone(rarity_tag.default_color)
		rarity_tag.better_inventory_original_color = table.clone(rarity_tag.default_color)
	end
end

Content.synchronize_rarity_tag_color = synchronize_rarity_tag_color

Content.apply_item_customization_style = apply_item_customization_style

Content.restore_item_customization_style = restore_item_customization_style

-- The weapon-information panel already composites its rarity tint through a
-- vertical gradient over Darktide's dark terminal background. Only replace
-- that tint (and, independently, the rarity keyword) so the native shading is
-- retained regardless of the card's per-item flat/shaded preference.
Content.apply_weapon_information_customization = function(mod, weapon_stats, item)
	local customization = item_customization(mod, item)
	local name_color = customization and customization.name_color
	local background_color = customization and customization.background_color
	local information_color = setting(mod, "custom_item_override_weapon_information_color", true) and background_color or nil
	local rarity_keyword_color = setting(mod, "custom_item_override_weapon_rarity_keyword_color", true) and background_color or nil
	local information_name_color = setting(mod, "custom_item_override_weapon_information_name_color", true) and name_color or nil
	local widgets = weapon_stats and weapon_stats._grid_widgets
	local widgets_by_name = weapon_stats and weapon_stats._widgets_by_name
	local title_widget = widgets_by_name and widgets_by_name.grid_divider_top_weapon
	local title_style = title_widget and title_widget.style and title_widget.style.weapon_display_name
	local applied = false

	if title_style then
		apply_custom_color(title_style, information_name_color, "text_color")

		if customization and type(customization.name) == "string" and customization.name ~= "" and customization.name_target ~= "sub" and title_widget.content then
			title_widget.content.weapon_display_name = customization.name
		end

		applied = true
	end

	if type(widgets) ~= "table" then
		return applied
	end

	for index = 1, #widgets do
		local widget = widgets[index]
		local style = widget and widget.style

		if style and (style.gradient_background or style.rarity_name) then
			apply_custom_color(style.gradient_background, information_color, "color")
			apply_custom_color(style.rarity_name, rarity_keyword_color, "text_color")

			if customization and customization.name_target == "sub" and type(customization.name) == "string" and customization.name ~= "" and widget.content and style.sub_display_name then
				widget.content.sub_display_name = customization.name
			end

			applied = true
		end
	end

	return applied
end

-- Re-run the same formatting path used when a card is initialized. This is
-- also used by the customization editor to update already-created loadout
-- widgets (notably the character overview hidden beneath InventoryWeaponsView)
-- without forcing the player to close and reopen the view.
Content.refresh_item_customization = function(mod, widget, element)
	if not widget then
		return false
	end

	element = element or widget.content and widget.content.element
	format_item_name(mod, widget, element, setting(mod, "append_mark_to_name", true), setting(mod, "force_weapon_name_single_line", true))
	apply_item_customization_style(mod, widget, element)

	return true
end

local function add_quick_look_card_grid_pass(mod, pass_template, card_width, text_left, position, bottom_offset)
	local font_size = numeric_setting(mod, "quick_look_card_grid_font_size", 13, 8, 20)
	local bottom_padding = numeric_setting(mod, "quick_look_card_grid_bottom_padding", 26, 20, 60)
	local lowest_modifier_color = configured_text_color(mod, "weapon_modifier_lowest_color", QUICK_LOOK_CARD_HIGHLIGHT_COLOR, "weapon_modifier_lowest_color_opacity", 80)
	local parenthesized = position ~= "above_power"
	local label_width = math.max(64, math.floor(font_size * 6 + 0.5))
	local style = {
		font_type = "machine_medium",
		font_size = font_size,
		text_color = lowest_modifier_color,
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
			-(bottom_padding + (bottom_offset or 0)),
			12,
		}
		style.size = {
			card_width - 16,
			font_size + 4,
		}
	end

	local pass = pass_by_style_id(pass_template, QUICK_LOOK_CARD_DUMP_STAT_ID) or {}

	pass.pass_type = "text"
	pass.style_id = QUICK_LOOK_CARD_DUMP_STAT_ID
	pass.value = ""
	pass.value_id = QUICK_LOOK_CARD_DUMP_STAT_ID
	pass.style = style
	pass.visibility_function = function(content)
		if not content then
			return false
		end

		-- A visibility pass runs for every card on every draw. Modifier
		-- projection and label assembly are item-data work, so resolve them once
		-- and invalidate only when the widget is rebound by populate_card_content.
		if content.better_inventory_quick_look_card_dump_stat_visibility_resolved ~= true or content.better_inventory_quick_look_card_dump_stat_parenthesized ~= parenthesized then
			content[QUICK_LOOK_CARD_DUMP_STAT_ID] = quick_look_card_lowest_stat_text(mod, content, parenthesized) or ""
			content.better_inventory_quick_look_card_dump_stat_visibility_resolved = true
			content.better_inventory_quick_look_card_dump_stat_parenthesized = parenthesized
		end

		return content[QUICK_LOOK_CARD_DUMP_STAT_ID] ~= ""
	end

	if not pass_by_style_id(pass_template, QUICK_LOOK_CARD_DUMP_STAT_ID) then
		pass_template[#pass_template + 1] = pass
	end

	return label_width
end

Content.GLOBAL_STORE_CHARACTER_PHOTO_BASE_SIZE = GLOBAL_STORE_CHARACTER_PHOTO_BASE_SIZE
Content.GLOBAL_STORE_CHARACTER_PHOTO_MIN_PERCENT = GLOBAL_STORE_CHARACTER_PHOTO_MIN_PERCENT
Content.GLOBAL_STORE_CHARACTER_PHOTO_DEFAULT_PERCENT = GLOBAL_STORE_CHARACTER_PHOTO_DEFAULT_PERCENT
Content.GLOBAL_STORE_CHARACTER_PHOTO_MAX_PERCENT = GLOBAL_STORE_CHARACTER_PHOTO_MAX_PERCENT
Content.GLOBAL_STORE_CHARACTER_ROW_HEIGHT = GLOBAL_STORE_CHARACTER_ROW_HEIGHT
Content.GLOBAL_STORE_CHARACTER_INFO_GAP_DEFAULT = GLOBAL_STORE_CHARACTER_INFO_GAP_DEFAULT
Content.GLOBAL_STORE_CHARACTER_INFO_GAP_MIN = GLOBAL_STORE_CHARACTER_INFO_GAP_MIN
Content.GLOBAL_STORE_CHARACTER_INFO_GAP_MAX = GLOBAL_STORE_CHARACTER_INFO_GAP_MAX
Content.GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_DEFAULT = GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_DEFAULT
Content.GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_MIN = GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_MIN
Content.GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_MAX = GLOBAL_STORE_CHARACTER_CLASS_ICON_SIZE_MAX
Content.GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_DEFAULT = GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_DEFAULT
Content.GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_MIN = GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_MIN
Content.GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_MAX = GLOBAL_STORE_CHARACTER_NAME_FONT_SIZE_MAX
Content.GLOBAL_STORE_CHARACTER_NAME_FIT_SAFETY_MARGIN = GLOBAL_STORE_CHARACTER_NAME_FIT_SAFETY_MARGIN
Content.GLOBAL_STORE_PRICE_ROW_PADDING_DEFAULT = GLOBAL_STORE_PRICE_ROW_PADDING_DEFAULT
Content.GLOBAL_STORE_PRICE_ROW_PADDING_MIN = GLOBAL_STORE_PRICE_ROW_PADDING_MIN
Content.GLOBAL_STORE_PRICE_ROW_PADDING_MAX = GLOBAL_STORE_PRICE_ROW_PADDING_MAX
Content.NATIVE_SINGLE_COLUMN_CONTENT_GAP = NATIVE_SINGLE_COLUMN_CONTENT_GAP
Content.CURIO_NAME_LINE_GAP = CURIO_NAME_LINE_GAP
Content.COLUMN_SETTING_BY_SLOT = COLUMN_SETTING_BY_SLOT
Content.WEAPON_PERK_COUNT = WEAPON_PERK_COUNT
Content.WEAPON_BLESSING_COUNT = WEAPON_BLESSING_COUNT
Content.BLESSING_TEXT_WIDTH_SAFETY_MARGIN = BLESSING_TEXT_WIDTH_SAFETY_MARGIN
Content.MINIMUM_AUTO_FIT_BLESSING_FONT_SIZE = MINIMUM_AUTO_FIT_BLESSING_FONT_SIZE
Content.QUICK_LOOK_CARD_DUMP_STAT_ID = QUICK_LOOK_CARD_DUMP_STAT_ID
Content.WEAPON_MODIFIER_TITLE_PREFIX = WEAPON_MODIFIER_TITLE_PREFIX
Content.WEAPON_MODIFIER_VALUE_PREFIX = WEAPON_MODIFIER_VALUE_PREFIX
Content.QUICK_LOOK_CARD_HIGHLIGHT_COLOR = QUICK_LOOK_CARD_HIGHLIGHT_COLOR
Content.QUICK_LOOK_CARD_BASE_STATS_POSITION_MAP = QUICK_LOOK_CARD_BASE_STATS_POSITION_MAP
Content.WEAPON_MODIFIER_TITLE_COLOR = WEAPON_MODIFIER_TITLE_COLOR
Content.WEAPON_MODIFIER_VALUE_COLOR = WEAPON_MODIFIER_VALUE_COLOR
Content.CURIO_PRIMARY_COLOR_DEFINITIONS = CURIO_PRIMARY_COLOR_DEFINITIONS
Content.COMPACT_CURIO_LABELS = COMPACT_CURIO_LABELS
Content.COMPACT_WEAPON_PERK_LABELS = COMPACT_WEAPON_PERK_LABELS
Content.CURIO_STAT_SIMPLIFICATIONS = CURIO_STAT_SIMPLIFICATIONS
Content.DEFAULT_CURIO_PRIMARY_COLOR = DEFAULT_CURIO_PRIMARY_COLOR
Content.DEFAULT_CURIO_SECONDARY_COLOR = DEFAULT_CURIO_SECONDARY_COLOR
Content.DEFAULT_WEAPON_PERK_COLOR = DEFAULT_WEAPON_PERK_COLOR
Content.DEFAULT_WEAPON_BLESSING_TEXT_COLOR = DEFAULT_WEAPON_BLESSING_TEXT_COLOR
Content.DEFAULT_ARMOURY_ITEM_LEVEL_COLOR = DEFAULT_ARMOURY_ITEM_LEVEL_COLOR
Content.SLOT_SETTING_BY_NAME = SLOT_SETTING_BY_NAME
Content.global_store_character_photo_percent = global_store_character_photo_percent
Content.global_store_character_photo_size = global_store_character_photo_size
Content.global_store_price_row_padding = global_store_price_row_padding
Content.global_store_character_info_gap = global_store_character_info_gap
Content.global_store_character_class_icon_size = global_store_character_class_icon_size
Content.global_store_character_name_font_size = global_store_character_name_font_size
Content.global_store_extra_height = global_store_extra_height
Content.columns = columns
Content.setting = setting
Content.enabled_name_it_mod = enabled_name_it_mod
Content.fallback_name_it_name = fallback_name_it_name
Content.name_it_curio_title_enabled = name_it_curio_title_enabled
Content.curio_name_font_size = curio_name_font_size
Content.curio_name_title_height = curio_name_title_height
Content.item_customization = item_customization
Content.numeric_setting = numeric_setting
Content.curio_primary_font_size = curio_primary_font_size
Content.curio_secondary_font_size = curio_secondary_font_size
Content.curio_primary_secondary_spacing = curio_primary_secondary_spacing
Content.blessing_icon_size = blessing_icon_size
Content.weapon_blessing_display_mode = weapon_blessing_display_mode
Content.separate_blessing_text_and_item_level = separate_blessing_text_and_item_level
Content.blessing_rank_name = blessing_rank_name
Content.weapon_perk_rank_icon_size = weapon_perk_rank_icon_size
Content.item_from_element = item_from_element
Content.item_from_content = item_from_content
Content.is_curio = is_curio
Content.is_weapon = is_weapon
Content.clamped_color_channel = clamped_color_channel
Content.curio_primary_color = curio_primary_color
Content.compact_curio_description = compact_curio_description
Content.configured_text_color = configured_text_color
Content.single_line_text = single_line_text
Content.compact_weapon_perk_description = compact_weapon_perk_description
Content.leading_plus_sign_description = leading_plus_sign_description
Content.simplified_curio_description = simplified_curio_description
Content.pass_by_style_id = pass_by_style_id
Content.is_quick_look_card_pass = is_quick_look_card_pass
Content.has_quick_look_card_passes = has_quick_look_card_passes
Content.quick_look_card_stat_kind_and_index = quick_look_card_stat_kind_and_index
Content.weapon_modifier_pass_kind_and_index = weapon_modifier_pass_kind_and_index
Content.fallback_weapon_modifier_label = fallback_weapon_modifier_label
Content.compact_weapon_modifier_label = compact_weapon_modifier_label
Content.localized_weapon_modifier_label = localized_weapon_modifier_label
Content.unique_weapon_modifier_label = unique_weapon_modifier_label
Content.projected_weapon_modifier_records = projected_weapon_modifier_records
Content.populate_weapon_modifier_content = populate_weapon_modifier_content
Content.quick_look_card_lowest_stat_text = quick_look_card_lowest_stat_text
Content.quick_look_card_grid_position = quick_look_card_grid_position
Content.add_quick_look_card_grid_pass = add_quick_look_card_grid_pass
Content.grid_ui_renderer = grid_ui_renderer
Content.valid_weapon_name_part = valid_weapon_name_part
Content.localized_item_name = localized_item_name
Content.format_item_name = format_item_name
Content.apply_custom_color = apply_custom_color
Content.restore_custom_color = restore_custom_color
Content.restore_item_customization_style = restore_item_customization_style
Content.apply_item_customization_style = apply_item_customization_style
Content.synchronize_rarity_tag_color = synchronize_rarity_tag_color

return Content
