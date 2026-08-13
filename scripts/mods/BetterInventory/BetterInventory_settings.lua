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
	"character_overview_show_only_dump_stat",
	"character_overview_dump_stat_horizontal_offset",
	"character_overview_dump_stat_font_scale_percent",
	"character_overview_dump_stat_color_preset",
	"character_overview_dump_stat_color_r",
	"character_overview_dump_stat_color_g",
	"character_overview_dump_stat_color_b",
	"character_overview_show_curio_rarity_strip",
	"character_overview_use_native_curio_overlay",
	"character_overview_curio_name_mode",
	"weapon_blessing_display_mode",
	"show_weapon_perks",
	"show_weapon_perk_rank_symbols",
	"highlight_equipped_items",
	"new_item_highlight_mode",
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
	"auto_crafter_level_mastery_20",
	"auto_crafter_reuse_inventory_base",
	"auto_crafter_include_favorite_inventory_bases",
	"auto_crafter_craft_duplicate_completed_queued_weapons",
	"auto_crafter_defer_bad_weapon_processing",
	"auto_crafter_allocate_mastery_points",
	"auto_crafter_change_perks",
	"auto_crafter_change_blessings",
	"auto_crafter_show_status_hud",
}

local dependency_refresh_metadata = {}

for _, setting_id in ipairs(DEPENDENCY_REFRESH_SETTING_IDS) do
	dependency_refresh_metadata[setting_id] = {
		refresh_domains = {
			dependencies = true,
		},
	}
end

-- Migration markers are intentionally declared once here so a setting's
-- schema entry, runtime owner, and migration contract can be audited together.
-- `false` in the generated metadata means "no migration required"; it is not
-- the same as an omitted field.
local MIGRATION_KEYS = {
	melee_columns = "_grid_columns_v1_migrated",
	ranged_columns = "_grid_columns_v1_migrated",
	curio_columns = "_grid_columns_v1_migrated",
	show_pattern_mark = "_compact_card_defaults_v1_migrated",
	character_overview_curio_name_mode = "_character_overview_curio_name_mode_v1_migrated",
	curio_display_profile = "_curio_compression_mode_v1_migrated",
	show_curio_item_level = "_curio_heavy_default_v1_migrated",
	custom_item_name_keybind = "_custom_item_name_keybind_v2_migrated",
	weapon_blessing_display_mode = "_weapon_blessing_display_mode_v1_migrated",
	highlight_equipped_items = "_equipped_highlight_mode_v1_migrated",
}

local function setting_owner(setting_id)
	local owners = {
		"automatic_curio_", "curio_acquisition",
		"quick_discard_", "discard",
		"character_overview_", "character_overview",
		"global_store_", "global_store",
		"armoury_", "armoury",
		"custom_item_", "customization",
		"weapon_", "weapons",
		"blessing_", "weapons",
		"curio_", "curios",
		"equipped_highlight_", "markers",
		"new_item_highlight_", "markers",
		"new_item_acknowledge_", "markers",
		"myfavorites_", "markers",
		"debug_", "diagnostics",
	}

	for index = 1, #owners, 2 do
		if string.sub(setting_id, 1, #owners[index]) == owners[index] then
			return owners[index + 1]
		end
	end

	if string.find(setting_id, "columns", 1, true) or string.find(setting_id, "inventory", 1, true) then
		return "inventory"
	end

	return "general"
end

local function metadata_for_entry(entry)
	local setting_id = entry.setting_id
	local refresh_domains = dependency_refresh_metadata[setting_id] and {
		dependencies = true,
	}

	return {
		default_value = entry.default_value,
		migration_key = MIGRATION_KEYS[setting_id] or false,
		owner = setting_owner(setting_id),
		refresh_domains = refresh_domains,
		setting_id = setting_id,
		test_id = "settings:" .. setting_id,
		title_id = entry.text or setting_id,
		tooltip_id = entry.tooltip or false,
		type = entry.type or "",
		visibility = refresh_domains and "runtime_dependency" or "always",
	}
end

local active_ids = {}
local active_entries = {}
local duplicate_ids = {}
local duplicate_id_set = {}
local metadata_issues = {}
local active_count = 0

local function collect_setting_entries(entries, category_name, parent_owned)
	for _, entry in ipairs(entries or {}) do
		if type(entry) == "table" then
			local entry_owned = category_name == nil

			if category_name ~= nil then
				if entry.category ~= nil then
					entry_owned = entry.category == category_name
				else
					entry_owned = parent_owned == true
				end
			end

			local setting_id = entry.setting_id

			if entry_owned and type(setting_id) == "string" and setting_id ~= "" then
				if active_ids[setting_id] then
					if not duplicate_id_set[setting_id] then
						duplicate_id_set[setting_id] = true
						duplicate_ids[#duplicate_ids + 1] = setting_id
					end
				else
					active_ids[setting_id] = true
					active_count = active_count + 1
					local metadata = metadata_for_entry(entry)
					active_entries[setting_id] = metadata

					if metadata.title_id == false then
						metadata_issues[#metadata_issues + 1] = setting_id .. ":title_id"
					end

					if metadata.type == "" then
						metadata_issues[#metadata_issues + 1] = setting_id .. ":type"
					end
				end
			end

			collect_setting_entries(entry.sub_widgets, category_name, entry_owned)
		end
	end
end

-- The runtime reaches these entry points through the guarded capability
-- adapter, which binds the registry table as `self`. Keep direct calls used by
-- tooling/tests compatible as well so the registry has one safe public API.
Registry.register = function(registry_or_settings, bound_settings, bound_category_name)
	local called_as_method = registry_or_settings == Registry
	local settings = registry_or_settings
	local category_name = bound_settings

	if called_as_method then
		settings = bound_settings
		category_name = bound_category_name
	end

	active_ids = {}
	active_entries = {}
	duplicate_ids = {}
	duplicate_id_set = {}
	metadata_issues = {}
	active_count = 0
	collect_setting_entries(settings, category_name, false)

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

Registry.metadata_manifest = function()
	local manifest = {}

	for _, metadata in pairs(active_entries) do
		manifest[#manifest + 1] = metadata
	end

	table.sort(manifest, function(left, right)
		return left.setting_id < right.setting_id
	end)

	return manifest
end

Registry.audit = function(localization)
	local orphan_metadata = {}
	local missing_localization = {}
	local unregistered_active_settings = {}

	for setting_id in pairs(MIGRATION_KEYS) do
		if not active_ids[setting_id] then
			orphan_metadata[#orphan_metadata + 1] = setting_id
		end
	end

	table.sort(orphan_metadata)

	if type(localization) == "table" then
		for setting_id, metadata in pairs(active_entries) do
			if metadata.title_id ~= false and localization[metadata.title_id] == nil then
				missing_localization[#missing_localization + 1] = setting_id .. ":title_id=" .. tostring(metadata.title_id)
			end

			if metadata.tooltip_id ~= false and localization[metadata.tooltip_id] == nil then
				missing_localization[#missing_localization + 1] = setting_id .. ":tooltip_id=" .. tostring(metadata.tooltip_id)
			end
		end
	end

	table.sort(metadata_issues)
	table.sort(missing_localization)

	for index = 1, #metadata_issues do
		unregistered_active_settings[#unregistered_active_settings + 1] = metadata_issues[index]
	end

	for index = 1, #missing_localization do
		unregistered_active_settings[#unregistered_active_settings + 1] = missing_localization[index]
	end

	table.sort(unregistered_active_settings)

	return {
		active_count = active_count,
		duplicate_ids = duplicate_ids,
		metadata_issues = metadata_issues,
		missing_localization = missing_localization,
		orphan_metadata = orphan_metadata,
		unregistered_active_settings = unregistered_active_settings,
	}
end

Registry.is_visible = function(setting_id, context)
	local metadata = Registry.metadata(setting_id)

	if not metadata then
		return false
	end

	if metadata.visibility == "always" then
		return true
	end

	if metadata.visibility == "runtime_dependency" then
		return type(context) ~= "table" or context.dependencies_enabled ~= false
	end

	return false
end

Registry.should_refresh_dependencies = function(registry_or_setting_id, bound_setting_id)
	local setting_id = registry_or_setting_id == Registry and bound_setting_id or registry_or_setting_id

	if type(setting_id) ~= "string" then
		return false
	end

	-- Setting notifications can arrive before DMF has exposed the options tree.
	-- Keep the historical conservative refresh until registration is complete.
	if active_count == 0 then
		return true
	end

	-- Refresh ownership is declarative and must not depend on the most recent
	-- rendered UI snapshot. Optional settings extensions may clone, omit, or
	-- rewrite templates without changing which BetterInventory settings own
	-- dependency state.
	if dependency_refresh_metadata[setting_id] then
		return true
	end

	return string.sub(setting_id, 1, 16) == "automatic_curio_"
end

return Registry
