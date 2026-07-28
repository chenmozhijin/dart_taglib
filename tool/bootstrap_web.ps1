# SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT

param(
  [string]$BuildDir = "wasm/build",
  [string]$Config = "Release",
  [ValidateSet("emscripten", "wasi")]
  [string]$Target = "emscripten",
  [string]$PackageDir = "",
  [switch]$SkipWasmBuild
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($PackageDir)) {
  $PackageDir = Split-Path -Parent $scriptRoot
}
$PackageDir = (Resolve-Path $PackageDir).Path
$BuildDir = if ([System.IO.Path]::IsPathRooted($BuildDir)) { $BuildDir } else { Join-Path $PackageDir $BuildDir }

if (-not $SkipWasmBuild) {
  Write-Host "1/4 Build wasm bridge artifacts"
  & (Join-Path $scriptRoot "build_wasm.ps1") `
    -BuildDir $BuildDir `
    -Config $Config `
    -Target $Target `
    -PackageDir $PackageDir
} else {
  Write-Host "1/4 Skip wasm build (using existing artifacts)"
}

Write-Host "2/4 Sync committed web runtime artifacts"
$runtimeDir = Join-Path $PackageDir "web_runtime"
New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null

if (-not $SkipWasmBuild) {
  Copy-Item (Join-Path $BuildDir "taglib_bridge.js") (Join-Path $runtimeDir "taglib_bridge.js") -Force
  Copy-Item (Join-Path $BuildDir "taglib_bridge.wasm") (Join-Path $runtimeDir "taglib_bridge.wasm") -Force
  Copy-Item (Join-Path $PackageDir "wasm/taglib_bridge_web.js") (Join-Path $runtimeDir "taglib_bridge_web.js") -Force
} else {
  $required = @(
    (Join-Path $runtimeDir "taglib_bridge.js"),
    (Join-Path $runtimeDir "taglib_bridge.wasm"),
    (Join-Path $runtimeDir "taglib_bridge_web.js")
  )
  foreach ($file in $required) {
    if (-not (Test-Path $file)) {
      throw "Missing prebuilt runtime artifact: $file. Run without -SkipWasmBuild first."
    }
  }
}

$hashes = @{}
foreach ($name in @("taglib_bridge.js", "taglib_bridge.wasm", "taglib_bridge_web.js")) {
  $file = Join-Path $runtimeDir $name
  $hashes[$name] = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLowerInvariant()
}
$manifest = [ordered]@{
  schemaVersion = 1
  generatedKind = "dart_taglib_web_runtime"
  target = $Target
  config = $Config
  command = "tool/bootstrap_web.ps1 -Target $Target -Config $Config"
  artifacts = $hashes
}
$manifestJson = ($manifest | ConvertTo-Json -Depth 5).Replace("`r`n", "`n").Replace("`r", "`n") + "`n"
[System.IO.File]::WriteAllText(
  (Join-Path $runtimeDir "manifest.json"),
  $manifestJson,
  [System.Text.UTF8Encoding]::new($false)
)

Write-Host "3/4 Compile Dart web entrypoint"
Push-Location $PackageDir
try {
  dart compile js --no-source-maps example/web/main.dart -o example/web/main.dart.js
  if ($LASTEXITCODE -ne 0) {
    throw "Dart web compilation failed with exit code $LASTEXITCODE."
  }
  Remove-Item example/web/main.dart.js.deps -Force -ErrorAction SilentlyContinue
  Remove-Item example/web/main.dart.js.map -Force -ErrorAction SilentlyContinue
}
finally {
  Pop-Location
}

Write-Host "4/4 Prepare browser runtime/test assets"
& (Join-Path $scriptRoot "prepare_browser_test_assets.ps1") `
  -BuildDir $BuildDir `
  -PackageDir $PackageDir

Write-Host "Web bootstrap completed."
Write-Host "Open: $PackageDir/example/web/index.html"
