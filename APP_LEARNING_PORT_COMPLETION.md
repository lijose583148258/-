# APP 学习功能补齐记录

## 本次已补齐

- 课程树：入门生存越南语、日常会话、工作沟通。
- 关卡系统：每个课程包含多个 lesson，每个 lesson 含词汇和选择题。
- 练习题：题目、选项、答案、解析全部本地内置。
- 学习进度：记录尝试次数、答对数量、最高分、完成状态。
- 积分系统：按答题正确数和首次通关奖励累计 XP。
- 连击系统：按自然日记录学习 streak。
- 成就入口：课程页显示连击、积分、成就状态。
- 无会员权益：新增功能已加入免费权益层，默认全部开放。

## 新增/修改文件

- `fanyi_app/lib/services/learning_course_service.dart`
- `fanyi_app/lib/services/local_db_service.dart`
- `fanyi_app/lib/screens/learn_screen.dart`
- `fanyi_app/lib/services/free_entitlement_service.dart`
- `fanyi_app/lib/main.dart`
- `fanyi_app/lib/screens/settings_screen.dart`

## 数据库变化

本地 APP 数据库版本从 `1` 升级到 `2`，新增：

- `learning_progress`
- `learning_stats`

老用户升级时会通过 `onUpgrade` 自动创建新表，不会清空翻译历史。

## 当前实现方式

这是自有 APP 内的同类功能补齐：课程内容、练习题、进度逻辑、积分逻辑均为本仓库代码实现，不依赖服务器、账号或会员校验。

## 验证建议

```powershell
cd "C:\Users\Administrator\Documents\Codex\2026-07-12\new-chat\owner_app_repo\fanyi_app"
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

当前这台电脑未检测到 Flutter/Dart 命令，已完成代码级静态检查与差异检查。

## 已加入的稳定性测试

- `test/learning_course_service_test.dart`
- 检查课程/关卡结构不为空。
- 检查 lesson id 不重复。
- 检查每道题答案索引都在选项范围内。
- 检查新增学习功能都包含在无会员权益层中。
