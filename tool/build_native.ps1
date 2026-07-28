# SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT

param(
  [string]$BuildDir = "native/taglib_bridge/build",
  [string]$Config = "Release",
  [string]$PackageDir = ""
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($PackageDir)) {
  $PackageDir = Split-Path -Parent $scriptRoot
}
$PackageDir = (Resolve-Path $PackageDir).Path
$BuildDir = if ([System.IO.Path]::IsPathRooted($BuildDir)) { $BuildDir } else { Join-Path $PackageDir $BuildDir }

Write-Host "Configure native bridge -> $BuildDir"
cmake -S (Join-Path $PackageDir "native/taglib_bridge") -B $BuildDir "-DCMAKE_BUILD_TYPE=$Config"
if ($LASTEXITCODE -ne 0) {
  throw "Native CMake configure failed with exit code $LASTEXITCODE."
}

Write-Host "Build native bridge"
cmake --build $BuildDir --clean-first --config $Config
if ($LASTEXITCODE -ne 0) {
  throw "Native CMake build failed with exit code $LASTEXITCODE."
}
