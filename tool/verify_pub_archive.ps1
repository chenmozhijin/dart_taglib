# SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

# Pub recursively reads submodule .gitignore files and warns about tracked
# maintenance files they hide. The root .pubignore excludes them from the
# archive, so only this fixed list is allowed; any new warning or publish error
# still fails the gate.
$expectedIgnoredFiles = @(
  "third_party/taglib/.astylerc"
  "third_party/taglib/.editorconfig"
  "third_party/taglib/.github/dependabot.yml"
  "third_party/taglib/.github/workflows/build.yml"
  "third_party/taglib/.gitignore"
  "third_party/taglib/.gitmodules"
  "third_party/taglib/3rdparty/utfcpp/.github/workflows/ci-linux-clang.yml"
  "third_party/taglib/3rdparty/utfcpp/.github/workflows/ci-linux-gcc.yml"
  "third_party/taglib/3rdparty/utfcpp/.github/workflows/ci-windows-msvc.yml"
  "third_party/taglib/3rdparty/utfcpp/.gitignore"
)

$output = @(& dart pub publish --dry-run 2>&1 | ForEach-Object { $_.ToString() })
$exitCode = $LASTEXITCODE
$output | ForEach-Object { Write-Host $_ }

if ($exitCode -eq 0) {
  Write-Host "Pub archive verified without warnings."
  exit 0
}
if ($exitCode -ne 65) {
  throw "Pub dry-run failed with unexpected exit code $exitCode."
}

$warningSummary = @($output | Where-Object { $_ -match '^Package has \d+ warnings?\.$' })
if ($warningSummary.Count -ne 1 -or $warningSummary[0] -ne "Package has 1 warning.") {
  throw "Pub dry-run warning count changed."
}

$marker = "Files that are checked in while gitignored:"
$markerIndex = -1
for ($index = 0; $index -lt $output.Count; $index++) {
  if ($output[$index].Trim() -eq $marker) {
    $markerIndex = $index
    break
  }
}
if ($markerIndex -lt 0) {
  throw "Pub dry-run did not report the expected submodule .gitignore warning."
}

$actualIgnoredFiles = @()
for ($index = $markerIndex + 1; $index -lt $output.Count; $index++) {
  $line = $output[$index].Trim().Replace("\", "/")
  if ($line.StartsWith("third_party/taglib/")) {
    $actualIgnoredFiles += $line
    continue
  }
  if ($actualIgnoredFiles.Count -gt 0 -and $line -eq "") {
    break
  }
}

$difference = @(Compare-Object `
    -ReferenceObject ($expectedIgnoredFiles | Sort-Object) `
    -DifferenceObject ($actualIgnoredFiles | Sort-Object))
if ($difference.Count -ne 0) {
  throw "Pub dry-run submodule warning file list changed:`n$($difference | Out-String)"
}

Write-Host "Pub archive verified with the fixed recursive-submodule metadata warning only."
exit 0
