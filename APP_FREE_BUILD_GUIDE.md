# APP 无会员完整版本构建说明

## 已完成修改
- 新增 `lib/services/free_entitlement_service.dart`。
- 应用启动时初始化免费权益层。
- 设置页新增“无会员完整版本”卡片。
- 所有核心功能统一声明为已开放：翻译、对话、学习、拍照、本地词典、俚语、TTS、历史、输入法辅助、小组件、离线模型管理。

## 本机验证状态
当前电脑未检测到 `flutter` / `dart` 命令，因此本地未执行 Flutter 编译。

## 在有 Flutter 环境的电脑上构建
```powershell
cd "C:\Users\Administrator\Documents\Codex\2026-07-12\new-chat\owner_app_repo\fanyi_app"
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## 生成位置
release APK 通常在：
```text
build\app\outputs\flutter-apk\app-release.apk
```
