# APP 全面对标矩阵

## 对标目标

把仓库 APP 从“翻译工具 + 词库学习”升级为完整学习型 APP：

- 翻译工具稳定可用
- 学习课程体系完整
- 无会员限制
- 进度、连击、积分、成就可保存
- 本地优先、可离线运行
- 可通过 CI/真机测试逐步稳定到正式版

## 已落地模块

| 模块 | 状态 | 文件 |
|---|---:|---|
| 文本翻译 | 已有 | `translation_screen.dart`, `translation_service.dart` |
| 语音/对话翻译 | 已有 | `conversation_screen.dart`, `speech_service.dart` |
| 拍照/OCR入口 | 已有 | `camera_screen.dart` |
| 本地词典/俚语 | 已有 | `local_db_service.dart`, `dictionary_screen.dart`, `slang_screen.dart` |
| 输入法辅助 | 已有 | `keyboard_helper_screen.dart`, Android IME service |
| 小组件 | 已有 | Android widget provider |
| 无会员权益层 | 已落地 | `free_entitlement_service.dart` |
| 课程树 | 已落地 | `learning_course_service.dart`, `learn_screen.dart` |
| Unit/Lesson 关卡 | 已落地 | `learning_course_service.dart` |
| 选择题 | 已落地 | `LearningQuestionType.choice` |
| 匹配理解题 | 已落地 | `LearningQuestionType.matching` |
| 填空句型题 | 已落地 | `LearningQuestionType.fillBlank` |
| 跟读口语题 | 已落地 | `LearningQuestionType.speaking` |
| XP 积分 | 已落地 | `learning_stats.total_xp` |
| 每日目标 | 已落地 | `learning_stats.today_xp` |
| 连击天数 | 已落地 | `learning_stats.current_streak` |
| 最高分/完成状态 | 已落地 | `learning_progress` |
| 徽章成就 | 已落地 | `LearningBadge` |
| 稳定性测试 | 已落地 | `test/learning_course_service_test.dart` |

## 课程内容现状

当前内置 5 个课程组：

1. 入门生存越南语
2. 日常会话
3. 工作沟通
4. 语法与句型
5. 发音训练

当前内置题型：

- 选择题
- 匹配理解
- 填空句型
- 跟读口语

## 还需要真机验证的稳定性项目

| 验证项 | 命令/方式 |
|---|---|
| Flutter 依赖解析 | `flutter pub get` |
| 静态分析 | `flutter analyze` |
| 单元测试 | `flutter test` |
| Release APK | `flutter build apk --release` |
| 安装测试 | `adb install -r build\app\outputs\flutter-apk\app-release.apk` |
| 真机冒烟 | 打开翻译、学习课程、完成关卡、退出重开检查进度 |

## 结论

功能架构已经开始全面对标，不再只是简单“无会员”。  
下一步重点不是继续堆页面，而是装 Flutter 环境后跑完整构建和真机测试，把崩溃、权限、数据库升级、设备兼容逐项打磨。
