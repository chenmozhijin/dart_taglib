# SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT

param(
  [string]$PackageDir = "."
)

$ErrorActionPreference = "Stop"

Push-Location $PackageDir
try {
  dart run ffigen --config ffigen.yaml
  if ($LASTEXITCODE -ne 0) {
    throw "ffigen failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
