# Local USB OEM testing without cloud billing

Use this path when Firebase Test Lab, Android Device Streaming, BrowserStack, or another real-device cloud asks for a billing profile or payment method.

This route does not require a bank account. It requires physical Android phones connected to the workstation by USB.

## Device targets

Run at least one Android 10+ phone from each target family:

- Xiaomi / Redmi / POCO
- OPPO / OnePlus / realme
- Honor / Huawei

## Phone preparation

On each phone:

1. Enable Developer options.
2. Enable USB debugging.
3. Connect the phone by USB.
4. Accept the RSA debugging prompt on the phone.
5. Keep the phone unlocked during the smoke test.

Check that ADB can see the phones:

```powershell
adb devices -l
```

Every target phone must be listed as `device`, not `unauthorized` or `offline`.

## Build APK

```powershell
cd fanyi_app
flutter build apk --release
cd ..
```

## Run local OEM USB smoke

```powershell
.\scripts\run-local-oem-usb-smoke.ps1
```

For a custom APK:

```powershell
.\scripts\run-local-oem-usb-smoke.ps1 -ApkPath "C:\path\to\app-release.apk"
```

The script installs the APK, force-stops the app, clears logcat, launches the app from the launcher intent, waits for the cold-start window, and records:

- manufacturer, brand, model, Android release, SDK level, build version
- APK SHA-256
- install result
- launch result and PID
- `logcat`
- `dumpsys window`
- `dumpsys activity top`
- cold-start failure flags

Artifacts are written to:

```text
artifacts/local-oem-usb/
```

## Pass criteria

Each device must pass:

- APK installs successfully.
- App launches and remains in the foreground.
- No package-level `FATAL EXCEPTION`.
- No package-level `AndroidRuntime` crash.
- No fatal Flutter crash marker during cold launch.
- No cold-start `Creating TextToSpeech after first Flutter method call` marker.
- No `Failed to initialize TextToSpeech` marker during cold launch.

## What this replaces

This replaces paid/cloud OEM validation when no billing method is available. It does not replace the requirement for real OEM devices; an AOSP emulator with a modified manufacturer string is not valid OEM evidence.
