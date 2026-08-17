# OZIRAF Mobile

Flutter app for OZIRAF with Android, iOS, web and Windows targets.

## Setup

Flutter SDK:

```text
D:\OZIRAF\tools\flutter-zip\flutter
```

Android SDK:

```text
C:\Users\aleja\AppData\Local\Android\Sdk
```

Recommended PowerShell environment for this machine:

```powershell
$env:Path="D:\OZIRAF\tools\flutter-zip\flutter\bin;$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin;$env:LOCALAPPDATA\Android\Sdk\platform-tools;$env:LOCALAPPDATA\Android\Sdk\emulator;$env:Path"
$env:ANDROID_HOME="$env:LOCALAPPDATA\Android\Sdk"
$env:GRADLE_USER_HOME="D:\OZIRAF\tools\gradle-cache"
$env:TEMP="D:\OZIRAF\tools\tmp"
$env:TMP="D:\OZIRAF\tools\tmp"
```

## Commands

```powershell
flutter doctor
flutter analyze
flutter test
flutter build apk --debug
flutter build web --debug
```

To point the app to another API:

```powershell
flutter run -d chrome --dart-define=OZIRAF_API_URL=http://localhost:3001
flutter run -d emulator --dart-define=OZIRAF_ANDROID_API_URL=http://10.0.2.2:3001
```

## Outputs

Debug APK:

```text
build\app\outputs\flutter-apk\app-debug.apk
```
