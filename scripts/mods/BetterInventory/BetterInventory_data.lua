local MOD_VERSION = "2.2.4"
local mod = get_mod("BetterInventory")
local DEFAULT_OPERATIVE_SLOT_CAPACITY = 10
local MAX_REASONABLE_OPERATIVE_SLOT_CAPACITY = 64

local function native_operative_slot_capacity()
	local success, settings = pcall(require, "scripts/ui/views/main_menu_view/main_menu_view_settings")
	local capacity = success and type(settings) == "table" and tonumber(settings.max_num_characters) or nil

	if not capacity or capacity < 1 then
		return DEFAULT_OPERATIVE_SLOT_CAPACITY
	end

	return math.min(math.floor(capacity), MAX_REASONABLE_OPERATIVE_SLOT_CAPACITY)
end

local function character_slot_setting_id(index)
	return "automatic_curio_character_slot_" .. tostring(index)
end

local function automatic_curio_character_slot_widgets()
	local widgets = {}

	for index = 1, native_operative_slot_capacity() do
		widgets[index] = {
			setting_id = character_slot_setting_id(index),
			type = "checkbox",
			default_value = false,
		}
	end

	return widgets
end

local function color_preset_options(include_mode_default)
	local options = {}

	if include_mode_default then
		options[#options + 1] = {
			text = "color_preset_mode_default",
			value = "mode_default",
		}
	end

	local presets = {
		{
			text = "color_preset_red",
			value = "red",
		},
		{
			text = "color_preset_light_blue",
			value = "light_blue",
		},
		{
			text = "color_preset_sky_blue",
			value = "sky_blue",
		},
		{
			text = "color_preset_purple",
			value = "purple",
		},
		{
			text = "color_preset_pink",
			value = "pink",
		},
		{
			text = "color_preset_orange",
			value = "orange",
		},
		{
			text = "color_preset_yellow",
			value = "yellow",
		},
		{
			text = "color_preset_gold",
			value = "gold",
		},
		{
			text = "color_preset_green",
			value = "green",
		},
		{
			text = "color_preset_light_green",
			value = "light_green",
		},
		{
			text = "color_preset_terminal_green",
			value = "terminal_green",
		},
		{
			text = "color_preset_white",
			value = "white",
		},
		{
			text = "color_preset_neutral",
			value = "neutral",
		},
		{
			text = "color_preset_custom",
			value = "custom",
		},
	}

	for index = 1, #presets do
		options[#options + 1] = presets[index]
	end

	return options
end

local function color_group(group_id, prefix, default_preset, red, green, blue, include_mode_default)
	return {
		setting_id = group_id,
		type = "group",
		sub_widgets = {
			{
				setting_id = prefix .. "_preset",
				type = "dropdown",
				default_value = default_preset,
				options = color_preset_options(include_mode_default),
			},
			{
				setting_id = prefix .. "_r",
				type = "numeric",
				default_value = red,
				range = {
					0,
					255,
				},
			},
			{
				setting_id = prefix .. "_g",
				type = "numeric",
				default_value = green,
				range = {
					0,
					255,
				},
			},
			{
				setting_id = prefix .. "_b",
				type = "numeric",
				default_value = blue,
				range = {
					0,
					255,
				},
			},
		},
	}
end

local IMAGE_LAYOUT_COLUMN_PROFILES = {
	{ key = "single", text = "image_layout_single_column", value = 1 },
	{ key = "2", text = "image_layout_two_columns", value = 2 },
	{ key = "3", text = "image_layout_three_columns", value = 3 },
	{ key = "4", text = "image_layout_four_columns", value = 4 },
	{ key = "5", text = "image_layout_five_columns", value = 5 },
}

local IMAGE_LAYOUT_GRID_DEFAULTS = {
	weapon = {
		inventory = { x = -10, y = -1, width = 21, height = 0 },
		armoury = { x = -10, y = -1, width = 23, height = -10 },
		global_store = { x = -13, y = 5, width = 29, height = -8 },
	},
	curio = {
		inventory = { x = -20, y = 7, width = 38, height = 0 },
		armoury = { x = -20, y = 3, width = 36, height = -6 },
		global_store = { x = -19, y = 7, width = 35, height = -6 },
	},
}

local function image_geometry_controls(prefix, defaults)
	defaults = defaults or {}

	return {
		{
			setting_id = prefix .. "_x_offset_percent",
			text = "image_layout_x_offset_percent",
			tooltip = "image_layout_position_tooltip",
			type = "numeric",
			default_value = defaults.x or 0,
			range = { -100, 100 },
		},
		{
			setting_id = prefix .. "_y_offset_percent",
			text = "image_layout_y_offset_percent",
			tooltip = "image_layout_position_tooltip",
			type = "numeric",
			default_value = defaults.y or 0,
			range = { -100, 100 },
		},
		{
			setting_id = prefix .. "_width_offset_percent",
			text = "image_layout_width_offset_percent",
			tooltip = "image_layout_size_tooltip",
			type = "numeric",
			default_value = defaults.width or 0,
			range = { -90, 200 },
		},
		{
			setting_id = prefix .. "_height_offset_percent",
			text = "image_layout_height_offset_percent",
			tooltip = "image_layout_size_tooltip",
			type = "numeric",
			default_value = defaults.height or 0,
			range = { -90, 200 },
		},
	}
end

local function image_character_overview_group(item_kind)
	local prefix = item_kind .. "_image_character_overview"

	return {
		setting_id = prefix .. "_group",
		text = "image_layout_character_overview",
		type = "group",
		sub_widgets = image_geometry_controls(prefix),
	}
end

local function image_grid_context_group(item_kind, context, text_id)
	local prefix = item_kind .. "_image_" .. context
	local options = {}

	for index, profile in ipairs(IMAGE_LAYOUT_COLUMN_PROFILES) do
		options[index] = {
			text = profile.text,
			value = profile.value,
		}
	end

	local sub_widgets = {
		{
			setting_id = prefix .. "_profile_selector",
			text = "image_layout_grid_profile",
			tooltip = "image_layout_grid_profile_tooltip",
			type = "dropdown",
			default_value = 3,
			options = options,
		},
	}
	local item_defaults = IMAGE_LAYOUT_GRID_DEFAULTS[item_kind] or {}
	local editor_controls = image_geometry_controls(prefix .. "_editor", item_defaults[context])

	for _, control in ipairs(editor_controls) do
		sub_widgets[#sub_widgets + 1] = control
	end

	return {
		setting_id = prefix .. "_group",
		text = text_id,
		type = "group",
		sub_widgets = sub_widgets,
	}
end

local function image_layout_section(item_kind, section_id)
	return {
		setting_id = section_id,
		type = "group",
		sub_widgets = {
			image_character_overview_group(item_kind),
			image_grid_context_group(item_kind, "inventory", "image_layout_inventory_hadron"),
			image_grid_context_group(item_kind, "armoury", "image_layout_armoury_exchange"),
			image_grid_context_group(item_kind, "global_store", "image_layout_global_store"),
		},
	}
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	version = MOD_VERSION,
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id = "inventory_slots_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "enable_melee_inventory",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_ranged_inventory",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_curio_inventory",
						type = "checkbox",
						default_value = true,
					},
				},
			},
			{
				setting_id = "inventory_sorting_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "show_inventory_options_widget",
						tooltip = "show_inventory_options_widget_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "prioritize_equipped_favorites",
						tooltip = "prioritize_equipped_favorites_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "prioritize_perfect_roll_weapons",
						tooltip = "prioritize_perfect_roll_weapons_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "inventory_options_panel_geometry_group",
						type = "group",
						sub_widgets = {
							{
								setting_id = "enable_inventory_options_panel_prototype",
								tooltip = "enable_inventory_options_panel_prototype_tooltip",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "inventory_options_controller_focus_keybind",
								tooltip = "inventory_options_controller_focus_keybind_tooltip",
								type = "dropdown",
								default_value = "navigate_secondary_right_pressed",
								options = {
									{ text = "inventory_options_controller_focus_keybind_rt", value = "navigate_secondary_right_pressed" },
									{ text = "custom_item_editor_keybind_off", value = "off" },
								},
							},
							{
								setting_id = "curio_information_width_percent",
								tooltip = "inventory_options_geometry_reopen_tooltip",
								type = "numeric",
								default_value = 90,
								range = {75, 100},
							},
							{
								setting_id = "curio_preview_height_percent",
								tooltip = "curio_preview_height_percent_tooltip",
								type = "numeric",
								default_value = 76,
								range = {60, 100},
							},
							{
								setting_id = "inventory_options_panel_width",
								tooltip = "inventory_options_geometry_reopen_tooltip",
								type = "numeric",
								default_value = 445,
								range = {360, 560},
							},
							{
								setting_id = "inventory_options_panel_max_height",
								tooltip = "inventory_options_geometry_reopen_tooltip",
								type = "numeric",
								default_value = 360,
								range = {220, 500},
							},
							{
								setting_id = "inventory_options_panel_row_spacing",
								tooltip = "inventory_options_geometry_reopen_tooltip",
								type = "numeric",
								default_value = 8,
								range = {0, 16},
							},
							{
								setting_id = "inventory_options_panel_padding_top",
								tooltip = "inventory_options_geometry_reopen_tooltip",
								type = "numeric",
								default_value = 10,
								range = {0, 24},
							},
							{
								setting_id = "inventory_options_panel_padding_bottom",
								tooltip = "inventory_options_geometry_reopen_tooltip",
								type = "numeric",
								default_value = 10,
								range = {0, 24},
							},
							{
								setting_id = "inventory_options_panel_padding_left",
								tooltip = "inventory_options_geometry_reopen_tooltip",
								type = "numeric",
								default_value = 12,
								range = {0, 24},
							},
							{
								setting_id = "inventory_options_panel_padding_right",
								tooltip = "inventory_options_geometry_reopen_tooltip",
								type = "numeric",
								default_value = 12,
								range = {0, 24},
							},
						},
					},
				},
			},
			{
				setting_id = "experimental_quick_discard_group",
				type = "group",
					sub_widgets = {
						{
							setting_id = "enable_experimental_quick_discard",
							tooltip = "enable_experimental_quick_discard_tooltip",
							type = "checkbox",
							default_value = false,
						},
						{
							setting_id = "quick_discard_mode",
							tooltip = "quick_discard_mode_tooltip",
							type = "dropdown",
							default_value = "manual",
							options = {
								{
									text = "quick_discard_mode_manual",
									value = "manual",
								},
								{
									text = "quick_discard_mode_automatic",
									value = "automatic",
								},
							},
						},
						{
							setting_id = "quick_discard_skip_automatic_confirmation",
							tooltip = "quick_discard_skip_automatic_confirmation_tooltip",
							type = "checkbox",
							default_value = false,
						},
						{
							setting_id = "quick_discard_rarity",
						tooltip = "quick_discard_rarity_tooltip",
						type = "dropdown",
						default_value = 1,
						options = {
							{
								text = "quick_discard_rarity_1",
								value = 1,
							},
							{
								text = "quick_discard_rarity_2",
								value = 2,
							},
							{
								text = "quick_discard_rarity_3",
								value = 3,
							},
							{
								text = "quick_discard_rarity_4",
								value = 4,
							},
							{
								text = "quick_discard_rarity_5",
								value = 5,
							},
						},
					},
					{
						setting_id = "quick_discard_include_melee",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "quick_discard_include_ranged",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "quick_discard_include_curios",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "quick_discard_max_item_level",
						tooltip = "quick_discard_max_item_level_tooltip",
						type = "numeric",
						default_value = 490,
						range = {
							0,
							500,
						},
					},
					{
						setting_id = "quick_discard_protect_above_equipped_level",
						tooltip = "quick_discard_protect_above_equipped_level_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "quick_discard_protect_perfect_weapons",
						tooltip = "quick_discard_protect_perfect_weapons_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "quick_discard_protect_high_level_curios",
						tooltip = "quick_discard_protect_high_level_curios_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "quick_discard_curio_protection_level",
						tooltip = "quick_discard_curio_protection_level_tooltip",
						type = "numeric",
						default_value = 410,
						range = {
							0,
							500,
						},
					},
					{
						setting_id = "quick_discard_keep_health_curios",
						tooltip = "quick_discard_keep_curio_type_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "quick_discard_keep_toughness_curios",
						tooltip = "quick_discard_keep_curio_type_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "quick_discard_keep_wound_curios",
						tooltip = "quick_discard_keep_curio_type_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "quick_discard_keep_stamina_curios",
						tooltip = "quick_discard_keep_curio_type_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "quick_discard_show_type_breakdown",
						tooltip = "quick_discard_show_type_breakdown_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "quick_discard_show_summary_notification",
						tooltip = "quick_discard_show_summary_notification_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "quick_discard_disable_no_eligible_notification",
						tooltip = "quick_discard_disable_no_eligible_notification_tooltip",
						type = "checkbox",
						default_value = false,
					},
				},
			},
			{
				setting_id = "automatic_curio_buyer_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "enable_automatic_curio_acquisition",
						tooltip = "enable_automatic_curio_acquisition_tooltip",
						type = "checkbox",
						default_value = false,
						sub_widgets = {
							{
								setting_id = "automatic_curio_scan_operative_selection",
								tooltip = "automatic_curio_scan_operative_selection_tooltip",
								type = "checkbox",
								default_value = false,
							},
							{
								setting_id = "automatic_curio_once_per_store_rotation",
								tooltip = "automatic_curio_once_per_store_rotation_tooltip",
								type = "checkbox",
								default_value = false,
							},
							{
								setting_id = "automatic_curio_rescan_on_store_refresh",
								tooltip = "automatic_curio_rescan_on_store_refresh_tooltip",
								type = "checkbox",
								default_value = false,
							},
							{
								setting_id = "automatic_curio_min_item_level",
								tooltip = "automatic_curio_min_item_level_tooltip",
								type = "numeric",
								default_value = 410,
								range = {
									0,
									500,
								},
							},
							{
								setting_id = "automatic_curio_diagnostic_logging",
								tooltip = "automatic_curio_diagnostic_logging_tooltip",
								type = "checkbox",
								default_value = false,
							},
							{
								setting_id = "automatic_curio_disable_no_eligible_notification",
								tooltip = "automatic_curio_disable_no_eligible_notification_tooltip",
								type = "checkbox",
								default_value = false,
							},
							{
								setting_id = "automatic_curio_target_mode",
								tooltip = "automatic_curio_target_mode_tooltip",
								type = "dropdown",
								default_value = "characters",
								options = {
									{
										text = "automatic_curio_target_mode_classes",
										value = "classes",
									},
									{
										text = "automatic_curio_target_mode_characters",
										value = "characters",
									},
								},
							},
							{
								setting_id = "automatic_curio_types_group",
								type = "group",
								sub_widgets = {
									{
										setting_id = "automatic_curio_buy_health",
										type = "checkbox",
										default_value = true,
										sub_widgets = {
											{
												setting_id = "automatic_curio_min_health",
												tooltip = "automatic_curio_min_health_tooltip",
												type = "numeric",
												default_value = 21,
												range = {
													0,
													21,
												},
											},
										},
									},
									{
										setting_id = "automatic_curio_buy_toughness",
										type = "checkbox",
										default_value = true,
										sub_widgets = {
											{
												setting_id = "automatic_curio_min_toughness",
												tooltip = "automatic_curio_min_toughness_tooltip",
												type = "numeric",
												default_value = 17,
												range = {
													0,
													17,
												},
											},
										},
									},
									{
										setting_id = "automatic_curio_buy_stamina",
										type = "checkbox",
										default_value = false,
									},
									{
										setting_id = "automatic_curio_buy_wounds",
										type = "checkbox",
										default_value = false,
									},
								},
							},
							{
								setting_id = "automatic_curio_classes_group",
								type = "group",
								sub_widgets = {
									{
										setting_id = "automatic_curio_class_veteran",
										type = "checkbox",
										default_value = true,
									},
									{
										setting_id = "automatic_curio_class_zealot",
										type = "checkbox",
										default_value = true,
									},
									{
										setting_id = "automatic_curio_class_psyker",
										type = "checkbox",
										default_value = true,
									},
									{
										setting_id = "automatic_curio_class_ogryn",
										type = "checkbox",
										default_value = true,
									},
									{
										setting_id = "automatic_curio_class_adamant",
										type = "checkbox",
										default_value = true,
									},
									{
										setting_id = "automatic_curio_class_broker",
										type = "checkbox",
										default_value = true,
									},
									{
										setting_id = "automatic_curio_class_cryptic",
										type = "checkbox",
										default_value = true,
									},
								},
							},
							{
								setting_id = "automatic_curio_characters_group",
								type = "group",
								sub_widgets = automatic_curio_character_slot_widgets(),
							},
						},
					},
				},
			},
			{
				setting_id = "auto_crafter_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "auto_crafter_enable",
						tooltip = "auto_crafter_enable_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "auto_crafter_read_only_probe",
						tooltip = "auto_crafter_read_only_probe_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "auto_crafter_show_probe_notifications",
						tooltip = "auto_crafter_show_probe_notifications_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "auto_crafter_show_status_hud",
						tooltip = "auto_crafter_show_status_hud_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "auto_crafter_target_dump_stat",
						tooltip = "auto_crafter_target_dump_stat_tooltip",
						type = "dropdown",
						default_value = "damage",
						options = {
							{
								text = "auto_crafter_dump_stat_damage",
								value = "damage",
							},
							{
								text = "auto_crafter_dump_stat_mobility",
								value = "mobility",
							},
							{
								text = "auto_crafter_dump_stat_finesse",
								value = "finesse",
							},
							{
								text = "auto_crafter_dump_stat_first_target",
								value = "first_target",
							},
							{
								text = "auto_crafter_dump_stat_penetration",
								value = "penetration",
							},
							{
								text = "auto_crafter_dump_stat_defenses",
								value = "defenses",
							},
						},
					},
					{
						setting_id = "auto_crafter_dump_stat_target",
						tooltip = "auto_crafter_dump_stat_target_tooltip",
						type = "numeric",
						default_value = 60,
						range = {
							1,
							100,
						},
					},
					{
						setting_id = "auto_crafter_custom_stats",
						tooltip = "auto_crafter_custom_stats_tooltip",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "auto_crafter_custom_stat_1",
						tooltip = "auto_crafter_custom_stat_value_tooltip",
						type = "numeric",
						default_value = 76,
						range = { 60, 80 },
					},
					{
						setting_id = "auto_crafter_custom_stat_2",
						tooltip = "auto_crafter_custom_stat_value_tooltip",
						type = "numeric",
						default_value = 76,
						range = { 60, 80 },
					},
					{
						setting_id = "auto_crafter_custom_stat_3",
						tooltip = "auto_crafter_custom_stat_value_tooltip",
						type = "numeric",
						default_value = 76,
						range = { 60, 80 },
					},
					{
						setting_id = "auto_crafter_custom_stat_4",
						tooltip = "auto_crafter_custom_stat_value_tooltip",
						type = "numeric",
						default_value = 76,
						range = { 60, 80 },
					},
					{
						setting_id = "auto_crafter_custom_stat_5",
						tooltip = "auto_crafter_custom_stat_value_tooltip",
						type = "numeric",
						default_value = 76,
						range = { 60, 80 },
					},
					{
						setting_id = "auto_crafter_cap_by_dockets",
						tooltip = "auto_crafter_cap_by_dockets_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "auto_crafter_docket_cap",
						tooltip = "auto_crafter_docket_cap_tooltip",
						type = "numeric",
						default_value = 500000,
						range = {
							0,
							10000000,
						},
					},
					{
						setting_id = "auto_crafter_cap_by_max_purchases",
						tooltip = "auto_crafter_cap_by_max_purchases_tooltip",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "auto_crafter_max_purchases",
						tooltip = "auto_crafter_max_purchases_tooltip",
						type = "numeric",
						default_value = 100,
						range = {
							1,
							10000,
						},
					},
					{
						setting_id = "auto_crafter_best_candidate_fallback",
						tooltip = "auto_crafter_best_candidate_fallback_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "auto_crafter_request_mode",
						tooltip = "auto_crafter_request_mode_tooltip",
						type = "dropdown",
						default_value = "sequential",
						options = {
							{
								text = "auto_crafter_request_mode_sequential",
								value = "sequential",
							},
							{
								text = "auto_crafter_request_mode_parallel_reads",
								value = "parallel_reads",
							},
							{
								text = "auto_crafter_request_mode_experimental",
								value = "experimental_parallel_mutations",
							},
						},
					},
					{
						setting_id = "auto_crafter_workflow_group",
						type = "group",
						sub_widgets = {
							{ setting_id = "auto_crafter_favorite_result", tooltip = "auto_crafter_favorite_result_tooltip", type = "checkbox", default_value = true },
							{ setting_id = "auto_crafter_buy_until_target", tooltip = "auto_crafter_buy_until_target_tooltip", type = "checkbox", default_value = true },
							{ setting_id = "auto_crafter_defer_bad_weapon_processing", tooltip = "auto_crafter_defer_bad_weapon_processing_tooltip", type = "checkbox", default_value = true },
							{ setting_id = "auto_crafter_level_mastery_20", tooltip = "auto_crafter_level_mastery_20_tooltip", type = "checkbox", default_value = true },
							{ setting_id = "auto_crafter_allocate_mastery_points", tooltip = "auto_crafter_allocate_mastery_points_tooltip", type = "checkbox", default_value = true },
							{ setting_id = "auto_crafter_consecrate_transcendent", tooltip = "auto_crafter_consecrate_transcendent_tooltip", type = "checkbox", default_value = true },
							{ setting_id = "auto_crafter_upgrade_expertise_500", tooltip = "auto_crafter_upgrade_expertise_500_tooltip", type = "checkbox", default_value = true },
							{ setting_id = "auto_crafter_change_perks", tooltip = "auto_crafter_change_perks_tooltip", type = "checkbox", default_value = true },
							{ setting_id = "auto_crafter_change_blessings", tooltip = "auto_crafter_change_blessings_tooltip", type = "checkbox", default_value = true },
						},
					},
					{
						setting_id = "auto_crafter_resuming_group",
						type = "group",
						sub_widgets = {
							{ setting_id = "auto_crafter_reuse_inventory_base", tooltip = "auto_crafter_reuse_inventory_base_tooltip", type = "checkbox", default_value = true },
							{ setting_id = "auto_crafter_include_favorite_inventory_bases", tooltip = "auto_crafter_include_favorite_inventory_bases_tooltip", type = "checkbox", default_value = true },
							{ setting_id = "auto_crafter_craft_duplicate_completed_queued_weapons", tooltip = "auto_crafter_craft_duplicate_completed_queued_weapons_tooltip", type = "checkbox", default_value = false },
						},
					},
					{
						setting_id = "auto_crafter_trait_targets_group",
						type = "group",
						sub_widgets = {
							{ setting_id = "auto_crafter_show_perk_grid", tooltip = "auto_crafter_show_perk_grid_tooltip", type = "checkbox", default_value = true },
							{ setting_id = "auto_crafter_show_blessing_grid", tooltip = "auto_crafter_show_blessing_grid_tooltip", type = "checkbox", default_value = true },
						},
					},
				},
			},
			{
				setting_id = "additional_views_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "hadron_additional_views_group",
						type = "group",
						sub_widgets = {
							{
								setting_id = "enable_hadron_entreat_grid",
								tooltip = "enable_hadron_entreat_grid_tooltip",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "enable_hadron_single_column_mirror",
								tooltip = "enable_hadron_single_column_mirror_tooltip",
								type = "checkbox",
								default_value = true,
							},
						},
					},
					{
						setting_id = "armoury_exchange_views_group",
						type = "group",
						sub_widgets = {
							{
								setting_id = "enable_armoury_requisition_grid",
								tooltip = "enable_armoury_requisition_grid_tooltip",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "enable_armoury_single_column_mirror",
								tooltip = "enable_armoury_single_column_mirror_tooltip",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "enable_armoury_requisition_sorting_panel",
								tooltip = "enable_armoury_requisition_sorting_panel_tooltip",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "brighten_armoury_item_levels",
								tooltip = "brighten_armoury_item_levels_tooltip",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "three_column_weapon_name_font_size",
								tooltip = "three_column_weapon_name_font_size_tooltip",
								type = "numeric",
								default_value = 14,
								range = {
									10,
									20,
								},
							},
							{
								setting_id = "expand_armoury_requisition_window",
								tooltip = "expand_armoury_requisition_window_tooltip",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "armoury_requisition_target_card_width",
								tooltip = "armoury_requisition_target_card_width_tooltip",
								type = "numeric",
								default_value = 230,
								range = {
									190,
									230,
								},
							},
									},
								},
								{
									setting_id = "global_store_integration_group",
						type = "group",
						sub_widgets = {
							{
								setting_id = "enable_global_store_integration",
								tooltip = "enable_global_store_integration_tooltip",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "enable_global_store_grid",
								tooltip = "enable_global_store_grid_tooltip",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "enable_global_store_sorting_panel",
								tooltip = "enable_global_store_sorting_panel_tooltip",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "global_store_character_photo_size_percent",
								tooltip = "global_store_character_photo_size_percent_tooltip",
								type = "numeric",
								default_value = 110,
								range = {
									50,
									125,
								},
							},
							{
								setting_id = "global_store_price_row_padding",
								tooltip = "global_store_price_row_padding_tooltip",
								type = "numeric",
								default_value = 10,
								range = {
									5,
									20,
								},
							},
													{
														setting_id = "global_store_character_info_gap",
														tooltip = "global_store_character_info_gap_tooltip",
														type = "numeric",
								default_value = 5,
														range = {
															0,
															40,
														},
													},
													{
														setting_id = "global_store_character_class_icon_size",
														tooltip = "global_store_character_class_icon_size_tooltip",
														type = "numeric",
														default_value = 16,
														range = {
															8,
															24,
														},
													},
													{
														setting_id = "global_store_character_name_font_size",
														tooltip = "global_store_character_name_font_size_tooltip",
														type = "numeric",
														default_value = 16,
														range = {
															8,
															20,
														},
													},
							{
									setting_id = "global_store_compact_character_names",
									tooltip = "global_store_compact_character_names_tooltip",
									type = "checkbox",
									default_value = true,
								},
								{
									setting_id = "global_store_single_column_modifier_horizontal_position",
									tooltip = "global_store_single_column_modifier_horizontal_position_tooltip",
									type = "numeric",
									default_value = 55,
									range = {
										0,
										100,
									},
								},
								{
									setting_id = "global_store_single_column_modifier_vertical_position",
									tooltip = "global_store_single_column_modifier_vertical_position_tooltip",
									type = "numeric",
									default_value = 100,
									range = {
										0,
										100,
									},
								},
						},
					},
					{
						setting_id = "character_overview_group",
						type = "group",
						sub_widgets = {
							{
								setting_id = "enable_character_overview_melee_mirror",
								tooltip = "enable_character_overview_melee_mirror_tooltip",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "character_overview_show_melee_rarity_strip",
								tooltip = "character_overview_show_melee_rarity_strip_tooltip",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "enable_character_overview_ranged_mirror",
								tooltip = "enable_character_overview_ranged_mirror_tooltip",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "character_overview_show_ranged_rarity_strip",
								tooltip = "character_overview_show_ranged_rarity_strip_tooltip",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "character_overview_show_only_dump_stat",
								tooltip = "character_overview_show_only_dump_stat_tooltip",
								type = "checkbox",
								default_value = false,
							},
							{
								setting_id = "character_overview_dump_stat_horizontal_offset",
								tooltip = "character_overview_dump_stat_horizontal_offset_tooltip",
								type = "numeric",
								default_value = -10,
								range = {
									-300,
									300,
								},
							},
							{
								setting_id = "character_overview_dump_stat_font_scale_percent",
								tooltip = "character_overview_dump_stat_font_scale_percent_tooltip",
								type = "numeric",
								default_value = 130,
								range = {
									50,
									200,
								},
							},
							{
								setting_id = "character_overview_dump_stat_color_preset",
								tooltip = "character_overview_dump_stat_color_preset_tooltip",
								type = "dropdown",
								default_value = "pink",
								options = color_preset_options(),
							},
							{
								setting_id = "character_overview_dump_stat_color_r",
								type = "numeric",
								default_value = 255,
								range = {
									0,
									255,
								},
							},
							{
								setting_id = "character_overview_dump_stat_color_g",
								type = "numeric",
								default_value = 94,
								range = {
									0,
									255,
								},
							},
							{
								setting_id = "character_overview_dump_stat_color_b",
								type = "numeric",
								default_value = 132,
								range = {
									0,
									255,
								},
							},
							{
								setting_id = "enable_character_overview_curio_details",
								tooltip = "enable_character_overview_curio_details_tooltip",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "character_overview_show_curio_rarity_strip",
								tooltip = "character_overview_show_curio_rarity_strip_tooltip",
								type = "checkbox",
								default_value = true,
							},
							{
								setting_id = "character_overview_use_native_curio_overlay",
								tooltip = "character_overview_use_native_curio_overlay_tooltip",
								type = "checkbox",
								default_value = false,
							},
							{
								setting_id = "character_overview_curio_name_mode",
								tooltip = "character_overview_curio_name_mode_tooltip",
								type = "dropdown",
								default_value = "two_lines",
								options = {
									{
										text = "character_overview_curio_name_mode_none",
										value = "none",
									},
									{
										text = "character_overview_curio_name_mode_one_line",
										value = "one_line",
									},
									{
										text = "character_overview_curio_name_mode_two_lines",
										value = "two_lines",
									},
								},
							},
							{
								setting_id = "character_overview_curio_font_size_percent",
								tooltip = "character_overview_curio_font_size_percent_tooltip",
								type = "numeric",
								default_value = 110,
								range = {
									50,
									150,
								},
							},
						},
					},
				},
			},
			{
				setting_id = "layout_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "enable_grid_layout",
						tooltip = "enable_grid_layout_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "melee_columns",
						tooltip = "melee_columns_tooltip",
						type = "numeric",
						default_value = 3,
						range = {
							2,
							5,
						},
					},
					{
						setting_id = "ranged_columns",
						tooltip = "ranged_columns_tooltip",
						type = "numeric",
						default_value = 3,
						range = {
							2,
							5,
						},
					},
					{
						setting_id = "curio_columns",
						tooltip = "curio_columns_tooltip",
						type = "numeric",
						default_value = 3,
						range = {
							2,
						5,
						},
					},
					{
						setting_id = "expand_inventory_window",
						tooltip = "expand_inventory_window_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "weapon_extra_width_column_threshold",
						tooltip = "weapon_extra_width_column_threshold_tooltip",
						type = "dropdown",
						default_value = "four_plus",
						options = {
							{
								text = "weapon_extra_width_column_threshold_four_plus",
								value = "four_plus",
							},
							{
								text = "weapon_extra_width_column_threshold_five_only",
								value = "five_only",
							},
						},
					},
					{
						setting_id = "five_column_weapon_extra_width",
						tooltip = "five_column_weapon_extra_width_tooltip",
						type = "numeric",
						default_value = 80,
						range = {
							0,
							120,
						},
					},
					{
						setting_id = "expand_curio_inventory_window",
						tooltip = "expand_curio_inventory_window_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "curio_target_card_width",
						tooltip = "curio_target_card_width_tooltip",
						type = "numeric",
						default_value = 190,
						range = {
							120,
							220,
						},
					},
					{
						setting_id = "grid_spacing",
						type = "numeric",
						default_value = 10,
						range = {
							0,
							40,
						},
					},
					{
						setting_id = "automatic_card_height",
						tooltip = "automatic_card_height_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "card_height",
						tooltip = "card_height_tooltip",
						type = "numeric",
						default_value = 110,
						range = {
							110,
							240,
						},
					},
					{
						setting_id = "icon_darkness",
						type = "numeric",
						default_value = 25,
						range = {
							0,
							85,
						},
					},
				},
			},
			image_layout_section("weapon", "weapon_images_size_position_group"),
			image_layout_section("curio", "curio_images_size_position_group"),
			{
				setting_id = "single_column_layout_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "single_column_weapon_name_font_size",
						tooltip = "single_column_weapon_name_font_size_tooltip",
						type = "numeric",
						default_value = 20,
						range = {
							10,
							24,
						},
					},
					{
						setting_id = "single_column_blessing_icons_on_right",
						tooltip = "single_column_blessing_icons_on_right_tooltip",
						type = "checkbox",
						default_value = true,
					},
				},
			},
			{
				setting_id = "custom_item_name_and_colors_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "enable_custom_item_name_and_colors",
						tooltip = "enable_custom_item_name_and_colors_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "custom_item_name_keybind",
						tooltip = "custom_item_name_keybind_tooltip",
						type = "dropdown",
						default_value = "lobby_open_inventory",
						options = {
							{ text = "custom_item_editor_keybind_i_view", value = "lobby_open_inventory" },
							{ text = "custom_item_editor_keybind_e", value = "hotkey_menu_special_1" },
							{ text = "custom_item_editor_keybind_q", value = "hotkey_menu_special_2" },
							{ text = "custom_item_editor_keybind_v", value = "hotkey_item_inspect" },
							{ text = "custom_item_editor_keybind_r", value = "group_finder_refresh_groups" },
							{ text = "custom_item_editor_keybind_off", value = "off" },
						},
					},
					{
						setting_id = "custom_item_name_color_keybind",
						tooltip = "custom_item_name_color_keybind_tooltip",
						type = "dropdown",
						default_value = "hotkey_menu_special_1",
						options = {
							{ text = "custom_item_editor_keybind_i_view", value = "lobby_open_inventory" },
							{ text = "custom_item_editor_keybind_e", value = "hotkey_menu_special_1" },
							{ text = "custom_item_editor_keybind_q", value = "hotkey_menu_special_2" },
							{ text = "custom_item_editor_keybind_v", value = "hotkey_item_inspect" },
							{ text = "custom_item_editor_keybind_r", value = "group_finder_refresh_groups" },
							{ text = "custom_item_editor_keybind_off", value = "off" },
						},
					},
					{
						setting_id = "custom_item_background_color_keybind",
						tooltip = "custom_item_background_color_keybind_tooltip",
						type = "dropdown",
						default_value = "navigate_secondary_left_pressed",
						options = {
							{ text = "custom_item_editor_keybind_i_view", value = "lobby_open_inventory" },
							{ text = "custom_item_editor_keybind_lt", value = "navigate_secondary_left_pressed" },
							{ text = "custom_item_editor_keybind_e", value = "hotkey_menu_special_1" },
							{ text = "custom_item_editor_keybind_q", value = "hotkey_menu_special_2" },
							{ text = "custom_item_editor_keybind_v", value = "hotkey_item_inspect" },
							{ text = "custom_item_editor_keybind_r", value = "group_finder_refresh_groups" },
							{ text = "custom_item_editor_keybind_off", value = "off" },
						},
					},
					{
						setting_id = "custom_item_skip_confirmation_prompts",
						tooltip = "custom_item_skip_confirmation_prompts_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "custom_item_preserve_card_shading",
						tooltip = "custom_item_preserve_card_shading_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "custom_item_override_weapon_information_color",
						tooltip = "custom_item_override_weapon_information_color_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "custom_item_override_weapon_rarity_keyword_color",
						tooltip = "custom_item_override_weapon_rarity_keyword_color_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "custom_item_override_weapon_information_name_color",
						tooltip = "custom_item_override_weapon_information_name_color_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "name_it_force_curio_name_in_detailed_mode",
						tooltip = "name_it_force_curio_name_in_detailed_mode_tooltip",
						type = "checkbox",
						default_value = true,
					},
				},
			},
			{
				-- Historical setting IDs are retained so existing Quick Look Card
				-- integration preferences migrate into the standalone implementation.
				setting_id = "quick_look_card_integration_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "enable_quick_look_card_single_column_integration",
						tooltip = "enable_quick_look_card_single_column_integration_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "quick_look_card_single_column_font_size",
						tooltip = "quick_look_card_single_column_font_size_tooltip",
						type = "numeric",
						default_value = 14,
						range = {
							8,
							20,
						},
					},
					{
						setting_id = "quick_look_card_single_column_label_value_gap",
						tooltip = "quick_look_card_single_column_label_value_gap_tooltip",
						type = "numeric",
						default_value = 1,
						range = {
							0,
							16,
						},
					},
					{
						setting_id = "quick_look_card_single_column_horizontal_position",
						tooltip = "quick_look_card_single_column_horizontal_position_tooltip",
						type = "numeric",
						default_value = 79,
						range = {
							0,
							100,
						},
					},
					{
						setting_id = "quick_look_card_single_column_vertical_position",
						tooltip = "quick_look_card_single_column_vertical_position_tooltip",
						type = "numeric",
						default_value = 93,
						range = {
							0,
							100,
						},
					},
					{
						setting_id = "enable_quick_look_card_grid_integration",
						tooltip = "enable_quick_look_card_grid_integration_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "quick_look_card_grid_stat_position",
						tooltip = "quick_look_card_grid_stat_position_tooltip",
						type = "dropdown",
						default_value = "above_power",
						options = {
							{
								text = "quick_look_card_grid_stat_position_above_power",
								value = "above_power",
							},
							{
								text = "quick_look_card_grid_stat_position_name_right",
								value = "name_right",
							},
							{
								text = "quick_look_card_grid_stat_position_name_left",
								value = "name_left",
							},
						},
					},
					{
						setting_id = "quick_look_card_grid_font_size",
						tooltip = "quick_look_card_grid_font_size_tooltip",
						type = "numeric",
						default_value = 13,
						range = {
							8,
							20,
						},
					},
					{
						setting_id = "quick_look_card_grid_bottom_padding",
						tooltip = "quick_look_card_grid_bottom_padding_tooltip",
						type = "numeric",
						default_value = 26,
						range = {
							20,
							60,
						},
					},
					{
						setting_id = "weapon_modifier_lowest_color_preset",
						tooltip = "weapon_modifier_lowest_color_preset_tooltip",
						type = "dropdown",
						default_value = "pink",
						options = color_preset_options(),
					},
					{
						setting_id = "weapon_modifier_lowest_color_r",
						type = "numeric",
						default_value = 255,
						range = {
							0,
							255,
						},
					},
					{
						setting_id = "weapon_modifier_lowest_color_g",
						type = "numeric",
						default_value = 94,
						range = {
							0,
							255,
						},
					},
					{
						setting_id = "weapon_modifier_lowest_color_b",
						type = "numeric",
						default_value = 132,
						range = {
							0,
							255,
						},
					},
					{
						setting_id = "weapon_modifier_lowest_color_opacity",
						tooltip = "weapon_modifier_lowest_color_opacity_tooltip",
						type = "numeric",
						default_value = 80,
						range = {
							0,
							100,
						},
					},
				},
			},
			{
				setting_id = "enhanced_descriptions_integration_group",
				type = "group",
				sub_widgets = {
					{
						-- Retain the established ID so existing configurations keep
						-- their value after this option moves into its own section.
						setting_id = "simplify_curio_primary_stat_text",
						tooltip = "simplify_curio_primary_stat_text_tooltip",
						type = "checkbox",
						default_value = true,
					},
				},
			},
			{
				setting_id = "myfavorites_integration_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "myfavorites_show_favorite_letter",
						tooltip = "myfavorites_show_favorite_letter_tooltip",
						type = "checkbox",
						default_value = false,
					},
				},
			},
			{
				setting_id = "lantern_integration_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "enable_lantern_inventory_section",
						tooltip = "enable_lantern_inventory_section_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "keep_lantern_curio_panel_separate",
						tooltip = "keep_lantern_curio_panel_separate_tooltip",
						type = "checkbox",
						default_value = true,
					},
				},
			},
			{
				setting_id = "card_content_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "append_mark_to_name",
						tooltip = "append_mark_to_name_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "force_weapon_name_single_line",
						tooltip = "force_weapon_name_single_line_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "show_pattern_mark",
						tooltip = "show_pattern_mark_tooltip",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "show_rarity_name",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "show_rarity_tag",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "weapon_blessing_display_mode",
						tooltip = "weapon_blessing_display_mode_tooltip",
						type = "dropdown",
						default_value = "ranked_text",
						options = {
							{
								text = "weapon_blessing_display_mode_icons",
								value = "icons",
							},
							{
								text = "weapon_blessing_display_mode_text",
								value = "text",
							},
							{
								text = "weapon_blessing_display_mode_ranked_text",
								value = "ranked_text",
							},
							{
								text = "weapon_blessing_display_mode_off",
								value = "off",
							},
						},
					},
					{
						setting_id = "blessing_text_item_level_separation",
						tooltip = "blessing_text_item_level_separation_tooltip",
						type = "dropdown",
						default_value = "four_plus",
						options = {
							{
								text = "blessing_text_item_level_separation_always",
								value = "always",
							},
							{
								text = "blessing_text_item_level_separation_four_plus",
								value = "four_plus",
							},
							{
								text = "blessing_text_item_level_separation_five_only",
								value = "five_only",
							},
							{
								text = "blessing_text_item_level_separation_never",
								value = "never",
							},
						},
					},
					{
						setting_id = "auto_fit_long_blessing_names",
						tooltip = "auto_fit_long_blessing_names_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "truncate_long_blessing_names",
						tooltip = "truncate_long_blessing_names_tooltip",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "weapon_blessing_text_vertical_spacing",
						tooltip = "weapon_blessing_text_vertical_spacing_tooltip",
						type = "numeric",
						default_value = 2,
						range = {
							0,
							20,
						},
					},
					{
						setting_id = "weapon_blessing_text_bottom_padding",
						tooltip = "weapon_blessing_text_bottom_padding_tooltip",
						type = "numeric",
						default_value = 4,
						range = {
							0,
							20,
						},
					},
					{
						setting_id = "weapon_blessing_text_color_preset",
						type = "dropdown",
						default_value = "light_blue",
						options = color_preset_options(),
					},
					{
						setting_id = "weapon_blessing_text_color_r",
						type = "numeric",
						default_value = 105,
						range = {
							0,
							255,
						},
					},
					{
						setting_id = "weapon_blessing_text_color_g",
						type = "numeric",
						default_value = 200,
						range = {
							0,
							255,
						},
					},
					{
						setting_id = "weapon_blessing_text_color_b",
						type = "numeric",
						default_value = 235,
						range = {
							0,
							255,
						},
					},
					{
						setting_id = "weapon_blessing_text_opacity",
						tooltip = "weapon_blessing_text_opacity_tooltip",
						type = "numeric",
						default_value = 80,
						range = {
							0,
							100,
						},
					},
					{
						setting_id = "blessing_icon_size",
						tooltip = "blessing_icon_size_tooltip",
						type = "numeric",
						default_value = 36,
						range = {
							20,
							48,
						},
					},
					{
						setting_id = "blessing_icon_spacing",
						tooltip = "blessing_icon_spacing_tooltip",
						type = "numeric",
						default_value = 3,
						range = {
							0,
							20,
						},
					},
					{
						setting_id = "show_weapon_perks",
						tooltip = "show_weapon_perks_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "weapon_perk_compression",
						tooltip = "weapon_perk_compression_tooltip",
						type = "dropdown",
						default_value = "heavy",
						options = {
							{
								text = "weapon_perk_compression_none",
								value = "none",
							},
							{
								text = "weapon_perk_compression_standard",
								value = "compression",
							},
							{
								text = "weapon_perk_compression_heavy",
								value = "heavy",
							},
						},
					},
					{
						setting_id = "show_weapon_perk_rank_symbols",
						tooltip = "show_weapon_perk_rank_symbols_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "weapon_perk_rank_icon_size",
						tooltip = "weapon_perk_rank_icon_size_tooltip",
						type = "numeric",
						default_value = 17,
						range = {
							12,
							32,
						},
					},
					{
						setting_id = "remove_weapon_perk_plus_signs",
						tooltip = "remove_weapon_perk_plus_signs_tooltip",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "weapon_perk_text_color_preset",
						type = "dropdown",
						default_value = "light_green",
						options = color_preset_options(),
					},
					{
						setting_id = "weapon_perk_text_color_r",
						type = "numeric",
						default_value = 190,
						range = {
							0,
							255,
						},
					},
					{
						setting_id = "weapon_perk_text_color_g",
						type = "numeric",
						default_value = 210,
						range = {
							0,
							255,
						},
					},
					{
						setting_id = "weapon_perk_text_color_b",
						type = "numeric",
						default_value = 180,
						range = {
							0,
							255,
						},
					},
					{
						setting_id = "weapon_perk_text_opacity",
						tooltip = "weapon_perk_text_opacity_tooltip",
						type = "numeric",
						default_value = 80,
						range = {
							0,
							100,
						},
					},
					{
						setting_id = "weapon_perk_vertical_spacing",
						tooltip = "weapon_perk_vertical_spacing_tooltip",
						type = "numeric",
						default_value = 2,
						range = {
							0,
							20,
						},
					},
					{
						setting_id = "weapon_perk_blessing_spacing",
						tooltip = "weapon_perk_blessing_spacing_tooltip",
						type = "numeric",
						default_value = 5,
						range = {
							0,
							20,
						},
					},
					{
						setting_id = "compact_favorite_marker",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "favorite_marker_position",
						tooltip = "favorite_marker_position_tooltip",
						type = "dropdown",
						default_value = "above_rating",
						options = {
							{
								text = "favorite_marker_position_above_rating",
								value = "above_rating",
							},
							{
								text = "favorite_marker_position_bottom_left",
								value = "bottom_left",
							},
						},
					},
					{
						setting_id = "item_name_font_size",
						type = "numeric",
						default_value = 16,
						range = {
							10,
							24,
						},
					},
					{
						setting_id = "minimum_item_name_font_size",
						tooltip = "minimum_item_name_font_size_tooltip",
						type = "numeric",
						default_value = 12,
						range = {
							8,
							20,
						},
					},
					{
						setting_id = "secondary_text_font_size",
						type = "numeric",
						default_value = 13,
						range = {
							8,
							20,
						},
					},
					{
						setting_id = "expertise_font_size",
						type = "numeric",
						default_value = 20,
						range = {
							10,
							28,
						},
					},
					{
						setting_id = "show_item_level_icon",
						tooltip = "show_item_level_icon_tooltip",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "equipped_highlight_group",
						type = "group",
						sub_widgets = {
							{
								setting_id = "highlight_equipped_items",
								tooltip = "highlight_equipped_items_tooltip",
								type = "dropdown",
								default_value = "animated_dashes",
								options = {
									{
										text = "equipped_highlight_mode_off",
										value = "off",
									},
									{
										text = "equipped_highlight_mode_soft_glow",
										value = "soft_glow",
									},
									{
										text = "equipped_highlight_mode_animated_dashes",
										value = "animated_dashes",
									},
									{
										text = "equipped_highlight_mode_pulsing_dashes",
										value = "pulsing_dashes",
									},
									{
										text = "equipped_highlight_mode_solid_border",
										value = "solid_border",
									},
								},
							},
							{
								setting_id = "equipped_highlight_glow_intensity",
								tooltip = "equipped_highlight_glow_intensity_tooltip",
								type = "numeric",
								default_value = 100,
								range = {
									0,
									100,
								},
							},
							{
								setting_id = "equipped_highlight_animated_border_width",
								tooltip = "equipped_highlight_animated_border_width_tooltip",
								type = "numeric",
								default_value = 2,
								range = {
									1,
									5,
								},
							},
							{
								setting_id = "equipped_highlight_solid_border_width",
								tooltip = "equipped_highlight_solid_border_width_tooltip",
								type = "numeric",
								default_value = 2,
								range = {
									1,
									5,
								},
							},
							{
								setting_id = "equipped_highlight_color_preset",
								type = "dropdown",
								default_value = "gold",
								options = color_preset_options(true),
							},
							{
								setting_id = "equipped_highlight_color_r",
								type = "numeric",
								default_value = 250,
								range = {
									0,
									255,
								},
							},
							{
								setting_id = "equipped_highlight_color_g",
								type = "numeric",
								default_value = 189,
								range = {
									0,
									255,
								},
							},
							{
								setting_id = "equipped_highlight_color_b",
								type = "numeric",
								default_value = 73,
								range = {
									0,
									255,
								},
							},
						},
					},
					{
						setting_id = "new_item_highlight_group",
						type = "group",
						sub_widgets = {
							{
								setting_id = "new_item_highlight_mode",
								tooltip = "new_item_highlight_mode_tooltip",
								type = "dropdown",
								default_value = "pulsing_dashes",
								options = {
									{
										text = "new_item_highlight_mode_native",
										value = "native",
									},
									{
										text = "new_item_highlight_mode_soft_glow",
										value = "soft_glow",
									},
									{
										text = "new_item_highlight_mode_animated_dashes",
										value = "animated_dashes",
									},
									{
										text = "new_item_highlight_mode_pulsing_dashes",
										value = "pulsing_dashes",
									},
									{
										text = "new_item_highlight_mode_solid_border",
										value = "solid_border",
									},
								},
							},
							{
								setting_id = "new_item_acknowledge_mode",
								tooltip = "new_item_acknowledge_mode_tooltip",
								type = "dropdown",
								default_value = "select",
								options = {
									{
										text = "new_item_acknowledge_mode_select",
										value = "select",
									},
									{
										text = "new_item_acknowledge_mode_hover",
										value = "hover",
									},
								},
							},
							{
								setting_id = "new_item_highlight_glow_intensity",
								tooltip = "new_item_highlight_glow_intensity_tooltip",
								type = "numeric",
								default_value = 100,
								range = {
									0,
									100,
								},
							},
							{
								setting_id = "new_item_highlight_animated_border_width",
								tooltip = "new_item_highlight_animated_border_width_tooltip",
								type = "numeric",
								default_value = 2,
								range = {
									1,
									5,
								},
							},
							{
								setting_id = "new_item_highlight_solid_border_width",
								tooltip = "new_item_highlight_solid_border_width_tooltip",
								type = "numeric",
								default_value = 2,
								range = {
									1,
									5,
								},
							},
							{
								setting_id = "new_item_highlight_color_preset",
								type = "dropdown",
								default_value = "green",
								options = color_preset_options(true),
							},
							{
								setting_id = "new_item_highlight_color_r",
								type = "numeric",
								default_value = 105,
								range = {
									0,
									255,
								},
							},
							{
								setting_id = "new_item_highlight_color_g",
								type = "numeric",
								default_value = 210,
								range = {
									0,
									255,
								},
							},
							{
								setting_id = "new_item_highlight_color_b",
								type = "numeric",
								default_value = 120,
								range = {
									0,
									255,
								},
							},
						},
					},
				},
			},
			{
				setting_id = "curio_content_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "curio_display_profile",
						tooltip = "curio_display_profile_tooltip",
						type = "dropdown",
						default_value = "detailed",
						options = {
							{
								text = "curio_display_profile_primary",
								value = "primary",
							},
							{
								text = "curio_display_profile_detailed",
								value = "detailed",
							},
						},
					},
					{
						setting_id = "curio_content_name_it_curio_name",
						tooltip = "curio_content_name_it_curio_name_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "show_curio_item_level",
						tooltip = "show_curio_item_level_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "curio_primary_stat_font_size",
						tooltip = "curio_primary_stat_font_size_tooltip",
						type = "numeric",
						default_value = 16,
						range = {
							9,
							20,
						},
					},
					{
						setting_id = "curio_secondary_stat_font_size",
						tooltip = "curio_secondary_stat_font_size_tooltip",
						type = "numeric",
						default_value = 13,
						range = {
							9,
							20,
						},
					},
					{
						setting_id = "curio_primary_secondary_spacing",
						tooltip = "curio_primary_secondary_spacing_tooltip",
						type = "numeric",
						default_value = 5,
						range = {
							0,
							20,
						},
					},
					{
						setting_id = "show_curio_quality",
						tooltip = "show_curio_quality_tooltip",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "curio_stat_compression",
						tooltip = "curio_stat_compression_tooltip",
						type = "dropdown",
						default_value = "heavy",
						options = {
							{
								text = "curio_stat_compression_none",
								value = "none",
							},
							{
								text = "curio_stat_compression_standard",
								value = "compression",
							},
							{
								text = "curio_stat_compression_heavy",
								value = "heavy",
							},
						},
					},
					{
						setting_id = "remove_curio_stat_plus_signs",
						tooltip = "remove_curio_stat_plus_signs_tooltip",
						type = "checkbox",
						default_value = false,
					},
					color_group("curio_health_color_group", "curio_health_color", "red", 235, 85, 85),
					color_group("curio_toughness_color_group", "curio_toughness_color", "light_blue", 105, 200, 235),
					color_group("curio_wound_color_group", "curio_wound_color", "purple", 190, 105, 230),
					color_group("curio_stamina_color_group", "curio_stamina_color", "yellow", 235, 205, 80),
					color_group("curio_secondary_text_color_group", "curio_secondary_text_color", "neutral", 220, 230, 210),
				},
			},
			{
				setting_id = "debug_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "debug_enable_hot_path_diagnostics",
						tooltip = "debug_enable_hot_path_diagnostics_tooltip",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "debug_expand_armoury_requisition_window_30_percent",
						tooltip = "debug_expand_armoury_requisition_window_30_percent_tooltip",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "debug_armoury_requisition_window_increase_percent",
						tooltip = "debug_armoury_requisition_window_increase_percent_tooltip",
						type = "numeric",
						default_value = 30,
						range = {
							10,
							100,
						},
					},
					{
						setting_id = "debug_adjust_inventory_window_width",
						tooltip = "debug_adjust_inventory_window_width_tooltip",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "debug_inventory_window_width_adjustment_percent",
						tooltip = "debug_inventory_window_width_adjustment_percent_tooltip",
						type = "numeric",
						default_value = 30,
						range = {
							-50,
							100,
						},
					},
					{
						setting_id = "debug_adjust_global_store_window_width",
						tooltip = "debug_adjust_global_store_window_width_tooltip",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "debug_global_store_window_width_adjustment_percent",
						tooltip = "debug_global_store_window_width_adjustment_percent_tooltip",
						type = "numeric",
						default_value = 30,
						range = {
							-50,
							100,
						},
					},
				},
			},
		},
	},
}
