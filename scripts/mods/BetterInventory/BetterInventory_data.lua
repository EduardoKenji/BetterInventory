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
			text = "color_preset_purple",
			value = "purple",
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
			text = "color_preset_neutral",
			value = "neutral",
		},
		{
			text = "color_preset_custom",
			value = "custom",
		},
	}
end

local function curio_color_group(group_id, prefix, default_preset, red, green, blue)
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
						setting_id = "show_weapon_blessings",
						tooltip = "show_weapon_blessings_tooltip",
						type = "checkbox",
						default_value = false,
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
						default_value = "primary",
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
						setting_id = "simplify_curio_primary_stat_text",
						tooltip = "simplify_curio_primary_stat_text_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "remove_curio_stat_plus_signs",
						tooltip = "remove_curio_stat_plus_signs_tooltip",
						type = "checkbox",
						default_value = false,
					},
					curio_color_group("curio_health_color_group", "curio_health_color", "red", 235, 85, 85),
					curio_color_group("curio_toughness_color_group", "curio_toughness_color", "light_blue", 105, 200, 235),
					curio_color_group("curio_wound_color_group", "curio_wound_color", "purple", 190, 105, 230),
					curio_color_group("curio_stamina_color_group", "curio_stamina_color", "yellow", 235, 205, 80),
				},
			},
		},
	},
}
