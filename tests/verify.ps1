param(
	[string] $DarktideSourcePath
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptRoot = Join-Path $projectRoot "scripts\mods\BetterInventory"
$requiredFiles = @(
	(Join-Path $projectRoot "BetterInventory.mod"),
	(Join-Path $scriptRoot "BetterInventory.lua"),
	(Join-Path $scriptRoot "BetterInventory_layout.lua"),
	(Join-Path $scriptRoot "BetterInventory_data.lua"),
	(Join-Path $scriptRoot "BetterInventory_localization.lua")
)

foreach ($file in $requiredFiles) {
	if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
		throw "Missing required file: $file"
	}
}

$main = Get-Content -LiteralPath (Join-Path $scriptRoot "BetterInventory.lua") -Raw

if ($main -notmatch 'mod:hook\(InventoryWeaponsView,\s*"present_grid_layout"') {
	throw "The InventoryWeaponsView hook was not found."
}

if ($main -notmatch 'mod:hook\(CraftingMechanicusModifyView,\s*"present_grid_layout"') {
	throw "The Entreat Hadron grid hook was not found."
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

if ($main -notmatch '_compact_card_defaults_v1_migrated' -or $main -notmatch 'mod:set\("show_pattern_mark",\s*false\)') {
	throw "The one-time compact-card settings migration was not found."
}

$data = Get-Content -LiteralPath (Join-Path $scriptRoot "BetterInventory_data.lua") -Raw
$localization = Get-Content -LiteralPath (Join-Path $scriptRoot "BetterInventory_localization.lua") -Raw
$layout = Get-Content -LiteralPath (Join-Path $scriptRoot "BetterInventory_layout.lua") -Raw

if ($layout -notmatch 'Layout\.armoury_grid_expansion' -or $layout -notmatch 'armoury_requisition_target_card_width') {
	throw "The Armoury target-width expansion contract was not found."
}

if ($layout -match 'Managers\.ui:(load|unload)_item_icon' -or $layout -match 'Renderer\.(create|destroy)_resource') {
	throw "BetterInventory must not directly allocate or manage item-icon render resources."
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

	foreach ($sourceFile in @($inventoryView, $hadronModifyView, $craftingViewDefinitions, $creditsVendorView, $creditsVendorBackgroundDefinitions, $itemGridBase, $itemGridBaseDefinitions, $itemBlueprints, $iconGenerator, $items, $masterItems, $gadgetTraits, $weaponPerksMelee, $weaponPerksRanged)) {
		if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
			throw "Missing expected Darktide source file: $sourceFile"
		}
	}

	if ((Get-Content -LiteralPath $itemGridBase -Raw) -notmatch 'ItemGridViewBase\.present_grid_layout') {
		throw "The current ItemGridViewBase presentation seam was not found."
	}

	$itemGridBaseDefinitionsSource = Get-Content -LiteralPath $itemGridBaseDefinitions -Raw

	if ($itemGridBaseDefinitionsSource -notmatch 'weapon_stats_pivot\s*=\s*{' -or $itemGridBaseDefinitionsSource -notmatch 'weapon_compare_stats_pivot\s*=\s*{') {
		throw "The base weapon-details scenegraph pivots were not found."
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
	foreach ($behaviorTest in @("test_layout.py", "test_settings.py")) {
		py -3 (Join-Path $PSScriptRoot $behaviorTest)

		if ($LASTEXITCODE -ne 0) {
			throw "Behavior test failed: $behaviorTest"
		}
	}
}

Write-Host "BetterInventory static verification passed." -ForegroundColor Green
