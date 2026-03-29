# 翻译通 APP 上线就绪清单（扫描+补全结果）

## 已补全（本次已完成）
- Android 构建配置重建：修复损坏的 `android/app/build.gradle`（原文件为单行转义文本，无法构建）。
- Android 平台关键文件补齐：新增 `settings.gradle`、`gradle.properties`、`MainActivity.kt`、`styles.xml`、`network_security_config.xml`、debug/profile manifest。
- Android 安全与兼容修正：
  - 移除 `requestLegacyExternalStorage=true`
  - 禁用明文流量 `usesCleartextTraffic=false`
  - 保留麦克风权限，且将麦克风硬件声明为可选，避免无麦设备安装失败。
- Dart 编译阻断修复：为 `TranslationResult` 增加 `isOnline`，修复 `translation_screen.dart` 的成员缺失问题。
- 发布自动体检脚本：
  - `tools/release_audit.ps1`
  - `tools/bootstrap_platforms.ps1`

## 仍需你在本机执行（因为当前环境缺少 Flutter SDK）
- 安装 Flutter SDK（并加入 PATH）。
- 补齐平台工程（尤其 iOS）：
  - `powershell -ExecutionPolicy Bypass -File tools/bootstrap_platforms.ps1`
- 生成本机 Android 路径配置（首次必做）：
  - 参考 `android/local.properties.example` 复制为 `android/local.properties`
- 拉依赖并本地检查：
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test`
- 产物构建：
  - Android APK: `flutter build apk --release`
  - Android AAB: `flutter build appbundle --release`
  - iOS（需 macOS + Xcode）: `flutter build ipa --release`

## 正式上线前必须完成（人工+设备验证）
- 签名与渠道：
  - 配置 Android release keystore，使用正式签名。
  - 如上架 Google Play，上传 AAB；如国内分发，准备多渠道 APK。
- 隐私与合规：
  - 完成隐私政策、用户协议、权限用途说明（麦克风、网络）。
  - 在应用内可见入口展示隐私政策。
- 真机覆盖测试（建议最少）：
  - Android 8/10/12/14 各 1 台（含华为/小米/OPPO/三星）
  - 无 Google Play 服务设备 1 台（验证 ML Kit 自动降级）
  - iPhone 近两代系统各 1 台（若发布 iOS）
- 发布验收项：
  - 首次安装启动无崩溃
  - 离线词典可用
  - 在线兜底可用（断网/弱网可回退）
  - 麦克风权限拒绝后可走手动输入，不崩溃
  - 前后台切换、锁屏恢复稳定

## 一键体检
- 普通体检：
  - `powershell -ExecutionPolicy Bypass -File tools/release_audit.ps1`
- 严格模式（警告也视为失败）：
  - `powershell -ExecutionPolicy Bypass -File tools/release_audit.ps1 -Strict`

## 无需本机大下载的云端测试方案（推荐）
- 已提供 GitHub Actions 工作流：
  - `.github/workflows/android-release.yml`（云端构建 APK/AAB）
  - `.github/workflows/android-emulator-smoke.yml`（云端安卓模拟器启动+冒烟测试）
- 使用方式：
  - 将项目推到 GitHub
  - 打开仓库 `Actions` 页面
  - 手动触发 `Android Emulator Smoke Test` 和 `Android Release Build`
  - 在 Artifacts 下载 APK/AAB，查看测试日志
