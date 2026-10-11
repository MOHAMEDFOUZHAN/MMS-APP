# Benchmark MMS - Agent & Build Guidelines

This document contains standard operating procedures (SOP) and persistent instructions for AI agents and developers working on the **Benchmark MMS** mobile & tablet application.

---

## 1. App Identity & Naming Rules
- **Display Label**: Must always be `Benchmark MMS` in:
  - `android/app/src/main/AndroidManifest.xml` (`android:label="Benchmark MMS"`)
  - `lib/main.dart` (`MaterialApp(title: 'Benchmark MMS', ...)`)
- **APK Deliverables**: Whenever a release APK is compiled, always copy/name the output in the project root as:
  - `Benchmark MMS.apk`
  - `Benchmark_MMS.apk`

---

## 2. Release & Version Bump Protocol
Before compiling any release APK intended for clients or OTA deployment:
1. Open `pubspec.yaml` and increment the version:
   - Example: `version: 1.0.22+25` -> `version: 1.0.23+26`
2. **Never** recompile without bumping the build number if an OTA update is needed, because `AppUpdateService` only triggers updates when `remoteInfo.versionCode > currentBuildNumber`.

---

## 3. Fresh Build & Cleanliness Protocol
Whenever a fresh compile is requested:
1. **Delete Old Local APKs**:
   - Remove any `*.apk` files in the root folder (`Benchmark MMS.apk`, `Benchmark_MMS*.apk`).
   - Remove old outputs in `build/app/outputs/flutter-apk/`.
2. **Clean Project State**:
   - Run: `& "D:\flutter\bin\flutter.bat" clean`
   - Run: `& "D:\flutter\bin\flutter.bat" pub get`
3. **Environment & Tool Paths**:
   - Flutter executable: `D:\flutter\bin\flutter.bat` (not in system PATH).
   - Android ADB: `C:\Users\fouzh\AppData\Local\Android\Sdk\platform-tools\adb.exe`.

---

## 4. Windows Resources & Gradle Stability
Windows Error 1450 (`java.io.IOException: Insufficient system resources exist to complete the requested service`) occurs if drive `C:` runs low on disk space or virtual memory during Gradle compilation.
- **Drive C Disk Space**: Ensure drive `C:` has at least 2GB free. If full, clean `C:\Users\fouzh\AppData\Local\Temp`.
- **Gradle Properties (`android/gradle.properties`)**: Must always retain:
  ```properties
  org.gradle.jvmargs=-Xmx1024m -XX:MaxMetaspaceSize=384m -Djava.io.tmpdir=D:\\tmp -XX:+UseSerialGC
  org.gradle.parallel=false
  org.gradle.workers.max=1
  android.useAndroidX=true
  android.enableJetifier=true
  kotlin.incremental=false
  ```
- **Temp Directory**: `D:\tmp` must exist and be used as `java.io.tmpdir`.

---

## 5. Build & OTA Supabase Publishing
To compile and publish in one command:
```powershell
python publish_update.py --build --notes "Description of changes"
```
This script:
1. Cleans old APK build artifacts.
2. Compiles release APK (`flutter build apk --split-per-abi`).
3. Copies output to `Benchmark MMS.apk` and `Benchmark_MMS.apk` in the root folder.
4. Uploads `mms_app_v<build>.apk` to Supabase Storage bucket `app-releases`.
5. Updates Supabase database table `public.app_versions` with the new version code, version name, and download URL.

---

## 6. Device Testing & Complete Reset Protocol
- **Completely Wipe App Data from Connected Device**:
  ```powershell
  & "C:\Users\fouzh\AppData\Local\Android\Sdk\platform-tools\adb.exe" uninstall com.benchmark.mms_app
  ```
  *(Note: `pm clear` may fail with SecurityException on MIUI/HyperOS, but `adb uninstall` cleanly purges all data, databases, and secure keystore keys).*
- **Clean Residual Device Downloads**:
  ```powershell
  & "C:\Users\fouzh\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell "rm -rf /sdcard/Download/MMS-APP"
  ```
- **Install Fresh Build to Connected Device**:
  ```powershell
  & "C:\Users\fouzh\AppData\Local\Android\Sdk\platform-tools\adb.exe" install -r "Benchmark MMS.apk"
  ```
