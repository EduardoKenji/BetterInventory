local MOD_VERSION = "1.3.2"
local mod = get_mod("BetterInventory")

local function color_preset_options()
	return {
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
			text = "color_preset_neutral",
			value = "neutral",
		},
		{
			text = "color_preset_custom",
			value = "custom",
		},
	}
end

local function color_group(group_id, prefix, default_preset, red, green, blue)
	return {
		setting_id = group_id,
		type = "group",
		sub_widgets = {
			{
				setting_id = prefix .. "_preset",
				type = "dropdown",
				default_value = default_preset,
				options = color_preset_options(),
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
								sub_widgets = {
									{
										setting_id = "automatic_curio_character_options_placeholder",
										type = "checkbox",
										default_value = false,
									},
								},
							},
						},
					},
				},
			},
			{
				setting_id = "additional_views_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "enable_hadron_entreat_grid",
						tooltip = "enable_hadron_entreat_grid_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_armoury_requisition_grid",
						tooltip = "enable_armoury_requisition_grid_tooltip",
						type = "checkbox",
						default_value = true,
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
						setting_id = "columns",
						tooltip = "columns_tooltip",
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
						setting_id = "highlight_equipped_items",
						tooltip = "highlight_equipped_items_tooltip",
						type = "checkbox",
						default_value = true,
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
		},
	},
}
