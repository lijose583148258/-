# Cloud Real Device Testing

This project now has two cloud-device paths for OEM validation.

## 1. Android Device Streaming / Partner Device Labs

Use this for interactive real-device checks on OEM phones.

Requirements:

- Android Studio stable channel with Device Streaming support
- A Firebase project where your Google account has Editor or Owner access
- Android Partner Device Labs enabled for the selected project

Recommended devices:

- Xiaomi or Redmi, Android 13+
- OPPO, OnePlus, or realme, Android 13+
- Honor or Huawei if available in the selected device catalog

Manual flow:

1. Open Android Studio.
2. Open this Flutter project at `fanyi_app`.
3. Open Device Manager.
4. Click Firebase / Select Remote Devices.
5. Filter for Xiaomi, OPPO, OnePlus, realme, Honor, or Huawei devices.
6. Connect to one device.
7. Install the latest `app-release.apk` from the GitHub `Android Release Build` artifact.
8. Verify install, cold launch, Settings, TTS settings routing, denied microphone permission, and lazy camera tab loading.

Official reference:

- https://developer.android.com/studio/run/android-device-streaming

## 2. Firebase Test Lab automated OEM matrix

Use this for repeatable cloud execution of the Flutter cold-start integration test.

Requirements:

- Google Cloud CLI installed locally, or the GitHub workflow configured
- Firebase Test Lab enabled for the project
- Billing/quota available for physical Android devices
- A service account with Test Lab permissions for GitHub Actions

Local command:

```powershell
.\scripts\run-firebase-test-lab.ps1 `
  -FirebaseProject YOUR_FIREBASE_PROJECT_ID `
  -DeviceFilters "xiaomi,oppo,oneplus,realme,honor,huawei"
```

The script:

- builds `app-debug.apk`
- builds `app-debug-androidTest.apk`
- queries Firebase Test Lab device models at run time
- selects matching physical devices by OEM keyword
- runs `integration_test/app_launch_test.dart` as an Android instrumentation test

GitHub workflow:

- Workflow name: `Android Firebase Test Lab OEM Devices`
- Trigger: manual `workflow_dispatch`
- Required secret: `GCP_SERVICE_ACCOUNT_JSON`
- Required input: `firebase_project`
- Optional input: `device_filters`

Official references:

- https://firebase.google.com/docs/test-lab
- https://firebase.google.com/docs/test-lab/flutter/integration-testing-with-flutter
- https://docs.flutter.dev/testing/integration-tests

## Acceptance targets

For each selected OEM device, record:

- APK installs successfully
- app cold-launches without a crash
- the first screen renders the translation page
- conversation, learn, and camera tabs are not built during cold launch
- logcat has no `Creating TextToSpeech after first Flutter method call` during cold launch
- logcat has no `Failed to initialize TextToSpeech`
- microphone denial does not crash conversation mode
- TTS settings button opens a system settings route or fails gracefully

Passing AOSP emulator tests does not replace these OEM real-device checks.
