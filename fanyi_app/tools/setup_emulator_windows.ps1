param(
  [string]$SdkRoot = "E:\android\Sdk",
  [string]$AvdName = "FanyiTongTest",
  [string]$SystemImage = "system-images;android-34;google_apis;x86_64",
  [string]$ApkPath = "F:\app-release(1).apk",
  [string]$ExistingJdk = "E:\android\jdk17\jdk-17.0.18+8",
  [string]$EmulatorHome = "E:\android\emu-home",
  [int]$LicenseTimeoutSec = 300,
  [int]$SdkInstallTimeoutSec = 1800,
  [int]$BootTimeoutSec = 240,
  [int]$AdbCommandTimeoutSec = 20
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$msg) {
  Write-Host "`n==> $msg"
}

function Stop-StaleAndroidProcesses {
  param([string]$PreferredSdkRoot)

  $names = @("adb", "emulator", "qemu-system-x86_64")
  $stopped = @()

  foreach ($name in $names) {
    $processes = Get-Process -Name $name -ErrorAction SilentlyContinue
    foreach ($process in $processes) {
      $path = $null
      try { $path = $process.Path } catch {}

      $shouldStop = $true
      if ($name -eq "adb" -and $path) {
        $normalized = $path.ToLowerInvariant()
        $preferred = (Join-Path $PreferredSdkRoot "platform-tools\adb.exe").ToLowerInvariant()
        if ($normalized -eq $preferred) {
          $shouldStop = $true
        }
      }

      if ($shouldStop) {
        try {
          Stop-Process -Id $process.Id -Force -ErrorAction Stop
          $stopped += "{0}({1})" -f $name, $process.Id
        } catch {}
      }
    }
  }

  if ($stopped.Count -gt 0) {
    Write-Step ("Stopped stale Android processes: " + ($stopped -join ", "))
    Start-Sleep -Seconds 2
  } else {
    Write-Step "No stale Android processes found"
  }
}

function Invoke-ProcessWithTimeout {
  param(
    [string]$FilePath,
    [string[]]$Arguments,
    [int]$TimeoutSec,
    [string]$StdInPath = "",
    [string]$StdOutPath = "",
    [string]$StdErrPath = ""
  )

  function Quote-Arg([string]$value) {
    if ($null -eq $value) { return '""' }
    if ($value -match '[\s"]') {
      return '"' + ($value -replace '"', '\"') + '"'
    }
    return $value
  }

  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = $FilePath
  $startInfo.Arguments = (($Arguments | ForEach-Object { Quote-Arg $_ }) -join ' ')
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  if ($StdInPath) {
    $startInfo.RedirectStandardInput = $true
  }

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $startInfo
  [void]$process.Start()

  if ($StdInPath) {
    $inputContent = Get-Content -LiteralPath $StdInPath -Raw
    $process.StandardInput.Write($inputContent)
    $process.StandardInput.Close()
  }

  if (-not $process.WaitForExit($TimeoutSec * 1000)) {
    try { $process.Kill($true) } catch {}
    return [pscustomobject]@{
      TimedOut = $true
      ExitCode = $null
      StdOut = ""
      StdErr = ""
    }
  }

  $stdOut = $process.StandardOutput.ReadToEnd()
  $stdErr = $process.StandardError.ReadToEnd()
  if ($StdOutPath) { Set-Content -LiteralPath $StdOutPath -Value $stdOut -Encoding UTF8 }
  if ($StdErrPath) { Set-Content -LiteralPath $StdErrPath -Value $stdErr -Encoding UTF8 }

  return [pscustomobject]@{
    TimedOut = $false
    ExitCode = $process.ExitCode
    StdOut = $stdOut
    StdErr = $stdErr
  }
}

function Ensure-Dir([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) {
    New-Item -ItemType Directory -Path $path | Out-Null
  }
}

function Download-File([string]$url, [string]$dest) {
  Write-Step "Download: $url"
  Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
}

function Expand-Zip([string]$zipPath, [string]$destDir) {
  Write-Step "Extract: $zipPath -> $destDir"
  Ensure-Dir $destDir
  Expand-Archive -LiteralPath $zipPath -DestinationPath $destDir -Force
}

Write-Step "Prepare SDK root: $SdkRoot"
Ensure-Dir $SdkRoot
Ensure-Dir $EmulatorHome
Stop-StaleAndroidProcesses -PreferredSdkRoot $SdkRoot

# sdkmanager requires Java. Prefer existing JDK if provided.
function Ensure-Java([string]$existing) {
  if ($existing -and (Test-Path -LiteralPath (Join-Path $existing "bin\\java.exe"))) {
$env:JAVA_HOME = $existing
    $env:Path = (Join-Path $existing "bin") + ";" + $env:Path
    Write-Step "Using existing JDK: $existing"
    return
  }
  $javaCmd = Get-Command java -ErrorAction SilentlyContinue
  if ($javaCmd) {
    Write-Step "Using system java: $($javaCmd.Source)"
    return
  }
  throw "Java not found. Please install JDK 17+ or set -ExistingJdk to a valid path."
}

Ensure-Java -existing $ExistingJdk
$env:ANDROID_EMULATOR_HOME = $EmulatorHome
$env:ANDROID_SDK_HOME = $EmulatorHome
$env:ANDROID_AVD_HOME = Join-Path $EmulatorHome "avd"
Ensure-Dir $env:ANDROID_AVD_HOME

# Use existing cmdline-tools if present; otherwise stop and ask user to install manually.
$cmdlineRoot = Join-Path $SdkRoot "cmdline-tools"
$latestDir = Join-Path $cmdlineRoot "latest"
if (-not (Test-Path -LiteralPath (Join-Path $latestDir "bin\\sdkmanager.bat"))) {
  throw "cmdline-tools not found at $latestDir. Please install Android commandline-tools via Android Studio SDK Manager, then rerun this script."
}

$env:ANDROID_SDK_ROOT = $SdkRoot
$env:ANDROID_HOME = $SdkRoot

$sdkManager = Join-Path $latestDir "bin\\sdkmanager.bat"
$avdManager = Join-Path $latestDir "bin\\avdmanager.bat"

if (-not (Test-Path -LiteralPath $sdkManager)) {
  throw "sdkmanager missing: $sdkManager"
}

Write-Step "Accept SDK licenses (auto-yes)"
$licensesInput = Join-Path $env:TEMP "android_sdk_licenses_yes.txt"
Set-Content -LiteralPath $licensesInput -Encoding ASCII -Value (("y`n" * 200))
$licensesOut = Join-Path $env:TEMP "android_sdk_licenses_out.txt"
$licensesErr = Join-Path $env:TEMP "android_sdk_licenses_err.txt"
if (Test-Path -LiteralPath $licensesOut) { Remove-Item -Force -LiteralPath $licensesOut }
if (Test-Path -LiteralPath $licensesErr) { Remove-Item -Force -LiteralPath $licensesErr }
$licenseResult = Invoke-ProcessWithTimeout `
  -FilePath $sdkManager `
  -Arguments @("--licenses") `
  -TimeoutSec $LicenseTimeoutSec `
  -StdInPath $licensesInput `
  -StdOutPath $licensesOut `
  -StdErrPath $licensesErr
if ($licenseResult.TimedOut) {
  throw "License acceptance timed out after $LicenseTimeoutSec seconds."
}
if ($licenseResult.ExitCode -ne 0) {
  throw "License acceptance failed. See $licensesErr"
}
if ($licenseResult.StdErr.Trim()) {
  Write-Host $licenseResult.StdErr
}

Write-Step "Install platform-tools/emulator/system image (will skip if already installed)"
$sdkInstallOut = Join-Path $env:TEMP "android_sdk_install_out.txt"
$sdkInstallErr = Join-Path $env:TEMP "android_sdk_install_err.txt"
$sdkInstallResult = Invoke-ProcessWithTimeout `
  -FilePath $sdkManager `
  -Arguments @("--install", "platform-tools", "emulator", "platforms;android-34", "build-tools;34.0.0", "$SystemImage") `
  -TimeoutSec $SdkInstallTimeoutSec `
  -StdOutPath $sdkInstallOut `
  -StdErrPath $sdkInstallErr
if ($sdkInstallResult.TimedOut) {
  throw "SDK install timed out after $SdkInstallTimeoutSec seconds. Check $sdkInstallOut and $sdkInstallErr"
}
if ($sdkInstallResult.ExitCode -ne 0) {
  throw "SDK install failed. Check $sdkInstallOut and $sdkInstallErr"
}

$adb = Join-Path $SdkRoot "platform-tools\\adb.exe"
$emulator = Join-Path $SdkRoot "emulator\\emulator.exe"
$emulatorCheck = Join-Path $SdkRoot "emulator\\emulator-check.exe"
$emulatorAccelArg = "-accel"
$emulatorAccelMode = "on"

if (-not (Test-Path -LiteralPath $adb)) { throw "adb missing: $adb" }
if (-not (Test-Path -LiteralPath $emulator)) { throw "emulator missing: $emulator" }

if (Test-Path -LiteralPath $emulatorCheck) {
  Write-Step "Check emulator acceleration"
  $accelResult = Invoke-ProcessWithTimeout -FilePath $emulatorCheck -Arguments @("accel") -TimeoutSec 20
  $accelText = (($accelResult.StdOut + "`n" + $accelResult.StdErr).Trim())
  if ($accelText) { Write-Host $accelText }
  if ($accelText -match "requires hardware acceleration|not installed|WHPX.*not installed|Hyper-V.*not installed") {
    Write-Step "Acceleration unavailable; falling back to software emulation"
    $emulatorAccelMode = "off"
  }
}

Write-Step "Start adb server"
$adbStart = Invoke-ProcessWithTimeout -FilePath $adb -Arguments @("start-server") -TimeoutSec $AdbCommandTimeoutSec
if ($adbStart.TimedOut) {
  throw "adb start-server timed out after $AdbCommandTimeoutSec seconds."
}
if ($adbStart.ExitCode -ne 0) {
  if ($adbStart.StdOut) { Write-Host $adbStart.StdOut }
  if ($adbStart.StdErr) { Write-Host $adbStart.StdErr }
  throw "adb start-server failed."
}

Write-Step "Create AVD: $AvdName"
$avdList = & $avdManager list avd
if ($avdList -notmatch [regex]::Escape($AvdName)) {
  # Create without interactive device picker. Pixel 5 is a safe default.
  "no" | & $avdManager create avd -n $AvdName -k "$SystemImage" -d pixel_5
}

Write-Step "Start emulator: $AvdName"
$emulatorOut = Join-Path $SdkRoot "emulator-out.log"
$emulatorErr = Join-Path $SdkRoot "emulator-err.log"
if (Test-Path -LiteralPath $emulatorOut) { Remove-Item -Force -LiteralPath $emulatorOut }
if (Test-Path -LiteralPath $emulatorErr) { Remove-Item -Force -LiteralPath $emulatorErr }
Start-Process -FilePath $emulator -ArgumentList @(
  "-avd", $AvdName,
  "-no-snapshot",
  "-no-snapshot-load",
  "-no-snapshot-save",
  "-no-audio",
  "-gpu", "swiftshader_indirect",
  $emulatorAccelArg, $emulatorAccelMode,
  "-verbose"
) -RedirectStandardOutput $emulatorOut -RedirectStandardError $emulatorErr | Out-Null

Write-Step "Wait for boot"
$booted = $false
Write-Host "Emulator home: $EmulatorHome"
for ($i=0; $i -lt [Math]::Ceiling($BootTimeoutSec / 2); $i++) {
  $deviceResult = Invoke-ProcessWithTimeout -FilePath $adb -Arguments @("devices") -TimeoutSec $AdbCommandTimeoutSec
  if (-not $deviceResult.TimedOut -and $deviceResult.StdOut -match "emulator-\d+\s+device") {
    $bootResult = Invoke-ProcessWithTimeout -FilePath $adb -Arguments @("shell", "getprop", "sys.boot_completed") -TimeoutSec $AdbCommandTimeoutSec
    if (-not $bootResult.TimedOut -and $bootResult.StdOut -match "1") {
      $booted = $true
      break
    }
  }
  Start-Sleep -Seconds 2
}
if (-not $booted) {
  Write-Host "Emulator boot timed out after $BootTimeoutSec seconds."
  if (Test-Path -LiteralPath $emulatorOut) {
    Write-Host "Last emulator stdout lines:"
    Get-Content -LiteralPath $emulatorOut -Tail 30
  }
  if (Test-Path -LiteralPath $emulatorErr) {
    Write-Host "Last emulator stderr lines:"
    Get-Content -LiteralPath $emulatorErr -Tail 30
  }
  throw "Emulator did not boot in time."
}

Write-Step "Install APK: $ApkPath"
if (-not (Test-Path -LiteralPath $ApkPath)) {
  throw "APK missing: $ApkPath"
}
$apkInstallResult = Invoke-ProcessWithTimeout -FilePath $adb -Arguments @("install", "-r", "-g", "$ApkPath") -TimeoutSec 180
if ($apkInstallResult.TimedOut) {
  throw "APK install timed out after 180 seconds."
}
if ($apkInstallResult.ExitCode -ne 0) {
  if ($apkInstallResult.StdOut) { Write-Host $apkInstallResult.StdOut }
  if ($apkInstallResult.StdErr) { Write-Host $apkInstallResult.StdErr }
  throw "APK install failed."
}
if ($apkInstallResult.StdOut) { Write-Host $apkInstallResult.StdOut }

Write-Step "Done. Open the app in the emulator to test."
