local localization = {
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
	armoury_native_sorting_header = {
		en = "Darktide Native Sorting",
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
	quick_discard_disable_no_eligible_notification = {
		en = "Disable notification when no eligible discard items are found",
	},
	quick_discard_disable_no_eligible_notification_tooltip = {
		en = "Suppresses the Morningstar automatic-discard notification when no items match the current filters. Successful discard notifications are unaffected.",
	},
	automatic_curio_buyer_group = {
		en = "Automatic Curio Buyer",
	},
	enable_automatic_curio_acquisition = {
		en = "Enable automatic curio acquisition",
	},
	enable_automatic_curio_acquisition_tooltip = {
		en = "Performs one cross-character Armoury Exchange scan after each Morningstar entry and automatically purchases every Curio matching the enabled item-level, primary-roll, type and target filters. Targets can be selected by class or by individual character. This spends Ordo Dockets without a confirmation prompt. Automatic discard finishes first, and Curios matching the acquisition rule remain protected from later automatic-discard passes.",
	},
	automatic_curio_min_item_level = {
		en = "Minimum curio item level to acquire",
	},
	automatic_curio_min_item_level_tooltip = {
		en = "Only Armoury Curios at or above this displayed item level are eligible. Health and Toughness Curios must also meet their enabled minimum-roll setting. Every matching offer for every enabled target is purchased when sufficient currency is available. The default is 410.",
	},
	automatic_curio_diagnostic_logging = {
		en = "Enable detailed diagnostic logging",
	},
	automatic_curio_diagnostic_logging_tooltip = {
		en = "Writes per-character, per-Curio and revalidation details to Darktide's shared session log during the single Morningstar scan. Disabled by default to minimize disk-log growth; failures are still logged.",
	},
	automatic_curio_disable_no_eligible_notification = {
		en = "Disable notification when no eligible Curios are found",
	},
	automatic_curio_disable_no_eligible_notification_tooltip = {
		en = "Suppresses the Automatic Curio Buyer notification when no Curios match the current filters. Purchase, insufficient-funds and failure notifications are unaffected.",
	},
	automatic_curio_target_mode = {
		en = "Curio acquisition targets",
	},
	automatic_curio_target_mode_tooltip = {
		en = "Characters is the default and lets each discovered operative be enabled independently. Classes applies each class checkbox to every operative of that class. New characters are enabled automatically; a confirmed empty character scan safely falls back to Classes.",
	},
	automatic_curio_target_mode_classes = {
		en = "Classes",
	},
	automatic_curio_target_mode_characters = {
		en = "Characters",
	},
	automatic_curio_target_mode_inventory_suffix = {
		en = "to acquire curios:",
	},
	automatic_curio_types_group = {
		en = "Curio types we are looking for:",
	},
	automatic_curio_buy_health = {
		en = "Health",
	},
	automatic_curio_min_health = {
		en = "Minimum Health (%%)",
	},
	automatic_curio_min_health_tooltip = {
		en = "A Health Curio must meet both this primary-roll threshold and the minimum item level. The comparison is inclusive. The default is 21%%.",
	},
	automatic_curio_buy_toughness = {
		en = "Toughness",
	},
	automatic_curio_min_toughness = {
		en = "Minimum Toughness (%%)",
	},
	automatic_curio_min_toughness_tooltip = {
		en = "A Toughness Curio must meet both this primary-roll threshold and the minimum item level. The comparison is inclusive. The default is 17%%.",
	},
	automatic_curio_buy_stamina = {
		en = "Stamina",
	},
	automatic_curio_buy_wounds = {
		en = "Wound",
	},
	automatic_curio_classes_group = {
		en = "Classes to acquire curios:",
	},
	automatic_curio_characters_group = {
		en = "Characters to acquire curios:",
	},
	automatic_curio_characters_discovering = {
		en = "Discovering characters... Reopen mod options shortly, or use the inventory options panel.",
	},
	automatic_curio_characters_discovering_inventory = {
		en = "Discovering characters...",
	},
	automatic_curio_character_options_placeholder = {
		en = "Discovering characters...",
	},
	automatic_curio_character_slot_placeholder = {
		en = "Character",
	},
	automatic_curio_character_slot_unavailable = {
		en = "(not currently found)",
	},
	automatic_curio_character_slot_empty_reason = {
		en = "No operative is currently assigned to this slot. BetterInventory refreshes the roster after entering the Morningstar and periodically while in the hub.",
	},
	automatic_curio_class_veteran = {
		en = "Veteran",
	},
	automatic_curio_class_zealot = {
		en = "Zealot",
	},
	automatic_curio_class_psyker = {
		en = "Psyker",
	},
	automatic_curio_class_ogryn = {
		en = "Ogryn",
	},
	automatic_curio_class_adamant = {
		en = "Arbites",
	},
	automatic_curio_class_broker = {
		en = "Hive Scum",
	},
	automatic_curio_class_cryptic = {
		en = "Skitarii",
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
	automatic_curio_buyer_inventory_label = {
		en = "Automatic Curio Buyer",
	},
	automatic_curio_types_inventory_label = {
		en = "Curio types we are looking for:",
	},
	automatic_curio_classes_inventory_label = {
		en = "Classes to acquire curios:",
	},
	automatic_curio_characters_inventory_label = {
		en = "Characters to acquire curios:",
	},
	automatic_curio_health = {
		en = "Health",
	},
	automatic_curio_toughness = {
		en = "Toughness",
	},
	automatic_curio_stamina = {
		en = "Stamina",
	},
	automatic_curio_wounds = {
		en = "Wound",
	},
	automatic_curio_purchased_title = {
		en = "Automatic Curio Buyer - Purchased Curios:",
	},
	automatic_curio_insufficient_title = {
		en = "Automatic Curio Buyer - Insufficient Ordo Dockets for:",
	},
	automatic_curio_currency_spent_label = {
		en = "Spent:",
	},
	automatic_curio_none_title = {
		en = "No eligible Curios found",
	},
	automatic_curio_none_description = {
		en = "The Morningstar Armoury scan found no Curios matching the current automatic-buyer filters.",
	},
	automatic_curio_failed_title = {
		en = "Automatic Curio Buyer could not finish",
	},
	automatic_curio_failed_description = {
		en = "The Armoury or wallet backend could not be validated. No failed or ambiguous purchase was retried automatically.",
	},
	automatic_curio_partial_failure = {
		en = "- The remaining queue stopped after a backend validation failure.",
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
	hadron_additional_views_group = {
		en = "Hadron",
	},
	armoury_exchange_views_group = {
		en = "Armoury Exchange",
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
	enable_character_overview_ranged_mirror = {
		en = "Mirror ranged weapon single-column format from inventory",
	},
	enable_character_overview_ranged_mirror_tooltip = {
		en = "Uses the detailed BetterInventory single-column card for the equipped ranged weapon on the character overview screen. Enabled by default.",
	},
	enable_character_overview_curio_details = {
		en = "Show detailed Curio card on character overview",
	},
	enable_character_overview_curio_details_tooltip = {
		en = "Shows the equipped Curio's primary and secondary stats in a compact BetterInventory card on the character overview screen. Enabled by default.",
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
	myfavorites_integration_group = {
		en = "Mod Integration: MyFavorites",
	},
	myfavorites_show_favorite_letter = {
		en = "Show F below favorite icon",
	},
	myfavorites_show_favorite_letter_tooltip = {
		en = "Adds a compact F beneath the coloured MyFavorites icon. Disabled by default.",
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
	custom_item_name_and_colors_group = {
		en = "Custom Item Names and Colors",
	},
	enable_custom_item_name_and_colors = {
		en = "Enable custom item names and colors",
	},
	enable_custom_item_name_and_colors_tooltip = {
		en = "Enables BetterInventory's standalone per-item name, name-color and background-color editor. Does not require Name It.",
	},
	custom_item_name_keybind = {
		en = "Change Name keybind",
	},
	custom_item_name_keybind_tooltip = {
		en = "Opens the name editor directly. When Name It is installed, BetterInventory uses its configured Change Name key and replaces its duplicate inventory action.",
	},
	custom_item_name_color_keybind = {
		en = "Name Color keybind",
	},
	custom_item_name_color_keybind_tooltip = {
		en = "Opens the item-name RGB selector directly.",
	},
	custom_item_background_color_keybind = {
		en = "Background Color keybind",
	},
	custom_item_background_color_keybind_tooltip = {
		en = "Opens the item-background RGB selector directly.",
	},
	custom_item_editor_keybind_e = {
		en = "[E]",
	},
	custom_item_editor_keybind_q = {
		en = "[Q]",
	},
	custom_item_editor_keybind_v = {
		en = "[V]",
	},
	custom_item_editor_keybind_r = {
		en = "[R]",
	},
	custom_item_editor_keybind_off = {
		en = "Off",
	},
	custom_item_skip_confirmation_prompts = {
		en = "Skip confirmation prompts",
	},
	custom_item_skip_confirmation_prompts_tooltip = {
		en = "Immediately applies reset actions instead of asking for confirmation. Enabled by default.",
	},
	custom_item_preserve_card_shading = {
		en = "Preserve Darktide Equipment Card Shading",
	},
	custom_item_preserve_card_shading_tooltip = {
		en = "Uses Darktide's dark base layer beneath custom background colors. Disable this to paint the entire card with the selected color. This is the default for newly painted backgrounds; each item retains the choice confirmed in its Background Color prompt.",
	},
	custom_item_override_weapon_information_color = {
		en = "Apply custom color to weapon information",
	},
	custom_item_override_weapon_information_color_tooltip = {
		en = "Uses an item's custom background color for the weapon-information header. Darktide's native dark base and gradient shading are always preserved in this panel.",
	},
	custom_item_override_weapon_rarity_keyword_color = {
		en = "Apply custom color to rarity keyword",
	},
	custom_item_override_weapon_rarity_keyword_color_tooltip = {
		en = "Uses an item's custom background color for its rarity keyword in the weapon-information panel.",
	},
	custom_item_override_weapon_information_name_color = {
		en = "Apply custom name color to weapon information",
	},
	custom_item_override_weapon_information_name_color_tooltip = {
		en = "Uses an item's custom name color for its name in the weapon-information panel.",
	},
	option_requires_custom_item_name_and_colors = {
		en = "Enable custom item names and colors to use this option.",
	},
	name_it_force_curio_name_in_detailed_mode = {
		en = "Show Curio name with all four attributes",
	},
	name_it_force_curio_name_in_detailed_mode_tooltip = {
		en = "Shows every Curio name in a reserved two-line title area above the primary attribute and three secondary attributes. Works with or without Name It. Reopen the current view after changing this option.",
	},
	curio_content_name_it_curio_name = {
		en = "Show Curio name with all four attributes",
	},
	curio_content_name_it_curio_name_tooltip = {
		en = "Shows every Curio name in a reserved two-line title area above the primary attribute and three secondary attributes. Works with or without Name It. Reopen the current view after changing this option.",
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
	color_preset_pink = {
		en = "Pink",
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

local zh_cn = {
	mod_name = "BetterInventory",
	mod_description = "为《暗潮》提供响应式且完整保留信息的库存布局。",
	automatic_curio_buyer_group = "自动珍品购买器",
	enable_automatic_curio_acquisition = "启用自动获取珍品",
	enable_automatic_curio_acquisition_tooltip = "每次进入晨星号后，对所有角色的军械库交易所执行一次扫描，并自动购买符合物品等级、主要属性数值、类型和职业筛选条件的所有珍品。此功能会在没有确认提示的情况下花费审判庭双子币。自动丢弃会先完成，且符合获取规则的珍品会在以后的自动丢弃流程中保持受保护状态。",
	automatic_curio_min_item_level = "获取珍品的最低物品等级",
	automatic_curio_min_item_level_tooltip = "只有显示物品等级达到或超过此值的军械库珍品才符合条件。生命和韧性珍品还必须达到对应的最低主要属性数值。货币充足时，会购买所有已启用职业的每个匹配商品。默认值为 410。",
	automatic_curio_diagnostic_logging = "启用详细诊断日志",
	automatic_curio_diagnostic_logging_tooltip = "在每次晨星号单次扫描期间，将每个角色、每件珍品和重新验证的详细信息写入《暗潮》的共享会话日志。默认关闭以尽量减少磁盘日志增长；错误仍会记录。",
	automatic_curio_disable_no_eligible_notification = "未找到符合条件的珍品时禁用通知",
	automatic_curio_disable_no_eligible_notification_tooltip = "当没有珍品符合当前筛选条件时，隐藏自动珍品购买器通知。购买、资金不足和失败通知不受影响。",
	automatic_curio_types_group = "我们正在寻找的珍品类型：",
	automatic_curio_buy_health = "生命",
	automatic_curio_min_health = "最低生命值 (%%)",
	automatic_curio_min_health_tooltip = "生命珍品必须同时达到此主要属性阈值和最低物品等级。比较包含等于阈值的情况。默认值为 21%%。",
	automatic_curio_buy_toughness = "韧性",
	automatic_curio_min_toughness = "最低韧性值 (%%)",
	automatic_curio_min_toughness_tooltip = "韧性珍品必须同时达到此主要属性阈值和最低物品等级。比较包含等于阈值的情况。默认值为 17%%。",
	automatic_curio_buy_stamina = "体力",
	automatic_curio_buy_wounds = "伤口",
	automatic_curio_classes_group = "要获取珍品的职业：",
	automatic_curio_class_veteran = "老兵",
	automatic_curio_class_zealot = "狂信徒",
	automatic_curio_class_psyker = "灵能者",
	automatic_curio_class_ogryn = "欧格林",
	automatic_curio_class_adamant = "法务官",
	automatic_curio_class_broker = "巢都渣滓",
	automatic_curio_class_cryptic = "护教军",
	option_requires_automatic_curio_acquisition = "需要启用自动获取珍品。",
	option_requires_automatic_curio_classes_mode = "请选择职业作为珍品获取目标模式。",
	option_requires_automatic_curio_characters_mode = "请选择角色作为珍品获取目标模式。",
	option_requires_automatic_curio_health = "需要启用生命珍品。",
	option_requires_automatic_curio_toughness = "需要启用韧性珍品。",
	automatic_curio_buyer_inventory_label = "自动珍品购买器",
	automatic_curio_types_inventory_label = "我们正在寻找的珍品类型：",
	automatic_curio_classes_inventory_label = "要获取珍品的职业：",
	automatic_curio_health = "生命",
	automatic_curio_toughness = "韧性",
	automatic_curio_stamina = "体力",
	automatic_curio_wounds = "伤口",
	automatic_curio_purchased_title = "自动珍品购买器 - 已购买珍品：",
	automatic_curio_insufficient_title = "自动珍品购买器 - 以下珍品的审判庭双子币不足：",
	automatic_curio_currency_spent_label = "已花费：",
	automatic_curio_none_title = "未找到符合条件的珍品",
	automatic_curio_none_description = "晨星号军械库扫描未找到符合当前自动购买筛选条件的珍品。",
	automatic_curio_failed_title = "自动珍品购买器未能完成",
	automatic_curio_failed_description = "无法验证军械库或钱包后端。失败或结果不明确的购买不会被自动重试。",
	automatic_curio_partial_failure = "- 后端验证失败后，剩余购买队列已停止。",
	inventory_slots_group = "适用库存",
	inventory_sorting_group = "库存排序",
	prioritize_equipped_favorites = "已装备和收藏物品置顶",
	prioritize_equipped_favorites_tooltip = "在近战、远程和珍品库存中，将已装备物品置于最前，收藏物品置于其后，同时仍由所选的原生排序方式排列各组。同步开关显示在珍品详情或武器操作按钮下方，并会在游戏会话间保存。",
	prioritize_perfect_roll_weapons = "完美属性武器置顶",
	prioritize_perfect_roll_weapons_tooltip = "将四项属性为 80、第五项为 60 或更高的武器置于普通物品之前。已装备和收藏物品仍拥有更高优先级。库存内的复选框位于可缩放面板中。",
	prioritize_perfect_roll_weapons_inventory_label = "完美属性武器置顶",
	enable_inventory_options_panel_prototype = "使用可扩展的库存选项面板原型",
	enable_inventory_options_panel_prototype_tooltip = "研究原型。重新打开库存后，将 BetterInventory 的同步控件集中到一个有边界、可滚动且带可点击折叠标题的《暗潮》面板中。关闭后恢复原有的独立控件。",
	inventory_options_panel_geometry_group = "可缩放库存面板（实验性）",
	curio_information_width_percent = "珍品信息窗口宽度(%%)",
	curio_preview_height_percent = "珍品预览区域高度 (%%)",
	curio_preview_height_percent_tooltip = "将上部珍品预览区域及其物品艺术一起缩放以保留原始宽高比。更改后重新打开库存。",
	inventory_options_panel_width = "选项面板宽度 (px)",
	inventory_options_panel_max_height = "选项面板最大高度 (px)",
	inventory_options_panel_row_spacing = "选项面板行距（px）",
	inventory_options_panel_padding_top = "选项面板顶部内边距 (px)",
	inventory_options_panel_padding_bottom = "选项面板底部填充（px）",
	inventory_options_panel_padding_left = "选项面板左内边距 (px)",
	inventory_options_panel_padding_right = "选项面板右内边距 (px)",
	inventory_options_geometry_reopen_tooltip = "实验性可扩展面板几何形状。更改此值后重新打开库存。",
	option_requires_inventory_options_panel_prototype = "需要可扩展的库存选项面板原型。",
	prioritize_equipped_favorites_inventory_label = "装备和收藏的物品位于顶部",
	inventory_sorting_inventory_label = "排序",
	armoury_native_sorting_header = "Darktide 原生排序",
	inventory_discard_management_inventory_label = "手动/自动物品丢弃管理",
	inventory_manual_discard_management_inventory_label = "手动物品丢弃管理",
	inventory_automated_discard_management_inventory_label = "自动物品丢弃管理",
	experimental_quick_discard_group = "手动/自动物品丢弃管理",
	enable_experimental_quick_discard = "在库存中显示快速丢弃控件",
	enable_experimental_quick_discard_tooltip = "重新打开库存后，在库存排序开关下方添加选择加入丢弃管理控件。手动模式仍为默认模式。",
	quick_discard_mode = "丢弃模式",
	quick_discard_mode_tooltip = "手动模式仅在按下库存按钮并确认后丢弃物品。自动模式会在每次进入晨星号并等待五秒就绪后执行一次受保护的清理。两种模式均保留手动按钮。",
	quick_discard_mode_manual = "手动",
	quick_discard_mode_automatic = "自动",
	quick_discard_skip_automatic_confirmation = "跳过确认提示",
	quick_discard_skip_automatic_confirmation_tooltip = "仅用于自动模式。启用后，每次进入晨星号时的清理会直接永久丢弃当前所有符合条件的物品，不再询问。库存中的手动按钮始终保留确认提示。",
	quick_discard_rarity = "丢弃稀有度阈值",
	quick_discard_rarity_tooltip = "仅考虑此稀有度或以下的物品。库存中的紧凑选择器循环使用相同的保存值。",
	quick_discard_rarity_1 = "亵渎",
	quick_discard_rarity_2 = "救赎",
	quick_discard_rarity_3 = "受膏",
	quick_discard_rarity_4 = "崇高",
	quick_discard_rarity_5 = "超凡",
	quick_discard_max_item_level = "可丢弃的最高物品等级",
	quick_discard_max_item_level_tooltip = "即使稀有度符合条件，显示物品等级高于此值的物品仍会受到保护。测试此功能时请谨慎设置。",
	quick_discard_protect_above_equipped_level = "不丢弃物品等级高于已装备物品的装备",
	quick_discard_protect_above_equipped_level_tooltip = "如果物品的显示等级高于当前配置及所有已保存配装中同类别已装备物品的最高等级，则保护该物品。近战武器、远程武器和珍品分别比较。",
	quick_discard_include_melee = "允许近战武器",
	quick_discard_include_ranged = "允许远程武器",
	quick_discard_include_curios = "允许珍品",
	quick_discard_protect_perfect_weapons = "不要丢弃完美属性武器",
	quick_discard_protect_perfect_weapons_tooltip = "保护当前已有或经《暗潮》最高专精预览后预计会达到四项显示属性为 80、另一项为 60 或更高的武器。完整的原始 380 点分配可能显示为 381 或 382，因为各项属性会独立取整。",
	quick_discard_protect_high_level_curios = "保留达到最低物品等级的珍品",
	quick_discard_protect_high_level_curios_tooltip = "无论稀有度如何，保护达到或超过所设最低物品等级的珍品。关闭此选项时仍可配置珍品类型筛选。",
	quick_discard_curio_protection_level = "保留珍品的最低物品等级",
	quick_discard_curio_protection_level_tooltip = "当珍品的主要祝福类型在下方启用时，保护显示物品等级达到或超过此值的珍品。仅在启用珍品最低等级保护时显示。默认值为 410。",
	quick_discard_keep_health_curios = "保留生命珍品",
	quick_discard_keep_toughness_curios = "保留韧性珍品",
	quick_discard_keep_wound_curios = "保留伤口珍品",
	quick_discard_keep_stamina_curios = "保留体力珍品",
	quick_discard_keep_curio_type_tooltip = "选择受最低物品等级规则保护的珍品主要祝福类型。即使该规则关闭，也可单独配置这些筛选。所有类型默认启用；未知的未来珍品类型会安全地保持受保护状态。",
	quick_discard_show_type_breakdown = "在确认窗口中显示装备类型数量",
	quick_discard_show_type_breakdown_tooltip = "在快速丢弃确认窗口的每个稀有度行中显示近战武器、远程武器和珍品数量。此显示选项仅在模组选项中提供，默认启用。",
	quick_discard_show_summary_notification = "显示自动丢弃通知",
	quick_discard_show_summary_notification_tooltip = "在后端确认自动丢弃后显示原生通知，丢弃的物品数量按稀有度着色。手动丢弃完成仍然属于《暗潮》的原生库存流程。",
	quick_discard_disable_no_eligible_notification = "未找到符合条件的丢弃物品时禁用通知",
	quick_discard_disable_no_eligible_notification_tooltip = "当没有物品符合当前筛选条件时，隐藏晨星号自动丢弃通知。成功丢弃通知不受影响。",
	quick_discard_inventory_prefix = "全部丢弃",
	quick_discard_inventory_mode = "模式",
	quick_discard_inventory_suffix = "及以下",
	quick_discard_inventory_action = "点击丢弃",
	quick_discard_inventory_max_level = "可丢弃的最高物品等级",
	quick_discard_inventory_item_types_label = "要丢弃的物品类型：",
	quick_discard_inventory_melee = "近战",
	quick_discard_inventory_ranged = "远程",
	quick_discard_inventory_curios = "珍品",
	quick_discard_inventory_curio_level = "保留珍品的最低物品等级",
	quick_discard_inventory_protect_above_equipped_level = "不丢弃等级高于已装备物品的装备",
	quick_discard_inventory_keep_curio_types_label = "保留以下类型的珍品：",
	quick_discard_inventory_protect_weapons = "不要丢弃完美属性武器",
	quick_discard_inventory_protect_curios = "保留达到最低物品等级的珍品",
	quick_discard_inventory_keep_health_curios = "生命",
	quick_discard_inventory_keep_toughness_curios = "韧性",
	quick_discard_inventory_keep_wound_curios = "伤口",
	quick_discard_inventory_keep_stamina_curios = "体力",
	quick_discard_automatic_confirmation_title = "确认自动丢弃",
	quick_discard_confirmation_title = "确认快速丢弃",
	quick_discard_confirmation_description = "已启用装备类型中未收藏、未装备的物品将被永久丢弃。受保护物品不会包含在内。",
	quick_discard_summary_melee_singular = "近战武器",
	quick_discard_summary_melee_plural = "近战武器",
	quick_discard_summary_ranged_singular = "远程武器",
	quick_discard_summary_ranged_plural = "远程武器",
	quick_discard_summary_curio_singular = "件珍品",
	quick_discard_summary_curio_plural = "件珍品",
	quick_discard_summary_and = "和",
	quick_discard_confirmation_warning = "此操作无法撤消。",
	quick_discard_confirmation_yes = "是的，丢弃物品",
	quick_discard_confirmation_no = "不，保留物品",
	quick_discard_nothing_title = "没有符合条件的物品",
	quick_discard_nothing_description = "此库存中没有任何物品与当前的快速丢弃过滤器匹配。收藏的、装备的和受保护的物品始终被排除在外。",
	quick_discard_automatic_nothing_description = "自动晨星号扫描已完成，但没有物品与当前丢弃过滤器匹配。收藏的、装备的和受保护的物品始终被排除在外。",
	quick_discard_automatic_nothing_notification_title = "未发现可丢弃的物品",
	quick_discard_automatic_nothing_notification_description = "晨星号自动扫描未发现符合条件的物品。",
	quick_discard_notification_title = "已丢弃物品：",
	quick_discard_notification_items = "件物品",
	quick_discard_close = "关闭",
	enable_melee_inventory = "近战武器",
	enable_ranged_inventory = "远程武器",
	enable_curio_inventory = "珍品",
	additional_views_group = "其他库存视图",
	enable_hadron_entreat_grid = "哈德隆：请求哈德隆",
	enable_hadron_entreat_grid_tooltip = "通过“请求哈德隆”选择物品时使用 BetterInventory 卡片。有效布局最多为三列；哈德隆单独的“献祭武器”流程不受影响。",
	enable_armoury_requisition_grid = "军械库：申领武器与珍品",
	enable_armoury_requisition_grid_tooltip = "在“申领武器与珍品”中使用 BetterInventory 卡片。有效布局最多为三列；布伦特军械库和多干员补给不受影响。",
	expand_armoury_requisition_window = "扩展军械库申领窗口",
	expand_armoury_requisition_window_tooltip = "向右加宽征用武器和珍品网格，并安全地重新定位物品详细信息面板和获取按钮。仅当两列布局的卡片比所选目标窄时，两列布局才会展开。",
	armoury_requisition_target_card_width = "军械库目标卡宽度",
	armoury_requisition_target_card_width_tooltip = "扩展军械库网格所需的卡宽度（以像素为单位）。在三列中，默认值 230 像素为《暗潮》的原生网格宽度增加了 114 像素。",
	layout_group = "网格布局",
	quick_look_card_integration_group = "模组集成：Quick Look Card",
	enable_quick_look_card_single_column_integration = "在单列模式中显示武器属性",
	enable_quick_look_card_single_column_integration_tooltip = "无需安装其他模组即可显示武器五项最大潜力属性。安装 Quick Look Card 时，BetterInventory 会复用并规范其绘制项以避免重复。关闭后将保留 Quick Look Card 原生的单列内容。更改后请重新打开库存。",
	quick_look_card_single_column_font_size = "单列属性字号",
	quick_look_card_single_column_font_size_tooltip = "控制单列模式中五项武器属性区块的字号。更改后请重新打开库存。",
	quick_look_card_single_column_label_value_gap = "单列属性标签与数值间距",
	quick_look_card_single_column_label_value_gap_tooltip = "控制单列模式中每项属性标签与数值之间的水平像素间距。调低可使区块更紧凑，调高可增加分隔。更改后请重新打开库存。",
	quick_look_card_single_column_horizontal_position = "单列属性水平位置（%%）",
	quick_look_card_single_column_horizontal_position_tooltip = "在卡片可用宽度内水平移动五项武器属性区块。0 为左边缘，100 为右边缘。更改后请重新打开库存。",
	quick_look_card_single_column_vertical_position = "单列属性垂直位置（%%）",
	quick_look_card_single_column_vertical_position_tooltip = "在卡片可用高度内垂直移动五项武器属性区块。0 为上边缘，100 为下边缘。更改后请重新打开库存。",
	enable_quick_look_card_grid_integration = "在网格模式中显示最低武器属性",
	enable_quick_look_card_grid_integration_tooltip = "无需安装其他模组即可显示每件武器最低的最大潜力属性。并列时使用显示顺序中的第一项。安装 Quick Look Card 时，其重叠的网格绘制项会保持隐藏。更改后请重新打开库存。",
	quick_look_card_grid_stat_position = "最低属性位置",
	quick_look_card_grid_stat_position_tooltip = "将最低武器属性放在武器威力上方或武器名称旁。名称旁的位置会预留卡片宽度；卡片过窄时会自动回退到武器威力上方，以确保名称可读。",
	quick_look_card_grid_stat_position_above_power = "武器威力上方",
	quick_look_card_grid_stat_position_name_right = "武器名称右侧",
	quick_look_card_grid_stat_position_name_left = "武器名称左侧",
	quick_look_card_grid_font_size = "网格最低属性字号",
	quick_look_card_grid_font_size_tooltip = "控制网格中短板属性标签的字号。更改后请重新打开库存。",
	quick_look_card_grid_bottom_padding = "最低属性底部边距",
	quick_look_card_grid_bottom_padding_tooltip = "控制最低属性标签在武器威力上方显示时，与卡片底边之间的像素距离。数值越低，标签越靠近威力值。更改后请重新打开库存。",
	weapon_modifier_lowest_color_preset = "最低属性颜色预设",
	weapon_modifier_lowest_color_preset_tooltip = "设置网格模式中最低属性及单列五项属性区块中高亮缩写所使用的颜色。",
	weapon_modifier_lowest_color_r = "最低属性颜色红色",
	weapon_modifier_lowest_color_g = "最低属性颜色绿色",
	weapon_modifier_lowest_color_b = "最低属性颜色蓝色",
	weapon_modifier_lowest_color_opacity = "最低属性不透明度",
	weapon_modifier_lowest_color_opacity_tooltip = "设置最低属性文字的不透明度：0%% 为完全透明，100%% 为完全不透明。",
	weapon_modifier_melee_damage = "近战",
	weapon_modifier_ammo = "弹药",
	weapon_modifier_penetration = "穿透",
	weapon_modifier_burn = "燃烧",
	weapon_modifier_charge_rate = "充能",
	weapon_modifier_cleave_damage = "劈伤",
	weapon_modifier_cleave_targets = "劈数",
	weapon_modifier_crowd_control = "控场",
	weapon_modifier_collateral = "远控",
	weapon_modifier_critical_bonus = "暴击",
	weapon_modifier_damage = "伤害",
	weapon_modifier_defences = "防御",
	weapon_modifier_blast_penetration = "爆穿",
	weapon_modifier_blast_damage = "爆伤",
	weapon_modifier_blast_radius = "爆距",
	weapon_modifier_finesse = "娴熟",
	weapon_modifier_shredder = "撕裂",
	weapon_modifier_first_target = "首个",
	weapon_modifier_cloud_radius = "火距",
	weapon_modifier_thermal_resistance = "热阻",
	weapon_modifier_mobility = "机动",
	weapon_modifier_power_output = "能量",
	weapon_modifier_stopping_power = "制动",
	weapon_modifier_range = "范围",
	weapon_modifier_reload_speed = "装弹",
	weapon_modifier_stability = "稳定",
	weapon_modifier_quell_speed = "冷却",
	weapon_modifier_warp_resistance = "亚阻",
	weapon_modifier_heat_management = "热管",
	weapon_modifier_arc_efficiency = "电弧",
	weapon_modifier_cleave_efficiency = "劈效",
	single_column_layout_group = "单列布局",
	single_column_weapon_name_font_size = "武器名称字号",
	single_column_weapon_name_font_size_tooltip = "控制单列模式中的武器名称字号。字号增大时，自动卡片尺寸会相应增加高度，避免名称占用下方详情行。更改后请重新打开库存。",
	single_column_blessing_icons_on_right = "在名称旁显示祝福图标",
	single_column_blessing_icons_on_right_tooltip = "在单列文字模式中，将两个完整的带边框祝福图标并排显示在祝福名称右侧的空间中。等级符号仍保持在名称前方。更改后请重新打开库存。",
	enhanced_descriptions_integration_group = "模组集成：Enhanced Descriptions",
	enable_grid_layout = "启用网格布局",
	enable_grid_layout_tooltip = "使用 BetterInventory 的多列卡片。关闭后保留《暗潮》原生单列尺寸，同时继续使用已启用的卡片内容增强功能。",
	columns = "列数",
	columns_tooltip = "每行显示的物品卡片数量。建议从三列开始。",
	expand_inventory_window = "需要时扩大库存窗口",
	expand_inventory_window_tooltip = "扩展库存面板，使较窄的卡片保持在面板范围内。武器宽度阈值和珍品目标宽度设置控制额外扩展。关闭后则缩小卡片。",
	weapon_extra_width_column_threshold = "应用额外武器宽度的列数",
	weapon_extra_width_column_threshold_tooltip = "选择额外的近战和远程库存宽度是适用于四列和五列网格还是仅适用于五列网格。",
	weapon_extra_width_column_threshold_four_plus = "4 列或更多",
	weapon_extra_width_column_threshold_five_only = "仅 5 列",
	five_column_weapon_extra_width = "额外武器库存宽度",
	five_column_weapon_extra_width_tooltip = "达到所设列数阈值时，为近战和远程库存增加指定像素宽度。默认 80 像素会让四列中的每张卡片增加 20 像素，五列中增加 16 像素。扩展会在操作面板触及屏幕边缘前安全限制。",
	expand_curio_inventory_window = "按列数扩展珍品窗口",
	expand_curio_inventory_window_tooltip = "在添加列时使用目标珍品卡宽度来加宽库存面板。三列通常保留原始面板宽度；四列和五列可以使用可用的水平空间。",
	curio_target_card_width = "目标珍品卡片宽度",
	curio_target_card_width_tooltip = "启用列感知珍品扩展时所需的珍品卡宽度（以像素为单位）。最终面板宽度源自该值、列数和网格间距。",
	grid_spacing = "卡片间距",
	card_height = "卡片高度",
	card_height_tooltip = "手动网格卡高度。当自动卡高度启用时，此控件被禁用。",
	automatic_card_height = "自动卡片高度",
	automatic_card_height_tooltip = "当所选文字行和字号需要更多垂直空间时自动增高卡片。单列卡片也会为已启用的 BetterInventory 专长和祝福行预留足够高度。",
	option_requires_grid_layout = "启用网格布局以使用此选项。",
	option_requires_single_column_mode = "关闭网格布局以使用此单列选项。",
	option_requires_ranked_blessing_text = "选择带等级的祝福文本以使用此选项。",
	option_requires_quick_look_card_single_column_integration = "启用单列武器属性以使用此选项。",
	option_requires_quick_look_card_grid_integration = "启用网格武器属性以使用此选项。",
	option_requires_quick_look_card_above_power = "选择“武器威力上方”后才能使用此选项。",
	option_requires_weapon_extra_width_threshold = "将列增加到配置的额外宽度阈值以使用此选项。",
	option_disabled_by_automatic_height = "禁用自动卡高度以设置手动高度。",
	option_requires_window_expansion = "启用库存窗口扩展以使用此选项。",
	option_requires_curio_expansion = "启用列感知珍品扩展以设置目标卡宽度。",
	option_requires_armoury_grid = "启用军械库征用网格以使用此选项。",
	option_requires_armoury_expansion = "启用军械库征用窗口扩展以设置目标卡宽度。",
	option_requires_weapon_perks = "启用武器专长文字后才能使用此选项。",
	option_requires_perk_rank_symbols = "启用专长等级符号后才能设置其大小。",
	option_requires_weapon_blessings = "选择祝福图标后才能使用此选项。",
	option_requires_single_column_blessing_icons = "启用单列祝福图标后，才能在祝福文字模式中使用此选项。",
	option_requires_detailed_curio_profile = "选择珍品“全部四项属性”模式后才能使用此选项。",
	option_requires_experimental_quick_discard = "启用实验性库存快速丢弃控件以使用此选项。",
	option_requires_automatic_discard_mode = "选择自动丢弃模式以使用此选项。",
	option_requires_curio_discard_protection = "启用最小物品等级珍品保护以设置其阈值。",
	icon_darkness = "图标暗度(%%)",
	card_content_group = "卡片内容",
	append_mark_to_name = "将型号附加到武器名称",
	append_mark_to_name_tooltip = "将武器标题格式化为“Combat Blade Mk VI”一类的形式，并让次要行仅显示武器型号系列。标题过窄需要缩写时仍会保留 Mk 型号。",
	show_pattern_mark = "显示武器型号行",
	show_pattern_mark_tooltip = "显示《暗潮》武器卡片的次要名称。启用“将型号附加到武器名称”后，此行仅显示武器型号系列；否则同时显示系列和 Mk 型号。",
	show_rarity_name = "显示武器品质文字",
	show_rarity_tag = "显示稀有度颜色条",
	weapon_blessing_display_mode = "武器祝福显示",
	weapon_blessing_display_mode_tooltip = "选择完整祝福图标、带罗马数字等级的紧凑名称、带原生等级符号的名称，或隐藏祝福内容。自动卡片高度会预留所需空间。",
	weapon_blessing_display_mode_icons = "图标",
	weapon_blessing_display_mode_text = "文字行",
	weapon_blessing_display_mode_ranked_text = "等级符号 + 文字",
	weapon_blessing_display_mode_off = "关闭",
	blessing_text_item_level_separation = "分开显示祝福文字和物品等级",
	blessing_text_item_level_separation_tooltip = "选择何时将两个祝福名称置于独立的物品等级行上方。默认在较窄的四列和五列库存网格中使用这种更安全、更宽松的布局。",
	blessing_text_item_level_separation_always = "始终",
	blessing_text_item_level_separation_four_plus = "4 列或更多",
	blessing_text_item_level_separation_five_only = "仅 5 列",
	blessing_text_item_level_separation_never = "从不",
	auto_fit_long_blessing_names = "自动适配过长的祝福名称",
	auto_fit_long_blessing_names_tooltip = "仅缩小超出可用宽度的祝福文字，直到其能在物品等级旁完整显示。默认启用。",
	truncate_long_blessing_names = "截断过长的祝福名称",
	truncate_long_blessing_names_tooltip = "强制祝福名称单行显示。如果在可选的自动缩小后仍然过长，会在物品等级区域前用 ... 替换名称末尾。",
	blessing_icon_size = "祝福图标大小",
	option_requires_weapon_blessing_text = "选择祝福文字模式后才能使用此选项。",
	weapon_blessing_text_vertical_spacing = "祝福文字垂直间距",
	weapon_blessing_text_vertical_spacing_tooltip = "设置两行武器祝福文字之间的垂直像素间距。自动卡片高度会预留新增空间。",
	weapon_blessing_text_bottom_padding = "祝福文字底部边距",
	weapon_blessing_text_bottom_padding_tooltip = "设置第二行祝福文字下方的像素间距。预留物品等级行或军械库页脚时，边距会应用在该区域上方。自动卡片高度会预留此空间。",
	weapon_blessing_text_color_preset = "武器祝福文字颜色预设",
	weapon_blessing_text_color_r = "武器祝福文字颜色红色",
	weapon_blessing_text_color_g = "武器祝福文字颜色绿色",
	weapon_blessing_text_color_b = "武器祝福文字颜色蓝色",
	weapon_blessing_text_opacity = "武器祝福文字不透明度",
	weapon_blessing_text_opacity_tooltip = "设置祝福文字不透明度：0%% 为完全透明，100%% 为完全不透明。等级符号保持原生外观。",
	blessing_icon_size_tooltip = "设置每个武器祝福符号的宽度和高度（以像素为单位）。当较大的符号需要更多空间时，卡片高度会自动增加。",
	show_weapon_perks = "显示武器专长文字",
	show_weapon_perks_tooltip = "将两项武器专长分别显示为单独的一行。默认启用；自动卡片高度会预留所需空间，过长文字会先缩小，再以省略号截断。",
	weapon_perk_compression = "武器专长文字压缩",
	weapon_perk_compression_tooltip = "高度压缩为默认设置，适合较窄卡片；普通压缩使用较温和的缩写。未知专长标识符会保留《暗潮》的原始本地化文字。",
	weapon_perk_compression_none = "不压缩",
	weapon_perk_compression_standard = "压缩",
	weapon_perk_compression_heavy = "高度压缩",
	show_weapon_perk_rank_symbols = "显示专长等级符号",
	show_weapon_perk_rank_symbols_tooltip = "在每个可见武器专长行左侧显示《暗潮》的原生专长等级符号。默认启用。",
	weapon_perk_rank_icon_size = "等级符号大小",
	weapon_perk_rank_icon_size_tooltip = "设置武器专长和等级符号+文本祝福使用的原生等级符号的宽度和高度。当较大的符号需要更多空间时，卡片高度会自动增加。",
	option_requires_rank_symbols = "启用专长等级符号或选择“等级符号 + 文字”祝福模式后才能使用此选项。",
	remove_weapon_perk_plus_signs = "移除武器专长文字中的 +",
	remove_weapon_perk_plus_signs_tooltip = "仅移除每个可见武器专长行开头的加号；其他位置的数值和符号保持不变。",
	weapon_perk_text_color_preset = "武器专长文字颜色预设",
	weapon_perk_text_color_r = "武器专长文字颜色预设红色",
	weapon_perk_text_color_g = "武器专长文字颜色预设绿色",
	weapon_perk_text_color_b = "武器专长文字颜色预设蓝色",
	weapon_perk_text_opacity = "武器专长文字不透明度",
	weapon_perk_text_opacity_tooltip = "设置武器专长文字不透明度：0%% 为完全透明，100%% 为完全不透明。专长等级符号保持原生外观。",
	weapon_perk_vertical_spacing = "武器专长垂直间距",
	weapon_perk_vertical_spacing_tooltip = "设置两行武器专长之间的垂直像素间距。自动卡片高度会预留新增空间。",
	weapon_perk_blessing_spacing = "专长与祝福区域间距",
	weapon_perk_blessing_spacing_tooltip = "当武器专长和祝福区域同时可见时，设置两者之间的垂直像素边距。边距超过默认值时，卡片高度会自动增加。",
	option_requires_perk_and_blessing_sections = "同时显示武器专长和武器祝福后才能使用此选项。",
	blessing_icon_spacing = "祝福图标水平间距",
	blessing_icon_spacing_tooltip = "设置武器祝福图标之间的水平像素间距。",
	highlight_equipped_items = "高亮已装备物品",
	highlight_equipped_items_tooltip = "在装备的物品卡周围添加柔和的白色光芒，同时保留《暗潮》的原生装备符号。",
	compact_favorite_marker = "使用紧凑收藏标记",
	favorite_marker_position = "收藏标记位置",
	favorite_marker_position_tooltip = "将收藏标记放在物品威力上方的右上区域或左下角。已装备物品会将右上标记下移，以避开装备徽章。",
	favorite_marker_position_above_rating = "右上角，武器威力上方",
	favorite_marker_position_bottom_left = "左下角",
	item_name_font_size = "物品名称字号",
	minimum_item_name_font_size = "最小物品名称字号",
	minimum_item_name_font_size_tooltip = "长名称会先缩小到此字号，再以省略号截断。名称绝不会换行到系列或型号行。",
	secondary_text_font_size = "型号和稀有度字号",
	expertise_font_size = "专精等级字号",
	show_item_level_icon = "显示物品威力图标",
	show_item_level_icon_tooltip = "在物品威力数字左侧显示《暗潮》的威力图标。默认关闭；数字威力值始终保留。",
	curio_content_group = "珍品内容",
	curio_display_profile = "珍品显示模式",
	curio_display_profile_tooltip = "“全部四项属性”为默认模式，显示主要属性及三项专长。“主要属性”模式保留珍品名称和威力，仅额外显示其主要属性。",
	curio_display_profile_primary = "主要属性",
	curio_display_profile_detailed = "全部四项属性",
	show_curio_item_level = "显示珍品基础等级",
	show_curio_item_level_tooltip = "在两种显示模式的右下角显示珍品的标准化基础等级。默认启用，便于识别 400–430 级珍品。",
	curio_primary_stat_font_size = "珍品主要属性字号",
	curio_primary_stat_font_size_tooltip = "设置两种显示模式中珍品主要生命、韧性、伤口或体力属性行的字号。",
	curio_secondary_stat_font_size = "珍品次要属性字号",
	curio_secondary_stat_font_size_tooltip = "设置“全部四项属性”模式中三行珍品次要专长的字号。",
	curio_primary_secondary_spacing = "珍品主要与次要属性间距",
	curio_primary_secondary_spacing_tooltip = "设置“全部四项属性”模式中珍品主要属性与第一行次要属性之间的垂直像素间距。",
	show_curio_quality = "显示珍品品质文字",
	show_curio_quality_tooltip = "在“主要属性”模式中显示珍品品质行。默认关闭，因为卡片颜色已经表示品质。",
	curio_stat_compression = "珍品属性文字压缩",
	curio_stat_compression_tooltip = "高度压缩为默认设置，使用“减伤、恢复、格挡、疾跑”等紧凑标签；普通压缩使用较温和的缩写。未知描述会保留《暗潮》的原始本地化文字。",
	curio_stat_compression_none = "不压缩",
	curio_stat_compression_standard = "压缩",
	curio_stat_compression_heavy = "高度压缩",
	simplify_curio_primary_stat_text = "简化珍品属性行",
	simplify_curio_primary_stat_text_tooltip = "开启：BetterInventory 会精简受支持的珍品主要和次要属性行。关闭：完整保留《暗潮》或 Enhanced Descriptions 提供的原始措辞。",
	remove_curio_stat_plus_signs = "移除珍品属性行中的 +",
	remove_curio_stat_plus_signs_tooltip = "移除 BetterInventory 珍品卡片中每个属性行开头的 + 号。默认关闭。",
	curio_secondary_text_color_group = "珍品次要属性行颜色",
	curio_secondary_text_color_preset = "预设",
	curio_secondary_text_color_r = "红色",
	curio_secondary_text_color_g = "绿色",
	curio_secondary_text_color_b = "蓝色",
	curio_health_color_group = "最大生命属性行颜色",
	curio_health_color_preset = "预设",
	curio_health_color_r = "红色",
	curio_health_color_g = "绿色",
	curio_health_color_b = "蓝色",
	curio_toughness_color_group = "最大韧性属性行颜色",
	curio_toughness_color_preset = "预设",
	curio_toughness_color_r = "红色",
	curio_toughness_color_g = "绿色",
	curio_toughness_color_b = "蓝色",
	curio_wound_color_group = "伤口属性行颜色",
	curio_wound_color_preset = "预设",
	curio_wound_color_r = "红色",
	curio_wound_color_g = "绿色",
	curio_wound_color_b = "蓝色",
	curio_stamina_color_group = "最大体力属性行颜色",
	curio_stamina_color_preset = "预设",
	curio_stamina_color_r = "红色",
	curio_stamina_color_g = "绿色",
	curio_stamina_color_b = "蓝色",
	color_preset_red = "红色",
	color_preset_light_blue = "浅蓝色",
	color_preset_sky_blue = "天蓝色",
	color_preset_purple = "紫色",
	color_preset_pink = "粉色",
	color_preset_orange = "橙色",
	color_preset_yellow = "黄色",
	color_preset_green = "绿色",
	color_preset_light_green = "浅绿色",
	color_preset_terminal_green = "终端绿色",
	color_preset_neutral = "中性色",
	color_preset_custom = "自定义颜色",
	curio_resistance_flamers = "火焰兵抗性",
	curio_resistance_snipers = "狙击手抗性",
	curio_resistance_grenadiers = "轰炸者抗性",
	curio_resistance_hounds = "瘟疫猎犬抗性",
	curio_resistance_mutants = "变种人抗性",
	curio_resistance_gunners = "炮手抗性",
	curio_resistance_bombers = "瘟疫爆者抗性",
	curio_resistance_grimoires = "魔法书腐化抗性",
	curio_reward_chance = "珍品任务奖励概率",
	curio_toughness_regeneration = "韧性恢复",
	curio_ordo_dockets = "审判庭双子币",
	curio_revive_speed = "复活速度",
	curio_dr_flamers = "火焰兵减伤",
	curio_dr_snipers = "狙击手减伤",
	curio_dr_grenadiers = "轰炸者减伤",
	curio_dr_hounds = "瘟疫猎犬减伤",
	curio_dr_mutants = "变种人减伤",
	curio_dr_gunners = "炮手减伤",
	curio_dr_bombers = "瘟疫爆者减伤",
	curio_dr_grimoires = "魔法书腐化减伤",
	curio_heavy_ability_regen = "技能恢复",
	curio_heavy_toughness_regen = "韧性恢复",
	curio_heavy_corruption_dr = "腐化减伤",
	curio_heavy_block = "格挡",
	curio_heavy_sprint = "疾跑",
	curio_heavy_stamina_regen = "体力恢复",
	weapon_perk_unarmoured_damage = "无甲伤害",
	weapon_perk_unarmoured_damage_heavy = "无甲伤害",
	weapon_perk_flak_damage = "防弹装甲伤害",
	weapon_perk_flak_damage_heavy = "防弹伤害",
	weapon_perk_unyielding_damage = "不屈伤害",
	weapon_perk_unyielding_damage_heavy = "不屈伤害",
	weapon_perk_maniacs_damage = "狂人伤害",
	weapon_perk_maniacs_damage_heavy = "狂人伤害",
	weapon_perk_carapace_damage = "硬壳装甲伤害",
	weapon_perk_carapace_damage_heavy = "硬壳伤害",
	weapon_perk_infested_damage = "感染伤害",
	weapon_perk_infested_damage_heavy = "感染伤害",
	weapon_perk_melee_crit_chance = "近战暴击率",
	weapon_perk_melee_crit_chance_heavy = "近战暴击",
	weapon_perk_melee_crit_damage = "近战暴击伤害",
	weapon_perk_melee_crit_damage_heavy = "暴击伤害",
	weapon_perk_horde_melee_damage = "群怪近战伤害",
	weapon_perk_horde_melee_damage_heavy = "群怪伤害",
	weapon_perk_elites_melee_damage = "精英近战伤害",
	weapon_perk_elites_melee_damage_heavy = "精英伤害",
	weapon_perk_specialist_melee_damage = "专家近战伤害",
	weapon_perk_specialist_melee_damage_heavy = "专家伤害",
	weapon_perk_melee_weakspot_damage = "近战弱点伤害",
	weapon_perk_melee_weakspot_damage_heavy = "弱点伤害",
	weapon_perk_ranged_crit_chance = "远程暴击率",
	weapon_perk_ranged_crit_chance_heavy = "远程暴击",
	weapon_perk_ranged_crit_damage = "远程暴击伤害",
	weapon_perk_ranged_crit_damage_heavy = "暴击伤害",
	weapon_perk_horde_ranged_damage = "群怪远程伤害",
	weapon_perk_horde_ranged_damage_heavy = "群怪伤害",
	weapon_perk_elites_ranged_damage = "精英远程伤害",
	weapon_perk_elites_ranged_damage_heavy = "精英伤害",
	weapon_perk_specialist_ranged_damage = "专家远程伤害",
	weapon_perk_specialist_ranged_damage_heavy = "专家伤害",
	weapon_perk_ranged_weakspot_damage = "远程弱点伤害",
	weapon_perk_ranged_weakspot_damage_heavy = "弱点伤害",
	weapon_perk_stamina = "体力",
	weapon_perk_melee_damage = "近战伤害",
	weapon_perk_melee_damage_heavy = "近战伤害",
	weapon_perk_ranged_damage = "远程伤害",
	weapon_perk_ranged_damage_heavy = "远程伤害",
	weapon_perk_melee_finesse = "近战娴熟",
	weapon_perk_ranged_finesse = "远程娴熟",
	weapon_perk_finesse_heavy = "娴熟",
	weapon_perk_melee_power = "近战威力",
	weapon_perk_ranged_power = "远程威力",
	weapon_perk_power_heavy = "威力",
	weapon_perk_melee_impact = "近战冲击",
	weapon_perk_impact_heavy = "冲击",
	weapon_perk_block_efficiency = "格挡效率",
	weapon_perk_block_heavy = "格挡",
	weapon_perk_sprint_efficiency = "疾跑效率",
	weapon_perk_sprint_heavy = "疾跑",
	weapon_perk_reload_speed = "装填速度",
	weapon_perk_reload_heavy = "装填",
}

zh_cn.automatic_curio_target_mode = "珍品获取目标"
zh_cn.automatic_curio_target_mode_tooltip = "角色模式为默认选项，可分别启用每个已发现的角色。职业模式会将每个职业复选框应用于该职业的所有角色。新角色会自动启用；若确认扫描不到可用角色，则会安全回退到职业模式。"
zh_cn.automatic_curio_target_mode_classes = "职业"
zh_cn.automatic_curio_target_mode_characters = "角色"
zh_cn.automatic_curio_target_mode_inventory_suffix = "获取珍品："
zh_cn.automatic_curio_characters_group = "要获取珍品的角色："
zh_cn.automatic_curio_characters_inventory_label = "要获取珍品的角色："
zh_cn.automatic_curio_characters_discovering = "正在发现角色……请稍后重新打开模组选项，或使用库存选项面板。"
zh_cn.automatic_curio_characters_discovering_inventory = "正在发现角色..."
zh_cn.automatic_curio_character_options_placeholder = "正在发现角色……"
zh_cn.automatic_curio_character_slot_placeholder = "角色"
zh_cn.automatic_curio_character_slot_unavailable = "（当前未找到）"
zh_cn.automatic_curio_character_slot_empty_reason = "当前没有角色分配到此栏位。BetterInventory 会在进入晨星号后刷新角色列表，并在枢纽中定期刷新。"
zh_cn.enable_automatic_curio_acquisition_tooltip = "每次进入晨星号后，对所有角色的军械库交易所执行一次扫描，并自动购买符合物品等级、主要属性数值、类型和目标筛选条件的所有珍品。目标可按职业或单个角色选择。此功能会在没有确认提示的情况下花费审判庭双子币。自动丢弃会先完成，且符合获取规则的珍品会在以后的自动丢弃流程中保持受保护状态。"
zh_cn.automatic_curio_min_item_level_tooltip = "只有显示物品等级达到或超过此值的军械库珍品才符合条件。生命和韧性珍品还必须达到对应的最低主要属性数值。货币充足时，会购买每个已启用目标的所有匹配商品。默认值为 410。"

zh_cn.enable_armoury_requisition_sorting_panel = "显示军械库排序组件"
zh_cn.enable_armoury_requisition_sorting_panel_tooltip = "在申领武器与珍品中添加可折叠的 BetterInventory 排序组件。需要开启军械库网格，默认开启。"
zh_cn.brighten_armoury_item_levels = "提亮军械库物品等级"
zh_cn.brighten_armoury_item_levels_tooltip = "使用更明亮的文字显示军械库交易所卡片中的物品等级，避免被底部价格区域遮暗。默认开启。"
zh_cn.three_column_weapon_name_font_size = "军械库武器名称字号"
zh_cn.three_column_weapon_name_font_size_tooltip = "控制军械库卡片中的武器名称字号。调低数值可帮助较长名称保持在一行，同时不影响库存卡片。"
zh_cn.hadron_additional_views_group = "哈德隆"
zh_cn.armoury_exchange_views_group = "军械库交易所"
zh_cn.global_store_integration_group = "Mod 集成：GlobalStore"
zh_cn.enable_global_store_integration = "启用 GlobalStore 集成"
zh_cn.enable_global_store_integration_tooltip = "为多干员补给启用 BetterInventory 的 GlobalStore 集成。关闭后将保持 GlobalStore 的原生卡片和排序。"
zh_cn.enable_global_store_grid = "使用 BetterInventory 网格卡片"
zh_cn.enable_global_store_grid_tooltip = "在 GlobalStore 的多干员补给中使用 BetterInventory 响应式网格卡片。该视图最多三列；近战、远程和珍品列数设置仅适用于库存标签页。三列会增加角色信息行，但不会拉伸武器图像。"
zh_cn.enable_global_store_sorting_panel = "显示 GlobalStore 排序组件"
zh_cn.enable_global_store_sorting_panel_tooltip = "在 GlobalStore 的多干员补给中添加可折叠的 BetterInventory 排序和暗潮原生排序组件。需要开启 GlobalStore 网格，默认开启。"
zh_cn.global_store_character_photo_size_percent = "GlobalStore 角色头像大小（%%）"
zh_cn.global_store_character_photo_size_percent_tooltip = "控制二至三列卡片中的 GlobalStore 角色头像大小（50-125%%，默认110%%）。角色信息行位于价格和物品等级行下方，预留高度保持不变，因此调整此值不会改变卡片尺寸或使价格移动。"
zh_cn.global_store_price_row_padding = "GlobalStore 价格/物品等级行内边距"
zh_cn.global_store_price_row_padding_tooltip = "控制 GlobalStore 角色信息行上方的垂直内边距。增加此值会让奥多点券和物品等级行远离角色头像，而不会改变头像大小。"
zh_cn.global_store_character_info_gap = "GlobalStore 角色信息水平间距"
zh_cn.global_store_character_info_gap_tooltip = "控制 GlobalStore 角色头像与职业图标/名称之间的水平间距。单位为像素，适用于二至三列卡片。"
zh_cn.global_store_character_class_icon_size = "GlobalStore 职业图标大小"
zh_cn.global_store_character_class_icon_size_tooltip = "控制二至三列卡片中的 GlobalStore 职业图标字号（8-24像素，默认16）。角色信息行和卡片尺寸保持不变。"
zh_cn.global_store_character_name_font_size = "GlobalStore 角色名称字号"
zh_cn.global_store_character_name_font_size_tooltip = "控制二至三列卡片中的 GlobalStore 角色名称字号（8-20像素，默认16）。角色信息行和卡片尺寸保持不变。"
zh_cn.global_store_compact_character_names = "在4-5列中压缩 GlobalStore 角色名称"
zh_cn.global_store_compact_character_names_tooltip = "为兼容旧配置而保留。GlobalStore 最多三列，因此不会使用四列和五列窄卡片行为。默认开启。"
zh_cn.option_requires_global_store_grid = "启用 GlobalStore 网格后才能使用此选项。"
zh_cn.option_requires_global_store_integration = "启用 GlobalStore 集成后才能使用此选项。"

zh_cn.global_store_single_column_modifier_horizontal_position = "GlobalStore single-column modifier horizontal position (%%)"
zh_cn.global_store_single_column_modifier_horizontal_position_tooltip = "Move native single-column GlobalStore weapon modifiers horizontally. 0 is left and 100 is right. Reopen GlobalStore after changing."
zh_cn.global_store_single_column_modifier_vertical_position = "GlobalStore single-column modifier vertical position (%%)"
zh_cn.global_store_single_column_modifier_vertical_position_tooltip = "Move native single-column GlobalStore weapon modifiers vertically. 0 is top and 100 is bottom. Reopen GlobalStore after changing."
zh_cn.melee_columns = "Melee Weapons Columns"
zh_cn.melee_columns_tooltip = "Number of melee-weapon cards per inventory row. Defaults to three."
zh_cn.ranged_columns = "Ranged Weapons Columns"
zh_cn.ranged_columns_tooltip = "Number of ranged-weapon cards per inventory row. Defaults to three."
zh_cn.curio_columns = "Curios Columns"
zh_cn.curio_columns_tooltip = "Number of Curio cards per inventory row. Defaults to three."

zh_cn.enable_hadron_single_column_mirror = "Mirror single-column format from inventory"
zh_cn.enable_hadron_single_column_mirror_tooltip = "Uses the detailed BetterInventory single-column card format for Entreat Hadron when grid layout is disabled. Enabled by default."
zh_cn.enable_armoury_single_column_mirror = "Enable custom detailed card for single column"
zh_cn.enable_armoury_single_column_mirror_tooltip = "Uses BetterInventory's custom detailed card for Requisition Weapons & Curios when grid layout is disabled. Enabled by default."
zh_cn.custom_item_name_and_colors_group = "Custom Item Names and Colors"
zh_cn.enable_custom_item_name_and_colors = "Enable custom item names and colors"
zh_cn.enable_custom_item_name_and_colors_tooltip = "Enables BetterInventory's standalone per-item name, name-color and background-color editor. Does not require Name It."
zh_cn.custom_item_name_keybind = "Change Name keybind"
zh_cn.custom_item_name_keybind_tooltip = "Opens the name editor directly. When Name It is installed, BetterInventory uses its configured Change Name key and replaces its duplicate inventory action."
zh_cn.custom_item_name_color_keybind = "Name Color keybind"
zh_cn.custom_item_name_color_keybind_tooltip = "Opens the item-name RGB selector directly."
zh_cn.custom_item_background_color_keybind = "Background Color keybind"
zh_cn.custom_item_background_color_keybind_tooltip = "Opens the item-background RGB selector directly."
zh_cn.custom_item_editor_keybind_e = "[E]"
zh_cn.custom_item_editor_keybind_q = "[Q]"
zh_cn.custom_item_editor_keybind_v = "[V]"
zh_cn.custom_item_editor_keybind_r = "[R]"
zh_cn.custom_item_editor_keybind_off = "Off"
zh_cn.custom_item_skip_confirmation_prompts = "Skip confirmation prompts"
zh_cn.custom_item_skip_confirmation_prompts_tooltip = "Immediately applies reset actions instead of asking for confirmation. Enabled by default."
zh_cn.custom_item_preserve_card_shading = "Preserve Darktide Equipment Card Shading"
zh_cn.custom_item_preserve_card_shading_tooltip = "Uses Darktide's dark base layer beneath custom background colors. Disable this to paint the entire card with the selected color. Each painted item retains its confirmed choice."
zh_cn.custom_item_override_weapon_information_color = "Apply custom color to weapon information"
zh_cn.custom_item_override_weapon_information_color_tooltip = "Uses an item's custom background color for the weapon-information header. Darktide's native dark base and gradient shading are always preserved in this panel."
zh_cn.custom_item_override_weapon_rarity_keyword_color = "Apply custom color to rarity keyword"
zh_cn.custom_item_override_weapon_rarity_keyword_color_tooltip = "Uses an item's custom background color for its rarity keyword in the weapon-information panel."
zh_cn.custom_item_override_weapon_information_name_color = "Apply custom name color to weapon information"
zh_cn.custom_item_override_weapon_information_name_color_tooltip = "Uses an item's custom name color for its name in the weapon-information panel."
zh_cn.option_requires_custom_item_name_and_colors = "Enable custom item names and colors to use this option."
zh_cn.name_it_force_curio_name_in_detailed_mode = "Show Curio name with all four attributes"
zh_cn.name_it_force_curio_name_in_detailed_mode_tooltip = "Shows a two-line Curio name above all four attribute lines in Character Overview and supported item views. Works with or without Name It."
zh_cn.curio_content_name_it_curio_name = "Show Curio name with all four attributes"
zh_cn.curio_content_name_it_curio_name_tooltip = "Shows a two-line Curio name above all four attribute lines in Character Overview and supported item views. Works with or without Name It."
zh_cn.character_overview_group = "Character overview"
zh_cn.enable_character_overview_melee_mirror = "Mirror melee weapon single-column format from inventory"
zh_cn.enable_character_overview_melee_mirror_tooltip = "Uses the detailed BetterInventory single-column card for the equipped melee weapon on the character overview screen. Enabled by default."
zh_cn.enable_character_overview_ranged_mirror = "Mirror ranged weapon single-column format from inventory"
zh_cn.enable_character_overview_ranged_mirror_tooltip = "Uses the detailed BetterInventory single-column card for the equipped ranged weapon on the character overview screen. Enabled by default."
zh_cn.enable_character_overview_curio_details = "Show detailed Curio card on character overview"
zh_cn.enable_character_overview_curio_details_tooltip = "Shows the equipped Curio's primary and secondary stats in a compact BetterInventory card on the character overview screen. Enabled by default."
zh_cn.character_overview_curio_name_mode = "Curio title mode"
zh_cn.character_overview_curio_name_mode_tooltip = "Hides Curio titles or fits them within one or two lines above the four stat rows on the character overview."
zh_cn.character_overview_curio_name_mode_none = "No title"
zh_cn.character_overview_curio_name_mode_one_line = "One-line title"
zh_cn.character_overview_curio_name_mode_two_lines = "Two-line title"
zh_cn.character_overview_curio_font_size_percent = "Character overview Curio font size (%%)"
zh_cn.character_overview_curio_font_size_percent_tooltip = "Scales all text on detailed Curio cards in the character overview (50-150%%, default 110%%). Does not affect Curio cards in inventory or stores."
zh_cn.option_requires_character_overview_curio_details = "Requires detailed Curio cards on the character overview."
zh_cn.myfavorites_integration_group = "Mod Integration: MyFavorites"
zh_cn.myfavorites_show_favorite_letter = "Show F below favorite icon"
zh_cn.myfavorites_show_favorite_letter_tooltip = "Adds a compact F beneath the coloured MyFavorites icon. Disabled by default."

for localization_id, text in pairs(zh_cn) do
	local entry = localization[localization_id]

	if entry then
		entry["zh-cn"] = text
	end
end

-- Character-slot controls must exist in the static DMF schema so their
-- cardinality is stable for Alf's DMF Extensions and across cold starts. Their
-- initialized titles are replaced with discovered operative names at runtime.
for index = 1, 64 do
	localization["automatic_curio_character_slot_" .. tostring(index)] = {
		en = "Character " .. tostring(index),
		["zh-cn"] = "角色 " .. tostring(index),
	}
end

return localization
