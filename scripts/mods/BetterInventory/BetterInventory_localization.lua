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
	additional_views_group = {
		en = "Additional inventory views",
	},
	enable_hadron_entreat_grid = {
		en = "Hadron: Entreat Hadron",
	},
	enable_hadron_entreat_grid_tooltip = {
		en = "Uses Better Inventory cards when selecting an item through Entreat Hadron. The effective layout is capped at three columns; Hadron's separate Sacrifice Weapons flow is not changed.",
	},
	enable_armoury_requisition_grid = {
		en = "Armoury: Requisition Weapons & Curios",
	},
	enable_armoury_requisition_grid_tooltip = {
		en = "Uses Better Inventory cards in Requisition Weapons & Curios. The effective layout is capped at three columns; Brunt's Armoury and Multi-Operative Supply are not changed.",
	},
	expand_armoury_requisition_window = {
		en = "Expand Armoury Requisition window",
	},
	expand_armoury_requisition_window_tooltip = {
		en = "Widens the Requisition Weapons & Curios grid toward the right and safely repositions the item-details panel and Acquire button. Two-column layouts expand only when their cards are narrower than the selected target.",
	},
	armoury_requisition_target_card_width = {
		en = "Armoury target card width",
	},
	armoury_requisition_target_card_width_tooltip = {
		en = "Desired card width in pixels for the expanded Armoury grid. At three columns, the 230 px default adds 114 px to Darktide's native grid width.",
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
	option_requires_armoury_grid = {
		en = "Enable the Armoury Requisition grid to use this option.",
	},
	option_requires_armoury_expansion = {
		en = "Enable Armoury Requisition window expansion to set a target card width.",
	},
	option_requires_weapon_perks = {
		en = "Enable weapon perk text to use this option.",
	},
	option_requires_perk_rank_symbols = {
		en = "Enable perk level symbols to set their size.",
	},
	option_requires_weapon_blessings = {
		en = "Enable weapon blessing symbols to use this option.",
	},
	option_requires_detailed_curio_profile = {
		en = "Select the All four stats Curio profile to use this option.",
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
		en = "Shows up to two blessing symbols on weapon cards. Enabled by default; Darktide's ranked frames include the blessing level.",
	},
	blessing_icon_size = {
		en = "Blessing icon size",
	},
	blessing_icon_size_tooltip = {
		en = "Sets the width and height of each weapon blessing symbol in pixels. Automatic card height grows when larger symbols need more room.",
	},
	show_weapon_perks = {
		en = "Show weapon perk text",
	},
	show_weapon_perks_tooltip = {
		en = "Shows both weapon perks as dedicated single-line rows. Enabled by default; automatic card height reserves the required space, and narrow text shrinks before using an ellipsis.",
	},
	weapon_perk_compression = {
		en = "Weapon perk text compression",
	},
	weapon_perk_compression_tooltip = {
		en = "Heavy Compression is the default and is intended for narrow cards. Compression uses milder labels; unknown perk identifiers retain Darktide's original localized text.",
	},
	weapon_perk_compression_none = {
		en = "No compression",
	},
	weapon_perk_compression_standard = {
		en = "Compression",
	},
	weapon_perk_compression_heavy = {
		en = "Heavy Compression",
	},
	show_weapon_perk_rank_symbols = {
		en = "Show perk level symbols",
	},
	show_weapon_perk_rank_symbols_tooltip = {
		en = "Shows Darktide's native ranked perk symbol to the left of each visible weapon perk line. Enabled by default.",
	},
	weapon_perk_rank_icon_size = {
		en = "Perk level symbol size",
	},
	weapon_perk_rank_icon_size_tooltip = {
		en = "Sets the width and height of each perk level symbol in pixels. Automatic card height grows when larger symbols need more room.",
	},
	remove_weapon_perk_plus_signs = {
		en = "Remove + from weapon perk text",
	},
	remove_weapon_perk_plus_signs_tooltip = {
		en = "Removes only the leading plus sign from each visible weapon perk line. Numeric values and signs elsewhere are preserved.",
	},
	weapon_perk_text_color_preset = {
		en = "Weapon perk text colour preset",
	},
	weapon_perk_text_color_r = {
		en = "Weapon perk text colour preset red",
	},
	weapon_perk_text_color_g = {
		en = "Weapon perk text colour preset green",
	},
	weapon_perk_text_color_b = {
		en = "Weapon perk text colour preset blue",
	},
	blessing_icon_spacing = {
		en = "Blessing icon horizontal spacing",
	},
	blessing_icon_spacing_tooltip = {
		en = "Clear horizontal gap in pixels between weapon blessing icons.",
	},
	highlight_equipped_items = {
		en = "Highlight equipped items",
	},
	highlight_equipped_items_tooltip = {
		en = "Adds a soft white glow around equipped item cards while preserving Darktide's native equipped symbol.",
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
	show_item_level_icon = {
		en = "Show item power icon",
	},
	show_item_level_icon_tooltip = {
		en = "Shows Darktide's power glyph to the left of the item power number. Disabled by default; the numeric power value is always retained.",
	},
	curio_content_group = {
		en = "Curio content",
	},
	curio_display_profile = {
		en = "Curio display profile",
	},
	curio_display_profile_tooltip = {
		en = "All four stats is the default and shows the innate stat plus three perks. Primary stat keeps the Curio name and power while adding only its innate stat.",
	},
	curio_display_profile_primary = {
		en = "Primary stat",
	},
	curio_display_profile_detailed = {
		en = "All four stats",
	},
	show_curio_item_level = {
		en = "Show Curio base level",
	},
	show_curio_item_level_tooltip = {
		en = "Shows the Curio's normalized base-level number in the lower-right corner in either display profile. Enabled by default to make 400–430 Curios easy to identify.",
	},
	curio_primary_stat_font_size = {
		en = "Primary Curio stat font size",
	},
	curio_primary_stat_font_size_tooltip = {
		en = "Font size for the Curio's innate Health, Toughness, Wound or Stamina line in both display profiles.",
	},
	curio_secondary_stat_font_size = {
		en = "Secondary Curio stat font size",
	},
	curio_secondary_stat_font_size_tooltip = {
		en = "Font size for the three secondary Curio perk lines in the All four stats profile.",
	},
	curio_primary_secondary_spacing = {
		en = "Primary-to-secondary Curio spacing",
	},
	curio_primary_secondary_spacing_tooltip = {
		en = "Vertical gap in pixels between the primary Curio stat and the first of its three secondary lines in the All four stats profile.",
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
	remove_curio_stat_plus_signs = {
		en = "Remove + from Curio stat lines",
	},
	remove_curio_stat_plus_signs_tooltip = {
		en = "Removes the leading + sign from every stat line on BetterInventory Curio cards. Disabled by default.",
	},
	curio_secondary_text_color_group = {
		en = "Secondary Curio line colour",
	},
	curio_secondary_text_color_preset = {
		en = "Preset",
	},
	curio_secondary_text_color_r = {
		en = "Red",
	},
	curio_secondary_text_color_g = {
		en = "Green",
	},
	curio_secondary_text_color_b = {
		en = "Blue",
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
	color_preset_terminal_green = {
		en = "Terminal green",
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
	weapon_perk_unarmoured_damage = {
		en = "Unarmoured Damage",
	},
	weapon_perk_unarmoured_damage_heavy = {
		en = "Unarmoured Dmg",
	},
	weapon_perk_flak_damage = {
		en = "Flak Damage",
	},
	weapon_perk_flak_damage_heavy = {
		en = "Flak Dmg",
	},
	weapon_perk_unyielding_damage = {
		en = "Unyielding Damage",
	},
	weapon_perk_unyielding_damage_heavy = {
		en = "Unyielding Dmg",
	},
	weapon_perk_maniacs_damage = {
		en = "Maniacs Damage",
	},
	weapon_perk_maniacs_damage_heavy = {
		en = "Maniac Dmg",
	},
	weapon_perk_carapace_damage = {
		en = "Carapace Damage",
	},
	weapon_perk_carapace_damage_heavy = {
		en = "Carapace Dmg",
	},
	weapon_perk_infested_damage = {
		en = "Infested Damage",
	},
	weapon_perk_infested_damage_heavy = {
		en = "Infested Dmg",
	},
	weapon_perk_melee_crit_chance = {
		en = "Melee Crit Chance",
	},
	weapon_perk_melee_crit_chance_heavy = {
		en = "Melee Crit",
	},
	weapon_perk_melee_crit_damage = {
		en = "Melee Crit Dmg",
	},
	weapon_perk_melee_crit_damage_heavy = {
		en = "Crit Dmg",
	},
	weapon_perk_horde_melee_damage = {
		en = "Horde Melee Dmg",
	},
	weapon_perk_horde_melee_damage_heavy = {
		en = "Horde Dmg",
	},
	weapon_perk_elites_melee_damage = {
		en = "Elites Melee Dmg",
	},
	weapon_perk_elites_melee_damage_heavy = {
		en = "Elite Dmg",
	},
	weapon_perk_specialist_melee_damage = {
		en = "Specialist Melee Dmg",
	},
	weapon_perk_specialist_melee_damage_heavy = {
		en = "Spec Dmg",
	},
	weapon_perk_melee_weakspot_damage = {
		en = "Melee Weakspot Dmg",
	},
	weapon_perk_melee_weakspot_damage_heavy = {
		en = "Weakspot Dmg",
	},
	weapon_perk_ranged_crit_chance = {
		en = "Ranged Crit Chance",
	},
	weapon_perk_ranged_crit_chance_heavy = {
		en = "Ranged Crit",
	},
	weapon_perk_ranged_crit_damage = {
		en = "Ranged Crit Dmg",
	},
	weapon_perk_ranged_crit_damage_heavy = {
		en = "Crit Dmg",
	},
	weapon_perk_horde_ranged_damage = {
		en = "Horde Ranged Dmg",
	},
	weapon_perk_horde_ranged_damage_heavy = {
		en = "Horde Dmg",
	},
	weapon_perk_elites_ranged_damage = {
		en = "Elites Ranged Dmg",
	},
	weapon_perk_elites_ranged_damage_heavy = {
		en = "Elite Dmg",
	},
	weapon_perk_specialist_ranged_damage = {
		en = "Specialist Ranged Dmg",
	},
	weapon_perk_specialist_ranged_damage_heavy = {
		en = "Spec Dmg",
	},
	weapon_perk_ranged_weakspot_damage = {
		en = "Ranged Weakspot Dmg",
	},
	weapon_perk_ranged_weakspot_damage_heavy = {
		en = "Weakspot Dmg",
	},
	weapon_perk_stamina = {
		en = "Stamina",
	},
	weapon_perk_melee_damage = {
		en = "Melee Damage",
	},
	weapon_perk_melee_damage_heavy = {
		en = "Melee Dmg",
	},
	weapon_perk_ranged_damage = {
		en = "Ranged Damage",
	},
	weapon_perk_ranged_damage_heavy = {
		en = "Ranged Dmg",
	},
	weapon_perk_melee_finesse = {
		en = "Melee Finesse",
	},
	weapon_perk_ranged_finesse = {
		en = "Ranged Finesse",
	},
	weapon_perk_finesse_heavy = {
		en = "Finesse",
	},
	weapon_perk_melee_power = {
		en = "Melee Power",
	},
	weapon_perk_ranged_power = {
		en = "Ranged Power",
	},
	weapon_perk_power_heavy = {
		en = "Power",
	},
	weapon_perk_melee_impact = {
		en = "Melee Impact",
	},
	weapon_perk_impact_heavy = {
		en = "Impact",
	},
	weapon_perk_block_efficiency = {
		en = "Block Efficiency",
	},
	weapon_perk_block_heavy = {
		en = "Block",
	},
	weapon_perk_sprint_efficiency = {
		en = "Sprint Efficiency",
	},
	weapon_perk_sprint_heavy = {
		en = "Sprint",
	},
	weapon_perk_reload_speed = {
		en = "Reload Speed",
	},
	weapon_perk_reload_heavy = {
		en = "Reload",
	},
}
