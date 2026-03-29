param(
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$ok = New-Object System.Collections.Generic.List[string]

function Add-Ok([string]$message) { $ok.Add($message) }
function Add-Warn([string]$message) { $warnings.Add($message) }
function Add-Error([string]$message) { $errors.Add($message) }

function Require-File([string]$path, [string]$name) {
    if (Test-Path $path) {
        Add-Ok("$name exists: $path")
    } else {
        Add-Error("$name missing: $path")
    }
}

Write-Host "== FanyiTong Release Audit =="

# 1) Tooling
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCmd) {
    Add-Ok("Flutter found: $($flutterCmd.Source)")
} else {
    Add-Warn("Flutter not found in PATH; cannot run pub get or build on this machine.")
}

# 2) Android required files
Require-File "android\build.gradle" "Android top-level build file"
Require-File "android\settings.gradle" "Android settings.gradle"
Require-File "android\gradle.properties" "Android gradle.properties"
Require-File "android\gradle\wrapper\gradle-wrapper.properties" "Gradle wrapper properties"
Require-File "android\app\build.gradle" "Android app build file"
Require-File "android\app\src\main\AndroidManifest.xml" "AndroidManifest"
Require-File "android\app\src\main\kotlin\com\fanyitong\app\MainActivity.kt" "MainActivity"
Require-File "android\app\src\main\res\values\styles.xml" "styles.xml"
Require-File "android\app\src\main\res\xml\network_security_config.xml" "network_security_config.xml"
if (-not (Test-Path "android\gradlew")) {
    Add-Warn("android/gradlew is missing. Run tools/bootstrap_platforms.ps1 -Platforms android")
}
if (-not (Test-Path "android\gradlew.bat")) {
    Add-Warn("android/gradlew.bat is missing. Run tools/bootstrap_platforms.ps1 -Platforms android")
}
if (-not (Test-Path "android\gradle\wrapper\gradle-wrapper.jar")) {
    Add-Warn("android/gradle/wrapper/gradle-wrapper.jar is missing. Run tools/bootstrap_platforms.ps1 -Platforms android")
}
if (-not (Test-Path "android\local.properties")) {
    Add-Warn("android/local.properties is missing (machine-specific). Use android/local.properties.example as template.")
}

# 3) Android release configuration checks
if (Test-Path "android\app\build.gradle") {
    $gradle = Get-Content -Raw -Encoding UTF8 "android\app\build.gradle"
    if ($gradle -match "targetSdk\s+(\d+)") {
        $target = [int]$Matches[1]
        if ($target -ge 34) {
            Add-Ok("targetSdk is compliant: $target")
        } else {
            Add-Error("targetSdk is too low: $target (expected >= 34)")
        }
    } else {
        Add-Error("targetSdk not found in android/app/build.gradle")
    }
}

if (Test-Path "android\app\src\main\AndroidManifest.xml") {
    $manifest = Get-Content -Raw -Encoding UTF8 "android\app\src\main\AndroidManifest.xml"
    if ($manifest -match 'usesCleartextTraffic="true"') {
        Add-Error("Manifest allows cleartext traffic (usesCleartextTraffic=true).")
    } else {
        Add-Ok("Manifest blocks cleartext traffic.")
    }

    if ($manifest -match 'requestLegacyExternalStorage="true"') {
        Add-Error("Manifest still uses requestLegacyExternalStorage=true.")
    } else {
        Add-Ok("Manifest does not use legacy external storage.")
    }
}

# 4) Dart compile guard
if (Test-Path "lib\services\translation_service.dart") {
    $translationService = Get-Content -Raw -Encoding UTF8 "lib\services\translation_service.dart"
    if ($translationService -match "bool get isOnline") {
        Add-Ok("TranslationResult.isOnline exists.")
    } else {
        Add-Error("TranslationResult.isOnline is missing (translation_screen depends on it).")
    }
}

# 5) Cross-platform status
if (Test-Path "ios") {
    Add-Ok("iOS directory exists.")
} else {
    Add-Warn("iOS directory is missing. Run: tools/bootstrap_platforms.ps1 -Platforms ios")
}

Write-Host ""
Write-Host "---- PASS ----"
foreach ($line in $ok) { Write-Host "  [OK] $line" }

Write-Host ""
Write-Host "---- WARN ----"
if ($warnings.Count -eq 0) {
    Write-Host "  none"
} else {
    foreach ($line in $warnings) { Write-Host "  [WARN] $line" }
}

Write-Host ""
Write-Host "---- FAIL ----"
if ($errors.Count -eq 0) {
    Write-Host "  none"
} else {
    foreach ($line in $errors) { Write-Host "  [ERROR] $line" }
}

Write-Host ""
if ($errors.Count -gt 0 -or ($Strict -and $warnings.Count -gt 0)) {
    Write-Host "Audit result: FAILED" -ForegroundColor Red
    exit 1
}

Write-Host "Audit result: PASSED" -ForegroundColor Green
