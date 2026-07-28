# SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT

param(
  [string]$BuildDir = "wasm/build",
  [string]$PackageDir = "",
  [string]$ThirdPartyDataDir = "",
  [string]$RuntimeDir = ""
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($PackageDir)) {
  $PackageDir = Split-Path -Parent $scriptRoot
}
$PackageDir = (Resolve-Path $PackageDir).Path
$BuildDir = if ([System.IO.Path]::IsPathRooted($BuildDir)) { $BuildDir } else { Join-Path $PackageDir $BuildDir }
if ([string]::IsNullOrWhiteSpace($ThirdPartyDataDir)) {
  $ThirdPartyDataDir = Join-Path $PackageDir "third_party/taglib/tests/data"
} elseif (-not [System.IO.Path]::IsPathRooted($ThirdPartyDataDir)) {
  $ThirdPartyDataDir = Join-Path $PackageDir $ThirdPartyDataDir
}
if ([string]::IsNullOrWhiteSpace($RuntimeDir)) {
  $RuntimeDir = Join-Path $PackageDir "web_runtime"
} elseif (-not [System.IO.Path]::IsPathRooted($RuntimeDir)) {
  $RuntimeDir = Join-Path $PackageDir $RuntimeDir
}

$testRuntimeDir = Join-Path $PackageDir "test/web_runtime"
New-Item -ItemType Directory -Path $testRuntimeDir -Force | Out-Null
$testPackageRuntimeDir = Join-Path $PackageDir "test/assets/packages/dart_taglib/web_runtime"
New-Item -ItemType Directory -Path $testPackageRuntimeDir -Force | Out-Null

$fixtureDataDir = Join-Path $PackageDir "test/fixtures/taglib_data"
New-Item -ItemType Directory -Path $fixtureDataDir -Force | Out-Null

$moduleJs = Join-Path $BuildDir "taglib_bridge.js"
$moduleWasm = Join-Path $BuildDir "taglib_bridge.wasm"
$bridgeJs = Join-Path $PackageDir "wasm/taglib_bridge_web.js"
$runtimeModuleJs = Join-Path $RuntimeDir "taglib_bridge.js"
$runtimeModuleWasm = Join-Path $RuntimeDir "taglib_bridge.wasm"
$runtimeBridgeJs = Join-Path $RuntimeDir "taglib_bridge_web.js"
$fixtureManifest = Join-Path $PackageDir "test/fixture_matrix.dart"

if (-not (Test-Path $moduleJs)) {
  if (Test-Path $runtimeModuleJs) { $moduleJs = $runtimeModuleJs } else { throw "Missing wasm module JS: $moduleJs and fallback: $runtimeModuleJs" }
}
if (-not (Test-Path $moduleWasm)) {
  if (Test-Path $runtimeModuleWasm) { $moduleWasm = $runtimeModuleWasm } else { throw "Missing wasm module WASM: $moduleWasm and fallback: $runtimeModuleWasm" }
}
if (-not (Test-Path $bridgeJs)) {
  if (Test-Path $runtimeBridgeJs) { $bridgeJs = $runtimeBridgeJs } else { throw "Missing bridge JS: $bridgeJs and fallback: $runtimeBridgeJs" }
}
if (-not (Test-Path $fixtureManifest)) {
  throw "Missing fixture manifest: $fixtureManifest"
}
if (-not (Test-Path $ThirdPartyDataDir)) {
  throw "Missing third-party data directory: $ThirdPartyDataDir"
}

foreach ($targetRuntimeDir in @($testRuntimeDir, $testPackageRuntimeDir)) {
  Copy-Item $moduleJs (Join-Path $targetRuntimeDir "taglib_bridge.js") -Force
  Copy-Item $moduleWasm (Join-Path $targetRuntimeDir "taglib_bridge.wasm") -Force
  Copy-Item $bridgeJs (Join-Path $targetRuntimeDir "taglib_bridge_web.js") -Force
}

$manifestText = Get-Content -Raw $fixtureManifest
$pathRegex = [regex]"relativePath:\s*'([^']+)'"
$matches = $pathRegex.Matches($manifestText)
$relativePaths = New-Object System.Collections.Generic.HashSet[string]
foreach ($match in $matches) {
  $null = $relativePaths.Add($match.Groups[1].Value)
}

foreach ($relativePath in $relativePaths | Sort-Object) {
  $sourcePath = Join-Path $ThirdPartyDataDir $relativePath
  if (-not (Test-Path $sourcePath)) {
    throw "Missing fixture file referenced by manifest: $sourcePath"
  }

  $targetPath = Join-Path $fixtureDataDir $relativePath
  $targetDir = Split-Path -Parent $targetPath
  New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
  Copy-Item $sourcePath $targetPath -Force
}

Write-Host "Prepared browser runtime assets in $testRuntimeDir"
Write-Host "Prepared package runtime assets in $testPackageRuntimeDir"
Write-Host "Prepared browser fixture assets in $fixtureDataDir (count=$($relativePaths.Count))"
