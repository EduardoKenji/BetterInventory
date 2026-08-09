param(
	[string] $DestinationPath
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceScriptRoot = Join-Path $projectRoot "scripts\mods\BetterInventory"

if (-not $DestinationPath) {
	$contentRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot "..\.."))
	$DestinationPath = Join-Path $contentRoot "mods\BetterInventory"
}

$resolvedDestination = [IO.Path]::GetFullPath($DestinationPath)
$destinationScriptRoot = Join-Path $resolvedDestination "scripts\mods\BetterInventory"
$sourceFiles = @(
	Get-Item -LiteralPath (Join-Path $projectRoot "BetterInventory.mod")
	Get-ChildItem -LiteralPath $sourceScriptRoot -File -Recurse
)

foreach ($sourceFile in $sourceFiles) {
	$relativePath = if ($sourceFile.FullName -eq (Join-Path $projectRoot "BetterInventory.mod")) {
		"BetterInventory.mod"
	} else {
		Join-Path "scripts\mods\BetterInventory" $sourceFile.FullName.Substring($sourceScriptRoot.Length).TrimStart("\")
	}
	$destinationFile = Join-Path $resolvedDestination $relativePath
	$destinationDirectory = Split-Path -Parent $destinationFile

	New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
	Copy-Item -LiteralPath $sourceFile.FullName -Destination $destinationFile -Force

	if ((Get-FileHash -Algorithm SHA256 -LiteralPath $sourceFile.FullName).Hash -ne (Get-FileHash -Algorithm SHA256 -LiteralPath $destinationFile).Hash) {
		throw "Installed runtime hash mismatch after copy: $relativePath"
	}
}

Write-Host "BetterInventory installed runtime synchronized and hash-verified: $resolvedDestination" -ForegroundColor Green
