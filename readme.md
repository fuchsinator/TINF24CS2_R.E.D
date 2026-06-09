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

# Git Guide

## Working with Git

### Clone Repository

```bash
git clone "url"
```

Clones the repository to your local machine.

### Check Status

```bash
git status
```

Shows the current branch, modified files, commits, and repository status.

### Restore a File

```bash
git restore "filename"
```

Restores a file if it was deleted accidentally.

**Important:** This only works before the changes have been pushed.

### Switch Branch

```bash
git switch "Branchname"
```

Switches to another branch.

### Merge a Branch

```bash
git merge "branch"
```

Merges the specified branch into the current branch.

Example:

```bash
git merge main
```

All changes from `main` are merged into the currently selected branch.

After merging, do not forget to push:

```bash
git push
```

---

## Pushing Changes

### Add Files

```bash
git add .
```

Adds all files in the current folder to the staging area.

### Check Status

```bash
git status
```

Shows current repository status.

### View Differences

```bash
git diff
```

Shows what has changed.

### Create Commit

```bash
git commit -m "commit message"
```

Creates a commit with a message.

### Push Changes

```bash
git push
```

Publishes all committed changes to the remote repository.

---

# How Git Works

Git works in 4 stages:

## 1. Local Environment

Your current working directory on your computer.

Changes only exist locally.

## 2. Staging Area

```bash
git add .
```

Moves selected files into the staging area.

This allows you to decide which files should be included in the next commit.

## 3. Commit

```bash
git commit -m "Message"
```

Creates a snapshot of the staged files and attaches a commit message.

The commit is still only local.

## 4. Publish

```bash
git push
```

Publishes all committed changes to the remote repository so everyone can see them.

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
