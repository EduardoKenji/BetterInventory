return {
	mod_name = {
		en = "Better Inventory",
	},
	mod_description = {
		en = "A responsive, information-preserving inventory layout for Darktide.",
	},
	inventory_slots_group = {
		en = "Inventory coverage",
	},
	enable_melee_inventory = {
		en = "Melee weapons",
	},
	enable_ranged_inventory = {
		en = "Ranged weapons",
	},
	enable_curio_inventory = {
		en = "Curios",
	},
	layout_group = {
		en = "Grid layout",
	},
	enable_grid_layout = {
		en = "Enable grid layout",
	},
	enable_grid_layout_tooltip = {
		en = "Uses Better Inventory's multi-column cards. Disable this to retain Darktide's native single-column geometry while keeping enabled card-content enhancements.",
	},
	columns = {
		en = "Columns",
	},
	columns_tooltip = {
		en = "Number of item cards per inventory row. Three is the recommended starting point.",
	},
	expand_inventory_window = {
		en = "Expand inventory window when needed",
	},
	expand_inventory_window_tooltip = {
		en = "Widens the inventory panel enough to keep narrow cards inside it. This normally affects five-column layouts, or four columns with very large spacing. Disable this to shrink the cards instead.",
	},
	expand_curio_inventory_window = {
		en = "Expand Curio window by columns",
	},
	expand_curio_inventory_window_tooltip = {
		en = "Uses the target Curio card width to widen the inventory panel as columns are added. Three columns normally retain the native panel width; four and five columns can use the available horizontal space.",
	},
	curio_target_card_width = {
		en = "Target Curio card width",
	},
	curio_target_card_width_tooltip = {
		en = "Desired Curio card width in pixels when column-aware Curio expansion is enabled. The final panel width is derived from this value, the column count and grid spacing.",
	},
	grid_spacing = {
		en = "Card spacing",
	},
	card_height = {
		en = "Card height",
	},
	card_height_tooltip = {
		en = "Manual grid-card height. This control is disabled while automatic card height is enabled.",
	},
	automatic_card_height = {
		en = "Automatic card height",
	},
	automatic_card_height_tooltip = {
		en = "Expands grid cards when the selected text rows and font sizes need more vertical space. Darktide's native single-column mode retains its native height.",
	},
	option_requires_grid_layout = {
		en = "Enable grid layout to use this option.",
	},
	option_disabled_by_automatic_height = {
		en = "Disable automatic card height to set a manual height.",
	},
	option_requires_window_expansion = {
		en = "Enable inventory-window expansion to use this option.",
	},
	option_requires_curio_expansion = {
		en = "Enable column-aware Curio expansion to set a target card width.",
	},
	icon_darkness = {
		en = "Icon darkness (%%)",
	},
	card_content_group = {
		en = "Card content",
	},
	append_mark_to_name = {
		en = "Append Mark to weapon name",
	},
	append_mark_to_name_tooltip = {
		en = "Formats weapon titles like 'Combat Blade Mk VI' and leaves only the weapon pattern on the secondary line. Narrow titles preserve the Mark when shortened.",
	},
	show_pattern_mark = {
		en = "Show weapon pattern line",
	},
	show_pattern_mark_tooltip = {
		en = "Shows Darktide's secondary weapon-card name. With 'Append Mark to weapon name' enabled, this line contains only the weapon pattern; otherwise it contains the pattern and Mark.",
	},
	show_rarity_name = {
		en = "Show weapon quality text",
	},
	show_rarity_tag = {
		en = "Show rarity colour strip",
	},
	show_weapon_blessings = {
		en = "Show weapon blessing symbols",
	},
	show_weapon_blessings_tooltip = {
		en = "Shows up to two blessing symbols on weapon cards. Darktide's ranked frames include the blessing level.",
	},
	blessing_icon_spacing = {
		en = "Blessing icon horizontal spacing",
	},
	blessing_icon_spacing_tooltip = {
		en = "Clear horizontal gap in pixels between weapon blessing icons.",
	},
	compact_favorite_marker = {
		en = "Use compact favorite marker",
	},
	favorite_marker_position = {
		en = "Favorite marker position",
	},
	favorite_marker_position_tooltip = {
		en = "Places the favorite marker either in the upper-right area above item power or in the lower-left corner. Equipped items move the upper-right marker down to avoid the equipped badge.",
	},
	favorite_marker_position_above_rating = {
		en = "Upper right, above power",
	},
	favorite_marker_position_bottom_left = {
		en = "Bottom left",
	},
	item_name_font_size = {
		en = "Item name font size",
	},
	minimum_item_name_font_size = {
		en = "Minimum item name font size",
	},
	minimum_item_name_font_size_tooltip = {
		en = "Long names shrink to this size before being shortened with an ellipsis. Names never wrap into the pattern or Mark line.",
	},
	secondary_text_font_size = {
		en = "Pattern and rarity font size",
	},
	expertise_font_size = {
		en = "Expertise font size",
	},
	curio_content_group = {
		en = "Curio content",
	},
	curio_display_profile = {
		en = "Curio display profile",
	},
	curio_display_profile_tooltip = {
		en = "Primary stat keeps the Curio name and power while adding its innate stat. The All four stats profile replaces those labels with the innate stat and three perks.",
	},
	curio_display_profile_primary = {
		en = "Primary stat",
	},
	curio_display_profile_detailed = {
		en = "All four stats",
	},
	show_curio_quality = {
		en = "Show Curio quality text",
	},
	show_curio_quality_tooltip = {
		en = "Shows the Curio quality line in the Primary stat profile. Disabled by default because the card colour already communicates quality.",
	},
	curio_stat_compression = {
		en = "Curio stat text compression",
	},
	curio_stat_compression_tooltip = {
		en = "Heavy Compression is the default and uses compact labels such as DR, Regen, Block and Sprint. Compression applies milder shortening. Unknown descriptions retain Darktide's original localized text.",
	},
	curio_stat_compression_none = {
		en = "No compression",
	},
	curio_stat_compression_standard = {
		en = "Compression",
	},
	curio_stat_compression_heavy = {
		en = "Heavy Compression",
	},
	simplify_curio_primary_stat_text = {
		en = "Simplify primary Curio stat text",
	},
	simplify_curio_primary_stat_text_tooltip = {
		en = "Removes redundant wording from supported primary lines: Max Health becomes Health, Max Stamina becomes Stamina, and Wound(s) becomes Wound.",
	},
	curio_health_color_group = {
		en = "Max Health line colour",
	},
	curio_health_color_preset = {
		en = "Preset",
	},
	curio_health_color_r = {
		en = "Red",
	},
	curio_health_color_g = {
		en = "Green",
	},
	curio_health_color_b = {
		en = "Blue",
	},
	curio_toughness_color_group = {
		en = "Max Toughness line colour",
	},
	curio_toughness_color_preset = {
		en = "Preset",
	},
	curio_toughness_color_r = {
		en = "Red",
	},
	curio_toughness_color_g = {
		en = "Green",
	},
	curio_toughness_color_b = {
		en = "Blue",
	},
	curio_wound_color_group = {
		en = "Wound line colour",
	},
	curio_wound_color_preset = {
		en = "Preset",
	},
	curio_wound_color_r = {
		en = "Red",
	},
	curio_wound_color_g = {
		en = "Green",
	},
	curio_wound_color_b = {
		en = "Blue",
	},
	curio_stamina_color_group = {
		en = "Max Stamina line colour",
	},
	curio_stamina_color_preset = {
		en = "Preset",
	},
	curio_stamina_color_r = {
		en = "Red",
	},
	curio_stamina_color_g = {
		en = "Green",
	},
	curio_stamina_color_b = {
		en = "Blue",
	},
	color_preset_red = {
		en = "Red",
	},
	color_preset_light_blue = {
		en = "Light blue",
	},
	color_preset_purple = {
		en = "Purple",
	},
	color_preset_orange = {
		en = "Orange",
	},
	color_preset_yellow = {
		en = "Yellow",
	},
	color_preset_green = {
		en = "Green",
	},
	color_preset_neutral = {
		en = "Neutral",
	},
	color_preset_custom = {
		en = "Custom colour",
	},
	curio_resistance_flamers = {
		en = "Flamers Resistance",
	},
	curio_resistance_snipers = {
		en = "Snipers Resistance",
	},
	curio_resistance_grenadiers = {
		en = "Grenadiers Resistance",
	},
	curio_resistance_hounds = {
		en = "Pox Hounds Resistance",
	},
	curio_resistance_mutants = {
		en = "Mutants Resistance",
	},
	curio_resistance_gunners = {
		en = "Gunners Resistance",
	},
	curio_resistance_bombers = {
		en = "Bombers Resistance",
	},
	curio_resistance_grimoires = {
		en = "Grimoire Resistance",
	},
	curio_reward_chance = {
		en = "Curio as Reward",
	},
	curio_toughness_regeneration = {
		en = "Toughness Regen",
	},
	curio_ordo_dockets = {
		en = "Ordo Dockets",
	},
	curio_revive_speed = {
		en = "Revive Speed",
	},
	curio_dr_flamers = {
		en = "Flamers DR",
	},
	curio_dr_snipers = {
		en = "Snipers DR",
	},
	curio_dr_grenadiers = {
		en = "Grenadiers DR",
	},
	curio_dr_hounds = {
		en = "Pox Hounds DR",
	},
	curio_dr_mutants = {
		en = "Mutants DR",
	},
	curio_dr_gunners = {
		en = "Gunners DR",
	},
	curio_dr_bombers = {
		en = "Bombers DR",
	},
	curio_dr_grimoires = {
		en = "Grim Corruption DR",
	},
	curio_heavy_ability_regen = {
		en = "Ability Regen",
	},
	curio_heavy_toughness_regen = {
		en = "Tough Regen",
	},
	curio_heavy_corruption_dr = {
		en = "Corruption DR",
	},
	curio_heavy_block = {
		en = "Block",
	},
	curio_heavy_sprint = {
		en = "Sprint",
	},
	curio_heavy_stamina_regen = {
		en = "Stamina Regen",
	},
}
