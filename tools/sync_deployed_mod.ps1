param(
	[string] $TargetPath
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $projectRoot "scripts\mods\BetterInventory"
$descriptor = Join-Path $projectRoot "BetterInventory.mod"
$contentRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot "..\.."))

if ([string]::IsNullOrWhiteSpace($TargetPath)) {
	$TargetPath = Join-Path $contentRoot "mods\BetterInventory"
}

$targetRoot = [IO.Path]::GetFullPath($TargetPath)
$contentPrefix = $contentRoot.TrimEnd("\") + "\"

if (-not $targetRoot.StartsWith($contentPrefix, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($targetRoot) -ne "BetterInventory") {
	throw "Refusing to synchronize outside Content\mods\BetterInventory: $targetRoot"
}

if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container) -or -not (Test-Path -LiteralPath $descriptor -PathType Leaf)) {
	throw "BetterInventory source runtime is incomplete: $projectRoot"
}

New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
$sourceFiles = @($descriptor) + @(Get-ChildItem -LiteralPath $sourceRoot -Filter "*.lua" -File -Recurse | Sort-Object FullName | ForEach-Object { $_.FullName })

foreach ($sourceFile in $sourceFiles) {
	if ($sourceFile -eq $descriptor) {
		$relativePath = "BetterInventory.mod"
	} else {
		$relativePath = "scripts\mods\BetterInventory" + $sourceFile.Substring($sourceRoot.Length)
	}

	$destination = Join-Path $targetRoot $relativePath
	$destinationDirectory = Split-Path -Parent $destination
	New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
	Copy-Item -LiteralPath $sourceFile -Destination $destination -Force
}

$expected = @{}
foreach ($sourceFile in $sourceFiles) {
	if ($sourceFile -eq $descriptor) {
		$relativePath = "BetterInventory.mod"
	} else {
		$relativePath = "scripts\mods\BetterInventory" + $sourceFile.Substring($sourceRoot.Length)
	}

	$expected[$relativePath] = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceFile).Hash
}

$actual = @{}
$targetDescriptor = Join-Path $targetRoot "BetterInventory.mod"
if (Test-Path -LiteralPath $targetDescriptor -PathType Leaf) {
	$actual["BetterInventory.mod"] = (Get-FileHash -Algorithm SHA256 -LiteralPath $targetDescriptor).Hash
}

$targetScriptRoot = Join-Path $targetRoot "scripts\mods\BetterInventory"
if (Test-Path -LiteralPath $targetScriptRoot -PathType Container) {
	Get-ChildItem -LiteralPath $targetScriptRoot -Filter "*.lua" -File -Recurse | ForEach-Object {
		$relativePath = "scripts\mods\BetterInventory" + $_.FullName.Substring($targetScriptRoot.Length)
		$actual[$relativePath] = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
	}
}

$differences = @(Compare-Object (@($expected.Keys | Sort-Object)) (@($actual.Keys | Sort-Object)))
if ($differences.Count -gt 0) {
	throw "Deployed runtime file set differs from source. Re-run sync or remove stale runtime Lua files from $targetRoot."
}

foreach ($relativePath in $expected.Keys) {
	if ($expected[$relativePath] -ne $actual[$relativePath]) {
		throw "Deployed runtime hash mismatch: $relativePath"
	}
}

Write-Host "BetterInventory deployed runtime synchronized: $targetRoot" -ForegroundColor Green
Write-Host "Runtime files verified: $($expected.Count)"
