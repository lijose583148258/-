# Cloud Testing Playbook

## Goal

Use cloud testing to validate install, launch, and basic flows when the local Windows emulator is unreliable.

This project already has:

- GitHub Actions for Android release build
- GitHub Actions for Android emulator smoke testing

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

Use it after BrowserStack confirms:

- the APK can install
- the app can launch
- the main screens are reachable

At that point, Firebase Test Lab becomes useful for:

- repeating smoke tests
- comparing devices and Android versions
- attaching cloud results to release readiness

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
2. BrowserStack App Live to validate install and launch on real devices
3. Firebase Test Lab for repeatable cloud smoke testing
4. local real-device testing for chat-assist, IME, and accessibility flows

## What not to rely on

- Do not treat the Windows local emulator as the primary validation path.
- Do not treat GitHub emulator smoke success as proof that the APK installs on real phones.
- Do not use cloud emulator results alone for accessibility or IME behavior.

## Immediate next action

For this project, the highest-value next cloud step is:

1. download the latest `app-release.apk` from GitHub Actions
2. upload it to BrowserStack App Live
3. verify install and first launch on at least two Android devices
