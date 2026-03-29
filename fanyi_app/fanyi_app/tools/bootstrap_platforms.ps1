param(
    [string]$Org = "com.fanyitong",
    [string]$ProjectName = "fanyi_tong",
    [string[]]$Platforms = @("android", "ios")
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    Write-Error "Flutter SDK not found. Install Flutter and add flutter to PATH."
}

$platformArg = $Platforms -join ","
Write-Host "Generating platform scaffolding: $platformArg"
flutter create --org $Org --project-name $ProjectName --platforms=$platformArg .

Write-Host "Platform scaffolding generation completed."
