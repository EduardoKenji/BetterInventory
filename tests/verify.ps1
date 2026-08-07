param(
	[string] $DarktideSourcePath
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptRoot = Join-Path $projectRoot "scripts\mods\BetterInventory"
$runtimeLuaFiles = @(Get-ChildItem -LiteralPath $scriptRoot -Filter "BetterInventory*.lua" -File | Sort-Object Name)
$requiredFiles = @(
	(Join-Path $projectRoot "BetterInventory.mod")
)
$requiredFiles += @($runtimeLuaFiles | ForEach-Object { $_.FullName })
$releasePackager = Join-Path $projectRoot "tools\package_release.ps1"
$packagingDocumentation = Join-Path $projectRoot "docs\release-packaging.md"
$packagingSource = Get-Content -LiteralPath $releasePackager -Raw

foreach ($file in $requiredFiles) {
	if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
		throw "Missing required file: $file"
	}
}

foreach ($releaseFile in @($releasePackager, $packagingDocumentation)) {
	if (-not (Test-Path -LiteralPath $releaseFile -PathType Leaf)) {
		throw "Missing mandatory release-packaging safeguard: $releaseFile"
	}
}

$main = Get-Content -LiteralPath (Join-Path $scriptRoot "BetterInventory.lua") -Raw
$curioVisualPlan = Get-Content -LiteralPath (Join-Path $projectRoot "docs\v1.9.4-curio-card-visuals-plan.md") -Raw

if ($main -notmatch 'mod:hook\(InventoryWeaponsView,\s*"present_grid_layout"') {
	throw "The InventoryWeaponsView hook was not found."
}

if ($main -notmatch 'mod:hook\(InventoryWeaponsView,\s*"_handle_input"' -or $main -notmatch 'capture_inventory_controller_navigation' -or $main -notmatch 'consume_inventory_controller_grid_navigation') {
	throw "The multi-column controller-navigation guard was not found."
}

if ($main -match 'mod:hook_safe\(InventoryWeaponsView,\s*"update"') {
	throw "InventoryWeaponsView.update must use one hook type so DMF hot reload does not reject a duplicate rehook."
}

if ($main -notmatch 'mod:hook\(CraftingMechanicusModifyView,\s*"present_grid_layout"') {
	throw "The Entreat Hadron grid hook was not found."
}

if ($main -notmatch 'mod:hook\(InventoryView,\s*"_create_entry_widget_from_config"' -or $main -notmatch 'enable_character_overview_melee_mirror' -or $main -notmatch 'enable_character_overview_ranged_mirror' -or $main -notmatch 'enable_character_overview_curio_details' -or $main -notmatch 'character_overview_show_melee_rarity_strip' -or $main -notmatch 'character_overview_show_ranged_rarity_strip' -or $main -notmatch 'character_overview_show_curio_rarity_strip' -or $main -notmatch 'configure_character_overview_rarity_strip' -or $main -notmatch 'character_overview_use_native_curio_overlay' -or $main -notmatch 'configure_native_curio_overlay' -or $main -notmatch 'inner_frame' -or $main -notmatch 'table\.clone\(native_inner_frame\)' -or $main -notmatch 'CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_CONTENT_SHIFT_Y' -or $main -notmatch 'CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_EQUIPPED_ICON_SHIFT_Y' -or $main -notmatch 'CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_TITLE_HORIZONTAL_PADDING' -or $main -notmatch 'CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_TITLE_SHIFT_X' -or $main -notmatch 'CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_ITEM_LEVEL_SHIFT_X' -or $main -notmatch 'CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_ITEM_LEVEL_SHIFT_Y' -or $main -notmatch 'CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_MARKER_SHIFT_X' -or $main -notmatch 'CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_EQUIPPED_ICON_SHIFT_X' -or $main -notmatch 'CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_FAVORITE_SHIFT_Y' -or $main -notmatch 'CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_TITLE_MARKER_GAP_Y' -or $main -notmatch 'better_inventory_native_curio_favorite_min_y' -or $main -notmatch 'better_inventory_native_curio_equipped_min_y' -or $main -notmatch 'character_overview_native_curio_equipped_marker_y' -or $main -notmatch 'better_inventory_curio_stat_1' -or $main -notmatch 'CHARACTER_OVERVIEW_CURIO_TITLE_STAT_PADDING_Y' -or $main -notmatch 'level_requirement_met\s*=\s*true') {
	throw "Character overview weapon/Curio card integration was not found."
}

if ($main -notmatch 'display_name\.style\.offset\[1\]\s*=\s*CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_TITLE_SHIFT_X' -or $main -match 'display_name\.style\.offset\[1\]\s*=\s*CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_TITLE_HORIZONTAL_PADDING') {
	throw "Centered native Curio title must use an additive X delta; horizontal inset belongs in the title width."
}

if ($main -notmatch 'local CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_ITEM_LEVEL_SHIFT_Y\s*=\s*-\d+' -or $main -notmatch 'CHARACTER_OVERVIEW_NATIVE_CURIO_OVERLAY_TITLE_MARKER_GAP_Y\s*=\s*40') {
	throw "Native Curio item-level Y must move upward with a negative bottom-aligned delta, and the marker gap must remain explicit."
}

if ($main -notmatch 'local native_marker_min_y' -or $main -notmatch 'is_top_right_style' -or $main -notmatch 'attach_runtime_marker_styles' -or $main -notmatch 'refresh_character_overview_visual_layout_if_needed' -or $main -notmatch 'better_inventory_curio_fit_stat_sources' -or $main -notmatch 'fit_curio_text\(widget,\s*ui_renderer,\s*true\)' -or $main -notmatch 'type\(overview_init\)\s*==\s*"function"' -or $main -notmatch 'CHARACTER_OVERVIEW_MELEE_WIDGET_TYPE' -or $main -notmatch 'CHARACTER_OVERVIEW_RANGED_WIDGET_TYPE' -or $main -match 'CHARACTER_OVERVIEW_WEAPON_WIDGET_TYPE') {
	throw "v1.9.4 audit corrections for marker scope, marker alignment, lifecycle refresh, text-fit caching, and separate weapon blueprints were not found."
}

if ($curioVisualPlan -notmatch 'Coordinate contract and regression guard' -or $curioVisualPlan -notmatch 'offset\[1\].*X' -or $curioVisualPlan -notmatch 'offset\[2\].*Y' -or $curioVisualPlan -notmatch 'Never put a centered pass''s horizontal inset into `offset\[1\]`') {
	throw "The native Curio coordinate contract is missing from the v1.9.4 visual plan."
}

if ($main -notmatch 'move_up\s*=\s*9' -or $main -notmatch 'move_down\s*=\s*6' -or $main -notmatch 'move_down\s*=\s*4' -or $main -notmatch 'style\.offset\[2\]\s*=\s*\(style\.offset\[2\]\s*or\s*0\)\s*-\s*6' -or $main -notmatch 'style\.offset\[1\]\s*=\s*math\.max\(style\.offset\[1\]\s*or\s*0,\s*weapon_name_left\)' -or $main -notmatch 'character_overview_curio_name_mode' -or $main -notmatch 'character_overview_curio_font_size_percent' -or $main -notmatch 'curio_name_line_limit\s*=\s*curio_name_mode\s*==\s*"two_lines"\s*and\s*2' -or $main -notmatch 'curio_name_block_height\s*=\s*curio_name_font_size\s*\*\s*curio_name_line_limit\s*\+\s*11' -or $main -notmatch 'stat_style\.offset\[2\]\s*=\s*\(stat_style\.offset\[2\]\s*or\s*0\)\s*\+\s*curio_name_block_height' -or $main -notmatch 'Text\.word_wrap\(ui_renderer,\s*full_name,\s*title_style,\s*title_width\)' -or $main -notmatch 'table\.concat\(wrapped_rows,\s*"\\n"\)' -or $main -notmatch 'title_style\.font_size\s*=\s*curio_name_font_size' -or $main -notmatch 'fit_curio_text\(widget,\s*ui_renderer,\s*false\)') {
	throw "Character overview visual offsets or Curio font scaling were not found."
}

if ($main -notmatch 'better_inventory_overview_full_curio_stat_' -or $main -notmatch 'cumulative_extra_height\s*=\s*cumulative_extra_height\s*\+\s*\(line_count\s*-\s*1\)\s*\*\s*line_height' -or $main -notmatch 'CHARACTER_OVERVIEW_EMPTY_CURIO_WIDGET_TYPE' -or $main -notmatch 'content\s*and\s*content\.unlocked\s*and\s*not\s*content\.item') {
	throw "Character overview multiline Curio stats or empty-slot handling were not found."
}

if ($main -notmatch 'mod:hook\(CreditsVendorView,\s*"present_grid_layout"') {
	throw "The Requisition Weapons & Curios grid hook was not found."
}

if ($main -notmatch 'Layout\.expanded_armoury_view_definitions' -or $main -notmatch 'mod:hook\(CreditsVendorView,\s*"on_enter"') {
	throw "The expanded Requisition view or divider hook was not found."
}

if ($main -notmatch 'ItemGridViewBaseDefinitions\s*=\s*require\("scripts/ui/views/item_grid_view_base/item_grid_view_base_definitions"\)') {
	throw "The base scenegraph fallback required to move Armoury weapon details was not found."
}

if ($main -match 'CreditsGoodsVendorView\s*=\s*require' -or $main -match 'CraftingMechanicusBarterItemsView\s*=\s*require') {
	throw "The focused vendor settings must not hook Brunt's Armoury or Hadron's sacrifice flow."
}

if ($main -match 'InventoryWeaponsView\.present_grid_layout\s*=') {
	throw "Direct class assignment found; BetterInventory must remain in the DMF hook chain."
}

if ($main -notmatch 'is_armoury_requisition_view' -or $main -notmatch '_optional_store_service\s*==\s*nil' -or $main -notmatch 'is_global_store_view' -or $main -notmatch 'get_all_characters_store_custom') {
	throw "The vendor hooks must distinguish native Requisition from the optional GlobalStore service."
}

if ($main -notmatch 'pack_values\(pcall\(func,[\s\S]*?unpack_values\(results,\s*2,\s*result_count\)') {
	throw "The active-grid hook must restore context while preserving every wrapped return value."
}

if ($main -notmatch '_compact_card_defaults_v1_migrated' -or $main -notmatch 'mod:set\("show_pattern_mark",\s*false\)') {
	throw "The one-time compact-card settings migration was not found."
}

$data = Get-Content -LiteralPath (Join-Path $scriptRoot "BetterInventory_data.lua") -Raw
$localization = Get-Content -LiteralPath (Join-Path $scriptRoot "BetterInventory_localization.lua") -Raw
$layout = Get-Content -LiteralPath (Join-Path $scriptRoot "BetterInventory_layout.lua") -Raw
$features = Get-Content -LiteralPath (Join-Path $scriptRoot "BetterInventory_features.lua") -Raw
$curioAcquisition = Get-Content -LiteralPath (Join-Path $scriptRoot "BetterInventory_curio_acquisition.lua") -Raw
$curioValues = Get-Content -LiteralPath (Join-Path $scriptRoot "BetterInventory_curio_values.lua") -Raw
$itemCustomization = Get-Content -LiteralPath (Join-Path $scriptRoot "BetterInventory_item_customization.lua") -Raw

$trackedReleaseArchive = Join-Path $projectRoot "BetterInventory.zip"

if (-not (Test-Path -LiteralPath $trackedReleaseArchive -PathType Leaf)) {
	throw "Tracked release archive is missing: $trackedReleaseArchive"
}

if ($features -notmatch 'popup_id\s*=\s*nil' -or $features -notmatch 'event_remove_ui_popup' -or $features -notmatch 'active_popups' -or $features -notmatch 'Features\.reconcile_discard_transaction' -or $main -notmatch 'Features\.reconcile_discard_transaction\(\)' -or $features -notmatch 'discard_transaction_is_current\("automatic",\s*transaction_token\)' -or $features -notmatch 'Features\.clear_discard_popup\("automatic",\s*transaction_token\)') {
	throw "Discard popup lifecycle reconciliation and token ownership guard were not found."
}

if ($features -notmatch 'return automatic_discard_state\.delete_inflight\s+or discard_transaction\.owner == "automatic"' -or $features -notmatch 'delete_transaction_token\s*=\s*transaction_token' -or $features -notmatch 'release_discard_transaction\("automatic",\s*transaction_token\)') {
	throw "Automatic discard must retain shared ownership until backend deletion settles."
}

if ($main -notmatch '_better_inventory_myfavorites_active\s*=\s*true' -or $main -notmatch '_better_inventory_myfavorites_active\s*~=\s*true' -or $main -notmatch 'local pass_input, pass_draw = func\(view, dt, t, input_service\)' -or $main -notmatch 'func\(item_grid, \.\.\.\)\s*\r?\n\s*for widget in pairs\(tracked_widgets\)' -or $main -notmatch 'hotspot_style\.offset\[2\] == offset_y') {
	throw "Known UI update contracts and MyFavorites idle fast paths were not found."
}

if ($features -notmatch '_registered_sort_views' -or $features -notmatch 'Features\.rebind_sort_options' -or $features -notmatch 'Features\._registered_sort_views\[view\]\s*=\s*true' -or $features -notmatch 'Features\._registered_sort_views\[view\]\s*=\s*nil' -or $features -notmatch 'for view in pairs\(Features\._registered_sort_views\)' -or $main -notmatch 'Features\.rebind_sort_options\(mod,\s*Layout\)') {
	throw "Sort comparator ownership and disable/re-enable rebinding contract was not found."
}

if (([regex]::Matches($main, 'local previous_item\s*=\s*content\s+and\s+content\.item')).Count -lt 2 -or ([regex]::Matches($main, 'character_overview_item_changed\(previous_item,\s*current_item\)')).Count -lt 2 -or $main -notmatch 'Layout\.restore_item_customization_style\(widget\)' -or $main -notmatch 'reset_character_overview_curio_fit_state\(widget\)' -or $main -notmatch 'better_inventory_overview_fitted_curio_stat_' -or $layout -notmatch 'restore_item_customization_style' -or $layout -notmatch 'restore_item_customization_style\(widget\)\s*\r?\n\s*original_update_data') {
	throw "Character Overview item-swap cache/style refresh regression"
}

if ($layout -notmatch 'synchronize_rarity_tag_color' -or $layout -notmatch 'Items\.rarity_color' -or $layout -notmatch 'better_inventory_original_color') {
	throw "The shared Curio rarity-strip colour synchronization was not found."
}

if ($features -notmatch 'inventory_grid_has_right_neighbour' -or $features -notmatch 'navigate_right_continuous') {
	throw "The controller-navigation neighbour check was not found."
}

if ($data -notmatch 'setting_id\s*=\s*"inventory_options_controller_focus_keybind"[\s\S]*?default_value\s*=\s*"navigate_secondary_right_pressed"' -or $data -notmatch 'setting_id\s*=\s*"custom_item_name_keybind"[\s\S]*?default_value\s*=\s*"lobby_open_inventory"' -or $data -notmatch 'setting_id\s*=\s*"custom_item_background_color_keybind"[\s\S]*?default_value\s*=\s*"navigate_secondary_left_pressed"' -or $features -notmatch 'capture_inventory_options_panel_controller_focus' -or $features -notmatch 'update_inventory_options_panel_controller_selection' -or $main -notmatch 'inventory_options_panel_controller_focused') {
	throw "Controller focus switching or its conflict-free default bindings were not found."
}

if ($main -notmatch 'Features\.set_item_sorting_integration\(get_mod\("ItemSorting"\)\)' -or $main -notmatch 'Features\.preserve_item_sorting_native_options' -or $features -notmatch 'ITEM_SORTING_INVENTORY_VANILLA_SETTINGS' -or $features -notmatch 'ITEM_SORTING_STORE_VANILLA_SETTINGS' -or $features -notmatch 'item_sorting_custom_option_start' -or $features -notmatch 'item_sorting_mod_header') {
	throw "ItemSorting inventory/store panel integration was not found."
}

if ($data -notmatch 'setting_id\s*=\s*"myfavorites_integration_group"' -or $data -match 'setting_id\s*=\s*"enable_myfavorites_integration"' -or $data -notmatch 'setting_id\s*=\s*"myfavorites_show_favorite_letter"[\s\S]*?default_value\s*=\s*false' -or $layout -notmatch 'myfavorites_compatibility\s*=\s*myfavorites_hotspot\s+and\s+myfavorites_hotspot\.style' -or $layout -notmatch 'resolved_size\s*=\s*size\s+or\s+hotspot_style\.size' -or $main -notmatch 'mod:hook\(ViewElementGrid,\s*"_create_entry_widget_from_config"' -or $main -notmatch 'attach_runtime_marker_styles\(widget,\s*item_grid\)' -or $main -notmatch 'content\.better_inventory_myfavorites_hotspot_style\s*=\s*styles\.myfav_hotspot' -or $main -notmatch 'better_inventory_equipped_icon_visibility_function\s*=\s*pass\.visibility_function' -or $main -notmatch 'mod:hook\(ViewElementGrid,\s*"_update_grid_widgets"' -or $main -notmatch '_better_inventory_myfavorites_widgets' -or $main -notmatch 'tracked_widgets\[widget\]\s*=\s*true' -or $main -notmatch 'next\(tracked_widgets\)' -or $main -notmatch 'synchronize_myfavorites_marker\(widget\)' -or $layout -notmatch 'runtime_hotspot_style\.offset\[2\]\s*=\s*offset_y' -or $layout -notmatch 'content\.favorite_icon\s*=\s*compact_favorite_value' -or $layout -notmatch 'align_myfavorites_hotspot') {
	throw "MyFavorites compact-marker compatibility integration was not found."
}

if ($features -notmatch 'pcall\(view\.is_item_equipped_in_any_slot' -or $features -notmatch 'pcall\(Items\.is_item_id_favorited' -or $features -notmatch '_better_inventory_item_sorting_signature_cache' -or $features -notmatch 'poll\s*<\s*15' -or $features -notmatch '_better_inventory_armoury_native_sort_pivot_x\s*~=\s*x') {
	throw "Fail-closed sort priority or idle signature/pivot caching was not found."
}

if ($curioAcquisition -notmatch 'PromiseContainer' -or $curioAcquisition -notmatch 'track_read_promise' -or $curioAcquisition -notmatch 'reset_read_requests' -or $curioAcquisition -notmatch 'active_read_requests' -or $curioAcquisition -notmatch 'track_read_promise\(call_promise\(service, service\.fetch_all_profiles\)\)' -or $curioAcquisition -notmatch 'call_promise\(store_service, store_service\.purchase_item_with_wallet') {
	throw "Read-only Curio requests must be owned/cancelable without tracking purchase POSTs."
}

if ($itemCustomization -notmatch 'local save_ok, save_result = pcall\(dmf\.save_unsaved_settings_to_file\)' -or $itemCustomization -notmatch 'save_result == true' -or $itemCustomization -notmatch 'flush_persistence\(true\)' -or $itemCustomization -notmatch 'persistence_retry_elapsed') {
	throw "Customization persistence must retain unknown save outcomes, retry on a bounded cadence, and flush at disable."
}

if ($curioAcquisition -notmatch 'MAX_PENDING_REPORT_ITEMS' -or $curioAcquisition -notmatch 'pending_report' -or $curioAcquisition -notmatch 'deliver_pending_report' -or $curioAcquisition -notmatch 'report_context == "operative_selection"' -or $curioAcquisition -notmatch 'not is_morningstar\(\) or is_operative_selection\(\)') {
	throw "Operative Selection Curio outcomes must use bounded account-scoped deferred reporting delivered only in Morningstar."
}

if ($packagingSource -notmatch 'finally\s*{[\s\S]*?Test-Path -LiteralPath \$buildPath[\s\S]*?Remove-Item -LiteralPath \$buildPath') {
	throw "Release packaging must remove an unresolved temporary build archive after failures."
}

if ($data -match 'setting_id\s*=\s*"visible_equipment_integration_group"' -or $data -match 'setting_id\s*=\s*"enable_visible_equipment_character_overview_override"' -or $main -notmatch 'config\.widget_type\s*==\s*"gear_placement_slot"' -or $main -notmatch 'visible_equipment_placement\s+and\s+get_mod\("visible_equipment"\)' -or $main -notmatch 'pcall\(visible_equipment_mod\.is_enabled,\s*visible_equipment_mod\)' -or $main -notmatch 'preserve_visible_equipment_placement\s*=\s*visible_equipment_active' -or $main -notmatch 'not\s+preserve_visible_equipment_placement\s+and\s+setting_id') {
	throw "Visible Equipment character-overview compatibility integration was not found."
}

if ($layout -notmatch 'Layout\.armoury_grid_expansion' -or $layout -notmatch 'armoury_requisition_target_card_width') {
	throw "The Armoury target-width expansion contract was not found."
}

if ($layout -notmatch 'five_column_weapon_extra_width' -or $data -notmatch 'five_column_weapon_extra_width') {
	throw "The five-column weapon width configuration was not found."
}

if ($layout -match 'Managers\.ui:(load|unload)_item_icon' -or $layout -match 'Renderer\.(create|destroy)_resource') {
	throw "BetterInventory must not directly allocate or manage item-icon render resources."
}

if ($data -notmatch 'setting_id\s*=\s*"enable_experimental_quick_discard"[\s\S]*?default_value\s*=\s*false') {
	throw "Experimental quick discard must remain disabled by default."
}

if ($data -notmatch 'setting_id\s*=\s*"global_store_integration_group"' -or $data -notmatch 'setting_id\s*=\s*"enable_global_store_integration"[\s\S]*?default_value\s*=\s*true' -or $main -notmatch 'enable_global_store_integration') {
	throw "GlobalStore integration must have a dedicated default-on subsection and runtime switch."
}

if ($data -notmatch 'setting_id\s*=\s*"quick_discard_mode"[\s\S]*?default_value\s*=\s*"manual"' -or $data -notmatch 'setting_id\s*=\s*"quick_discard_skip_automatic_confirmation"[\s\S]*?default_value\s*=\s*false') {
	throw "Automatic discard and confirmation skipping must remain opt-in."
}

if ($data -notmatch 'setting_id\s*=\s*"quick_discard_protect_above_equipped_level"[\s\S]*?default_value\s*=\s*true') {
	throw "Higher-than-equipped item protection must remain enabled by default."
}

if ($features -notmatch 'Items\.is_item_id_favorited' -or $features -notmatch 'is_item_equipped_in_any_slot' -or $features -notmatch 'ProfileUtils\.get_profile_presets' -or $features -notmatch 'quick_discard_protect_perfect_weapons') {
	throw "Quick discard is missing a required protected-item gate."
}

if ($features -notmatch 'quick_discard_candidates\(mod,\s*layout,\s*view,\s*captured_ids\)' -or $features -notmatch 'event_discard_items') {
	throw "Quick discard must revalidate the captured preview before using Darktide's native discard event."
}

if ($main -notmatch 'mod\.on_game_state_changed' -or $main -notmatch 'Features\.update_morningstar_auto_discard' -or $features -notmatch 'game_mode_name\s*==\s*"hub"' -or $features -notmatch 'game_mode_name\s*==\s*"hub_singleplay"' -or $features -notmatch 'AUTOMATIC_DISCARD_DELAY\s*=\s*5' -or $features -notmatch 'hub_character_id\s*~=\s*character_id') {
	throw "The guarded once-per-Morningstar automatic-discard lifecycle was not found."
}

if ($data -notmatch 'setting_id\s*=\s*"enable_automatic_curio_acquisition"[\s\S]*?default_value\s*=\s*false' -or $data -notmatch 'setting_id\s*=\s*"automatic_curio_min_item_level"[\s\S]*?default_value\s*=\s*410') {
	throw "Automatic Curio acquisition must remain explicitly opt-in with a 410 default minimum item level."
}

if ($data -notmatch 'setting_id\s*=\s*"automatic_curio_min_health"[\s\S]*?default_value\s*=\s*21' -or $data -notmatch 'setting_id\s*=\s*"automatic_curio_min_toughness"[\s\S]*?default_value\s*=\s*17' -or $data -notmatch 'setting_id\s*=\s*"automatic_curio_diagnostic_logging"[\s\S]*?default_value\s*=\s*false') {
	throw "Automatic Curio acquisition must keep its 21% Health, 17% Toughness and quiet diagnostic defaults."
}

if ($data -notmatch 'setting_id\s*=\s*"automatic_curio_scan_operative_selection"[\s\S]*?default_value\s*=\s*false' -or $data -notmatch 'setting_id\s*=\s*"automatic_curio_once_per_store_rotation"[\s\S]*?default_value\s*=\s*false' -or $data -notmatch 'setting_id\s*=\s*"automatic_curio_rescan_on_store_refresh"[\s\S]*?default_value\s*=\s*false') {
	throw "Automatic Curio scheduling settings or their safe defaults are missing."
}

if ($main -notmatch 'MainMenuView' -or $main -notmatch 'hook_safe\(MainMenuView,\s*"on_enter"' -or $main -notmatch 'hook_safe\(MainMenuView,\s*"on_exit"' -or $main -notmatch 'CurioAcquisition\.leave_morningstar') {
	throw "Automatic Curio context lifecycle hooks are missing or unguarded."
}

if ($curioAcquisition -notmatch 'get_server_time' -or $curioAcquisition -notmatch 'currentRotationEnd' -or $curioAcquisition -notmatch 'validTo' -or $curioAcquisition -notmatch 'automatic_curio_once_per_store_rotation' -or $curioAcquisition -notmatch 'automatic_curio_rescan_on_store_refresh' -or $curioAcquisition -notmatch 'STORE_ROTATION_GRACE_MS') {
	throw "Automatic Curio rotation scheduling is missing backend-time, boundary, throttle or idle-refresh safeguards."
}

if ($curioAcquisition -notmatch 'local_player_safe' -or $curioAcquisition -match 'local_player,\s*player_manager,\s*1') {
	throw "Automatic Curio startup readiness must use Darktide's nil-safe local-player lookup."
}

if ($curioAcquisition -match 'os\.time\s*\(') {
	throw "Automatic Curio rotation eligibility must not use the local OS clock."
}

if ($data -notmatch 'setting_id\s*=\s*"automatic_curio_target_mode"[\s\S]*?default_value\s*=\s*"characters"' -or $data -notmatch 'setting_id\s*=\s*"automatic_curio_characters_group"' -or $curioAcquisition -notmatch 'No usable characters were returned; safely falling back to class targeting') {
	throw "Automatic Curio acquisition must default to character targeting and safely fall back to classes when no usable characters are returned."
}

foreach ($settingId in @(
	"automatic_curio_class_veteran",
	"automatic_curio_class_zealot",
	"automatic_curio_class_psyker",
	"automatic_curio_class_ogryn",
	"automatic_curio_class_adamant",
	"automatic_curio_class_broker",
	"automatic_curio_class_cryptic"
)) {
	if ($data -notmatch ('setting_id\s*=\s*"' + [regex]::Escape($settingId) + '"[\s\S]*?default_value\s*=\s*true')) {
		throw "Automatic Curio acquisition class must default to enabled: $settingId"
	}
}

if ($curioAcquisition -notmatch 'fetch_all_profiles' -or $curioAcquisition -notmatch 'StoreNames\.by_archetype\.credit' -or $curioAcquisition -notmatch 'character_wallets,\s*candidate\.character_id' -or $curioAcquisition -notmatch 'purchase_item_with_wallet') {
	throw "Automatic Curio acquisition is missing an all-character scan or explicit target-wallet purchase contract."
}

if ($curioAcquisition -notmatch 'CHARACTER_SELECTION_SETTING_ID' -or $curioAcquisition -notmatch 'character_is_enabled' -or $curioAcquisition -notmatch 'profile_is_enabled\(mod,\s*captured\.profile\)' -or $curioAcquisition -notmatch 'setting_id == nil or mod:get\(setting_id\) ~= false') {
	throw "Character targeting or future-archetype inclusion is missing its stable-ID and final-revalidation gates."
}

if ($curioValues -notmatch 'scripts/settings/buff/buff_templates' -or $curioValues -notmatch 'lerped_stat_buffs' -or $curioAcquisition -notmatch 'io_dofile\("BetterInventory/scripts/mods/BetterInventory/BetterInventory_curio_values"\)' -or $features -notmatch 'io_dofile\("BetterInventory/scripts/mods/BetterInventory/BetterInventory_curio_values"\)' -or $curioAcquisition -notmatch 'CurioValues\.resolve' -or $features -notmatch 'CurioValues\.resolve') {
	throw "Curio buyer filtering and discard protection must share vanilla BuffTemplate roll conversion."
}

if ($main -notmatch 'no_op_module' -or $main -notmatch 'Failed to load %s; its features are disabled') {
	throw "Runtime feature-module failures must degrade safely instead of spamming the per-frame update hook."
}

if ($curioAcquisition -notmatch 'MAX_OFFER_ERROR_LOGS_PER_SCAN\s*=\s*5' -or $curioAcquisition -notmatch 'MAX_ERROR_TEXT_LENGTH\s*=\s*1000' -or $curioAcquisition -notmatch 'automatic_curio_diagnostic_logging') {
	throw "Automatic Curio acquisition logging must remain opt-in for detail and bounded for always-on errors."
}

if ($curioAcquisition -match 'purchase_item\(current\.offer' -or $curioAcquisition -match 'purchase_item\(offer') {
	throw "Cross-character Curio purchases must never use StoreService.purchase_item with the selected character's wallet."
}

if ($curioAcquisition -notmatch 'fetch_storefront\(captured\.profile\)[\s\S]*?same_candidate\(captured,\s*current\)' -or $curioAcquisition -notmatch 'processed_offer_keys\[key\]\s*=\s*"in_flight"') {
	throw "Automatic Curio acquisition must re-fetch every offer and establish idempotency before purchase."
}

if ($main -notmatch 'CurioAcquisition\.update\(mod,\s*dt,\s*Features\.morningstar_auto_discard_is_busy\(mod\)\)' -or $features -notmatch 'automatic_curio_acquisition_protects') {
	throw "Automatic discard and Curio acquisition are missing their sequencing or cross-feature protection contract."
}

if ($features -notmatch 'progression_manager\.is_fetching_session_report' -or $features -notmatch 'gear_service:invalidate_gear_cache\(\)[\s\S]*?fetch_inventory_promise\(gear_service,\s*character_id\)') {
	throw "Automatic discard must wait for mission rewards and refresh the gear cache before its first inventory scan."
}

if ($features -notmatch 'automatic_protection_snapshot\(character_id\)' -or $features -notmatch 'quick_discard_candidates_from_items\(mod,\s*items,\s*protection\.equipped_gear_ids,\s*captured_ids,\s*protection\.favorite_gear_ids\)' -or $features -notmatch 'quick_discard_skip_automatic_confirmation' -or $features -notmatch 'gear_service\.delete_gear_batch') {
	throw "Automatic discard must re-fetch and revalidate captured IDs before the native gear service deletes them."
}

if ($main -notmatch 'local_blueprints\s*=\s*shallow_copy\(content_blueprints\)[\s\S]*?local_item_blueprint\s*=\s*table\.clone\(item_blueprint\)' -or $features -notmatch 'adjusted_blueprints\s*=\s*shallow_copy\(content_blueprints\)[\s\S]*?adjusted_header\s*=\s*table\.clone\(gadget_header\)') {
	throw "Blueprint transforms must clone only the target blueprint instead of every shared blueprint."
}

$settingMatches = [regex]::Matches($data, 'setting_id\s*=\s*"([^"]+)"')
$dropdownTextMatches = [regex]::Matches($data, 'text\s*=\s*"([^"]+)"')
$settingIds = @(
	$settingMatches | ForEach-Object { $_.Groups[1].Value }
	$dropdownTextMatches | ForEach-Object { $_.Groups[1].Value }
) | Sort-Object -Unique

foreach ($settingId in $settingIds) {
	$escapedId = [regex]::Escape($settingId)

	if ($localization -notmatch "(?m)^\s*$escapedId\s*=\s*{") {
		throw "Missing English localization entry for setting: $settingId"
	}
}

$dmfRoot = Join-Path $projectRoot "..\..\mods\dmf"
$dmfSettings = Join-Path $dmfRoot "scripts\mods\dmf\modules\core\settings.lua"
$dmfOptionBlueprints = Join-Path $dmfRoot "scripts\mods\dmf\modules\ui\options\dmf_options_view_content_blueprints.lua"
$dmfModOptions = Join-Path $dmfRoot "scripts\mods\dmf\modules\ui\options\mod_options.lua"

foreach ($dmfFile in @($dmfSettings, $dmfOptionBlueprints, $dmfModOptions)) {
	if (-not (Test-Path -LiteralPath $dmfFile -PathType Leaf)) {
		throw "Missing expected DMF source file: $dmfFile"
	}
}

if ((Get-Content -LiteralPath $dmfSettings -Raw) -notmatch 'mod_setting_changed_event\(self, setting_id\)') {
	throw "DMF no longer appears to dispatch live mod setting changes."
}

if ((Get-Content -LiteralPath $dmfOptionBlueprints -Raw) -notmatch 'local is_disabled = entry\.disabled or false') {
	throw "DMF option widgets no longer appear to consume final-template disabled state."
}

if ((Get-Content -LiteralPath $dmfModOptions -Raw) -notmatch 'create_mod_options_settings') {
	throw "DMF's final mod-options template seam was not found."
}

if ($DarktideSourcePath) {
	$inventoryView = Join-Path $DarktideSourcePath "scripts\ui\views\inventory_weapons_view\inventory_weapons_view.lua"
	$hadronModifyView = Join-Path $DarktideSourcePath "scripts\ui\views\crafting_mechanicus_modify_view\crafting_mechanicus_modify_view.lua"
	$craftingViewDefinitions = Join-Path $DarktideSourcePath "scripts\ui\views\crafting_view\crafting_view_definitions.lua"
	$creditsVendorView = Join-Path $DarktideSourcePath "scripts\ui\views\credits_vendor_view\credits_vendor_view.lua"
	$creditsVendorBackgroundDefinitions = Join-Path $DarktideSourcePath "scripts\ui\views\credits_vendor_background_view\credits_vendor_background_view_definitions.lua"
	$itemGridBase = Join-Path $DarktideSourcePath "scripts\ui\views\item_grid_view_base\item_grid_view_base.lua"
	$itemGridBaseDefinitions = Join-Path $DarktideSourcePath "scripts\ui\views\item_grid_view_base\item_grid_view_base_definitions.lua"
	$itemBlueprints = Join-Path $DarktideSourcePath "scripts\ui\view_content_blueprints\item_blueprints.lua"
	$iconGenerator = Join-Path $DarktideSourcePath "scripts\ui\render_target_icon_generator_base.lua"
	$items = Join-Path $DarktideSourcePath "scripts\utilities\items.lua"
	$masterItems = Join-Path $DarktideSourcePath "scripts\backend\master_items.lua"
	$gadgetTraits = Join-Path $DarktideSourcePath "scripts\settings\equipment\gadget_traits\gadget_traits_common.lua"
	$weaponPerksMelee = Join-Path $DarktideSourcePath "scripts\settings\equipment\weapon_traits\weapon_perks_melee.lua"
	$weaponPerksRanged = Join-Path $DarktideSourcePath "scripts\settings\equipment\weapon_traits\weapon_perks_ranged.lua"
	$traitValueParser = Join-Path $DarktideSourcePath "scripts\utilities\trait_value_parser.lua"
	$gadgetBuffTemplates = Join-Path $DarktideSourcePath "scripts\settings\buff\gadget_buff_templates.lua"
	$gearService = Join-Path $DarktideSourcePath "scripts\managers\data_service\services\gear_service.lua"
	$progressionManager = Join-Path $DarktideSourcePath "scripts\managers\progression\progression_manager.lua"

	foreach ($sourceFile in @($inventoryView, $hadronModifyView, $craftingViewDefinitions, $creditsVendorView, $creditsVendorBackgroundDefinitions, $itemGridBase, $itemGridBaseDefinitions, $itemBlueprints, $iconGenerator, $items, $masterItems, $gadgetTraits, $weaponPerksMelee, $weaponPerksRanged, $traitValueParser, $gadgetBuffTemplates, $gearService, $progressionManager)) {
		if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
			throw "Missing expected Darktide source file: $sourceFile"
		}
	}

	if ((Get-Content -LiteralPath $itemGridBase -Raw) -notmatch 'ItemGridViewBase\.present_grid_layout') {
		throw "The current ItemGridViewBase presentation seam was not found."
	}

	$itemGridBaseDefinitionsSource = Get-Content -LiteralPath $itemGridBaseDefinitions -Raw
	$inventoryViewSource = Get-Content -LiteralPath $inventoryView -Raw

	if ($itemGridBaseDefinitionsSource -notmatch 'weapon_stats_pivot\s*=\s*{' -or $itemGridBaseDefinitionsSource -notmatch 'weapon_compare_stats_pivot\s*=\s*{') {
		throw "The base weapon-details scenegraph pivots were not found."
	}

	if ($itemGridBaseDefinitionsSource -notmatch 'local width, height = 530, 920') {
		throw "The weapon-details width used by the inventory safety clamp has changed."
	}

	if ($inventoryViewSource -notmatch 'InventoryWeaponsView\._setup_weapon_actions[\s\S]*?local grid_width = 420') {
		throw "The weapon-actions width used by the inventory safety clamp has changed."
	}

	if ($inventoryViewSource -notmatch 'InventoryWeaponsView\.is_item_equipped_in_any_slot' -or $inventoryViewSource -notmatch 'InventoryWeaponsView\.cb_on_favorite_pressed') {
		throw "The Curio equipped/favorite sorting APIs were not found."
	}

	$traitParserSource = Get-Content -LiteralPath $traitValueParser -Raw
	$gadgetBuffSource = Get-Content -LiteralPath $gadgetBuffTemplates -Raw

	if ($traitParserSource -notmatch 'math\.round\(value \* 100\)' -or $gadgetBuffSource -notmatch 'math\.round_with_precision\(value, 2\)') {
		throw "Curio innate percentages no longer appear to be quantized to whole percentage points. Re-audit precise Curio values."
	}

	if ((Get-Content -LiteralPath $hadronModifyView -Raw) -notmatch 'class\("CraftingMechanicusModifyView",\s*"ItemGridViewBase"\)') {
		throw "Entreat Hadron no longer appears to use CraftingMechanicusModifyView's item grid."
	}

	if ((Get-Content -LiteralPath $craftingViewDefinitions -Raw) -notmatch 'view\s*=\s*"crafting_mechanicus_modify_view"') {
		throw "The Entreat Hadron route no longer maps to crafting_mechanicus_modify_view."
	}

	if ((Get-Content -LiteralPath $creditsVendorView -Raw) -notmatch 'class\("CreditsVendorView",\s*"VendorViewBase"\)') {
		throw "Requisition Weapons & Curios no longer appears to use CreditsVendorView."
	}

	if ((Get-Content -LiteralPath $creditsVendorBackgroundDefinitions -Raw) -notmatch 'display_name\s*=\s*"loc_credits_vendor_view_option_buy"[\s\S]*?view\s*=\s*"credits_vendor_view"') {
		throw "The Armoury requisition route no longer maps to credits_vendor_view."
	}

	$itemBlueprintSource = Get-Content -LiteralPath $itemBlueprints -Raw

	if ($itemBlueprintSource -notmatch '(?m)^\s*item\s*=\s*{' -or $itemBlueprintSource -notmatch '(?m)^\s*store_item\s*=\s*{') {
		throw "The current inventory or Armoury item blueprint was not found."
	}

	if ($itemBlueprintSource -notmatch 'Managers\.ui:load_item_icon') {
		throw "The current managed item-icon API was not found."
	}

	if ((Get-Content -LiteralPath $iconGenerator -Raw) -notmatch 'optional_render_context\s+and\s+optional_render_context\.size') {
		throw "The current icon renderer no longer appears to accept a requested size."
	}

	$itemsSource = Get-Content -LiteralPath $items -Raw
	$gearServiceSource = Get-Content -LiteralPath $gearService -Raw
	$progressionManagerSource = Get-Content -LiteralPath $progressionManager -Raw

	if ($gearServiceSource -notmatch 'GearService\.fetch_inventory' -or $gearServiceSource -notmatch 'GearService\.delete_gear_batch' -or $gearServiceSource -notmatch 'local max_operations = 40') {
		throw "The audited inventory-fetch or bounded batch-delete gear service contract has changed."
	}

	if ($progressionManagerSource -notmatch 'if #item_rewards > 0 then[\s\S]*?invalidate_gear_cache\(\)[\s\S]*?Items\.mark_item_id_as_new\(reward\)') {
		throw "Darktide's mission-reward gear-cache invalidation contract has changed."
	}

	if (
		$itemsSource -notmatch 'Items\.weapon_lore_mark_name' -or
		$itemsSource -notmatch 'Items\.weapon_lore_pattern_name' -or
		$itemsSource -notmatch 'Items\.trait_textures' -or
		$itemsSource -notmatch 'Items\.perk_textures' -or
		$itemsSource -notmatch 'Items\.trait_description' -or
		$itemsSource -notmatch 'Items\.expertise_level\s*=\s*function\s*\(item,\s*no_symbol' -or
		$itemsSource -notmatch 'if\s+no_symbol\s+then'
	) {
		throw "One or more current card-content APIs were not found."
	}

	$gadgetTraitSource = Get-Content -LiteralPath $gadgetTraits -Raw

	foreach ($traitId in @(
		"gadget_innate_health_increase",
		"gadget_innate_toughness_increase",
		"gadget_innate_max_wounds_increase",
		"gadget_stamina_increase",
		"gadget_cooldown_reduction",
		"gadget_corruption_resistance",
		"gadget_block_cost_reduction",
		"gadget_sprint_cost_reduction",
		"gadget_stamina_regeneration",
		"gadget_damage_reduction_vs_flamers",
		"gadget_damage_reduction_vs_snipers",
		"gadget_damage_reduction_vs_grenadiers",
		"gadget_damage_reduction_vs_hounds",
		"gadget_damage_reduction_vs_mutants",
		"gadget_damage_reduction_vs_gunners",
		"gadget_damage_reduction_vs_bombers",
		"gadget_permanent_damage_resistance",
		"gadget_mission_reward_gear_instead_of_weapon_increase",
		"gadget_toughness_regen_delay",
		"gadget_mission_credits_increase",
		"gadget_revive_speed_increase"
	)) {
		if ($gadgetTraitSource -notmatch [regex]::Escape($traitId)) {
			throw "The expected Curio primary trait ID was not found: $traitId"
		}
	}

	$weaponPerkSources = @(
		(Get-Content -LiteralPath $weaponPerksMelee -Raw),
		(Get-Content -LiteralPath $weaponPerksRanged -Raw)
	) -join "`n"

	$weaponPerkMatches = [regex]::Matches($weaponPerkSources, 'weapon_traits_[a-z_]+\.(weapon_trait_[a-z0-9_]+)\s*=\s*{')
	$weaponPerkIds = @($weaponPerkMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

	if ($weaponPerkIds.Count -eq 0) {
		throw "No current melee or ranged weapon perk IDs were discovered."
	}

	foreach ($traitId in $weaponPerkIds) {
		if ($layout -notmatch ('"' + [regex]::Escape($traitId) + '"')) {
			throw "BetterInventory has no compact-label mapping for current weapon perk: $traitId"
		}
	}
}

$hasLuaParser = $false
$hasLupa = $false

if (Get-Command py -ErrorAction SilentlyContinue) {
	py -3 -c "import luaparser" 2>$null
	$hasLuaParser = $LASTEXITCODE -eq 0
	py -3 -c "import lupa" 2>$null
	$hasLupa = $LASTEXITCODE -eq 0
}

if ($hasLuaParser) {
	$luaFiles = Get-ChildItem -LiteralPath $projectRoot -Recurse -File |
		Where-Object { $_.Extension -in @(".lua", ".mod") }

	foreach ($luaFile in $luaFiles) {
		py -3 -c "from luaparser import ast; ast.parse(open(r'''$($luaFile.FullName)''', encoding='utf-8').read())"

		if ($LASTEXITCODE -ne 0) {
			throw "Lua syntax validation failed: $($luaFile.FullName)"
		}
	}
}

if ($hasLupa) {
	foreach ($behaviorTest in @("test_layout.py", "test_settings.py", "test_features.py", "test_curio_acquisition.py", "test_item_customization.py")) {
		py -3 (Join-Path $PSScriptRoot $behaviorTest)

		if ($LASTEXITCODE -ne 0) {
			throw "Behavior test failed: $behaviorTest"
		}
	}
}

$packagingTestArchive = Join-Path ([IO.Path]::GetTempPath()) "BetterInventory-package-test-$([Guid]::NewGuid().ToString('N')).zip"

try {
	& $releasePackager -OutputPath $packagingTestArchive

	Add-Type -AssemblyName System.IO.Compression.FileSystem
	$packagingTest = [IO.Compression.ZipFile]::OpenRead($packagingTestArchive)

	try {
		$actualReleasePaths = @($packagingTest.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) } | ForEach-Object { $_.FullName } | Sort-Object)
		$expectedReleasePaths = @("BetterInventory/BetterInventory.mod")
		$expectedReleasePaths += @($runtimeLuaFiles | ForEach-Object { "BetterInventory/scripts/mods/BetterInventory/$($_.Name)" })
		$expectedReleasePaths = @($expectedReleasePaths | Sort-Object)

		if (@(Compare-Object $expectedReleasePaths $actualReleasePaths).Count -gt 0) {
			throw "Independent release test found a Nexus-incompatible archive layout."
		}

		if (@($actualReleasePaths | Where-Object { $_.Contains("\") }).Count -gt 0) {
			throw "Independent release test found a backslash-bearing ZIP entry."
		}

		$localModuleReferences = @(
			$runtimeLuaFiles | ForEach-Object {
				$content = Get-Content -LiteralPath $_.FullName -Raw
				[regex]::Matches($content, 'io_dofile\("BetterInventory/scripts/mods/BetterInventory/([^".]+)"\)') | ForEach-Object {
					"BetterInventory/scripts/mods/BetterInventory/$($_.Groups[1].Value).lua"
				}
			} | Sort-Object -Unique
		)
		$missingReferencedModules = @($localModuleReferences | Where-Object { $_ -notin $actualReleasePaths })

		if ($missingReferencedModules.Count -gt 0) {
			throw "Release archive is missing locally loaded module(s): $($missingReferencedModules -join ', ')"
		}
	} finally {
		$packagingTest.Dispose()
	}
} finally {
	if (Test-Path -LiteralPath $packagingTestArchive -PathType Leaf) {
		[IO.File]::Delete($packagingTestArchive)
	}
}

$trackedArchive = [IO.Compression.ZipFile]::OpenRead($trackedReleaseArchive)

try {
	$trackedEntryMap = @{}

	foreach ($entry in $trackedArchive.Entries) {
		if (-not [string]::IsNullOrEmpty($entry.Name)) {
			if ($entry.FullName.Contains("\")) {
				throw "Tracked release archive entry uses a Windows path separator: $($entry.FullName)"
			}

			$trackedEntryMap[$entry.FullName] = $entry
		}
	}

	$expectedTrackedPaths = @("BetterInventory/BetterInventory.mod")
	$expectedTrackedPaths += @($runtimeLuaFiles | ForEach-Object { "BetterInventory/scripts/mods/BetterInventory/$($_.Name)" })
	$expectedTrackedPaths = @($expectedTrackedPaths | Sort-Object)
	$actualTrackedPaths = @($trackedEntryMap.Keys | Sort-Object)

	if (@(Compare-Object $expectedTrackedPaths $actualTrackedPaths).Count -gt 0) {
		throw "Tracked release archive does not contain the current runtime file set. Rebuild BetterInventory.zip."
	}

	foreach ($archivePath in $expectedTrackedPaths) {
		$entryStream = $trackedEntryMap[$archivePath].Open()
		$sha256 = [Security.Cryptography.SHA256]::Create()

		try {
			$entryHash = ([BitConverter]::ToString($sha256.ComputeHash($entryStream))).Replace("-", "")
		} finally {
			$sha256.Dispose()
			$entryStream.Dispose()
		}

		$sourcePath = if ($archivePath -eq "BetterInventory/BetterInventory.mod") {
			Join-Path $projectRoot "BetterInventory.mod"
		} else {
			Join-Path $scriptRoot ([IO.Path]::GetFileName($archivePath))
		}
		$sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash

		if ($entryHash -ne $sourceHash) {
			throw "Tracked release archive hash mismatch: $archivePath. Rebuild BetterInventory.zip."
		}
	}

	$dataEntry = $trackedEntryMap["BetterInventory/scripts/mods/BetterInventory/BetterInventory_data.lua"]
	$dataReader = New-Object IO.StreamReader($dataEntry.Open())

	try {
		$trackedData = $dataReader.ReadToEnd()
	} finally {
		$dataReader.Dispose()
	}

	$sourceVersionMatch = [regex]::Match($data, 'MOD_VERSION\s*=\s*"([^"]+)"')
	$trackedVersionMatch = [regex]::Match($trackedData, 'MOD_VERSION\s*=\s*"([^"]+)"')

	if (-not $sourceVersionMatch.Success -or -not $trackedVersionMatch.Success -or $sourceVersionMatch.Groups[1].Value -ne $trackedVersionMatch.Groups[1].Value) {
		throw "Tracked release archive version does not match BetterInventory_data.lua. Rebuild BetterInventory.zip."
	}
} finally {
	$trackedArchive.Dispose()
}

Write-Host "Tracked release archive parity verified: $trackedReleaseArchive" -ForegroundColor Green

Write-Host "BetterInventory static verification passed." -ForegroundColor Green
