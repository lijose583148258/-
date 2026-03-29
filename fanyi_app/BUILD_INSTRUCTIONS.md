# APK构建指南

本指南将详细介绍如何构建APK文件，以便在Android设备上运行。请按照以下步骤操作：

## 前提条件
在开始构建APK之前，请确保您已经安装了以下软件：
- [JDK 11或更高版本](https://www.oracle.com/java/technologies/javase-jdk11-downloads.html)
- [Android Studio](https://developer.android.com/studio)
- [Gradle](https://gradle.org/install/)

## 步骤

### 1. 克隆项目
如果您还没有克隆项目，请使用以下命令：
```bash
git clone https://github.com/lijose583148258/fanyi_app.git
cd fanyi_app
```

### 2. 打开Android Studio
打开Android Studio并选择“打开现有项目”，然后选择克隆的项目文件夹。

### 3. 配置Gradle
在Android Studio中，可能会提示您更新Gradle版本。请接受并等待更新完成。

### 4. 生成签名密钥
为了能够发布应用，您需要生成一个签名密钥：
```bash
keytool -genkey -v -keystore my-release-key.keystore -alias alias_name -keyalg RSA -keysize 2048 -validity 10000
```
按照提示输入所有必要信息。

### 5. 创建构建配置
在`app`目录下的`build.gradle`文件中，配置您的签名密钥：
```groovy
android {
    signingConfigs {
        release {
            storeFile file("my-release-key.keystore")
            storePassword "your_store_password"
            keyAlias "alias_name"
            keyPassword "your_key_password"
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### 6. 构建APK
打开终端，导航至项目目录，然后执行以下命令：
```bash
./gradlew assembleRelease
```

构建成功后，APK文件将位于`app/build/outputs/apk/release/`目录下。

### 7. 安装APK
将生成的APK文件发送至Android设备，您可以通过以下命令进行安装：
```bash
adb install app/build/outputs/apk/release/app-release.apk
```

## 结论
按照上述步骤，您应该能够成功构建和安装APK。如有任何问题，请检查构建日志以获取更多信息。