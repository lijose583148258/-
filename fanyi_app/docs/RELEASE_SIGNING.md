# Android 正式签名与可持续升级

Android 使用签名确认应用身份。同一个包名 `com.fanyitong.app` 的后续 APK 必须使用同一把发布密钥签名，否则手机会提示安装失败，必须卸载旧版才能安装，并会丢失本地数据。

## 必须长期保存的资料

- 发布密钥文件，例如 `fanyitong-release-keystore.jks`
- 密钥库密码
- 密钥别名
- 密钥密码

这些资料不得提交到 Git 仓库、聊天群、公开网盘或 APK 中。至少保存两份离线加密备份。密钥一旦永久丢失，就无法继续给已经安装的同包名应用发布可覆盖升级的 APK。

## GitHub Actions Secrets

在仓库 **Settings → Secrets and variables → Actions** 中配置以下四项：

- `ANDROID_KEYSTORE_BASE64`：发布密钥文件的单行 Base64 内容
- `ANDROID_KEYSTORE_PASSWORD`：密钥库密码
- `ANDROID_KEY_ALIAS`：密钥别名
- `ANDROID_KEY_PASSWORD`：密钥密码

Linux / macOS 可生成单行 Base64：

```bash
base64 -w 0 fanyitong-release-keystore.jks
```

Windows PowerShell 可生成单行 Base64：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("fanyitong-release-keystore.jks"))
```

## 构建规则

- Pull Request：允许没有正式密钥时生成 `debug-fallback` 安装测试包。
- 推送到 `main` / `master`：必须配置正式密钥，否则构建失败。
- 手动运行 `Android Release Build`：勾选 `production_release` 后必须使用正式密钥。
- 每次构建都会执行 APK 对齐检查、签名验证，并生成 APK/AAB 的 SHA-256。

## 手机升级验收

1. 安装一个正式签名的旧版本并产生少量翻译历史。
2. 将 `version` 的 build number 增加，例如从 `1.0.2+3` 增加到 `1.0.3+4`。
3. 使用同一套 GitHub Secrets 构建新 APK。
4. 不卸载旧版，直接覆盖安装新 APK。
5. 确认应用可以启动，翻译历史仍存在，语音和设置入口正常。

只有完成覆盖升级验证，才能确认签名链和本地数据升级路径可用于正式发布。
