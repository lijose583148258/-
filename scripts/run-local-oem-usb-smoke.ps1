param(
  [string]$ApkPath = "fanyi_app/build/app/outputs/flutter-apk/app-release.apk",
  [string]$PackageName = "com.fanyitong.app",
  [int]$LaunchWaitSeconds = 12,
  [string]$ArtifactsDir = "artifacts/local-oem-usb"
)

$ErrorActionPreference = "Stop"

function Resolve-RepoRoot {
  $root = git rev-parse --show-toplevel 2>$null
  if (-not $root) {
    throw "Run this script from inside the repository."
  }
  return $root.Trim()
}

function Require-Command {
  param([string]$Name)
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $command) {
    throw "Required command '$Name' was not found on PATH."
  }
  return $command.Source
}

function Invoke-Adb {
  param(
    [string]$Adb,
    [string[]]$Arguments,
    [switch]$AllowFailure
  )
  $output = & $Adb @Arguments 2>&1
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0 -and -not $AllowFailure) {
    throw "adb $($Arguments -join ' ') failed with exit code $exitCode`n$output"
  }
  return [pscustomobject]@{
    ExitCode = $exitCode
    Output = ($output -join "`n")
  }
}

function Get-DeviceValue {
  param(
    [string]$Adb,
    [string]$Serial,
    [string]$Prop
  )
  $result = Invoke-Adb $Adb @("-s", $Serial, "shell", "getprop", $Prop) -AllowFailure
  return $result.Output.Trim()
}

function Get-OemFamily {
  param([string]$Manufacturer, [string]$Brand, [string]$Model)
  $value = "$Manufacturer $Brand $Model".ToLowerInvariant()
  if ($value -match "xiaomi|redmi|poco") { return "xiaomi" }
  if ($value -match "oppo|oneplus|realme|oplus") { return "oplus" }
  if ($value -match "honor|huawei|荣耀|华为") { return "honor_huawei" }
  return "other"
}

function Sanitize-FileName {
  param([string]$Value)
  return ($Value -replace "[^A-Za-z0-9._-]", "_")
}

$repoRoot = Resolve-RepoRoot
Set-Location $repoRoot

$adb = Require-Command "adb"
$resolvedApk = if ([System.IO.Path]::IsPathRooted($ApkPath)) {
  $ApkPath
} else {
  Join-Path $repoRoot $ApkPath
}
if (-not (Test-Path $resolvedApk)) {
  throw "APK not found: $resolvedApk. Build it first, for example: cd fanyi_app; flutter build apk --release"
}

$resolvedArtifacts = if ([System.IO.Path]::IsPathRooted($ArtifactsDir)) {
  $ArtifactsDir
} else {
  Join-Path $repoRoot $ArtifactsDir
}
New-Item -ItemType Directory -Force -Path $resolvedArtifacts | Out-Null

$devicesRaw = Invoke-Adb $adb @("devices", "-l")
$devices = @()
foreach ($line in ($devicesRaw.Output -split "`n")) {
  $trimmed = $line.Trim()
  if (-not $trimmed -or $trimmed -match "^List of devices") { continue }
  if ($trimmed -match "^(\S+)\s+device\b") {
    $devices += $matches[1]
  }
}
if ($devices.Count -eq 0) {
  throw "No authorized USB Android devices found. Enable Developer options + USB debugging, accept the RSA prompt, then run: adb devices -l"
}

$apkHash = (Get-FileHash -Algorithm SHA256 $resolvedApk).Hash
$runStarted = (Get-Date).ToString("o")
$allResults = @()

foreach ($serial in $devices) {
  Write-Host "=== Testing USB device $serial ==="
  $safeSerial = Sanitize-FileName $serial
  $deviceDir = Join-Path $resolvedArtifacts $safeSerial
  New-Item -ItemType Directory -Force -Path $deviceDir | Out-Null

  $manufacturer = Get-DeviceValue $adb $serial "ro.product.manufacturer"
  $brand = Get-DeviceValue $adb $serial "ro.product.brand"
  $model = Get-DeviceValue $adb $serial "ro.product.model"
  $androidRelease = Get-DeviceValue $adb $serial "ro.build.version.release"
  $sdk = Get-DeviceValue $adb $serial "ro.build.version.sdk"
  $buildIncremental = Get-DeviceValue $adb $serial "ro.build.version.incremental"
  $family = Get-OemFamily $manufacturer $brand $model

  $install = Invoke-Adb $adb @("-s", $serial, "install", "-r", "-d", $resolvedApk) -AllowFailure
  $installOk = $install.ExitCode -eq 0 -and $install.Output -match "Success"
  if (-not $installOk) {
    $result = [pscustomobject]@{
      serial = $serial
      oem_family = $family
      manufacturer = $manufacturer
      brand = $brand
      model = $model
      android_release = $androidRelease
      sdk = $sdk
      build_incremental = $buildIncremental
      apk_sha256 = $apkHash
      install_ok = $false
      launch_ok = $false
      cold_start_crash = $true
      failure = "adb install failed"
      install_output = $install.Output
    }
    $allResults += $result
    $result | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 (Join-Path $deviceDir "result.json")
    continue
  }

  Invoke-Adb $adb @("-s", $serial, "shell", "am", "force-stop", $PackageName) -AllowFailure | Out-Null
  Invoke-Adb $adb @("-s", $serial, "logcat", "-c") -AllowFailure | Out-Null

  $launch = Invoke-Adb $adb @("-s", $serial, "shell", "monkey", "-p", $PackageName, "-c", "android.intent.category.LAUNCHER", "1") -AllowFailure
  Start-Sleep -Seconds $LaunchWaitSeconds

  $pid = (Invoke-Adb $adb @("-s", $serial, "shell", "pidof", $PackageName) -AllowFailure).Output.Trim()
  $windows = (Invoke-Adb $adb @("-s", $serial, "shell", "dumpsys", "window", "windows") -AllowFailure).Output
  $activity = (Invoke-Adb $adb @("-s", $serial, "shell", "dumpsys", "activity", "top") -AllowFailure).Output
  $logcat = (Invoke-Adb $adb @("-s", $serial, "logcat", "-d", "-v", "time") -AllowFailure).Output

  $logcatPath = Join-Path $deviceDir "logcat.txt"
  $windowsPath = Join-Path $deviceDir "dumpsys-window.txt"
  $activityPath = Join-Path $deviceDir "dumpsys-activity-top.txt"
  $launch.Output | Set-Content -Encoding UTF8 (Join-Path $deviceDir "launch.txt")
  $logcat | Set-Content -Encoding UTF8 $logcatPath
  $windows | Set-Content -Encoding UTF8 $windowsPath
  $activity | Set-Content -Encoding UTF8 $activityPath

  $packageEscaped = [regex]::Escape($PackageName)
  $fatalPackageCrash = $logcat -match "FATAL EXCEPTION" -and $logcat -match "Process:\s*$packageEscaped"
  $javaRuntimeCrash = $logcat -match "AndroidRuntime" -and $logcat -match $packageEscaped
  $flutterFatal = $logcat -match "F\/flutter" -and $logcat -match $packageEscaped
  $ttsColdInit = $logcat -match "Creating TextToSpeech after first Flutter method call"
  $ttsInitFailure = $logcat -match "Failed to initialize TextToSpeech"
  $packageInForeground = $windows -match $packageEscaped -or $activity -match $packageEscaped
  $launchOk = $launch.ExitCode -eq 0 -and $pid.Length -gt 0 -and $packageInForeground
  $coldStartCrash = $fatalPackageCrash -or $javaRuntimeCrash -or $flutterFatal -or $ttsColdInit -or $ttsInitFailure -or (-not $launchOk)

  $result = [pscustomobject]@{
    serial = $serial
    oem_family = $family
    manufacturer = $manufacturer
    brand = $brand
    model = $model
    android_release = $androidRelease
    sdk = $sdk
    build_incremental = $buildIncremental
    apk_sha256 = $apkHash
    install_ok = $true
    launch_exit_code = $launch.ExitCode
    launch_ok = $launchOk
    pid = $pid
    package_in_foreground = $packageInForeground
    fatal_package_crash = $fatalPackageCrash
    android_runtime_crash = $javaRuntimeCrash
    flutter_fatal = $flutterFatal
    tts_cold_init_marker = $ttsColdInit
    tts_init_failure = $ttsInitFailure
    cold_start_crash = $coldStartCrash
    artifacts = @{
      logcat = $logcatPath
      dumpsys_window = $windowsPath
      dumpsys_activity_top = $activityPath
    }
  }
  $allResults += $result
  $result | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 (Join-Path $deviceDir "result.json")

  if ($coldStartCrash) {
    Write-Warning "Device $serial failed cold-start smoke. See $deviceDir"
  } else {
    Write-Host "Device $serial passed cold-start smoke."
  }
}

$summary = [pscustomobject]@{
  started_at = $runStarted
  completed_at = (Get-Date).ToString("o")
  apk = $resolvedApk
  apk_sha256 = $apkHash
  package = $PackageName
  device_count = $devices.Count
  passed = @($allResults | Where-Object { -not $_.cold_start_crash }).Count
  failed = @($allResults | Where-Object { $_.cold_start_crash }).Count
  results = $allResults
}

$summaryPath = Join-Path $resolvedArtifacts "summary.json"
$summary | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $summaryPath
Write-Host "Local OEM USB smoke summary: $summaryPath"

if ($summary.failed -gt 0) {
  throw "$($summary.failed) USB device(s) failed cold-start smoke."
}
