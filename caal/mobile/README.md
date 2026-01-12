# CAAL Mobile

Cross-platform mobile client for CAAL voice assistant.

## Requirements

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.5.1+)
- Android Studio or Xcode
- CAAL server running on your network

## Pre-built APK

A pre-built Android APK is available on the [GitHub Releases](https://github.com/CoreWorxLab/CAAL/releases) page.

## Building from Source

```bash
# 1. Get dependencies
flutter pub get

# 2. Run on connected device/emulator
flutter run
```

## Configuration

On first launch, the app shows a setup screen where you enter your CAAL server URL:

- **LAN HTTP:** `http://192.168.1.100:3000`
- **LAN HTTPS:** `https://192.168.1.100`
- **Tailscale:** `https://your-machine.tailnet.ts.net`

Settings are saved on device and can be changed later via the settings icon.

## Building

### Android

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### iOS

```bash
flutter build ios --release
# Then open ios/Runner.xcworkspace in Xcode to archive
```

## Wake Word (Optional)

Wake word detection uses Picovoice Porcupine. The free tier allows 1 device per account.

### Using the pre-built APK

1. Get a free access key from [Picovoice Console](https://console.picovoice.ai/)
2. Train a wake word model for **Android** platform
3. Download the `.ppn` file to your device
4. In the app's setup screen, enter your access key and select the `.ppn` file

### Building from source

If building the APK yourself, you can optionally bundle a default wake word:

1. Train a wake word model for **Android** platform
2. Add the `.ppn` file to `assets/wakeword.ppn`
3. Users can still override with their own file via the setup screen

**Note:** The web WASM model from the main frontend will NOT work on mobile - you need a separate Android model.

## Project Structure

```
mobile/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── app.dart                  # App widget and theme
│   ├── controllers/
│   │   └── app_ctrl.dart         # App state controller
│   ├── screens/
│   │   ├── welcome_screen.dart   # Initial connection screen
│   │   └── agent_screen.dart     # Active conversation UI
│   ├── services/
│   │   └── caal_token_source.dart # Token fetch from CAAL API
│   └── widgets/                  # UI components
├── android/                      # Android-specific config
├── ios/                          # iOS-specific config
└── pubspec.yaml                  # Flutter dependencies
```

## Troubleshooting

### Connection Failed

1. Verify CAAL server is running: `curl http://YOUR_IP:3000/api/health`
2. Check phone and server are on same network
3. Try HTTP first, then HTTPS

### Audio Not Working

- Ensure microphone permissions are granted
- Check device is not muted
- Verify CAAL's Speaches (STT) and Kokoro (TTS) services are running

### Android Build Errors

```bash
flutter clean
flutter pub get
flutter run
```

### iOS Build Errors

```bash
cd ios
pod install --repo-update
cd ..
flutter run
```
