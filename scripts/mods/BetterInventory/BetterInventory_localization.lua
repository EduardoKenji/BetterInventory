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
	inventory_sorting_group = {
		en = "Inventory sorting",
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
		en = "Places weapons with four attributes at 80 and the fifth at 60 or higher ahead of ordinary items. Equipped and favorited items retain higher priority. The in-inventory checkbox is available in the scalable panel.",
	},
	prioritize_perfect_roll_weapons_inventory_label = {
		en = "Perfect-roll weapons at the top",
	},
	enable_inventory_options_panel_prototype = {
		en = "Use scalable inventory-options panel prototype",
	},
	enable_inventory_options_panel_prototype_tooltip = {
		en = "Research prototype. After reopening the inventory, places BetterInventory's synchronized controls inside one bounded, scrollable Darktide panel with clickable collapsible section headers. Disable it to restore the established loose controls.",
	},
	inventory_options_panel_geometry_group = {
		en = "Scalable inventory panel (experimental)",
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
		en = "Experimental scalable-panel geometry. Reopen the inventory after changing this value.",
	},
	option_requires_inventory_options_panel_prototype = {
		en = "Requires the scalable inventory-options panel prototype.",
	},
	prioritize_equipped_favorites_inventory_label = {
		en = "Equipped and favorited items at the top",
	},
	inventory_sorting_inventory_label = {
		en = "Sorting",
	},
	inventory_discard_management_inventory_label = {
		en = "Manual/Automated Item Discard Management",
	},
	inventory_manual_discard_management_inventory_label = {
		en = "Manual Item Discard Management",
	},
	inventory_automated_discard_management_inventory_label = {
		en = "Automated Item Discard Management",
	},
	experimental_quick_discard_group = {
		en = "Manual/Automated Item Discard Management",
	},
	enable_experimental_quick_discard = {
		en = "Show quick-discard controls in inventory",
	},
	enable_experimental_quick_discard_tooltip = {
		en = "Adds opt-in discard-management controls below the inventory sorting toggle after the inventory is reopened. Manual mode remains the default.",
	},
	quick_discard_mode = {
		en = "Discard mode",
	},
	quick_discard_mode_tooltip = {
		en = "Manual only discards when you press the inventory button and confirm. Automated performs one protected cleanup pass after each Morningstar entry, following a five-second readiness delay. The manual button remains available in either mode.",
	},
	quick_discard_mode_manual = {
		en = "Manual",
	},
	quick_discard_mode_automatic = {
		en = "Automated",
	},
	quick_discard_skip_automatic_confirmation = {
		en = "Skip confirmation prompts",
	},
	quick_discard_skip_automatic_confirmation_tooltip = {
		en = "Automated mode only. When enabled, the once-per-Morningstar cleanup permanently discards all currently eligible items without asking first. The manual inventory button always retains its confirmation.",
	},
	quick_discard_rarity = {
		en = "Discard rarity threshold",
	},
	quick_discard_rarity_tooltip = {
		en = "Only items at this rarity or below are considered. The compact selector in the inventory cycles through the same saved value.",
	},
	quick_discard_rarity_1 = {
		en = "Profane",
	},
	quick_discard_rarity_2 = {
		en = "Redeemed",
	},
	quick_discard_rarity_3 = {
		en = "Anointed",
	},
	quick_discard_rarity_4 = {
		en = "Exalted",
	},
	quick_discard_rarity_5 = {
		en = "Transcendent",
	},
	quick_discard_max_item_level = {
		en = "Maximum item level to discard",
	},
	quick_discard_max_item_level_tooltip = {
		en = "Items above this displayed item level are protected even when their rarity matches. Set this conservatively while testing the feature.",
	},
	quick_discard_protect_above_equipped_level = {
		en = "Do not discard higher item level than equipped",
	},
	quick_discard_protect_above_equipped_level_tooltip = {
		en = "Protects an item when its displayed item level exceeds the highest equipped item of the same category across the active and every saved loadout. Melee weapons, ranged weapons and Curios are compared separately.",
	},
	quick_discard_include_melee = {
		en = "Allow melee weapons",
	},
	quick_discard_include_ranged = {
		en = "Allow ranged weapons",
	},
	quick_discard_include_curios = {
		en = "Allow Curios",
	},
	quick_discard_protect_perfect_weapons = {
		en = "Do not discard perfect-roll weapons",
	},
	quick_discard_protect_perfect_weapons_tooltip = {
		en = "Protects weapons that already have, or Darktide's maximum-expertise preview predicts will have, four displayed attributes at 80 plus one at 60 or higher. A completed raw 380 allocation can display 381 or 382 because each attribute is rounded independently.",
	},
	quick_discard_protect_high_level_curios = {
		en = "Keep curios of a minimum item level",
	},
	quick_discard_protect_high_level_curios_tooltip = {
		en = "Protects Curios at or above the configured minimum item level, regardless of rarity. Curio-type filters remain configurable while this option is off.",
	},
	quick_discard_curio_protection_level = {
		en = "Minimum item level to keep curios",
	},
	quick_discard_curio_protection_level_tooltip = {
		en = "Curios at or above this displayed item level are protected when their primary blessing type is enabled below. This setting is shown only while minimum-item-level Curio protection is enabled. The default is 410.",
	},
	quick_discard_keep_health_curios = {
		en = "Keep Health Curios",
	},
	quick_discard_keep_toughness_curios = {
		en = "Keep Toughness Curios",
	},
	quick_discard_keep_wound_curios = {
		en = "Keep Wound Curios",
	},
	quick_discard_keep_stamina_curios = {
		en = "Keep Stamina Curios",
	},
	quick_discard_keep_curio_type_tooltip = {
		en = "Selects the Curio primary blessing types protected by the minimum-item-level rule. These filters can be configured independently while that rule is off. All types default to enabled. Unknown future Curio types fail safe and remain protected.",
	},
	quick_discard_show_type_breakdown = {
		en = "Show equipment-type counts in confirmation",
	},
	quick_discard_show_type_breakdown_tooltip = {
		en = "Adds melee weapon, ranged weapon and Curio counts to each rarity line in the quick-discard confirmation. This presentation option is available only in mod options and is enabled by default.",
	},
	quick_discard_show_summary_notification = {
		en = "Show automated discard notification",
	},
	quick_discard_show_summary_notification_tooltip = {
		en = "Shows a native notification after the backend confirms an automated discard, with discarded item counts colored by rarity. Manual discard completion remains owned by Darktide's native inventory flow.",
	},
	quick_discard_inventory_prefix = {
		en = "Discard all",
	},
	quick_discard_inventory_mode = {
		en = "Mode",
	},
	quick_discard_inventory_suffix = {
		en = "and below",
	},
	quick_discard_inventory_action = {
		en = "CLICK TO DISCARD",
	},
	quick_discard_inventory_max_level = {
		en = "Maximum item level to discard",
	},
	quick_discard_inventory_item_types_label = {
		en = "Types of items to discard:",
	},
	quick_discard_inventory_melee = {
		en = "Melee",
	},
	quick_discard_inventory_ranged = {
		en = "Ranged",
	},
	quick_discard_inventory_curios = {
		en = "Curios",
	},
	quick_discard_inventory_curio_level = {
		en = "Minimum item level to keep curios",
	},
	quick_discard_inventory_protect_above_equipped_level = {
		en = "Do not discard higher item level than equipped",
	},
	quick_discard_inventory_keep_curio_types_label = {
		en = "Keep curios of this type:",
	},
	quick_discard_inventory_protect_weapons = {
		en = "Do not discard perfect-roll weapons",
	},
	quick_discard_inventory_protect_curios = {
		en = "Keep curios of a minimum item level",
	},
	quick_discard_inventory_keep_health_curios = {
		en = "Health",
	},
	quick_discard_inventory_keep_toughness_curios = {
		en = "Toughness",
	},
	quick_discard_inventory_keep_wound_curios = {
		en = "Wounds",
	},
	quick_discard_inventory_keep_stamina_curios = {
		en = "Stamina",
	},
	quick_discard_automatic_confirmation_title = {
		en = "Confirm automated discard",
	},
	quick_discard_confirmation_title = {
		en = "Confirm quick discard",
	},
	quick_discard_confirmation_description = {
		en = "non-favorited, non-equipped item(s) from the enabled equipment types will be permanently discarded. Protected items are excluded.",
	},
	quick_discard_summary_melee_singular = {
		en = "melee weapon",
	},
	quick_discard_summary_melee_plural = {
		en = "melee weapons",
	},
	quick_discard_summary_ranged_singular = {
		en = "ranged weapon",
	},
	quick_discard_summary_ranged_plural = {
		en = "ranged weapons",
	},
	quick_discard_summary_curio_singular = {
		en = "Curio",
	},
	quick_discard_summary_curio_plural = {
		en = "Curios",
	},
	quick_discard_summary_and = {
		en = "and",
	},
	quick_discard_confirmation_warning = {
		en = "This action cannot be undone.",
	},
	quick_discard_confirmation_yes = {
		en = "Yes, discard items",
	},
	quick_discard_confirmation_no = {
		en = "No, keep items",
	},
	quick_discard_nothing_title = {
		en = "No eligible items",
	},
	quick_discard_nothing_description = {
		en = "No items in this inventory match the current quick-discard filters. Favorited, equipped and protected items are always excluded.",
	},
	quick_discard_automatic_nothing_description = {
		en = "The automated Morningstar scan completed, but no items match the current discard filters. Favorited, equipped and protected items are always excluded.",
	},
	quick_discard_automatic_nothing_notification_title = {
		en = "No items found to discard",
	},
	quick_discard_automatic_nothing_notification_description = {
		en = "The automated Morningstar scan found no eligible items.",
	},
	quick_discard_notification_title = {
		en = "Discarded items:",
	},
	quick_discard_notification_items = {
		en = "items",
	},
	quick_discard_close = {
		en = "Close",
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
	quick_look_card_integration_group = {
		en = "Mod integration: Quick Look Card",
	},
	enable_quick_look_card_single_column_integration = {
		en = "Support Quick Look Card in single-column mode",
	},
	enable_quick_look_card_single_column_integration_tooltip = {
		en = "When Quick Look Card is installed, keeps its five weapon modifier stats while Better Inventory renders the perk and blessing rows. Disable this to leave Quick Look Card's native single-column card content untouched. Reopen the inventory after changing this option.",
	},
	enable_quick_look_card_grid_integration = {
		en = "Support Quick Look Card in grid mode",
	},
	enable_quick_look_card_grid_integration_tooltip = {
		en = "When Quick Look Card is installed, shows its lowest weapon modifier on Better Inventory grid cards. Quick Look Card's other grid passes remain hidden to prevent duplicate or overlapping details. Reopen the inventory after changing this option.",
	},
	quick_look_card_grid_stat_position = {
		en = "Lowest modifier position",
	},
	quick_look_card_grid_stat_position_tooltip = {
		en = "Places Quick Look Card's lowest weapon modifier above the weapon power or beside the weapon name. Name-side positions reserve card width and automatically fall back above the power on cards too narrow to keep the name readable.",
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
		en = "Lowest modifier font size",
	},
	quick_look_card_grid_font_size_tooltip = {
		en = "Controls the grid dump-stat label size. Reopen the inventory after changing this value.",
	},
	quick_look_card_grid_bottom_padding = {
		en = "Lowest modifier bottom padding",
	},
	quick_look_card_grid_bottom_padding_tooltip = {
		en = "Controls the distance in pixels between the pink modifier label and the card's bottom edge when it is above weapon power. Lower values move it closer to the power value. Reopen the inventory after changing this value.",
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
	option_requires_quick_look_card_grid_integration = {
		en = "Enable Quick Look Card grid integration to use this option.",
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
	option_requires_weapon_perks = {
		en = "Enable weapon perk text to use this option.",
	},
	option_requires_perk_rank_symbols = {
		en = "Enable perk level symbols to set their size.",
	},
	option_requires_weapon_blessings = {
		en = "Select blessing Icons to use this option.",
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
	color_preset_sky_blue = {
		en = "Sky blue",
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
	color_preset_light_green = {
		en = "Light green",
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
