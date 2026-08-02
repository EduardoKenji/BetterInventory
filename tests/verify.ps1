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

if ($main -match 'InventoryWeaponsView\.present_grid_layout\s*=') {
	throw "Direct class assignment found; BetterInventory must remain in the DMF hook chain."
}

if ($main -notmatch '_compact_card_defaults_v1_migrated' -or $main -notmatch 'mod:set\("show_pattern_mark",\s*false\)') {
	throw "The one-time compact-card settings migration was not found."
}

$data = Get-Content -LiteralPath (Join-Path $scriptRoot "BetterInventory_data.lua") -Raw
$localization = Get-Content -LiteralPath (Join-Path $scriptRoot "BetterInventory_localization.lua") -Raw
$settingMatches = [regex]::Matches($data, 'setting_id\s*=\s*"([^"]+)"')
$settingIds = $settingMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

foreach ($settingId in $settingIds) {
	$escapedId = [regex]::Escape($settingId)

	if ($localization -notmatch "(?m)^\s*$escapedId\s*=\s*{") {
		throw "Missing English localization entry for setting: $settingId"
	}
}

if ($DarktideSourcePath) {
	$inventoryView = Join-Path $DarktideSourcePath "scripts\ui\views\inventory_weapons_view\inventory_weapons_view.lua"
	$itemGridBase = Join-Path $DarktideSourcePath "scripts\ui\views\item_grid_view_base\item_grid_view_base.lua"
	$itemBlueprints = Join-Path $DarktideSourcePath "scripts\ui\view_content_blueprints\item_blueprints.lua"
	$iconGenerator = Join-Path $DarktideSourcePath "scripts\ui\render_target_icon_generator_base.lua"
	$items = Join-Path $DarktideSourcePath "scripts\utilities\items.lua"

	foreach ($sourceFile in @($inventoryView, $itemGridBase, $itemBlueprints, $iconGenerator, $items)) {
		if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
			throw "Missing expected Darktide source file: $sourceFile"
		}
	}

	if ((Get-Content -LiteralPath $itemGridBase -Raw) -notmatch 'ItemGridViewBase\.present_grid_layout') {
		throw "The current ItemGridViewBase presentation seam was not found."
	}

	if ((Get-Content -LiteralPath $itemBlueprints -Raw) -notmatch 'Managers\.ui:load_item_icon') {
		throw "The current managed item-icon API was not found."
	}

	if ((Get-Content -LiteralPath $iconGenerator -Raw) -notmatch 'optional_render_context\s+and\s+optional_render_context\.size') {
		throw "The current icon renderer no longer appears to accept a requested size."
	}

	$itemsSource = Get-Content -LiteralPath $items -Raw

	if ($itemsSource -notmatch 'Items\.weapon_lore_mark_name' -or $itemsSource -notmatch 'Items\.weapon_lore_pattern_name') {
		throw "The current weapon Mark/pattern naming APIs were not found."
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
	py -3 (Join-Path $PSScriptRoot "test_layout.py")

	if ($LASTEXITCODE -ne 0) {
		throw "Layout behavior tests failed."
	}
}

Write-Host "BetterInventory static verification passed." -ForegroundColor Green
