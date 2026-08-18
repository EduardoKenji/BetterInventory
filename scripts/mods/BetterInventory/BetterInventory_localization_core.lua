local localization = {
	mod_name = {
		en = "Better Inventory",
	},
	mod_description = {
		en = "A responsive, information-preserving inventory layout for Darktide.",
	},
	debug_group = {
		en = "Debug (testing only)",
	},
	debug_enable_hot_path_diagnostics = {
		en = "Enable hot-path diagnostics",
	},
	debug_enable_hot_path_diagnostics_tooltip = {
		en = "Opt-in sampled counters for UI rebuilds, alignment/pivot writes, active read promises, operation age and Lua memory. Disabled by default; enable only while collecting a baseline.",
	},
	debug_weapon_options_button_count = {
		en = "Weapon-action test button count",
	},
	debug_weapon_options_button_count_tooltip = {
		en = "Sets the total action-row count to 5, 10, or 20 by adding presentation-only no-op buttons after real actions. The panel grows through seven rows, then scrolls without drawing overflow outside its frame. Reopen the inventory after changing this value.",
	},
	debug_weapon_options_button_count_off = {
		en = "Off",
	},
	debug_weapon_options_button_count_5 = {
		en = "5 buttons",
	},
	debug_weapon_options_button_count_10 = {
		en = "10 buttons",
	},
	debug_weapon_options_button_count_20 = {
		en = "20 buttons",
	},
	debug_weapon_kill_counter_kills = {
		en = "Weapon Kill Counter test kills",
	},
	debug_weapon_kill_counter_kills_tooltip = {
		en = "Presentation-only. When Weapon Kill Counter is installed and its card overlay is enabled, shows 1,000 kills on every weapon card without changing WKC's saved statistics.",
	},
	debug_weapon_kill_counter_kills_off = {
		en = "Off",
	},
	debug_weapon_kill_counter_kills_1000 = {
		en = "1,000 kills",
	},
	debug_expand_armoury_requisition_window_30_percent = {
		en = "Increase Armoury Exchange store width",
	},
	debug_expand_armoury_requisition_window_30_percent_tooltip = {
		en = "Debug geometry stress test. In Requisition Weapons & Curios only, increases the normally resolved store grid width by the percentage below and proportionally refits its equipment cards. Reopen the Armoury Exchange after changing this setting.",
	},
	debug_armoury_requisition_window_increase_percent = {
		en = "Store width increase (%%)",
	},
	debug_armoury_requisition_window_increase_percent_tooltip = {
		en = "Sets the artificial Armoury Exchange store-width increase from 10%% to 100%%. The default stress-test increase is 30%%.",
	},
	debug_adjust_inventory_window_width = {
		en = "Adjust inventory window width",
	},
	debug_adjust_inventory_window_width_tooltip = {
		en = "Debug geometry stress test for melee, ranged and Curio inventories. Applies the signed percentage below to the normally resolved grid width and proportionally refits its equipment cards. Reopen the inventory after changing this setting.",
	},
	debug_inventory_window_width_adjustment_percent = {
		en = "Inventory width adjustment (%%)",
	},
	debug_inventory_window_width_adjustment_percent_tooltip = {
		en = "Shrinks or enlarges the resolved inventory width from -50%% to +100%%. The default stress-test adjustment is +30%%.",
	},
	debug_adjust_global_store_window_width = {
		en = "Adjust GlobalStore window width",
	},
	debug_adjust_global_store_window_width_tooltip = {
		en = "Debug geometry stress test for GlobalStore's Multi-Operative Supply grid. Applies the signed percentage below to the normally resolved grid width and proportionally refits its equipment cards. Reopen GlobalStore after changing this setting.",
	},
	debug_global_store_window_width_adjustment_percent = {
		en = "GlobalStore width adjustment (%%)",
	},
	debug_global_store_window_width_adjustment_percent_tooltip = {
		en = "Shrinks or enlarges the resolved GlobalStore width from -50%% to +100%%. The default stress-test adjustment is +30%%.",
	},
	inventory_slots_group = {
		en = "Inventory coverage",
	},
	inventory_sorting_group = {
		en = "Inventory sorting",
	},
	show_inventory_options_widget = {
		en = "Show inventory options widget",
	},
	show_inventory_options_widget_tooltip = {
		en = "Shows BetterInventory's Sorting and item-management widget in melee, ranged and Curio inventories. Turning it off hides both the scalable panel and the compact fallback without changing their saved settings.",
	},
	prioritize_equipped_favorites = {
		en = "Equipped and favorited items at the top",
	},
	prioritize_equipped_favorites_tooltip = {
		en = "In melee, ranged and Curio inventories, keeps equipped items first and favorited items second while the selected native sort still orders each group. The synchronized toggle appears below Curio details or below the weapon action buttons, and its value persists between game sessions.",
	},
	prioritize_perfect_roll_weapons = {
		en = "Perfect-roll weapons at the top",
	},
	prioritize_perfect_roll_weapons_tooltip = {
		en = "Places weapons with four attributes at 80 and the fifth at 60 or higher ahead of ordinary items, ordered by the fifth attribute from highest to lowest. Equipped and favorited items retain higher priority. The in-inventory checkbox is available in the scalable panel.",
	},
	prioritize_perfect_roll_weapons_inventory_label = {
		en = "Perfect-roll weapons at the top",
	},
	inventory_options_panel_geometry_group = {
		en = "Inventory options panel",
	},
	curio_information_width_percent = {
		en = "Curio information window width (%%)",
	},
	curio_preview_height_percent = {
		en = "Curio preview-area height (%%)",
	},
	curio_preview_height_percent_tooltip = {
		en = "Scales the upper Curio preview area and its item art together to preserve the original aspect ratio. Reopen the inventory after changing it.",
	},
	inventory_options_panel_width = {
		en = "Options panel width (px)",
	},
	inventory_options_panel_max_height = {
		en = "Options panel maximum height (px)",
	},
	inventory_options_panel_row_spacing = {
		en = "Options panel row spacing (px)",
	},
	inventory_options_panel_padding_top = {
		en = "Options panel top padding (px)",
	},
	inventory_options_panel_padding_bottom = {
		en = "Options panel bottom padding (px)",
	},
	inventory_options_panel_padding_left = {
		en = "Options panel left padding (px)",
	},
	inventory_options_panel_padding_right = {
		en = "Options panel right padding (px)",
	},
	inventory_options_geometry_reopen_tooltip = {
		en = "Inventory-options panel geometry. Reopen the inventory after changing this value.",
	},
	prioritize_equipped_favorites_inventory_label = {
		en = "Equipped and favorited items at the top",
	},
	inventory_sorting_inventory_label = {
		en = "Sorting",
	},
	armoury_native_sorting_header = {
		en = "Darktide Native Sorting",
	},
	enable_experimental_quick_discard = {
		en = "Show quick-discard controls in inventory",
	},
	enable_experimental_quick_discard_tooltip = {
		en = "Adds opt-in discard-management controls below the inventory sorting toggle after the inventory is reopened. Manual mode remains the default.",
	},
	enable_automatic_curio_acquisition = {
		en = "Enable automatic curio acquisition",
	},
	enable_automatic_curio_acquisition_tooltip = {
		en = "Performs one cross-character Armoury Exchange scan after each eligible context entry and automatically purchases every Curio matching the enabled item-level, primary-roll, type and target filters. Morningstar is enabled by the existing buyer setting; Operative Selection requires its separate option. Targets can be selected by class or by individual character. This spends Ordo Dockets without a confirmation prompt. Automatic discard finishes first in Morningstar, and matching Curios remain protected from later automatic-discard passes.",
	},
	option_requires_automatic_curio_acquisition = {
		en = "Requires automatic Curio acquisition.",
	},
	option_requires_automatic_curio_classes_mode = {
		en = "Select Classes as the Curio acquisition target mode.",
	},
	option_requires_automatic_curio_characters_mode = {
		en = "Select Characters as the Curio acquisition target mode.",
	},
	option_requires_automatic_curio_health = {
		en = "Requires Health Curios to be enabled.",
	},
	option_requires_automatic_curio_toughness = {
		en = "Requires Toughness Curios to be enabled.",
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
	hadron_additional_views_group = {
		en = "Hadron",
	},
	armoury_exchange_views_group = {
		en = "Armoury Exchange",
	},
	melk_views_group = {
		en = "Sire Melk's Requisitorium",
	},
	character_overview_group = {
		en = "Character overview",
	},
	enable_character_overview_melee_mirror = {
		en = "Mirror melee weapon single-column format from inventory",
	},
	enable_character_overview_melee_mirror_tooltip = {
		en = "Uses the detailed BetterInventory single-column card for the equipped melee weapon on the character overview screen. Enabled by default.",
	},
	character_overview_show_melee_rarity_strip = {
		en = "Show melee weapon colour strip",
	},
	character_overview_show_melee_rarity_strip_tooltip = {
		en = "Draws the left rarity-colour strip on the mirrored melee weapon card. Enabled by default.",
	},
	enable_character_overview_ranged_mirror = {
		en = "Mirror ranged weapon single-column format from inventory",
	},
	enable_character_overview_ranged_mirror_tooltip = {
		en = "Uses the detailed BetterInventory single-column card for the equipped ranged weapon on the character overview screen. Enabled by default.",
	},
	character_overview_show_ranged_rarity_strip = {
		en = "Show ranged weapon colour strip",
	},
	character_overview_show_ranged_rarity_strip_tooltip = {
		en = "Draws the left rarity-colour strip on the mirrored ranged weapon card. Enabled by default.",
	},
	character_overview_show_only_dump_stat = {
		en = "Show only weapon dump stat",
	},
	character_overview_show_only_dump_stat_tooltip = {
		en = "Replaces the five maximum-potential modifier rows on mirrored Character Overview weapons with only the lowest modifier above item power. Disabled by default.",
	},
	option_requires_character_overview_weapon_mirror = {
		en = "Requires a mirrored Character Overview weapon card and single-column weapon modifiers.",
	},
	character_overview_dump_stat_horizontal_offset = {
		en = "Dump stat horizontal offset",
	},
	character_overview_dump_stat_horizontal_offset_tooltip = {
		en = "Moves the Character Overview dump-stat label horizontally from -300 to 300 pixels. Negative values move left; positive values move right.",
	},
	character_overview_dump_stat_font_scale_percent = {
		en = "Dump stat font scale (%%)",
	},
	character_overview_dump_stat_font_scale_percent_tooltip = {
		en = "Scales the Character Overview dump-stat label from 50%% to 200%% without changing other card text.",
	},
	character_overview_dump_stat_color_preset = {
		en = "Dump stat font colour preset",
	},
	character_overview_dump_stat_color_preset_tooltip = {
		en = "Sets the Character Overview dump-stat label colour. Editing an RGB channel selects Custom.",
	},
	character_overview_dump_stat_color_r = {
		en = "Dump stat font colour red",
	},
	character_overview_dump_stat_color_g = {
		en = "Dump stat font colour green",
	},
	character_overview_dump_stat_color_b = {
		en = "Dump stat font colour blue",
	},
	option_requires_character_overview_dump_stat_only = {
		en = "Requires Show only weapon dump stat.",
	},
	enable_character_overview_curio_details = {
		en = "Show detailed Curio card on character overview",
	},
	enable_character_overview_curio_details_tooltip = {
		en = "Shows the equipped Curio's primary and secondary stats in a compact BetterInventory card on the character overview screen. Enabled by default.",
	},
	character_overview_show_curio_rarity_strip = {
		en = "Show Curio colour strip",
	},
	character_overview_show_curio_rarity_strip_tooltip = {
		en = "Draws the left rarity-colour strip on the detailed Curio card. Enabled by default.",
	},
	character_overview_use_native_curio_overlay = {
		en = "Use native Curio overlay",
	},
	character_overview_use_native_curio_overlay_tooltip = {
		en = "Uses Darktide's ornate Curio frame and portrait layout for detailed Character Overview Curios while keeping BetterInventory's title and stat lines. Disabled by default.",
	},
	character_overview_curio_name_mode = {
		en = "Curio title mode",
	},
	character_overview_curio_name_mode_tooltip = {
		en = "Hides Curio titles or fits them within one or two lines above the four stat rows on the character overview.",
	},
	character_overview_curio_name_mode_none = {
		en = "No title",
	},
	character_overview_curio_name_mode_one_line = {
		en = "One-line title",
	},
	character_overview_curio_name_mode_two_lines = {
		en = "Two-line title",
	},
	character_overview_curio_font_size_percent = {
		en = "Character overview Curio font size (%%)",
	},
	character_overview_curio_font_size_percent_tooltip = {
		en = "Scales all text on detailed Curio cards in the character overview (50-150%%, default 110%%). Does not affect Curio cards in inventory or stores.",
	},
	option_requires_character_overview_curio_details = {
		en = "Requires detailed Curio cards on the character overview.",
	},
	lantern_integration_group = {
		en = "Mod Integration: Lantern of the Omnissiah",
	},
	global_store_integration_group = {
		en = "Mod Integration: GlobalStore",
	},
	enable_global_store_integration = {
		en = "Enable GlobalStore integration",
	},
	enable_global_store_integration_tooltip = {
		en = "Enables BetterInventory's GlobalStore integration for Multi-Operative Supply. Disable this to leave GlobalStore's native cards and sorting untouched.",
	},
	enable_global_store_grid = {
		en = "Use BetterInventory grid cards",
	},
	enable_global_store_grid_tooltip = {
		en = "Uses BetterInventory's responsive grid cards in GlobalStore's Multi-Operative Supply. The view is capped at three columns; the Melee, Ranged and Curios column settings only apply to inventory tabs. Three columns reserve an extra character-information row without stretching weapon art.",
	},
	enable_global_store_sorting_panel = {
		en = "Show GlobalStore sorting widget",
	},
	enable_global_store_sorting_panel_tooltip = {
		en = "Adds collapsible BetterInventory Sorting and Darktide Native Sorting sections to GlobalStore's Multi-Operative Supply. Requires the GlobalStore grid option and is enabled by default.",
	},
	global_store_character_photo_size_percent = {
		en = "GlobalStore character photo size (%%)",
	},
	global_store_character_photo_size_percent_tooltip = {
		en = "Controls the GlobalStore character photo size in two- and three-column cards (50-125%%, with 110%% as the default). The character row remains below the price and item-level row while its reserved height stays fixed, so changing this value does not change card dimensions or move the price.",
	},
	global_store_price_row_padding = {
		en = "GlobalStore price/item-level row padding",
	},
	global_store_price_row_padding_tooltip = {
		en = "Controls the vertical padding above the GlobalStore character row. Increasing it moves the Ordo Dockets and item-level row farther from the character photo without changing the photo size.",
	},
	global_store_character_info_gap = {
		en = "GlobalStore character info horizontal gap",
	},
	global_store_character_info_gap_tooltip = {
		en = "Controls the horizontal space between the GlobalStore character photo and the class icon/name. The value is in pixels and applies to two- and three-column cards.",
	},
	global_store_character_class_icon_size = {
		en = "GlobalStore class icon size",
	},
	global_store_character_class_icon_size_tooltip = {
		en = "Controls the GlobalStore class icon font size in two- and three-column cards (8-24 px, default 16). The character row and card dimensions stay fixed.",
	},
	global_store_character_name_font_size = {
		en = "GlobalStore character name font size",
	},
	global_store_character_name_font_size_tooltip = {
		en = "Controls the GlobalStore character name font size in two- and three-column cards (8-20 px, default 16). The character row and card dimensions stay fixed.",
	},
	global_store_compact_character_names = {
		en = "Compact GlobalStore character names in 4-5 columns",
	},
	global_store_compact_character_names_tooltip = {
		en = "Retained for compatibility with older profiles. GlobalStore is capped at three columns, so this narrow-card four- and five-column behavior is not used. Enabled by default.",
	},
	global_store_single_column_modifier_horizontal_position = {
		en = "GlobalStore single-column weapon modifier horizontal position (%%)",
	},
	global_store_single_column_modifier_horizontal_position_tooltip = {
		en = "Moves the DMG, CLVD, DEF and other weapon modifier values horizontally on native single-column GlobalStore cards. Zero is the left edge and 100 is the right edge. Reopen GlobalStore after changing this value.",
	},
	global_store_single_column_modifier_vertical_position = {
		en = "GlobalStore single-column weapon modifier vertical position (%%)",
	},
	global_store_single_column_modifier_vertical_position_tooltip = {
		en = "Moves the native single-column GlobalStore weapon modifier block vertically. Zero is the top edge and 100 is the bottom edge. Reopen GlobalStore after changing this value.",
	},
	enable_hadron_entreat_grid = {
		en = "Hadron: Entreat Hadron",
	},
	enable_hadron_entreat_grid_tooltip = {
		en = "Uses Better Inventory cards when selecting an item through Entreat Hadron. The effective layout is capped at three columns; Hadron's separate Sacrifice Weapons flow is not changed.",
	},
	enable_hadron_single_column_mirror = {
		en = "Mirror single-column format from inventory",
	},
	enable_hadron_single_column_mirror_tooltip = {
		en = "Uses the detailed BetterInventory single-column card format for Entreat Hadron when grid layout is disabled. This adds the same perk, blessing and weapon-stat rows used by the inventory. Enabled by default.",
	},
	enable_armoury_requisition_grid = {
		en = "Armoury: Requisition Weapons & Curios",
	},
	armoury_auto_favorite_purchased_items = {
		en = "Automatically favorite purchased items",
	},
	armoury_auto_favorite_purchased_items_tooltip = {
		en = "Favorites items after a manual Armoury Exchange purchase is confirmed. If GlobalStore is installed, this also covers Armoury Multi-Operative Supply purchases. Brunt's Armoury, Auto Crafter, and Automatic Curio Buyer purchases are excluded. Disabled by default.",
	},
	melk_auto_favorite_purchased_items = {
		en = "Automatically favorite Limited Time Acquisitions",
	},
	melk_auto_favorite_purchased_items_tooltip = {
		en = "Favorites items after a Limited Time Acquisitions purchase is confirmed. If GlobalStore is installed, this also covers Sire Melk Multi-Operative Supply purchases. Mystery Acquisitions are controlled separately, and Auto Crafter purchases are excluded. Disabled by default.",
	},
	melk_mystery_auto_favorite_purchased_items = {
		en = "Automatically favorite Mystery Acquisitions",
	},
	melk_mystery_auto_favorite_purchased_items_tooltip = {
		en = "Favorites items after a Mystery Acquisitions purchase is confirmed. Limited Time Acquisitions are controlled separately, and Auto Crafter purchases are excluded. Disabled by default.",
	},
	enable_armoury_requisition_grid_tooltip = {
		en = "Uses Better Inventory cards in Requisition Weapons & Curios. The effective layout is capped at three columns; Brunt's Armoury and Multi-Operative Supply are not changed.",
	},
	enable_armoury_single_column_mirror = {
		en = "Enable custom detailed card for single column",
	},
	enable_armoury_single_column_mirror_tooltip = {
		en = "Uses BetterInventory's custom detailed card for Requisition Weapons & Curios when grid layout is disabled. Enabled by default.",
	},
	enable_armoury_requisition_sorting_panel = {
		en = "Show Armoury sorting widget",
	},
	enable_armoury_requisition_sorting_panel_tooltip = {
		en = "Adds BetterInventory's collapsible Sorting and Darktide Native Sorting widget to Requisition Weapons & Curios. Requires the Armoury grid option and is enabled by default.",
	},
	brighten_armoury_item_levels = {
		en = "Brighten Armoury item levels",
	},
	brighten_armoury_item_levels_tooltip = {
		en = "Uses brighter text for item levels on Armoury Exchange cards so the value remains readable above the price footer. Enabled by default.",
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
	quick_look_card_integration_group = {
		en = "Mod Integration: Quick Look Card",
	},
	option_requires_custom_item_name_and_colors = {
		en = "Enable custom item names and colors to use this option.",
	},
	enable_quick_look_card_single_column_integration = {
		en = "Show weapon modifiers in single-column mode",
	},
	enable_quick_look_card_single_column_integration_tooltip = {
		en = "Shows all five maximum-potential weapon modifiers without requiring another mod. When Quick Look Card is installed, Better Inventory reuses and normalizes its passes to avoid duplicates. Disable this to leave Quick Look Card's native single-column content untouched. Reopen the inventory after changing this option.",
	},
	quick_look_card_single_column_font_size = {
		en = "Single-column modifier font size",
	},
	quick_look_card_single_column_font_size_tooltip = {
		en = "Controls the font size of the five-modifier block in single-column mode. Reopen the inventory after changing this value.",
	},
	quick_look_card_single_column_label_value_gap = {
		en = "Single-column modifier label/value gap",
	},
	quick_look_card_single_column_label_value_gap_tooltip = {
		en = "Controls the horizontal gap in pixels between each modifier label and its number in single-column mode. Set it lower for a tighter block or higher for more separation. Reopen the inventory after changing this value.",
	},
	quick_look_card_single_column_horizontal_position = {
		en = "Single-column modifier horizontal position (%%)",
	},
	quick_look_card_single_column_horizontal_position_tooltip = {
		en = "Moves the five-modifier block horizontally across the available card width, including native single-column GlobalStore cards. Zero is the left edge and 100 is the right edge. Reopen the inventory after changing this value.",
	},
	quick_look_card_single_column_vertical_position = {
		en = "Single-column modifier vertical position (%%)",
	},
	quick_look_card_single_column_vertical_position_tooltip = {
		en = "Moves the five-modifier block vertically across the available card height, including native single-column GlobalStore cards. Zero is the top edge and 100 is the bottom edge. Reopen the inventory after changing this value.",
	},
	enable_quick_look_card_grid_integration = {
		en = "Show lowest weapon modifier in grid mode",
	},
	enable_quick_look_card_grid_integration_tooltip = {
		en = "Shows each weapon's lowest maximum-potential modifier without requiring another mod. Ties use the first stat in display order. When Quick Look Card is installed, its overlapping grid passes remain hidden. Reopen the inventory after changing this option.",
	},
	quick_look_card_grid_stat_position = {
		en = "Lowest modifier position",
	},
	quick_look_card_grid_stat_position_tooltip = {
		en = "Places the lowest weapon modifier above the weapon power or beside the weapon name. Name-side positions reserve card width and automatically fall back above the power on cards too narrow to keep the name readable.",
	},
	quick_look_card_grid_stat_position_above_power = {
		en = "Above weapon power",
	},
	quick_look_card_grid_stat_position_name_right = {
		en = "Right of weapon name",
	},
	quick_look_card_grid_stat_position_name_left = {
		en = "Left of weapon name",
	},
	quick_look_card_grid_font_size = {
		en = "Grid lowest modifier font size",
	},
	quick_look_card_grid_font_size_tooltip = {
		en = "Controls the grid dump-stat label size. Reopen the inventory after changing this value.",
	},
	quick_look_card_grid_bottom_padding = {
		en = "Lowest modifier bottom padding",
	},
	quick_look_card_grid_bottom_padding_tooltip = {
		en = "Controls the distance in pixels between the lowest-modifier label and the card's bottom edge when it is above weapon power. Lower values move it closer to the power value. Reopen the inventory after changing this value.",
	},
	weapon_modifier_lowest_color_preset = {
		en = "Lowest modifier colour preset",
	},
	weapon_modifier_lowest_color_preset_tooltip = {
		en = "Sets the colour used by the lowest modifier in grid mode and its highlighted abbreviation in the five-stat single-column block.",
	},
	weapon_modifier_lowest_color_r = {
		en = "Lowest modifier colour red",
	},
	weapon_modifier_lowest_color_g = {
		en = "Lowest modifier colour green",
	},
	weapon_modifier_lowest_color_b = {
		en = "Lowest modifier colour blue",
	},
	weapon_modifier_lowest_color_opacity = {
		en = "Lowest modifier opacity",
	},
	weapon_modifier_lowest_color_opacity_tooltip = {
		en = "Sets the lowest-modifier text opacity from fully transparent at 0%% to fully opaque at 100%%.",
	},
	weapon_modifier_melee_damage = { en = "MELE" },
	weapon_modifier_ammo = { en = "AMMO" },
	weapon_modifier_penetration = { en = "PEN" },
	weapon_modifier_burn = { en = "BURN" },
	weapon_modifier_charge_rate = { en = "CHRG" },
	weapon_modifier_cleave_damage = { en = "CLVD" },
	weapon_modifier_cleave_targets = { en = "CLVT" },
	weapon_modifier_crowd_control = { en = "CC" },
	weapon_modifier_collateral = { en = "CLTR" },
	weapon_modifier_critical_bonus = { en = "CRIT" },
	weapon_modifier_damage = { en = "DMG" },
	weapon_modifier_defences = { en = "DEF" },
	weapon_modifier_blast_penetration = { en = "PENB" },
	weapon_modifier_blast_damage = { en = "BLSD" },
	weapon_modifier_blast_radius = { en = "BLSR" },
	weapon_modifier_finesse = { en = "FIN" },
	weapon_modifier_shredder = { en = "SHRD" },
	weapon_modifier_first_target = { en = "FRST" },
	weapon_modifier_cloud_radius = { en = "CLDR" },
	weapon_modifier_thermal_resistance = { en = "TRES" },
	weapon_modifier_mobility = { en = "MOB" },
	weapon_modifier_power_output = { en = "PWR" },
	weapon_modifier_stopping_power = { en = "STPW" },
	weapon_modifier_range = { en = "RNGE" },
	weapon_modifier_reload_speed = { en = "RLD" },
	weapon_modifier_stability = { en = "STB" },
	weapon_modifier_quell_speed = { en = "QUEL" },
	weapon_modifier_warp_resistance = { en = "WRES" },
	weapon_modifier_heat_management = { en = "HTMG" },
	weapon_modifier_arc_efficiency = { en = "ARC" },
	weapon_modifier_cleave_efficiency = { en = "CLVE" },
	single_column_layout_group = {
		en = "Single-column layout",
	},
	single_column_weapon_name_font_size = {
		en = "Weapon name font size",
	},
	single_column_weapon_name_font_size_tooltip = {
		en = "Controls weapon-name size in single-column mode. Automatic card sizing adds height as this value increases so the name does not consume the detail rows below it. Reopen the inventory after changing this value.",
	},
	single_column_blessing_icons_on_right = {
		en = "Show blessing icons beside names",
	},
	single_column_blessing_icons_on_right_tooltip = {
		en = "In single-column text modes, shows the two full framed blessing icons side by side in the space to the right of the blessing names. Tier symbols keep their normal position before names. Reopen the inventory after changing this option.",
	},
	enhanced_descriptions_integration_group = {
		en = "Mod integration: Enhanced Descriptions",
	},
	enable_grid_layout = {
		en = "Enable grid layout",
	},
	enable_grid_layout_tooltip = {
		en = "Uses Better Inventory's multi-column cards. Disable this to retain Darktide's native single-column geometry while keeping enabled card-content enhancements.",
	},
	melee_columns = {
		en = "Melee Weapons Columns",
	},
	melee_columns_tooltip = {
		en = "Number of melee-weapon cards per inventory row. Defaults to three. This setting affects melee weapons only.",
	},
	ranged_columns = {
		en = "Ranged Weapons Columns",
	},
	ranged_columns_tooltip = {
		en = "Number of ranged-weapon cards per inventory row. Defaults to three. This setting affects ranged weapons only.",
	},
	curio_columns = {
		en = "Curios Columns",
	},
	curio_columns_tooltip = {
		en = "Number of Curio cards per inventory row. Defaults to three. This setting affects Curios only.",
	},
	three_column_weapon_name_font_size = {
		en = "Armoury weapon name font size",
	},
	three_column_weapon_name_font_size_tooltip = {
		en = "Controls weapon-name size in Armoury Exchange cards. Lower values help long names stay on one line without changing inventory cards. Reopen the Armoury view after changing this value.",
	},
	expand_inventory_window = {
		en = "Expand inventory window when needed",
	},
	expand_inventory_window_tooltip = {
		en = "Widens the inventory panel enough to keep narrow cards inside it. The weapon-width threshold and Curio target-width settings control additional expansion. Disable this to shrink the cards instead.",
	},
	weapon_extra_width_column_threshold = {
		en = "Apply extra weapon width at",
	},
	weapon_extra_width_column_threshold_tooltip = {
		en = "Chooses whether the extra melee and ranged inventory width applies to both four- and five-column grids or only to five-column grids.",
	},
	weapon_extra_width_column_threshold_four_plus = {
		en = "At 4 or more columns",
	},
	weapon_extra_width_column_threshold_five_only = {
		en = "At 5 columns",
	},
	five_column_weapon_extra_width = {
		en = "Extra weapon inventory width",
	},
	five_column_weapon_extra_width_tooltip = {
		en = "Adds this many pixels to the normal melee and ranged inventory when the configured column threshold is met. The 80 px default gives each card 20 additional pixels across four columns or 16 across five. Expansion is safely clamped before the actions panel reaches the screen edge.",
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
		en = "Expands cards when the selected text rows and font sizes need more vertical space. Single-column cards also reserve enough height for enabled Better Inventory perk and blessing rows.",
	},
	option_requires_grid_layout = {
		en = "Enable grid layout to use this option.",
	},
	option_requires_single_column_mode = {
		en = "Disable grid layout to use this single-column option.",
	},
	option_requires_ranked_blessing_text = {
		en = "Select ranked blessing text to use this option.",
	},
	option_requires_quick_look_card_single_column_integration = {
		en = "Enable single-column weapon modifiers to use this option.",
	},
	option_requires_quick_look_card_grid_integration = {
		en = "Enable grid weapon modifiers to use this option.",
	},
	option_requires_quick_look_card_above_power = {
		en = "Select Above weapon power to use this option.",
	},
	option_requires_weapon_extra_width_threshold = {
		en = "Increase Columns to the configured extra-width threshold to use this option.",
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
	option_requires_global_store_grid = {
		en = "Enable the GlobalStore grid to use this option.",
	},
	option_requires_global_store_integration = {
		en = "Enable GlobalStore integration to use this option.",
	},
	option_requires_weapon_perks = {
		en = "Enable weapon perk text to use this option.",
	},
	option_requires_perk_rank_symbols = {
		en = "Enable perk level symbols to set their size.",
	},
	option_requires_weapon_blessings = {
		en = "Select blessing icons to use this option.",
	},
	option_requires_single_column_blessing_icons = {
		en = "Enable single-column blessing icons to use this option with blessing text.",
	},
	option_requires_detailed_curio_profile = {
		en = "Select the All four stats Curio profile to use this option.",
	},
	option_requires_experimental_quick_discard = {
		en = "Enable the experimental inventory quick-discard controls to use this option.",
	},
	option_requires_automatic_discard_mode = {
		en = "Select Automatic discard mode to use this option.",
	},
	option_requires_curio_discard_protection = {
		en = "Enable minimum-item-level Curio protection to set its threshold.",
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
	force_weapon_name_single_line = {
		en = "Force weapon name to a single line",
	},
	force_weapon_name_single_line_tooltip = {
		en = "Keeps each weapon title on one line. Long titles first shrink to the configured minimum item-name font size, then shorten with an ellipsis while preserving an appended Mk name.",
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
	weapon_blessing_display_mode = {
		en = "Weapon blessing display",
	},
	weapon_blessing_display_mode_tooltip = {
		en = "Choose full blessing icons, compact names with Roman text ranks, names with native tier symbols, or no blessing content. Automatic card height reserves the required space.",
	},
	weapon_blessing_display_mode_icons = {
		en = "Icons",
	},
	weapon_blessing_display_mode_text = {
		en = "Text lines",
	},
	weapon_blessing_display_mode_ranked_text = {
		en = "Tier symbols + text",
	},
	weapon_blessing_display_mode_off = {
		en = "Off",
	},
	blessing_text_item_level_separation = {
		en = "Separate blessing text and item level",
	},
	blessing_text_item_level_separation_tooltip = {
		en = "Chooses when either blessing text mode places both blessing names above a dedicated item-level row. The default applies this safer, wider layout to narrow four- and five-column inventory grids.",
	},
	blessing_text_item_level_separation_always = {
		en = "Always",
	},
	blessing_text_item_level_separation_four_plus = {
		en = "At 4 or more columns",
	},
	blessing_text_item_level_separation_five_only = {
		en = "At 5 columns",
	},
	blessing_text_item_level_separation_never = {
		en = "Never",
	},
	auto_fit_long_blessing_names = {
		en = "Auto-fit long blessing names",
	},
	auto_fit_long_blessing_names_tooltip = {
		en = "Reduces only an overflowing blessing line's font size until it fits beside the item level. Enabled by default.",
	},
	truncate_long_blessing_names = {
		en = "Truncate long blessing names",
	},
	truncate_long_blessing_names_tooltip = {
		en = "Forces blessing names onto one line. If a name is still too wide after optional auto-fitting, its end is replaced with ... before the item-level area.",
	},
	blessing_icon_size = {
		en = "Blessing icon size",
	},
	option_requires_weapon_blessing_text = {
		en = "Select a blessing text mode to use this option.",
	},
	weapon_blessing_text_vertical_spacing = {
		en = "Blessing text vertical spacing",
	},
	weapon_blessing_text_vertical_spacing_tooltip = {
		en = "Adds a clear vertical gap in pixels between the two weapon blessing text rows. Automatic card height reserves the added space.",
	},
	weapon_blessing_text_bottom_padding = {
		en = "Blessing text bottom padding",
	},
	weapon_blessing_text_bottom_padding_tooltip = {
		en = "Sets the clear space in pixels below the second blessing text row. When an item-level row or Armoury footer is reserved, the padding is applied above that area. Automatic card height reserves the space.",
	},
	weapon_blessing_text_color_preset = {
		en = "Weapon blessing text colour preset",
	},
	weapon_blessing_text_color_r = {
		en = "Weapon blessing text colour red",
	},
	weapon_blessing_text_color_g = {
		en = "Weapon blessing text colour green",
	},
	weapon_blessing_text_color_b = {
		en = "Weapon blessing text colour blue",
	},
	weapon_blessing_text_opacity = {
		en = "Weapon blessing text opacity",
	},
	weapon_blessing_text_opacity_tooltip = {
		en = "Sets blessing-text opacity from fully transparent at 0%% to fully opaque at 100%%. Tier symbols retain their native appearance.",
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
		en = "Tier symbol size",
	},
	weapon_perk_rank_icon_size_tooltip = {
		en = "Sets the width and height of native tier symbols used by weapon perks and Tier symbols + text blessings. Automatic card height grows when larger symbols need more room.",
	},
	option_requires_rank_symbols = {
		en = "Enable perk level symbols or select Tier symbols + text blessings to use this option.",
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
	weapon_perk_text_opacity = {
		en = "Weapon perk text opacity",
	},
	weapon_perk_text_opacity_tooltip = {
		en = "Sets weapon-perk text opacity from fully transparent at 0%% to fully opaque at 100%%. Perk tier symbols retain their native appearance.",
	},
	weapon_perk_vertical_spacing = {
		en = "Weapon perk vertical spacing",
	},
	weapon_perk_vertical_spacing_tooltip = {
		en = "Adds a clear vertical gap in pixels between the two weapon perk rows. Automatic card height reserves the added space.",
	},
	weapon_perk_blessing_spacing = {
		en = "Perk-to-blessing section spacing",
	},
	weapon_perk_blessing_spacing_tooltip = {
		en = "Sets the vertical padding in pixels between the weapon perk and blessing sections when both are visible. Automatic card height grows when padding exceeds the default.",
	},
	option_requires_perk_and_blessing_sections = {
		en = "Show both weapon perks and weapon blessings to use this option.",
	},
	blessing_icon_spacing = {
		en = "Blessing icon horizontal spacing",
	},
	blessing_icon_spacing_tooltip = {
		en = "Clear horizontal gap in pixels between weapon blessing icons.",
	},
	highlight_equipped_items = {
		en = "Highlight mode",
	},
	highlight_equipped_items_tooltip = {
		en = "Chooses how equipped item cards are highlighted while preserving Darktide's native equipped symbol. Pulsing animated dashes slowly fade from transparent to opaque and back.",
	},
	equipped_highlight_mode_off = {
		en = "Off",
	},
	equipped_highlight_mode_soft_glow = {
		en = "Soft glow",
	},
	equipped_highlight_mode_animated_dashes = {
		en = "Animated dashed border",
	},
	equipped_highlight_mode_pulsing_dashes = {
		en = "Pulsing animated dashed border",
	},
	equipped_highlight_mode_solid_border = {
		en = "Solid border",
	},
	equipped_highlight_group = {
		en = "Equipped item highlight",
	},
	equipped_highlight_glow_intensity = {
		en = "Soft glow intensity (%%)",
	},
	equipped_highlight_glow_intensity_tooltip = {
		en = "Controls soft-glow opacity from fully transparent at 0%% to full intensity at 100%%.",
	},
	equipped_highlight_animated_border_width = {
		en = "Animated dashed border width",
	},
	equipped_highlight_animated_border_width_tooltip = {
		en = "Thickens either animated dashed border mode with 1-5 bounded concentric layers. Layers are created only when card blueprints are rebuilt; no retained per-card animation state or per-frame allocation is used.",
	},
	equipped_highlight_solid_border_width = {
		en = "Solid border width",
	},
	equipped_highlight_solid_border_width_tooltip = {
		en = "Sets the solid equipped-card border width from 1-5 using Darktide's native frame materials and bounded concentric layers.",
	},
	equipped_highlight_color_preset = {
		en = "Preset",
	},
	equipped_highlight_color_r = {
		en = "Red",
	},
	equipped_highlight_color_g = {
		en = "Green",
	},
	equipped_highlight_color_b = {
		en = "Blue",
	},
	option_requires_equipped_highlight = {
		en = "Select an equipped item highlight mode to use these colour controls.",
	},
	option_requires_equipped_highlight_soft_glow = {
		en = "Select Soft glow to use this option.",
	},
	option_requires_equipped_highlight_animated_dashes = {
		en = "Select either animated dashed border mode to use this option.",
	},
	option_requires_equipped_highlight_solid_border = {
		en = "Select Solid border to use this option.",
	},
	new_item_highlight_group = {
		en = "Newly acquired item highlight",
	},
	new_item_highlight_mode = {
		en = "Highlight mode",
	},
	new_item_highlight_mode_tooltip = {
		en = "Highlights items that Darktide still marks as newly acquired. Enhanced modes replace the small native dot with a whole-card effect; pulsing animated dashes slowly fade in and out.",
	},
	new_item_highlight_mode_native = {
		en = "Native dot only",
	},
	new_item_highlight_mode_soft_glow = {
		en = "Soft glow",
	},
	new_item_highlight_mode_animated_dashes = {
		en = "Animated dashed border",
	},
	new_item_highlight_mode_pulsing_dashes = {
		en = "Pulsing animated dashed border",
	},
	new_item_highlight_mode_solid_border = {
		en = "Solid border",
	},
	new_item_acknowledge_mode = {
		en = "Mark item as seen",
	},
	new_item_acknowledge_mode_tooltip = {
		en = "Selection clears the new-item state only after the card is selected. Hover also clears it when the mouse enters the card or controller focus selects it. Both modes use Darktide's native saved new-item state.",
	},
	new_item_acknowledge_mode_select = {
		en = "On selection",
	},
	new_item_acknowledge_mode_hover = {
		en = "On hover or controller focus",
	},
	new_item_highlight_glow_intensity = {
		en = "Soft glow intensity (%%)",
	},
	new_item_highlight_glow_intensity_tooltip = {
		en = "Controls newly acquired item soft-glow opacity from fully transparent at 0%% to full intensity at 100%%.",
	},
	new_item_highlight_animated_border_width = {
		en = "Animated dashed border width",
	},
	new_item_highlight_animated_border_width_tooltip = {
		en = "Thickens either native animated dashed material with 1-5 bounded static layers. The pulsing mode uses Darktide's global UI clock without retained per-card timer state.",
	},
	new_item_highlight_solid_border_width = {
		en = "Solid border width",
	},
	new_item_highlight_solid_border_width_tooltip = {
		en = "Sets the newly acquired item border width from 1-5 using bounded native frame layers.",
	},
	new_item_highlight_color_preset = {
		en = "Preset",
	},
	new_item_highlight_color_r = {
		en = "Red",
	},
	new_item_highlight_color_g = {
		en = "Green",
	},
	new_item_highlight_color_b = {
		en = "Blue",
	},
	option_requires_new_item_enhanced_highlight = {
		en = "Select a whole-card newly acquired item highlight mode to use these colour controls.",
	},
	option_requires_new_item_soft_glow = {
		en = "Select Soft glow to use this option.",
	},
	option_requires_new_item_animated_dashes = {
		en = "Select either animated dashed border mode to use this option.",
	},
	option_requires_new_item_solid_border = {
		en = "Select Solid border to use this option.",
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
		en = "Simplify Curio stat lines",
	},
	simplify_curio_primary_stat_text_tooltip = {
		en = "On: BetterInventory removes redundant wording from supported primary and secondary Curio lines. Off: preserves the original wording supplied by Darktide or Enhanced Descriptions.",
	},
	remove_curio_stat_plus_signs = {
		en = "Remove + from Curio stat lines",
	},
	remove_curio_stat_plus_signs_tooltip = {
		en = "Removes the leading + sign from every stat line on BetterInventory Curio cards. Disabled by default.",
	},
	curio_secondary_color_mode = {
		en = "Secondary Curio line colour mode",
	},
	curio_secondary_color_mode_tooltip = {
		en = "Perk category colours (default): groups related secondary Curio perks and gives each group its own customisable colour. Single colour: uses one colour for every secondary line. Unknown future perks use the single-colour fallback.",
	},
	curio_secondary_color_mode_category = {
		en = "Perk category colours",
	},
	curio_secondary_color_mode_single = {
		en = "Single colour",
	},
	curio_secondary_text_color_group = {
		en = "Single-colour and unknown-perk fallback",
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
		en = "Health Curio lines colour",
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
		en = "Toughness Curio lines colour",
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
		en = "Wound Curio lines colour",
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
		en = "Stamina and efficiency lines colour",
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
	curio_enemy_resistance_color_group = {
		en = "Enemy damage resistance lines colour",
	},
	curio_enemy_resistance_color_preset = {
		en = "Preset",
	},
	curio_enemy_resistance_color_r = {
		en = "Red",
	},
	curio_enemy_resistance_color_g = {
		en = "Green",
	},
	curio_enemy_resistance_color_b = {
		en = "Blue",
	},
	curio_corruption_resistance_color_group = {
		en = "Corruption resistance lines colour",
	},
	curio_corruption_resistance_color_preset = {
		en = "Preset",
	},
	curio_corruption_resistance_color_r = {
		en = "Red",
	},
	curio_corruption_resistance_color_g = {
		en = "Green",
	},
	curio_corruption_resistance_color_b = {
		en = "Blue",
	},
	curio_ability_regeneration_color_group = {
		en = "Ability regeneration lines colour",
	},
	curio_ability_regeneration_color_preset = {
		en = "Preset",
	},
	curio_ability_regeneration_color_r = {
		en = "Red",
	},
	curio_ability_regeneration_color_g = {
		en = "Green",
	},
	curio_ability_regeneration_color_b = {
		en = "Blue",
	},
	curio_mission_rewards_color_group = {
		en = "Mission reward lines colour",
	},
	curio_mission_rewards_color_preset = {
		en = "Preset",
	},
	curio_mission_rewards_color_r = {
		en = "Red",
	},
	curio_mission_rewards_color_g = {
		en = "Green",
	},
	curio_mission_rewards_color_b = {
		en = "Blue",
	},
	curio_revive_speed_color_group = {
		en = "Revive speed lines colour",
	},
	curio_revive_speed_color_preset = {
		en = "Preset",
	},
	curio_revive_speed_color_r = {
		en = "Red",
	},
	curio_revive_speed_color_g = {
		en = "Green",
	},
	curio_revive_speed_color_b = {
		en = "Blue",
	},
	color_preset_red = {
		en = "Red",
	},
	color_preset_light_blue = {
		en = "Light blue",
	},
	color_preset_sky_blue = {
		en = "Sky blue",
	},
	color_preset_purple = {
		en = "Purple",
	},
	color_preset_pink = {
		en = "Pink",
	},
	color_preset_orange = {
		en = "Orange",
	},
	color_preset_yellow = {
		en = "Yellow",
	},
	color_preset_gold = {
		en = "Gold",
	},
	color_preset_green = {
		en = "Green",
	},
	color_preset_light_green = {
		en = "Light green",
	},
	color_preset_terminal_green = {
		en = "Terminal green",
	},
	color_preset_white = {
		en = "White",
	},
	color_preset_neutral = {
		en = "Neutral",
	},
	color_preset_custom = {
		en = "Custom colour",
	},
	color_preset_mode_default = {
		en = "Mode default",
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
	weapon_images_size_position_group = {
		en = "Weapons images size and position",
	},
	curio_images_size_position_group = {
		en = "Curios images size and position",
	},
	image_layout_character_overview = {
		en = "Character Overview",
	},
	image_layout_inventory_hadron = {
		en = "Inventory and Hadron",
	},
	image_layout_armoury_exchange = {
		en = "Armoury Exchange store",
	},
	image_layout_global_store = {
		en = "Armoury Exchange GlobalStore",
	},
	image_layout_grid_profile = {
		en = "Grid-column profile to edit",
	},
	image_layout_grid_profile_tooltip = {
		en = "Selects which independent column layout the four controls below edit. Cards automatically use the profile matching their actual column count.",
	},
	image_layout_single_column = {
		en = "Single column (grid mode off)",
	},
	image_layout_two_columns = {
		en = "2 column grid mode",
	},
	image_layout_three_columns = {
		en = "3 column grid mode",
	},
	image_layout_four_columns = {
		en = "4 column grid mode",
	},
	image_layout_five_columns = {
		en = "5 column grid mode",
	},
	image_layout_x_offset_percent = {
		en = "Image X offset (%%)",
	},
	image_layout_y_offset_percent = {
		en = "Image Y offset (%%)",
	},
	image_layout_width_offset_percent = {
		en = "Image width offset (%%)",
	},
	image_layout_height_offset_percent = {
		en = "Image height offset (%%)",
	},
	image_layout_position_tooltip = {
		en = "Adds a percentage of the resolved card width or height to the native image position. Zero preserves the current layout. Reopen the relevant view after changing it.",
	},
	image_layout_size_tooltip = {
		en = "Adds this percentage to the resolved native image size. Zero preserves the current size; -50 halves it and 100 doubles it. Reopen the relevant view after changing it.",
	},
	weapon_perk_reload_heavy = {
		en = "Reload",
	},
}

return localization
