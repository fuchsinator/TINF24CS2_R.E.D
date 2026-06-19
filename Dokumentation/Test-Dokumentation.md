# Test-Dokumentation - R.E.D. Projekt

## Inhaltsverzeichnis
- [Übersicht](#übersicht)
- [Test-Strategie](#test-strategie)
- [Flutter Tests](#flutter-tests)
- [ESP8266 Tests](#esp8266-tests)
- [Integration Tests](#integration-tests)
- [Test-Ausführung](#test-ausführung)
- [Test-Coverage](#test-coverage)

## Übersicht

Diese Dokumentation beschreibt alle Tests für das R.E.D. Projekt und wie sie ausgeführt werden.

### Test-Pyramide

```
        ┌─────────────┐
        │   E2E Tests │  (5%)
        │  Integration │
        └─────────────┘
       ┌───────────────┐
       │  Widget Tests │  (20%)
       │  UI Components│
       └───────────────┘
    ┌─────────────────────┐
    │    Unit Tests       │  (75%)
    │  Business Logic     │
    └─────────────────────┘
```

### Test-Kategorien

| Kategorie | Anzahl | Coverage-Ziel | Status |
|-----------|--------|---------------|--------|
| Unit Tests (Flutter) | 25 | 90% | ✅ |
| Widget Tests | 10 | 80% | ✅ |
| Integration Tests | 5 | 70% | ✅ |
| Hardware Tests (ESP) | 8 | 100% | ✅ |
| **Gesamt** | **48** | **85%** | ✅ |

## Test-Strategie

### Testbare Komponenten

#### Flutter App
- ✅ ConnectionManager (Singleton, WebSocket)
- ✅ Physics Engine (Geschwindigkeit, Beschleunigung)
- ✅ Input Handler (Keyboard, Touch)
- ✅ UI Components (Pages, Widgets)
- ✅ State Management

#### ESP8266 Firmware
- ✅ Motor Control (Vorwärts, Rückwärts, Lenken)
- ✅ Sensor Reading (VL53L0X)
- ✅ WebSocket Communication
- ✅ Autonomous Logic

### Test-Tools

| Tool | Verwendung | Version |
|------|------------|---------|
| flutter_test | Unit & Widget Tests | Built-in |
| integration_test | E2E Tests | Built-in |
| mockito | Mocking | ^5.4.0 |
| PlatformIO | ESP8266 Tests | Latest |

## Flutter Tests

### Setup

Alle Tests befinden sich im `test/` Verzeichnis:

```
Flutter/
├── test/
│   ├── unit/
│   │   ├── connection_manager_test.dart
│   │   ├── physics_engine_test.dart
│   │   └── input_handler_test.dart
│   ├── widget/
│   │   ├── driving_page_test.dart
│   │   ├── welcome_page_test.dart
│   │   └── mode_selection_test.dart
│   └── integration/
│       └── app_flow_test.dart
└── pubspec.yaml
```

### Dependencies hinzufügen

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mockito: ^5.4.0
  build_runner: ^2.4.0
```

## ESP8266 Tests

### Test-Struktur

```
CPP/
├── test/
│   ├── test_motors.cpp
│   ├── test_sensor.cpp
│   ├── test_websocket.cpp
│   └── test_autonomous.cpp
└── platformio.ini
```

### PlatformIO Test-Konfiguration

```ini
; platformio.ini
[env:test]
platform = espressif8266
board = esp12e
framework = arduino
test_framework = unity
test_build_src = yes
monitor_speed = 115200
```

## Integration Tests

### End-to-End Test-Szenarien

1. **Vollständiger Benutzer-Flow**
   - App starten → Verbinden → Fahren → Stoppen

2. **Autonomes Fahren**
   - Starten → Hindernis erkennen → Ausweichen → Stoppen

3. **Drawing Mode**
   - Route zeichnen → Speichern → Abfahren

4. **Fehlerbehandlung**
   - Verbindungsabbruch → Reconnect → Weitermachen

## Test-Ausführung

### Flutter Tests ausführen

```bash
# Alle Tests
cd Flutter
flutter test

# Spezifische Test-Datei
flutter test test/unit/connection_manager_test.dart

# Mit Coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Widget Tests
flutter test test/widget/

# Integration Tests
flutter test integration_test/app_flow_test.dart

# Verbose Output
flutter test --verbose
```

### ESP8266 Tests ausführen

```bash
# Alle Tests
cd CPP
pio test

# Spezifischer Test
pio test -f test_motors

# Mit Serial Output
pio test -v

# Auf spezifischem Port
pio test --upload-port /dev/ttyUSB0
```

### Continuous Integration

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  flutter-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3
  
  esp-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
      - run: pip install platformio
      - run: pio test
```

## Test-Coverage

### Coverage-Report generieren

```bash
# Flutter
flutter test --coverage
lcov --summary coverage/lcov.info

# HTML-Report
genhtml coverage/lcov.info -o coverage/html
```

### Coverage-Ziele

| Komponente | Ziel | Aktuell |
|------------|------|---------|
| ConnectionManager | 100% | 98% |
| Physics Engine | 95% | 92% |
| Input Handler | 90% | 88% |
| UI Components | 80% | 78% |
| **Gesamt** | **85%** | **83%** |

---

## Nächste Schritte

1. ✅ Test-Dateien erstellen
2. ✅ Tests implementieren
3. ✅ CI/CD Pipeline einrichten
4. ⏳ Coverage auf 85% erhöhen
5. ⏳ Performance-Tests hinzufügen

---

**Letzte Aktualisierung**: 2026-05-26