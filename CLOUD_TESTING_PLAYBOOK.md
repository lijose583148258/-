# Cloud Testing Playbook

## Goal

Use cloud testing to validate install, launch, and basic flows when the local Windows emulator is unreliable.

This project already has:

- GitHub Actions for Android release build
- GitHub Actions for Android emulator smoke testing
- a manual GitHub Actions workflow for Firebase Test Lab OEM devices
- a local `scripts/run-firebase-test-lab.ps1` runner

Cloud testing should be used for:

- install validation on real Android devices
- launch validation on different vendors and Android versions
- basic interaction checks without depending on the local emulator

## Recommended order

### 1. BrowserStack App Live

Best for:

- non-technical manual testing
- checking whether the APK installs
- checking whether the app opens and basic UI works
- quickly comparing behavior across Samsung, Xiaomi, Pixel, and other devices

Why this is the best first step:

- upload an APK directly
- run on real cloud devices
- no local emulator setup required

Official references:

- BrowserStack App Live overview
- BrowserStack upload apps for testing

## BrowserStack steps for this project

### Source APK

Use the APK already produced by this repository:

- GitHub Actions
- open the latest successful `Android Release Build`
- download `app-release-apk`
- use the extracted `app-release.apk`

### Manual test flow

1. Sign in to BrowserStack App Live.
2. Open `Uploaded Apps`.
3. Upload `app-release.apk`.
4. Choose an Android real device.
5. Wait for install to finish.
6. Open the app and test the following:
   - app installs successfully
   - app opens without crash
   - Translate page loads
   - Conversation page loads
   - Learn page loads
   - Settings page loads
   - History page loads
   - permissions denied path does not crash

### Devices to prioritize

- Pixel with recent Android
- Samsung with recent Android
- Xiaomi or Redmi with recent Android
- one lower-memory Android device if available

## BrowserStack result checklist

Record these outcomes:

- install success or failure
- first launch success or crash
- startup time impression
- black screen or permission issues
- any broken layout on smaller screens
- whether translation history and settings work

## 2. Firebase Test Lab

Best for:

- repeatable cloud execution
- scripted instrumentation tests
- broader device matrix after manual smoke testing is stable

Official references:

- Firebase Test Lab overview
- Firebase Test Lab Android getting started

## When to use Firebase Test Lab here

Use Firebase Test Lab as the first automated cloud path after GitHub AOSP
emulator smoke is green. It is now wired for this repository through:

- `scripts/run-firebase-test-lab.ps1`
- `.github/workflows/android-firebase-test-lab.yml`
- `fanyi_app/docs/CLOUD_REAL_DEVICE_TESTING.md`

The runner builds the Flutter integration test APKs, queries Firebase Test Lab
device models at run time, and selects physical devices by OEM keyword such as
Xiaomi, OPPO, OnePlus, realme, Honor, and Huawei.

## What to test first in Firebase

Start with small checks only:

- app launches
- main layout renders
- Translate tab opens
- Learn tab opens
- app survives a denied permission path

Do not start with advanced Zalo/accessibility flows in cloud devices.

Those should stay in:

- local real-device testing
- later vendor-specific testing

## Recommended project workflow

For this repository, use this order:

1. GitHub `Android Release Build` to produce APK
2. GitHub `Android Emulator Smoke Test` for API 24/29/34 cold-start coverage
3. Firebase Test Lab OEM workflow for repeatable real-device smoke testing
4. BrowserStack, Sauce Labs, or Pcloudy for manual exploratory OEM checks
5. local real-device testing for chat-assist, IME, and accessibility flows

## What not to rely on

- Do not treat the Windows local emulator as the primary validation path.
- Do not treat GitHub emulator smoke success as proof that the APK installs on real phones.
- Do not use cloud emulator results alone for accessibility or IME behavior.

## Immediate next action

For this project, the highest-value next cloud step is:

1. add `GCP_SERVICE_ACCOUNT_JSON` as a GitHub repository secret
2. run `Android Firebase Test Lab OEM Devices` manually
3. use `xiaomi,oppo,oneplus,realme,honor,huawei` as the device filter input
4. inspect the Firebase Test Lab matrix and uploaded request artifact
