local mod = get_mod("BetterInventory")

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
				setting_id = "layout_group",
				type = "group",
				sub_widgets = {
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
						setting_id = "grid_spacing",
						type = "numeric",
						default_value = 10,
						range = {
							0,
							40,
						},
					},
					{
						setting_id = "card_height",
						type = "numeric",
						default_value = 110,
						range = {
							110,
							180,
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
						setting_id = "show_pattern_mark",
						tooltip = "show_pattern_mark_tooltip",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "show_rarity_name",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "show_rarity_tag",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "compact_favorite_marker",
						type = "checkbox",
						default_value = true,
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
		},
	},
}
