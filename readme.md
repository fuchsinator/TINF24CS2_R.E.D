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
