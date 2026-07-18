param(
  [string] $FirebaseProject = "",
  [string] $Target = "integration_test/app_launch_test.dart",
  [string] $DeviceFilters = "xiaomi,oppo,oneplus,realme,honor,huawei",
  [string[]] $Device = @(),
  [string] $Locale = "zh_CN",
  [string] $Orientation = "portrait",
  [int] $MaxSdk = 36,
  [string] $Timeout = "10m",
  [string] $ResultsBucket = "",
  [string] $ResultsDir = ""
)

$ErrorActionPreference = "Stop"

function Require-Command([string] $Name) {
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $command) {
    throw "Required command '$Name' was not found. Install Google Cloud CLI and Flutter first."
  }
  return $command.Source
}

function Invoke-Checked([string] $File, [string[]] $Arguments, [string] $WorkingDirectory = "") {
  $display = "$File $($Arguments -join ' ')"
  Write-Host ">>> $display"
  if ($WorkingDirectory) {
    Push-Location $WorkingDirectory
    try {
      & $File @Arguments
    } finally {
      Pop-Location
    }
  } else {
    & $File @Arguments
  }
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code ${LASTEXITCODE}: $display"
  }
}

function ConvertTo-ModelSearchText($Model) {
  $parts = foreach ($property in $Model.PSObject.Properties) {
    if ($null -eq $property.Value) { continue }
    if ($property.Value -is [array]) {
      $property.Value -join " "
    } else {
      $property.Value.ToString()
    }
  }
  return ($parts -join " ").ToLowerInvariant()
}

function Select-Version($Model, [int] $MaxSdk) {
  $versions = @($Model.supportedVersionIds) |
    ForEach-Object { $_.ToString() } |
    Where-Object { $_ -match '^\d+$' } |
    Sort-Object { [int] $_ } -Descending
  return $versions | Where-Object { [int] $_ -le $MaxSdk } | Select-Object -First 1
}

function Resolve-DeviceMatrix([string] $Project, [string] $Filters, [string[]] $ExplicitDevices) {
  if ($ExplicitDevices.Count -gt 0) {
    return $ExplicitDevices
  }

  $modelArgs = @("firebase", "test", "android", "models", "list", "--format=json")
  if ($Project) {
    $modelArgs += @("--project", $Project)
  }

  Write-Host ">>> gcloud $($modelArgs -join ' ')"
  $jsonText = & gcloud @modelArgs | Out-String
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to list Firebase Test Lab Android models."
  }
  $models = $jsonText | ConvertFrom-Json

  $selected = New-Object System.Collections.Generic.List[string]
  $seenModels = New-Object System.Collections.Generic.HashSet[string]
  $filterList = $Filters.Split(",") |
    ForEach-Object { $_.Trim().ToLowerInvariant() } |
    Where-Object { $_ }

  foreach ($filter in $filterList) {
    $match = $models |
      Where-Object {
        $text = ConvertTo-ModelSearchText $_
        $form = if ($_.form) { $_.form.ToString() } else { "" }
        $isPhysical = ($form -eq "") -or ($form -match "PHYSICAL")
        $isPhysical -and $text.Contains($filter)
      } |
      Sort-Object @{ Expression = { Select-Version $_ $MaxSdk }; Descending = $true }, name |
      Select-Object -First 1

    if (-not $match) {
      Write-Warning "No physical Firebase Test Lab device matched filter '$filter'."
      continue
    }

    $version = Select-Version $match $MaxSdk
    if (-not $version) {
      Write-Warning "Matched '$($match.id)' for '$filter', but no supported SDK <= $MaxSdk was listed."
      continue
    }

    if ($seenModels.Add($match.id)) {
      $selected.Add("model=$($match.id),version=$version,locale=$Locale,orientation=$Orientation")
    }
  }

  if ($selected.Count -eq 0) {
    throw "No Firebase Test Lab devices were selected. Pass -Device explicitly or adjust -DeviceFilters."
  }

  return $selected.ToArray()
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$appRoot = Join-Path $repoRoot "fanyi_app"
$androidRoot = Join-Path $appRoot "android"
$artifactsRoot = Join-Path $repoRoot "artifacts/firebase-test-lab"
New-Item -ItemType Directory -Force -Path $artifactsRoot | Out-Null

Require-Command "gcloud" | Out-Null
Require-Command "flutter" | Out-Null

if (-not $FirebaseProject) {
  $FirebaseProject = (& gcloud config get-value project 2>$null | Select-Object -First 1).Trim()
}
if (-not $FirebaseProject) {
  throw "Firebase project is required. Pass -FirebaseProject or run 'gcloud config set project PROJECT_ID'."
}

$activeAccount = (& gcloud auth list --filter=status:ACTIVE --format=value(account) 2>$null | Select-Object -First 1).Trim()
if (-not $activeAccount) {
  throw "No active gcloud account. Run 'gcloud auth login' or activate a service account first."
}

if (-not $ResultsDir) {
  $ResultsDir = "fanyitong-oem-$((Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss'))"
}

Write-Host "Firebase project: $FirebaseProject"
Write-Host "Active gcloud account: $activeAccount"
Write-Host "Integration target: $Target"

Invoke-Checked "flutter" @("pub", "get") $appRoot
Invoke-Checked "flutter" @("build", "apk", "--debug", "--target", $Target) $appRoot

$isWindowsHost = [System.Environment]::OSVersion.Platform -eq "Win32NT"
$gradle = if ($isWindowsHost) { Join-Path $androidRoot "gradlew.bat" } else { Join-Path $androidRoot "gradlew" }
if (-not $isWindowsHost) {
  Invoke-Checked "chmod" @("+x", $gradle)
}
Invoke-Checked $gradle @("app:assembleAndroidTest", "-Ptarget=../$Target") $androidRoot

$appApk = Join-Path $appRoot "build/app/outputs/apk/debug/app-debug.apk"
$testApk = Join-Path $appRoot "build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk"
if (-not (Test-Path -LiteralPath $appApk)) { throw "App APK not found: $appApk" }
if (-not (Test-Path -LiteralPath $testApk)) { throw "Test APK not found: $testApk" }

$devices = Resolve-DeviceMatrix $FirebaseProject $DeviceFilters $Device
Write-Host "Selected Firebase Test Lab devices:"
$devices | ForEach-Object { Write-Host "  $_" }

$runArgs = @(
  "firebase", "test", "android", "run",
  "--project", $FirebaseProject,
  "--type", "instrumentation",
  "--app", $appApk,
  "--test", $testApk,
  "--timeout", $Timeout,
  "--results-dir", $ResultsDir
)
if ($ResultsBucket) {
  $runArgs += @("--results-bucket", $ResultsBucket)
}
foreach ($deviceSpec in $devices) {
  $runArgs += @("--device", $deviceSpec)
}

$summaryPath = Join-Path $artifactsRoot "firebase-test-lab-request.txt"
@(
  "firebase_project=$FirebaseProject",
  "active_account=$activeAccount",
  "target=$Target",
  "results_dir=$ResultsDir",
  "app_apk=$appApk",
  "test_apk=$testApk",
  "devices=$($devices -join ';')"
) | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Invoke-Checked "gcloud" $runArgs
