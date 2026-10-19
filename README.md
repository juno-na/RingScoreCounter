# RingScore

Private, offline-first archery score history for Android and iOS.

## Current preview

The first app slice includes score history, local SQLite persistence, camera capture, a round review screen, manual corrections, and daily totals. The on-device vision prototype locates a centered, front-facing single-spot target and estimates scores from dark impact marks. Use **Try sample target** on the capture screen to exercise detection, review, and saving with a generated image. This sample checks the app flow and basic image-processing path; real range photos are still needed to assess accuracy with perspective, glare, lighting, and actual arrow holes.

The camera plugin briefly writes a capture to its temporary area. The app reads it into memory and immediately deletes that temporary file; the review screen uses the in-memory image and discards it when closed. The platform project still needs backup-exclusion configuration before score history meets the no-cloud-backup requirement.

## Install for local development

Install:

1. Flutter stable (Dart 3.10 or later).
2. Android Studio, including Android SDK, platform tools, and an Android emulator.
3. For iPhone builds later: macOS with Xcode and CocoaPods. iOS device builds cannot be produced from Windows.

After installing Flutter, open PowerShell in this directory and run:

```powershell
flutter create --platforms=android,ios --project-name ring_score_counter .
flutter pub get
```

If Flutter reports existing project files, keep the files under `lib/` and `pubspec.yaml`, and create only the missing Android/iOS platform scaffolding. Set the Android `minSdk` to 24 or newer. In `ios/Runner/Info.plist`, add `NSCameraUsageDescription` with a short explanation that the camera is used to photograph an archery target. Do not add microphone permission; the app captures still photos only.

Before release, configure Android Auto Backup exclusions and mark the iOS database directory as excluded from iCloud/device backup.

## Preview on an Android emulator

`flutter emulators` lists configured emulator profiles. `flutter devices` lists devices that are currently running or connected. Use the emulator profile name with `flutter emulators --launch`; use the running device ID with `flutter run`.

Launch an emulator by replacing `AVD_NAME` with a profile name from `flutter emulators`:

```sh
flutter emulators --launch AVD_NAME
```

That command may return to the prompt without printing anything. Wait for the emulator to finish booting, then run:

```sh
flutter devices
```

Find the emulator's running device ID in the output, then use it in place of `DEVICE_ID`:

```sh
flutter run -d DEVICE_ID
```

Do not pass the AVD profile name to `flutter run`; it is not the running device ID. If the launch command returns silently, wait for boot to finish before checking `flutter devices`.

Once the app opens, choose **Try sample target** on the capture screen. It works even if the emulator has no usable virtual camera and opens a generated 40 cm target in the same analysis and review flow used for camera photos.

### If the emulator does not appear

1. In Android Studio, open **Tools > Device Manager** and press the play button next to the emulator profile you want to use. Wait until the Android home screen appears, then run `flutter devices` again.
2. Check **Tools > SDK Manager > SDK Tools** and make sure **Android Emulator** and **Android SDK Platform-Tools** are installed. Run `flutter doctor -v` and `flutter doctor --android-licenses` to identify or accept Android toolchain requirements.
3. If the emulator window is open but missing from `flutter devices`, run `adb devices -l`. A booted emulator should appear with a device ID and status `device`. If ADB shows it as `offline`, restart ADB with:

   ```sh
   adb kill-server
   adb start-server
   adb devices -l
   ```

4. If Device Manager cannot boot it, open the AVD's menu and select **Cold Boot Now**. If that still fails, use **Wipe Data** for that emulator profile and try again; this resets the virtual device only.
5. If it still will not start, check that CPU virtualization is enabled in firmware and that Windows has the hypervisor support required by the selected emulator acceleration mode.

## Preview on your Android phone

1. Enable Developer options and USB debugging on the phone.
2. Connect it by USB and accept the debugging authorization prompt.
3. Run `flutter devices`, then run `flutter run -d DEVICE_ID`, replacing `DEVICE_ID` with the phone's ID from the output.
4. Grant camera permission when Android asks. The app requires no internet connection.

For iPhone preview, use a Mac with Xcode, connect the phone, trust the Mac, then run `flutter devices` and `flutter run -d DEVICE_ID`, replacing `DEVICE_ID` with the phone's ID from the output. The first physical iOS build requires signing setup in Xcode.
