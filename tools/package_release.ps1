param(
	[Parameter(Mandatory = $true)]
	[string] $OutputPath
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptRoot = Join-Path $projectRoot "scripts\mods\BetterInventory"
$archiveRoot = "BetterInventory"
$runtimeFiles = [ordered]@{
	"$archiveRoot/BetterInventory.mod" = Join-Path $projectRoot "BetterInventory.mod"
}

# Package every runtime Lua source by discovery. A hand-maintained allowlist
# previously omitted a newly introduced module while still passing a verifier
# that duplicated the same incomplete list.
$runtimeLuaFiles = @(Get-ChildItem -LiteralPath $scriptRoot -Filter "BetterInventory*.lua" -File | Sort-Object Name)

if ($runtimeLuaFiles.Count -eq 0) {
	throw "No BetterInventory runtime Lua files were discovered in: $scriptRoot"
}

foreach ($sourceFile in $runtimeLuaFiles) {
	$runtimeFiles["$archiveRoot/scripts/mods/BetterInventory/$($sourceFile.Name)"] = $sourceFile.FullName
}

foreach ($sourcePath in $runtimeFiles.Values) {
	if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
		throw "Missing runtime source file: $sourcePath"
	}
}

$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutput

if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
	throw "Output directory does not exist: $outputDirectory"
}

$buildName = ".BetterInventory-build-$([Guid]::NewGuid().ToString('N')).zip"
$buildPath = Join-Path $outputDirectory $buildName

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$archive = [IO.Compression.ZipFile]::Open($buildPath, [IO.Compression.ZipArchiveMode]::Create)

try {
	foreach ($archivePath in $runtimeFiles.Keys) {
		$entry = $archive.CreateEntry($archivePath, [IO.Compression.CompressionLevel]::Optimal)
		$entryStream = $entry.Open()
		$sourceStream = [IO.File]::OpenRead($runtimeFiles[$archivePath])

		try {
			$sourceStream.CopyTo($entryStream)
		} finally {
			$sourceStream.Dispose()
			$entryStream.Dispose()
		}
	}
} finally {
	$archive.Dispose()
}

$archive = [IO.Compression.ZipFile]::OpenRead($buildPath)

try {
	$entryMap = @{}

	foreach ($entry in $archive.Entries) {
		if (-not [string]::IsNullOrEmpty($entry.Name)) {
			if ($entry.FullName.Contains("\")) {
				throw "Release archive entry uses a Windows path separator: $($entry.FullName)"
			}

			$entryMap[$entry.FullName] = $entry
		}
	}

	$expectedPaths = @($runtimeFiles.Keys | Sort-Object)
	$actualPaths = @($entryMap.Keys | Sort-Object)
	$differences = @(Compare-Object $expectedPaths $actualPaths)

	if ($differences.Count -gt 0) {
		throw "Release archive has an incorrect runtime file set."
	}

	if (@($actualPaths | Where-Object { $_ -notlike "$archiveRoot/*" }).Count -gt 0) {
		throw "Release archive contains a file outside the required $archiveRoot/ install directory."
	}

	if (@($actualPaths | Where-Object { $_ -like "$archiveRoot/$archiveRoot/*" }).Count -gt 0) {
		throw "Release archive contains a duplicated $archiveRoot/$archiveRoot/ directory."
	}

	foreach ($archivePath in $expectedPaths) {
		$entryStream = $entryMap[$archivePath].Open()
		$sha256 = [Security.Cryptography.SHA256]::Create()

		try {
			$entryHash = ([BitConverter]::ToString($sha256.ComputeHash($entryStream))).Replace("-", "")
		} finally {
			$sha256.Dispose()
			$entryStream.Dispose()
		}

		$sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $runtimeFiles[$archivePath]).Hash

		if ($entryHash -ne $sourceHash) {
			throw "Release archive hash mismatch: $archivePath"
		}
	}
} finally {
	$archive.Dispose()
}

Move-Item -LiteralPath $buildPath -Destination $resolvedOutput -Force

Write-Host "BetterInventory release archive verified: $resolvedOutput" -ForegroundColor Green
Write-Host "SHA-256: $((Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedOutput).Hash)"
