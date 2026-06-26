# RED Project

You can build a car as described in the documentation. The microcontroller code is uploaded using PlatformIO.

The attached files include a Flutter app used to control the car.

To get started, turn on the car and connect to the Wi-Fi network that appears. Once connected, open the app and you can start controlling the car.

# Running the Flutter App

Prebuilt apps are included for Windows, Android, and Linux.

## Files

- Android: download zip folder `red.zip`
- Linux: download the entire folder `linux/`

---

## Linux

```bash
cd linux
chmod +x executable
./linux/executable
```

⚠️ Keep the `linux/data/` and `linux/lib/` folders next to the executable.

---

## Android

### Install via device
- Copy `red.apk` to your phone
- Open and install (enable unknown sources if needed)

## Firmware

The ESP8266 firmware is uploaded using **PlatformIO**.

### Uploading Firmware

1. Open the firmware project in VS Code.
2. Make sure the ESP8266 is connected via USB.
3. Build and upload the firmware using PlatformIO.
4. Wait until the upload process has completed successfully.

---

## Flutter manual build up
Considering the main branch had been cloned follow the upcoming steps to fully build the working flutter up. 
If errors accure during this process please refer to the documentation of flutter: https://docs.flutter.dev/reference/supported-platforms

1. `flutter create . --platforms web` for the necessary web requirments
2. `flutter create --platforms=windows,macos,linux .` for the necessary platform requirments

Now consider your Operating System to follow the following steps: 
### Android APK
`flutter build apk --release`

### Android App Bundle (für Play Store)
`flutter build appbundle`

### iOS (nur auf macOS möglich)
`flutter build ipa --release`

### Web (preferred) 
`flutter build web`
For starting the application on web: 
`cd build/web`
`python -m http.server 8000`

