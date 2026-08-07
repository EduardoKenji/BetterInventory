local Registry = {}

-- Keep dependency refresh ownership in one declarative table while the larger
-- predicate extraction remains staged. Character-slot settings are handled by
-- the automatic_curio_ prefix because their count follows native capacity.
local DEPENDENCY_REFRESH_SETTING_IDS = {
	"enable_grid_layout",
	"melee_columns",
	"ranged_columns",
	"curio_columns",
	"automatic_card_height",
	"expand_inventory_window",
	"weapon_extra_width_column_threshold",
	"expand_curio_inventory_window",
	"enable_hadron_single_column_mirror",
	"enable_armoury_requisition_grid",
	"enable_armoury_single_column_mirror",
	"enable_armoury_requisition_sorting_panel",
	"brighten_armoury_item_levels",
	"three_column_weapon_name_font_size",
	"expand_armoury_requisition_window",
	"debug_expand_armoury_requisition_window_30_percent",
	"enable_global_store_integration",
	"enable_global_store_grid",
	"enable_global_store_sorting_panel",
	"global_store_character_photo_size_percent",
	"global_store_price_row_padding",
	"global_store_character_info_gap",
	"global_store_character_class_icon_size",
	"global_store_character_name_font_size",
	"global_store_compact_character_names",
	"global_store_single_column_modifier_horizontal_position",
	"global_store_single_column_modifier_vertical_position",
	"enable_character_overview_melee_mirror",
	"enable_character_overview_ranged_mirror",
	"enable_character_overview_curio_details",
	"character_overview_show_melee_rarity_strip",
	"character_overview_show_ranged_rarity_strip",
	"character_overview_show_curio_rarity_strip",
	"character_overview_use_native_curio_overlay",
	"character_overview_curio_name_mode",
	"weapon_blessing_display_mode",
	"show_weapon_perks",
	"show_weapon_perk_rank_symbols",
	"single_column_blessing_icons_on_right",
	"curio_display_profile",
	"enable_inventory_options_panel_prototype",
	"enable_lantern_inventory_section",
	"keep_lantern_curio_panel_separate",
	"enable_experimental_quick_discard",
	"quick_discard_mode",
	"quick_discard_protect_high_level_curios",
	"enable_automatic_curio_acquisition",
	"enable_quick_look_card_single_column_integration",
	"enable_quick_look_card_grid_integration",
	"quick_look_card_grid_stat_position",
	"enable_custom_item_name_and_colors",
}

local dependency_refresh_metadata = {}

for _, setting_id in ipairs(DEPENDENCY_REFRESH_SETTING_IDS) do
	dependency_refresh_metadata[setting_id] = {
		refresh_domains = {
			dependencies = true,
		},
	}
end

local active_ids = {}
local active_entries = {}
local duplicate_ids = {}
local active_count = 0

local function collect_setting_entries(entries)
	for _, entry in ipairs(entries or {}) do
		if type(entry) == "table" then
			local setting_id = entry.setting_id

			if type(setting_id) == "string" and setting_id ~= "" then
				if active_ids[setting_id] then
					duplicate_ids[#duplicate_ids + 1] = setting_id
				else
					active_ids[setting_id] = true
					active_count = active_count + 1
					active_entries[setting_id] = {
						setting_id = setting_id,
						refresh_domains = dependency_refresh_metadata[setting_id] and {
							dependencies = true,
						},
					}
				end
			end

			collect_setting_entries(entry.sub_widgets)
		end
	end
end

Registry.register = function(settings)
	active_ids = {}
	active_entries = {}
	duplicate_ids = {}
	active_count = 0
	collect_setting_entries(settings)

	return #duplicate_ids == 0, active_count, duplicate_ids
end

Registry.has = function(setting_id)
	return type(setting_id) == "string" and active_ids[setting_id] == true
end

Registry.count = function()
	return active_count
end

Registry.duplicates = function()
	return duplicate_ids
end

Registry.metadata = function(setting_id)
	return type(setting_id) == "string" and active_entries[setting_id] or nil
end

Registry.should_refresh_dependencies = function(setting_id)
	if type(setting_id) ~= "string" then
		return false
	end

	-- Setting notifications can arrive before DMF has exposed the options tree.
	-- Keep the historical conservative refresh until registration is complete.
	if active_count == 0 then
		return true
	end

	local entry = active_entries[setting_id]

	if not entry then
		return false
	end

	if entry.refresh_domains and entry.refresh_domains.dependencies then
		return true
	end

	return string.sub(setting_id, 1, 16) == "automatic_curio_"
end

return Registry
