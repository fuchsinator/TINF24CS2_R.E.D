# RED Project

## Files

The project contains the following application files:

* **red.exe** → Windows application
* **red.app** → macOS application
* **red.apk** → Flutter Android application

## Firmware

The ESP8266 firmware is uploaded using **PlatformIO**.

### Uploading Firmware

1. Open the firmware project in VS Code.
2. Make sure the ESP8266 is connected via USB.
3. Build and upload the firmware using PlatformIO.
4. Wait until the upload process has completed successfully.

---

# Flutter Setup

## If Flutter Is Already Installed

Check installation:

```bash
flutter doctor
```

Copy the project files from GitHub:

* `pubspec.yaml`
* `lib/main.dart`

Install dependencies:

```bash
flutter pub get
```

Run the project:

```bash
flutter run -d chrome
```

Connect the ESP8266 to your notebook/computer.

---

## New to Flutter

### Installation

Download Flutter:

https://docs.flutter.dev/install/manual

Follow the installation guide and add Flutter to your environment variables.

### Verify Installation

```bash
flutter --version
```

```bash
dart --version
```

```bash
flutter doctor
```

### Create a New Project

```bash
flutter create red
```

Enter the project directory:

```bash
cd esp_car_control
```

Open the project in VS Code.

### Dependencies

Edit `pubspec.yaml`:

```yaml
dependencies:
  http: ^1.1.0
```

Install dependencies:

```bash
flutter pub get
```

### Add Source Code

Copy the project source code into:

```text
lib/main.dart
```

### Run the Application

```bash
flutter run -d chrome
```

### Hardware

Connect the ESP8266 to your notebook/computer.

---

# Project Structure

```text
red.exe        -> Windows application
red.app        -> macOS application
red.apk        -> Android application
Firmware/      -> ESP8266 firmware (PlatformIO)
lib/           -> Flutter source code
pubspec.yaml   -> Flutter dependencies
README.md      -> Project documentation
```
