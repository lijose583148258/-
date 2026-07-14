# 主流国产 Android 真机验收

本清单覆盖小米（MIUI / HyperOS）、OPPO / OnePlus / realme（ColorOS）和荣耀（MagicOS）。它补充 AOSP 模拟器测试，不能由 AOSP 模拟器替代。

## 自动化真实设备门禁

仓库提供 `.github/workflows/oem-real-device-smoke.yml`，通过 BrowserStack Espresso 真实设备云执行 Android instrumentation 冷启动测试。

启用方式：

1. 在 GitHub 仓库 Actions secrets 中配置 `BROWSERSTACK_USERNAME` 和 `BROWSERSTACK_ACCESS_KEY`。
2. 手动运行 **OEM Real Device Smoke**，或让修改 `fanyi_app/**` 的 PR 自动触发。
3. 工作流会从账号当前可用设备池动态选择 Android 10+ 的 Xiaomi / Redmi / POCO、OPPO / OnePlus / realme / Oplus、Honor 设备，上传应用 APK 与测试 APK，等待所有真实设备会话完成。
4. 任一真实设备测试失败、云端执行超时、账号没有足够的匹配设备，或者凭证没有配置，门禁都会失败，不能把它当作已完成 OEM 验收。

公共云设备池不保证始终同时提供三个厂商。若 Honor 当前不在账号可用设备池中，必须使用 BrowserStack Private Devices、其他可审计的真实设备云，或一台荣耀 Android 10+ 真机补测并保留报告、录屏、设备型号、MagicOS 版本和 APK SHA-256。不得用修改 `Build.MANUFACTURER` 的 AOSP 镜像冒充荣耀真机。

## 每台设备的基础验收

1. 从冷启动打开应用，确认没有麦克风、相机、TTS 或 ML Kit 的权限弹窗和崩溃。
2. 在翻译页输入中文和越南语，分别确认本地词典、ML Kit 失败回退、网络失败回退均不会退出应用。
3. 打开对话页，允许麦克风；拒绝一次后使用“检查权限”进入系统应用信息页，重新授予后返回应用并再次检测。
4. 未安装越南语语音包时点击朗读，确认页面显示“语音包设置”入口，返回后可再次尝试。
5. 启用输入法与无障碍服务，切换到其他应用后再返回，确认服务入口仍在系统设置中可见且应用主界面正常。
6. 在低电量模式、断网、已清理后台和锁屏后重新打开应用，确认翻译页始终可进入，语音/ML Kit 不可用时降级为手动输入或在线/本地翻译。

## 厂商专项

### 小米 / Redmi / POCO

- 在应用信息中允许麦克风；从安全中心或权限管理重新授予被拒绝的权限。
- 使用输入法或无障碍翻译期间，不在系统清理工具中强制结束应用；仅按系统提示允许需要的后台活动。

### OPPO / OnePlus / realme

- 在应用信息的权限管理中允许麦克风；确认系统权限弹窗被拦截后，应用的“系统设置”入口仍可恢复权限。
- 如果需要持续使用输入法或无障碍翻译，按 ColorOS 提示允许相关后台/自启动设置；不申请无关的电池豁免。

### 荣耀

- 在应用信息权限中授予麦克风；拒绝后通过应用内入口恢复。
- 如果需要持续使用输入法或无障碍翻译，避免在系统清理中手动结束该服务。

## 正式发布通过标准

必须同时满足：

- Release Build、API 24 / 29 / 34 AOSP Emulator Smoke 全部通过；
- 小米系至少一台 Android 10+ 真实设备通过；
- OPlus 系至少一台 Android 10+ 真实设备通过；
- 荣耀至少一台 Android 10+ 真实设备通过；
- 无冷启动崩溃、无未处理异常；语音、语音包或 ML Kit 不可用时保持可操作的手动或网络回退路径；
- 发布 APK/AAB 使用正式签名，不得使用 CI 中的 debug signing fallback；
- 保存云测试结果或真机验收证据，并记录 APK SHA-256、设备型号、Android/厂商系统版本和测试日期。
