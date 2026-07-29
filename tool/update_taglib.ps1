# SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT

param(
  [switch]$Check
)

$ErrorActionPreference = "Stop"

$TagLibVersion = "2.3.1"
$TagLibCommit = "54ae7d8ac45755e286a5c574280f48d5bef93aef"
$UtfCppCommit = "819011bb01628fe1aa2f1da9f2c842a48fd5680b"
$TagLibRepository = "https://github.com/taglib/taglib.git"
$UtfCppRepository = "https://github.com/nemtrif/utfcpp.git"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$packageRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$vendorRoot = [System.IO.Path]::GetFullPath((Join-Path $packageRoot "third_party/taglib"))
$expectedVendorRoot = [System.IO.Path]::GetFullPath((Join-Path $packageRoot "third_party/taglib"))
if ($vendorRoot -ne $expectedVendorRoot -or -not $vendorRoot.StartsWith($packageRoot)) {
  throw "Refusing to manage an unexpected vendor path: $vendorRoot"
}

function Invoke-Git([string[]]$Arguments) {
  $output = & git @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Git command failed: git $($Arguments -join ' ')`n$($output -join "`n")"
  }
  return ($output -join "`n").Trim()
}

function Get-GitCommit([string]$WorkingDirectory, [string]$Path = "") {
  if ($Path -eq "") {
    return Invoke-Git @("-C", $WorkingDirectory, "rev-parse", "HEAD")
  }
  # Read the gitlink from the index so an uncommitted conversion cannot make us
  # inspect the old flattened directory by accident.
  return Invoke-Git @("-C", $WorkingDirectory, "rev-parse", ":$Path")
}

function Assert-CleanSubmodule([string]$Path, [string]$Name) {
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "$Name submodule is missing or not initialized: $Path"
  }
  $status = Invoke-Git @("-C", $Path, "status", "--porcelain", "--untracked-files=all")
  if ($status -ne "") {
    throw "$Name submodule has local changes:`n$status"
  }
}

function Assert-TagLibSubmodules {
  if (-not (Test-Path -LiteralPath (Join-Path $packageRoot ".gitmodules"))) {
    throw "Parent .gitmodules is missing."
  }

  $parentTagLibCommit = Get-GitCommit $packageRoot "third_party/taglib"
  if ($parentTagLibCommit -ne $TagLibCommit) {
    throw "Parent gitlink mismatch: expected=$TagLibCommit actual=$parentTagLibCommit"
  }

  Assert-CleanSubmodule $vendorRoot "TagLib"
  $taglibCommit = Get-GitCommit $vendorRoot
  if ($taglibCommit -ne $TagLibCommit) {
    throw "TagLib commit mismatch: expected=$TagLibCommit actual=$taglibCommit"
  }

  $taglibGitModules = Get-Content -Raw (Join-Path $vendorRoot ".gitmodules")
  if ($taglibGitModules -notmatch [regex]::Escape($UtfCppRepository)) {
    throw "TagLib .gitmodules does not point to the expected utfcpp repository."
  }

  $parentUtfCppCommit = Get-GitCommit $vendorRoot "3rdparty/utfcpp"
  if ($parentUtfCppCommit -ne $UtfCppCommit) {
    throw "TagLib nested gitlink mismatch: expected=$UtfCppCommit actual=$parentUtfCppCommit"
  }

  $utfcppRoot = Join-Path $vendorRoot "3rdparty/utfcpp"
  Assert-CleanSubmodule $utfcppRoot "utfcpp"
  $utfcppCommit = Get-GitCommit $utfcppRoot
  if ($utfcppCommit -ne $UtfCppCommit) {
    throw "utfcpp commit mismatch: expected=$UtfCppCommit actual=$utfcppCommit"
  }

  # Compare the fixed commits at the parent, TagLib, and utfcpp levels directly.
  # This avoids Git for Windows' git-submodule shell helper on minimal systems.

  foreach ($required in @(
      (Join-Path $vendorRoot "CMakeLists.txt"),
      (Join-Path $vendorRoot "taglib/CMakeLists.txt"),
      (Join-Path $vendorRoot "taglib/toolkit/tstring.h"),
      (Join-Path $utfcppRoot "source/utf8.h"),
      (Join-Path $vendorRoot "COPYING.LGPL"),
      (Join-Path $vendorRoot "COPYING.MPL"),
      (Join-Path $utfcppRoot "LICENSE")
    )) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
      throw "Required TagLib source file is missing: $required"
    }
  }

  Write-Host "TagLib submodules verified: version=$TagLibVersion taglib=$TagLibCommit utfcpp=$UtfCppCommit"
}

if (-not $Check) {
  # Update initializes only commits recorded by the parent repository; it does
  # not follow a moving upstream branch.
  Invoke-Git @("-C", $packageRoot, "submodule", "update", "--init", "--recursive") | Out-Null
}

Assert-TagLibSubmodules
