$ErrorActionPreference = "Stop"

param(
  [string]$AdbPath = "",
  [string]$ApkPath = "",
  [string]$PackageName = "com.fanyitong.app"
)

function Resolve-AdbPath {
  param([string]$Candidate)
  if ($Candidate -and (Test-Path -LiteralPath $Candidate)) { return $Candidate }

  $common = @(
    "E:\scrcpy\adb.exe",
    "E:\scrcpy-win64\adb.exe",
    "E:\platform-tools\adb.exe",
    "E:\Android\Sdk\platform-tools\adb.exe",
    "C:\Users\Administrator\AppData\Local\Android\Sdk\platform-tools\adb.exe",
    "C:\Android\Sdk\platform-tools\adb.exe"
  )
  foreach ($p in $common) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return ""
}

function Resolve-ApkPath {
  param([string]$Candidate)
  if ($Candidate -and (Test-Path -LiteralPath $Candidate)) { return $Candidate }

  $common = @(
    "E:\app-release.apk",
    "F:\app-release(1).apk"
  )
  foreach ($p in $common) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return ""
}

$adb = Resolve-AdbPath -Candidate $AdbPath
if (-not $adb) {
  Write-Host "未找到 adb.exe。"
  Write-Host "把 Android SDK Platform-Tools 解压到 E:\platform-tools\ 后重试（确保存在 E:\platform-tools\adb.exe）。"
  exit 2
}

$apk = Resolve-ApkPath -Candidate $ApkPath
if (-not $apk) {
  Write-Host "未找到 APK。"
  Write-Host "把安装包放到 E:\app-release.apk 或传入 -ApkPath 'E:\xxx.apk'。"
  exit 2
}

Write-Host "adb: $adb"
Write-Host "apk: $apk"

& $adb version
& $adb start-server | Out-Null

Write-Host "`n设备列表："
& $adb devices -l

$deviceLines = & $adb devices
$deviceOk = $deviceLines | Select-String -Pattern "device$" -SimpleMatch
$deviceUnauthorized = $deviceLines | Select-String -Pattern "unauthorized" -SimpleMatch

if ($deviceUnauthorized) {
  Write-Host "`n检测到 unauthorized：请在手机上点“允许 USB 调试”。"
  exit 3
}

if (-not $deviceOk) {
  Write-Host "`n没有检测到可用设备："
  Write-Host "- 手机打开 开发者选项 -> USB 调试"
  Write-Host "- 用数据线连接后，手机弹窗选择“允许”"
  Write-Host "- 仍然没有：换线/换USB口/把USB模式切到“文件传输(MTP)”"
  exit 3
}

Write-Host "`n手机 ABI："
try { & $adb shell getprop ro.product.cpu.abilist } catch { }

Write-Host "`n开始安装（会输出明确失败码）："
& $adb install -r -g $apk

Write-Host "`n已安装包名检查（如果能看到 com.fanyitong.app 就表示安装成功）："
try { & $adb shell pm list packages $PackageName } catch { }

Write-Host "`n如果看到 INSTALL_FAILED_UPDATE_INCOMPATIBLE：运行"
Write-Host "  $adb uninstall $PackageName"
Write-Host "再重试安装。"
