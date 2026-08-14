local localization = {
	inventory_options_controller_focus_keybind = {
		en = "Items / widget focus keybind",
	},
	inventory_options_controller_focus_keybind_tooltip = {
		en = "Switches controller focus between the inventory item grid and BetterInventory's options widget. RT is unused by Darktide's native melee, ranged and Curio inventory controls.",
	},
	inventory_options_controller_focus_keybind_rt = {
		en = "[D / RT]",
	},
	inventory_options_controller_focus_legend = {
		en = "Items / Widget Focus",
	},
	item_sorting_mod_header = {
		en = "ItemSorting mod",
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
	automatic_curio_scan_operative_selection = {
		en = "Scan and purchase from Operative Selection",
	},
	automatic_curio_scan_operative_selection_tooltip = {
		en = "Allows the Automatic Curio Buyer to run while the Operative Selection screen is open. Disabled by default. It still respects the store-rotation throttle and never waits for a selected Morningstar player.",
	},
	automatic_curio_once_per_store_rotation = {
		en = "Scan at most once per store rotation",
	},
	automatic_curio_once_per_store_rotation_tooltip = {
		en = "When enabled, Morningstar and Operative Selection share one account-scoped Armoury rotation gate. A scan at 17:06 permits the next scan after the store reset at 18:00; this is not a rolling 60-minute timer. Disabled by default.",
	},
	automatic_curio_rescan_on_store_refresh = {
		en = "Rescan when store refreshes while idle",
	},
	automatic_curio_rescan_on_store_refresh_tooltip = {
		en = "When enabled, performs one additional pass after the next Armoury store reset if you remain in an eligible screen. A scan just before reset can therefore be followed by another scan just after reset. Disabled by default to limit backend work and unexpected close-together purchases.",
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
	myfavorites_integration_group = {
		en = "Mod Integration: MyFavorites",
	},
	enable_lantern_inventory_section = {
		en = "Show Lantern recommendations in the inventory panel",
	},
	enable_lantern_inventory_section_tooltip = {
		en = "When Lantern of the Omnissiah is installed, places its recommendation window in the top section of BetterInventory's scalable inventory-options panel and hides Lantern's duplicate floating weapon panel. Curio recommendations remain separate by default.",
	},
	keep_lantern_curio_panel_separate = {
		en = "Keep Lantern's Curio panel separate",
	},
	keep_lantern_curio_panel_separate_tooltip = {
		en = "Leaves Lantern's Recommended Curios window in its native standalone placement instead of hosting it inside BetterInventory's inventory-options panel. Enabled by default because Lantern's Curio layout already fits beside BetterInventory's panel.",
	},
	option_requires_lantern_of_the_omnissiah = {
		en = "Requires Lantern of the Omnissiah.",
	},
	myfavorites_show_favorite_letter = {
		en = "Show F below favorite icon",
	},
	myfavorites_show_favorite_letter_tooltip = {
		en = "Adds a compact F beneath the coloured MyFavorites icon. Disabled by default.",
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
		en = "Opens the name editor directly. The default uses I / View / Touchpad to avoid Darktide's controller Favorite action. BetterInventory replaces Name It's duplicate inventory action while this editor is enabled.",
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
	custom_item_editor_keybind_i_view = {
		en = "[I / View / Touchpad]",
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
	custom_item_editor_keybind_lt = {
		en = "[A / LT]",
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
	auto_crafter_group = {
		en = "Auto Crafter Helper",
	},
	auto_crafter_enable = {
		en = "Enable Auto Crafter Helper probe",
	},
	auto_crafter_enable_tooltip = {
		en = "Enables the Brunt's Armoury Auto Crafter panel. Account changes begin only after an explicit Craft click and current authoritative validation.",
	},
	auto_crafter_read_only_probe = {
		en = "Run read-only Brunt probe",
	},
	auto_crafter_read_only_probe_tooltip = {
		en = "Reads current Brunt offers, wallets, and gear once after entering the Armoury view. Disabled automatically when Auto Crafter Helper is disabled.",
	},
	auto_crafter_show_probe_notifications = {
		en = "Show Auto Crafter status notifications",
	},
	auto_crafter_show_probe_notifications_tooltip = {
		en = "Enabled by default. Shows native notification status for probes, plans, purchase search, and mastery synchronization. Notification errors cannot affect game data.",
	},
	auto_crafter_target_dump_stat = {
		en = "Auto Crafter target dump stat",
	},
	auto_crafter_target_dump_stat_tooltip = {
		en = "Choose the dump stat manually from the selected weapon's indexed base stats. Changing weapons resets the selector to index 0.",
	},
	auto_crafter_dump_stat_damage = {
		en = "Damage",
	},
	auto_crafter_dump_stat_mobility = {
		en = "Mobility",
	},
	auto_crafter_dump_stat_finesse = {
		en = "Finesse",
	},
	auto_crafter_dump_stat_penetration = {
		en = "Penetration",
	},
	auto_crafter_dump_stat_first_target = {
		en = "First Target",
	},
	auto_crafter_dump_stat_defenses = {
		en = "Defenses",
	},
	auto_crafter_dump_stat_target = {
		en = "Dump stat target",
	},
	auto_crafter_dump_stat_target_tooltip = {
		en = "Desired dump-stat percentage used by the guarded serialized purchase search. Unknown stat shapes stop the run.",
	},
	auto_crafter_custom_stats = {
		en = "Custom stats",
	},
	auto_crafter_custom_stats_tooltip = {
		en = "Replace the single dump-stat target with an exact five-stat allocation. Every stat is limited to 60-80 and crafting requires an exact total of 380.",
	},
	auto_crafter_custom_stat_1 = { en = "Custom stat 1" },
	auto_crafter_custom_stat_2 = { en = "Custom stat 2" },
	auto_crafter_custom_stat_3 = { en = "Custom stat 3" },
	auto_crafter_custom_stat_4 = { en = "Custom stat 4" },
	auto_crafter_custom_stat_5 = { en = "Custom stat 5" },
	auto_crafter_custom_stat_value_tooltip = {
		en = "Saved value for the corresponding selected-weapon stat. The in-game Auto Crafter panel provides the contextual stat name and guarded arrows.",
	},
	auto_crafter_cap_by_dockets = {
		en = "Cap perfect-roll weapon acquisition by Ordo dockets",
	},
	auto_crafter_cap_by_dockets_tooltip = {
		en = "Enable the Ordo dockets cap for the perfect-roll weapon acquisition search. The numeric cap stays saved when this option is disabled.",
	},
	auto_crafter_docket_cap = {
		en = "Ordo dockets cap",
	},
	auto_crafter_docket_cap_tooltip = {
		en = "Maximum dockets the serialized purchase search may spend. The controller stops before dispatching a purchase that would cross this cap.",
	},
	auto_crafter_cap_by_max_purchases = {
		en = "Cap perfect-roll weapon acquisition by max purchases",
	},
	auto_crafter_cap_by_max_purchases_tooltip = {
		en = "Enable the maximum-purchases cap for the perfect-roll weapon acquisition search. The numeric limit stays saved when this option is disabled.",
	},
	auto_crafter_max_purchases = {
		en = "Auto Crafter maximum purchases",
	},
	auto_crafter_max_purchases_tooltip = {
		en = "Hard upper bound for the serialized purchase search. No next purchase is dispatched after this count.",
	},
	auto_crafter_best_candidate_fallback = {
		en = "Use closest fallback candidate weapon if exact stat match weapon is not found",
	},
	auto_crafter_best_candidate_fallback_tooltip = {
		en = "If an exact weapon is not found before a cap, use the closest valid roll. Custom stats minimize the sum of absolute differences across all five requested stats; single dump-stat mode minimizes that selected stat's difference. Equal-distance custom rolls keep the earliest purchase.",
	},
	auto_crafter_request_mode = {
		en = "Auto Crafter request mode",
	},
	auto_crafter_request_mode_tooltip = {
		en = "Sequential is the default and safest mode. Parallel reads are a future opt-in experiment; parallel mutations remain blocked until backend behavior is proven.",
	},
	auto_crafter_request_mode_sequential = {
		en = "Sequential (recommended)",
	},
	auto_crafter_request_mode_parallel_reads = {
		en = "Parallel reads",
	},
	auto_crafter_request_mode_experimental = {
		en = "Experimental parallel mutations",
	},
	auto_crafter_workflow_group = {
		en = "Crafting workflow",
	},
	auto_crafter_resuming_group = {
		en = "Resuming item options",
	},
	auto_crafter_buy_until_target = {
		en = "Automatically buy until dump stat target weapon is found",
	},
	auto_crafter_buy_until_target_tooltip = {
		en = "Runs the serialized Brunt purchase search until the selected dump-stat target is found or a configured safety cap is reached.",
	},
	auto_crafter_level_mastery_20 = {
		en = "Automatically level weapon mastery to 20",
	},
	auto_crafter_level_mastery_20_tooltip = {
		en = "Runs the guarded serialized buy, Redeem, sacrifice, claim and synchronization loop until authoritative mastery reaches level 20. Also unlocks Rank IV perk planning.",
	},
	auto_crafter_allocate_mastery_points = {
		en = "Automatically allocate mastery points",
	},
	auto_crafter_allocate_mastery_points_tooltip = {
		en = "After mastery reaches level 20, allocates the mastery points required by the selected crafting targets.",
	},
	auto_crafter_consecrate_transcendent = {
		en = "Automatically consecrate weapon to Transcendent",
	},
	auto_crafter_consecrate_transcendent_tooltip = {
		en = "Consecrates the final candidate through only its missing rarity tiers until it reaches Transcendent.",
	},
	auto_crafter_upgrade_expertise_500 = {
		en = "Automatically upgrade weapon item level to 500",
	},
	auto_crafter_upgrade_expertise_500_tooltip = {
		en = "Upgrades the final candidate to weapon level 500 after the required mastery rewards are available.",
	},
	auto_crafter_change_perks = {
		en = "Change perks",
	},
	auto_crafter_change_perks_tooltip = {
		en = "Requires mastery level 20 so Rank IV perks are unlocked, then safely applies the selected compatible perk targets.",
	},
	auto_crafter_change_blessings = {
		en = "Change blessings",
	},
	auto_crafter_change_blessings_tooltip = {
		en = "Requires mastery level 20 and the necessary allocated points, then safely applies the selected compatible blessing targets.",
	},
	auto_crafter_trait_targets_group = {
		en = "Perk and blessing targets",
	},
	auto_crafter_perk_1_target = {
		en = "Perk target 1",
	},
	auto_crafter_perk_2_target = {
		en = "Perk target 2",
	},
	auto_crafter_perk_target_tooltip = {
		en = "Requires mastery-to-20 and Change perks. Choose two distinct compatible Rank IV perks from the selected weapon catalogue.",
	},
	auto_crafter_show_perk_grid = {
		en = "Show perk grid",
	},
	auto_crafter_show_perk_grid_tooltip = {
		en = "Shows every compatible Rank IV perk in four columns. Left click assigns target 1 (yellow); right click assigns target 2 (green). Duplicate targets are prevented.",
	},
	option_requires_auto_crafter_mastery_20 = {
		en = "Enable Automatically level weapon mastery to 20 to unlock Rank IV perk selection.",
	},
	option_requires_auto_crafter_change_perks = {
		en = "Enable Change perks.",
	},
	option_requires_auto_crafter_blessing_workflow = {
		en = "Enable mastery allocation and Change blessings.",
	},
	auto_crafter_blessing_1_target = {
		en = "Blessing target 1",
	},
	auto_crafter_blessing_2_target = {
		en = "Blessing target 2",
	},
	auto_crafter_blessing_target_tooltip = {
		en = "Choose two distinct compatible blessings from the selected weapon family's trait sticker-book catalogue.",
	},
	auto_crafter_show_blessing_grid = {
		en = "Show blessing grid",
	},
	auto_crafter_show_blessing_grid_tooltip = {
		en = "Shows compatible blessings with icons in three columns. Left click assigns target 1 (yellow); right click assigns target 2 (green). Duplicate targets are prevented.",
	},
	auto_crafter_target_keep = {
		en = "Keep current",
	},
	auto_crafter_target_auto = {
		en = "Auto-select",
	},
	auto_crafter_target_auto_discovered = {
		en = "Auto-select",
	},
	auto_crafter_target_auto_pending = {
		en = "Auto-select (waiting for discovery)",
	},
	auto_crafter_trait_catalog_ready = {
		en = "Perks and blessings discovered",
	},
	auto_crafter_trait_catalog_pending = {
		en = "Discovering selected weapon",
	},
	auto_crafter_trait_catalog_failed = {
		en = "Discovery unavailable",
	},
	auto_crafter_defer_bad_weapon_processing = {
		en = "Only process bad weapons after finding perfect-rolled weapon",
	},
	auto_crafter_defer_bad_weapon_processing_tooltip = {
		en = "Keep purchased misses untouched until an exact target is confirmed. Then use them for mastery and discard any leftovers after mastery reaches level 20. Requires mastery-to-20.",
	},
	auto_crafter_favorite_result = {
		en = "Automatically favorite crafted weapon",
	},
	auto_crafter_favorite_result_tooltip = {
		en = "Favorite an exact matching weapon after authoritative inventory verification.",
	},
	auto_crafter_notification_title = {
		en = "Auto Crafter Helper",
	},
	auto_crafter_probe_started = {
		en = "Read-only Brunt probe started.",
	},
	auto_crafter_probe_failed = {
		en = "Read-only Brunt probe failed",
	},
	auto_crafter_panel_title = {
		en = "Auto Crafter Helper",
	},
	auto_crafter_panel_read_only = {
		en = "READ-ONLY PLANNER",
	},
	auto_crafter_panel_status = {
		en = "Status",
	},
	auto_crafter_panel_offers = {
		en = "Offers",
	},
	auto_crafter_panel_wallet = {
		en = "Resources",
	},
	auto_crafter_panel_gear = {
		en = "Gear",
	},
	auto_crafter_panel_inventory = {
		en = "Inventory",
	},
	auto_crafter_panel_target = {
		en = "Target",
	},
	auto_crafter_panel_no_target = {
		en = "no target selected",
	},
	auto_crafter_panel_offer_list = {
		en = "Weapon selection",
	},
	auto_crafter_panel_selected_weapon = {
		en = "Selected weapon",
	},
	auto_crafter_panel_select_weapon = {
		en = "Select a weapon in Brunt's list.",
	},
	auto_crafter_panel_no_offers = {
		en = "No weapon offers exposed yet.",
	},
	auto_crafter_panel_more = {
		en = "More offers available",
	},
	auto_crafter_panel_planner = {
		en = "Planner configuration",
	},
	auto_crafter_panel_marks = {
		en = "Marks",
	},
	auto_crafter_panel_estimates = {
		en = "Estimates",
	},
	auto_crafter_panel_planner_target = {
		en = "Planner target",
	},
	auto_crafter_panel_dump_stat = {
		en = "Dump stat",
	},
	auto_crafter_panel_dump_target = {
		en = "Dump target",
	},
	auto_crafter_panel_custom_stat_total = {
		en = "Total stat sum",
	},
	auto_crafter_panel_docket_cap = {
		en = "Ordo dockets cap",
	},
	auto_crafter_panel_max_purchases = {
		en = "Max purchases",
	},
	auto_crafter_panel_best_fallback = {
		en = "Use closest fallback candidate weapon if exact stat match weapon is not found",
	},
	auto_crafter_panel_request_mode = {
		en = "Request mode",
	},
	auto_crafter_panel_estimate = {
		en = "Search budget",
	},
	auto_crafter_panel_consecrate_cost = {
		en = "Profane to Transcendent",
	},
	auto_crafter_panel_mastery_cost = {
		en = "Mastery fodder investment",
	},
	auto_crafter_panel_total_cost = {
		en = "Known crafting investment",
	},
	auto_crafter_panel_disabled = {
		en = "disabled",
	},
	auto_crafter_panel_preview = {
		en = "> CLICK HERE TO CRAFT <",
	},
	auto_crafter_panel_phase_2 = {
		en = "Redeem + sacrifice one",
	},
	auto_crafter_panel_phase_2_waiting = {
		en = "No purchased candidate",
	},
	auto_crafter_panel_stop = {
		en = "> CLICK HERE TO STOP / INTERRUPT <",
	},
	auto_crafter_panel_waiting = {
		en = "waiting for probe",
	},
	auto_crafter_panel_ui_plan = {
		en = "UI PLAN",
	},
	auto_crafter_panel_workflow = {
		en = "Crafting workflow",
	},
	auto_crafter_panel_trait_targets = {
		en = "Perk and blessing targets",
	},
	auto_crafter_panel_resuming = {
		en = "Resuming item options",
	},
	auto_crafter_panel_option_unavailable = {
		en = "Enable prerequisite options",
	},
	auto_crafter_panel_advanced = {
		en = "Advanced and safety",
	},
	auto_crafter_value_on = {
		en = "On",
	},
	auto_crafter_value_off = {
		en = "Off",
	},
	auto_crafter_reuse_inventory_base = { en = "Resume matching dump stat weapon from inventory" },
	auto_crafter_reuse_inventory_base_tooltip = { en = "Before buying, use the best matching weapon already in inventory. Favorited weapons remain protected unless explicitly included." },
	auto_crafter_include_favorite_inventory_bases = { en = "Include favorited inventory weapons when resuming" },
	auto_crafter_include_favorite_inventory_bases_tooltip = { en = "Allow an already-favorited matching weapon to become the final crafting base." },
	auto_crafter_craft_duplicate_completed_queued_weapons = { en = "Craft duplicates of already completed queued weapons" },
	auto_crafter_craft_duplicate_completed_queued_weapons_tooltip = { en = "When no incomplete weapon can be resumed, craft a new copy instead of skipping a completed family-equivalent queued weapon." },
	auto_crafter_show_status_hud = { en = "Show top crafting HUD" },
	auto_crafter_show_status_hud_tooltip = { en = "Show active Auto Crafter objectives at the top of Morningstar store and inventory views. Hidden during missions and mission matchmaking." },
	option_requires_auto_crafter_inventory_reuse = { en = "Requires inventory-base reuse" },
}

return localization
