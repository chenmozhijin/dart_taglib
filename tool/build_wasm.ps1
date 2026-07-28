# SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT

param(
  [string]$BuildDir = "wasm/build",
  [string]$Config = "Release",
  [ValidateSet("emscripten", "wasi")]
  [string]$Target = "emscripten",
  [string]$PackageDir = ""
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($PackageDir)) {
  $PackageDir = Split-Path -Parent $scriptRoot
}
$PackageDir = (Resolve-Path $PackageDir).Path
$BuildDir = if ([System.IO.Path]::IsPathRooted($BuildDir)) { $BuildDir } else { Join-Path $PackageDir $BuildDir }

$emcmake = Get-Command emcmake -ErrorAction SilentlyContinue
if($null -eq $emcmake) {
  throw "emcmake not found. Please activate emsdk before building wasm."
}

Write-Host "Configure wasm bridge -> $BuildDir (target=$Target)"
$extraArgs = @()
if($Target -eq "wasi") {
  $extraArgs += "-DCMAKE_C_FLAGS=-mexec-model=reactor"
  $extraArgs += "-DCMAKE_CXX_FLAGS=-mexec-model=reactor"
}
emcmake cmake -S (Join-Path $PackageDir "wasm") -B $BuildDir "-DCMAKE_BUILD_TYPE=$Config" @extraArgs
if ($LASTEXITCODE -ne 0) {
  throw "WASM CMake configure failed with exit code $LASTEXITCODE."
}

Write-Host "Build wasm bridge"
cmake --build $BuildDir --clean-first --config $Config
if ($LASTEXITCODE -ne 0) {
  throw "WASM CMake build failed with exit code $LASTEXITCODE."
}

# Emscripten 每次都会重写胶水代码，因此文件头必须由构建流程补入。
$generatedJs = Join-Path $BuildDir "taglib_bridge.js"
if (-not (Test-Path $generatedJs)) {
  throw "Generated JavaScript runtime not found: $generatedJs"
}
$spdxHeader = @(
  "// SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>"
  "// SPDX-License-Identifier: MIT"
  ""
) -join "`n"
$spdxHeader += "`n"
$generatedJsContent = [System.IO.File]::ReadAllText($generatedJs)
if (-not $generatedJsContent.StartsWith($spdxHeader, [System.StringComparison]::Ordinal)) {
  $generatedJsContent = $spdxHeader + $generatedJsContent
}

# Emscripten 的胶水代码可能包含行尾空格。发布资产在每次重建后统一规范化，
# 避免生成器版本或平台换行差异反复污染 Git，同时不改变 JavaScript 语义。
$generatedJsContent = [regex]::Replace(
  $generatedJsContent,
  "[ `t]+(?=`r?$)",
  "",
  [System.Text.RegularExpressions.RegexOptions]::Multiline
)
$generatedJsContent = $generatedJsContent.Replace("`r`n", "`n").Replace("`r", "`n")
$generatedJsContent = $generatedJsContent.TrimEnd("`r", "`n") + "`n"
[System.IO.File]::WriteAllText(
  $generatedJs,
  $generatedJsContent,
  [System.Text.UTF8Encoding]::new($false)
)
