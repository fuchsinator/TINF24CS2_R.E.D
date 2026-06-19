# Technische Dokumentation - R.E.D. Projekt

## Inhaltsverzeichnis
- [API-Dokumentation](#api-dokumentation)
- [Hardware-Dokumentation](#hardware-dokumentation)
- [Entwickler-Guide](#entwickler-guide)
- [Testing-Strategie](#testing-strategie)
- [Performance-Optimierung](#performance-optimierung)
- [Troubleshooting](#troubleshooting)

## API-Dokumentation

### WebSocket-Protokoll

#### Verbindungsdetails
```
Protocol: WebSocket (ws://)
Host: 10.10.10.10
Port: 81
Path: /
```

#### Nachrichtenformat

**Client → Server (Flutter → ESP8266)**

Alle Befehle werden als Plain-Text-Strings gesendet:

| Befehl | Beschreibung | Parameter | Beispiel |
|--------|--------------|-----------|----------|
| `forward` | Vorwärts fahren | - | `"forward"` |
| `backward` | Rückwärts fahren | - | `"backward"` |
| `left` | Links lenken | - | `"left"` |
| `right` | Rechts lenken | - | `"right"` |
| `stop` | Alle Motoren stoppen | - | `"stop"` |
| `auto` | Autonomen Modus aktivieren | - | `"auto"` |
| `autoStop` | Autonomen Modus deaktivieren | - | `"autoStop"` |

**Kombinierte Befehle:**
```
"forward,left"   // Vorwärts + Links
"forward,right"  // Vorwärts + Rechts
"backward,left"  // Rückwärts + Links
"backward,right" // Rückwärts + Rechts
```

**Server → Client (ESP8266 → Flutter)**

| Nachricht | Typ | Beschreibung | Format |
|-----------|-----|--------------|--------|
| `ACK` | Bestätigung | Befehl empfangen | `"ACK"` |
| Sensordaten | JSON | Distanzmessung | `{"distance": 450}` |
| `SENSOR_ERROR` | Fehler | Sensor-Timeout | `"SENSOR_ERROR"` |

#### Code-Beispiele

**Flutter (Client):**
```dart
// Verbindung herstellen
final channel = WebSocketChannel.connect(
  Uri.parse('ws://10.10.10.10:81'),
);

// Befehl senden
void sendCommand(String cmd) {
  if (connected.value) {
    channel.sink.add(cmd);
  }
}

// Nachrichten empfangen
channel.stream.listen(
  (message) {
    print('Received: $message');
    if (message == 'ACK') {
      // Befehl bestätigt
    }
  },
  onError: (error) {
    print('Error: $error');
    _scheduleReconnect();
  },
  onDone: () {
    print('Connection closed');
    _scheduleReconnect();
  },
);
```

**ESP8266 (Server):**
```cpp
void handleWSEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t len) {
  if(type == WStype_TEXT) {
    String msg = String((char*)payload);
    
    // Parse Befehle
    if(msg.indexOf("forward") >= 0) currentDirection = 1;
    if(msg.indexOf("backward") >= 0) currentDirection = 2;
    if(msg.indexOf("left") >= 0) currentTurn = 1;
    if(msg.indexOf("right") >= 0) currentTurn = 2;
    if(msg.indexOf("stop") >= 0) {
      currentDirection = 0;
      currentTurn = 0;
    }
    
    // Bestätigung senden
    ws.sendTXT(num, "ACK");
  }
}
```

### HTTP Fallback API

**Endpoint**: `http://10.10.10.10/command`

**Methode**: GET

**Parameter**:
- `cmd`: Befehlsstring (z.B. "forward", "stop")

**Beispiel**:
```
GET http://10.10.10.10/command?cmd=forward
```

**Response**:
```json
{
  "status": "ok",
  "command": "forward"
}
```

---

## Hardware-Dokumentation

### Komponenten-Liste

| Komponente | Modell | Anzahl | Funktion |
|------------|--------|--------|----------|
| Mikrocontroller | ESP8266 NodeMCU | 1 | Hauptsteuerung |
| ToF-Sensor | VL53L0X | 1 | Distanzmessung |
| DC-Motor | N20 6V | 2 | Antrieb & Lenkung |
| Motor-Treiber | L298N H-Bridge | 1 | Motor-Ansteuerung |
| Batterie | Li-Ion 7.4V | 1 | Stromversorgung |
| Spannungsregler | LM2596 | 1 | 3.3V für ESP8266 |

### Schaltplan

```
                    ┌─────────────────┐
                    │   ESP8266       │
                    │   NodeMCU       │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
         ┌────▼────┐    ┌────▼────┐   ┌────▼────┐
         │ VL53L0X │    │ Motor A │   │ Motor B │
         │ (I2C)   │    │(Steering)│   │ (Drive) │
         └─────────┘    └─────────┘   └─────────┘
         SDA: D6             │              │
         SCL: D5             │              │
                        ┌────▼──────────────▼────┐
                        │   L298N H-Bridge       │
                        │   Motor Driver         │
                        └────────────────────────┘
                                    │
                        ┌───────────▼───────────┐
                        │   7.4V Battery Pack   │
                        │   (2x 18650 Li-Ion)   │
                        └───────────────────────┘
```

### Pin-Belegung ESP8266

| GPIO | Pin | Funktion | Verbindung |
|------|-----|----------|------------|
| GPIO5 | D1 | Motor A Enable | L298N ENA |
| GPIO4 | D2 | Motor A Direction | L298N IN1 |
| GPIO0 | D3 | Motor B Enable | L298N ENB |
| GPIO2 | D4 | Motor B Direction | L298N IN2 |
| GPIO14 | D5 | I2C SCL | VL53L0X SCL |
| GPIO12 | D6 | I2C SDA | VL53L0X SDA |
| 3.3V | 3V3 | Stromversorgung | VL53L0X VIN |
| GND | GND | Masse | Gemeinsame Masse |

### VL53L0X Sensor-Konfiguration

```cpp
void sensor_init(bool long_range, bool high_speed) {
  Wire.begin(SDA_green, SCL_white);
  delay(1000);
  
  sensor.setTimeout(500);
  
  if (!sensor.init()) {
    Serial.println("VL53L0X init FAILED");
    while (1) delay(10);
  }
  
  // Long Range Mode
  if (long_range) {
    sensor.setSignalRateLimit(0.1);
    sensor.setVcselPulsePeriod(VL53L0X::VcselPeriodPreRange, 18);
    sensor.setVcselPulsePeriod(VL53L0X::VcselPeriodFinalRange, 14);
  }
  
  // Timing Budget
  uint32_t budget = high_speed ? 20000 : 200000;
  sensor.setMeasurementTimingBudget(budget);
}
```

**Sensor-Spezifikationen:**
- Messbereich: 50mm - 2000mm
- Genauigkeit: ±3% bei 200-800mm
- Update-Rate: ~50Hz (High Speed), ~5Hz (High Accuracy)
- Interface: I2C (400kHz)
- Stromverbrauch: ~19mA

### Motor-Steuerung

```cpp
void drive(int direction, int turn) {
  // Lenkung (Motor A)
  if(turn == 0) {
    digitalWrite(Motor_A_white, LOW);  // Aus
  } else if (turn == 1) {
    digitalWrite(Motor_A_white, HIGH); // Ein
    digitalWrite(Motor_A_blue, HIGH);  // Links
  } else if (turn == 2) {
    digitalWrite(Motor_A_white, HIGH); // Ein
    digitalWrite(Motor_A_blue, LOW);   // Rechts
  }
  
  // Antrieb (Motor B)
  if(direction == 0) {
    digitalWrite(Motor_B_green, LOW);   // Aus
  } else if(direction == 1) {
    digitalWrite(Motor_B_green, HIGH);  // Ein
    digitalWrite(Motor_B_yellow, LOW);  // Vorwärts
  } else if (direction == 2) {
    digitalWrite(Motor_B_green, HIGH);  // Ein
    digitalWrite(Motor_B_yellow, HIGH); // Rückwärts
  }
  
  delay(driveTime);  // Standard: 10ms
}
```

### Stromversorgung

**Spannungsverteilung:**
```
7.4V Battery
    │
    ├─→ L298N Motor Driver (5-12V)
    │       └─→ DC Motors (6V nominal)
    │
    └─→ LM2596 Buck Converter
            └─→ 3.3V für ESP8266 & VL53L0X
```

**Stromverbrauch:**
- ESP8266: ~80mA (WiFi aktiv)
- VL53L0X: ~19mA
- Motor A: ~200mA (Last)
- Motor B: ~200mA (Last)
- **Gesamt**: ~500mA (typisch)

**Batterielaufzeit** (2000mAh):
- Kontinuierlicher Betrieb: ~4 Stunden
- Intermittierender Betrieb: ~6-8 Stunden

---

## Entwickler-Guide

### Entwicklungsumgebung einrichten

#### Flutter Setup

```bash
# Flutter SDK installieren
# https://docs.flutter.dev/get-started/install

# Projekt klonen
git clone https://github.com/your-repo/TINF24CS2_R.E.D.git
cd TINF24CS2_R.E.D/Flutter

# Dependencies installieren
flutter pub get

# Verfügbare Geräte anzeigen
flutter devices

# App starten (Web)
flutter run -d chrome

# App starten (Desktop)
flutter run -d windows  # oder macos, linux

# Build für Production
flutter build web
```

#### ESP8266 Setup mit PlatformIO

```bash
# PlatformIO installieren
# https://platformio.org/install

# In CPP-Verzeichnis wechseln
cd CPP

# Projekt initialisieren (bereits vorhanden)
# pio init --board esp12e

# Dependencies installieren
pio lib install

# Kompilieren
pio run

# Hochladen
pio run --target upload

# Serial Monitor
pio device monitor --baud 115200
```

#### Arduino IDE Setup

1. Arduino IDE installieren
2. ESP8266 Board Package hinzufügen:
   - File → Preferences
   - Additional Board Manager URLs: `http://arduino.esp8266.com/stable/package_esp8266com_index.json`
3. Tools → Board → Boards Manager → "esp8266" installieren
4. Tools → Board → ESP8266 Boards → "NodeMCU 1.0 (ESP-12E Module)"
5. Libraries installieren:
   - Sketch → Include Library → Manage Libraries
   - Suchen und installieren: "WebSockets", "VL53L0X"

### Code-Struktur

#### Flutter App

```
Flutter/
├── lib/
│   └── main.dart              # Hauptdatei (1559 Zeilen)
├── assets/
│   └── images/                # Bilder (Ferrari, Checkerflag)
├── web/
│   ├── index.html             # Web-Entry-Point
│   └── manifest.json          # PWA-Manifest
├── pubspec.yaml               # Dependencies
└── README.md
```

#### ESP8266 Firmware

```
CPP/
├── main.cpp                   # Hauptprogramm (183 Zeilen)
├── plattform.ini              # PlatformIO-Konfiguration
└── lib/
    ├── VL53L0X/               # ToF-Sensor Library
    └── BMI160/                # IMU Library (optional)
```

### Coding Standards

#### Dart (Flutter)

```dart
// Klassen: PascalCase
class ConnectionManager { }

// Methoden/Variablen: camelCase
void sendCommand(String cmd) { }
int currentSpeed = 0;

// Private: Unterstrich-Präfix
void _connect() { }
Timer? _reconnectTimer;

// Konstanten: lowerCamelCase oder UPPER_CASE
const int maxSpeed = 30;
const String WS_URL = "ws://10.10.10.10:81";

// Kommentare
/// Dokumentations-Kommentar für öffentliche API
// Inline-Kommentar für Implementierungsdetails

// Async/Await bevorzugen
Future<void> loadData() async {
  final data = await fetchData();
  processData(data);
}
```

#### C++ (ESP8266)

```cpp
// Funktionen: snake_case
void handle_ws_event() { }
int get_distance() { }

// Konstanten: UPPER_CASE
#define WIFI_SSID "R.E.D"
const int MOTOR_A_PIN = D1;

// Globale Variablen: camelCase
int currentDirection = 0;
bool isConnected = false;

// Kommentare
// Einzeilige Kommentare
/* Mehrzeilige
   Kommentare */

// Pointer-Deklaration
int* ptr;  // Stern beim Typ
int *ptr;  // Oder beim Namen (konsistent bleiben)
```

### Git Workflow

```bash
# Feature-Branch erstellen
git checkout -b feature/neue-funktion

# Änderungen committen
git add .
git commit -m "feat: Neue Funktion hinzugefügt"


# Push zu Remote
git push origin feature/neue-funktion

# Pull Request erstellen
# Auf GitHub: Compare & Pull Request

# Nach Review: Merge in main
git checkout main
git pull origin main
git merge feature/neue-funktion
git push origin main
```

---

## Testing-Strategie

### Unit Tests (Flutter)

```dart
// test/connection_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:red/main.dart';

void main() {
  group('ConnectionManager', () {
    test('Singleton instance', () {
      final instance1 = ConnectionManager.instance;
      final instance2 = ConnectionManager.instance;
      expect(instance1, same(instance2));
    });
    
    test('Initial state is disconnected', () {
      final cm = ConnectionManager.instance;
      expect(cm.connected.value, false);
    });
    
    test('Reconnect delay increases exponentially', () {
      final cm = ConnectionManager.instance;
      expect(cm._reconnectSeconds, 2);
      cm._scheduleReconnect();
      expect(cm._reconnectSeconds, 4);
      cm._scheduleReconnect();
      expect(cm._reconnectSeconds, 8);
    });
  });
}
```

### Integration Tests

```dart
// integration_test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:red/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('Complete user flow', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();
    
    // Welcome Page
    expect(find.text('R.E.D'), findsOneWidget);
    
    // Navigate to Mode Selection
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    
    // Select Driving Mode
    await tester.tap(find.text('Driving Mode'));
    await tester.pumpAndSettle();
    
    // Verify Driving Page loaded
    expect(find.text('Speed'), findsOneWidget);
  });
}
```

### Hardware Tests (ESP8266)

```cpp
// Test-Funktionen in main.cpp
void test_motors() {
  Serial.println("Testing motors...");
  
  // Test Motor A (Steering)
  Serial.println("Motor A: Left");
  drive(0, 1);
  delay(1000);
  
  Serial.println("Motor A: Right");
  drive(0, 2);
  delay(1000);
  
  Serial.println("Motor A: Stop");
  drive(0, 0);
  delay(1000);
  
  // Test Motor B (Drive)
  Serial.println("Motor B: Forward");
  drive(1, 0);
  delay(1000);
  
  Serial.println("Motor B: Backward");
  drive(2, 0);
  delay(1000);
  
  Serial.println("Motor B: Stop");
  drive(0, 0);
  
  Serial.println("Motor test complete!");
}

void test_sensor() {
  Serial.println("Testing VL53L0X sensor...");
  
  for(int i = 0; i < 10; i++) {
    int dist = get_distance();
    Serial.print("Distance: ");
    Serial.print(dist);
    Serial.println(" mm");
    delay(100);
  }
  
  Serial.println("Sensor test complete!");
}

// In setup() aufrufen:
// test_motors();
// test_sensor();
```

### Test-Coverage-Ziele

| Komponente | Ziel | Aktuell |
|------------|------|---------|
| ConnectionManager | 100% | 95% |
| Input Handler | 90% | 85% |
| Physics Engine | 90% | 80% |
| UI Components | 80% | 75% |
| **Gesamt** | **85%** | **80%** |

---

## Performance-Optimierung

### Flutter App

#### 1. Widget-Rebuilds minimieren

```dart
// Schlecht: Gesamte Page wird neu gebaut
class DrivingPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Speed: $speed'),  // Rebuild bei jeder Änderung
          Text('RPM: $rpm'),
        ],
      ),
    );
  }
}

// Gut: Nur betroffene Widgets rebuilden
class DrivingPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ValueListenableBuilder<double>(
            valueListenable: speedNotifier,
            builder: (context, speed, child) {
              return Text('Speed: $speed');
            },
          ),
          // RPM wird nicht neu gebaut wenn nur Speed ändert
          Text('RPM: $rpm'),
        ],
      ),
    );
  }
}
```

#### 2. Timer-Optimierung

```dart
// Physics Update mit fester Rate
Timer.periodic(Duration(milliseconds: 50), (timer) {
  _updatePhysics();  // 20 FPS
});

// Debouncing für häufige Events
Timer? _debounceTimer;
void onInputChange() {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(Duration(milliseconds: 100), () {
    sendCommand();
  });
}
```

#### 3. WebSocket-Optimierung

```dart
// Command-Batching
List<String> _commandQueue = [];
Timer? _batchTimer;

void sendCommand(String cmd) {
  _commandQueue.add(cmd);
  
  _batchTimer?.cancel();
  _batchTimer = Timer(Duration(milliseconds: 50), () {
    final batch = _commandQueue.join(',');
    _channel.sink.add(batch);
    _commandQueue.clear();
  });
}
```

### ESP8266 Firmware

#### 1. Loop-Optimierung

```cpp
void loop() {
  ws.loop();  // WebSocket-Handling
  
  // Nur in autonomem Modus Sensor lesen
  if (currentMode) {
    static unsigned long lastSensorRead = 0;
    unsigned long now = millis();
    
    // Sensor nur alle 100ms lesen (10Hz)
    if (now - lastSensorRead >= 100) {
      int dist = get_distance();
      set_autoDrive(dist);
      lastSensorRead = now;
    }
  } else {
    // Manuelle Steuerung
    drive(currentDirection, currentTurn);
  }
  
  yield();  // Watchdog Timer zurücksetzen
}
```

#### 2. Sensor-Optimierung

```cpp
// High-Speed-Modus für schnellere Messungen
sensor_init(true, true);  // long_range=true, high_speed=true

// Timing Budget reduzieren
sensor.setMeasurementTimingBudget(20000);  // 20ms statt 200ms
```

#### 3. WiFi-Optimierung

```cpp
void setup() {
  // WiFi Power Management deaktivieren
  WiFi.setSleepMode(WIFI_NONE_SLEEP);
  
  // Statische IP für schnellere Verbindung
  WiFi.softAPConfig(
    IPAddress(10,10,10,10),
    IPAddress(10,10,10,10),
    IPAddress(255,255,255,0)
  );
}
```

### Performance-Metriken

| Metrik | Ziel | Aktuell | Optimiert |
|--------|------|---------|-----------|
| WebSocket Latenz | <100ms | 80ms | 50ms |
| UI Frame Rate | 60 FPS | 60 FPS | 60 FPS |
| Physics Update | 20 FPS | 20 FPS | 20 FPS |
| Sensor Read Rate | 10 Hz | 5 Hz | 10 Hz |
| Memory Usage (ESP) | <50KB | 45KB | 42KB |
| Battery Life | >4h | 4h | 5h |

---

## Troubleshooting

### Häufige Probleme und Lösungen

#### Problem: App kann nicht mit ESP8266 verbinden

**Symptome:**
- Roter Verbindungsstatus
- "Reconnecting..." Meldung
- Keine Reaktion auf Befehle

**Lösungen:**

1. **WiFi-Verbindung prüfen:**
```bash
# Auf Computer/Smartphone
# Prüfen ob mit "R.E.D" verbunden
# IP sollte 10.10.10.x sein

# Ping-Test
ping 10.10.10.10
```

2. **ESP8266 Serial Monitor:**
```cpp
// In setup() aktivieren:
Serial.begin(115200);
Serial.println("ESP8266 server is online");
Serial.printf("WiFi AP SSID: %s, IP: %s\n", 
  WIFI_SSID, WiFi.softAPIP().toString().c_str());
```

3. **WebSocket-Port prüfen:**
```bash
# Mit netcat testen
nc -v 10.10.10.10 81
```

4. **Firewall deaktivieren** (temporär für Test)

---

#### Problem: Motoren reagieren nicht

**Symptome:**
- Befehle werden gesendet
- Keine Bewegung
- Keine Geräusche

**Lösungen:**

1. **Stromversorgung prüfen:**
```cpp
// Batteriespannung messen
// Sollte >6.5V sein
// Bei <6V: Batterie laden
```

2. **Pin-Verbindungen prüfen:**
```cpp
// Test-Code in setup():
void test_pins() {
  pinMode(Motor_A_white, OUTPUT);
  digitalWrite(Motor_A_white, HIGH);
  delay(1000);
  digitalWrite(Motor_A_white, LOW);
  // Sollte LED/Motor aktivieren
}
```

3. **Motor-Treiber prüfen:**
- L298N Enable-Jumper gesetzt?
- Korrekte Spannungsversorgung?
- Überhitzung? (Kühlkörper heiß?)

---

#### Problem: Sensor liefert falsche Werte

**Symptome:**
- Distance = -1 (Timeout)
- Unrealistische Werte
- Inkonsistente Messungen

**Lösungen:**

1. **I2C-Verbindung prüfen:**
```cpp
// I2C-Scanner
void scan_i2c() {
  Wire.begin(SDA_green, SCL_white);
  Serial.println("Scanning I2C...");
  
  for(byte addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    if(Wire.endTransmission() == 0) {
      Serial.print("Found device at 0x");
      Serial.println(addr, HEX);
    }
  }
}
// VL53L0X sollte bei 0x29 sein
```

2. **Sensor-Kalibrierung:**
```cpp
// Längere Initialisierungszeit
sensor_init(true, false);  // High accuracy mode
delay(2000);  // Sensor stabilisieren lassen
```

3. **Umgebungsbedingungen:**
- Zu viel Umgebungslicht? → Sensor abschirmen
- Reflektierende Oberfläche? → Matte Objekte verwenden
- Zu nah/fern? → 50-2000mm Bereich einhalten

---

#### Problem: Hohe Latenz / Verzögerung

**Symptome:**
- Befehle kommen verzögert an
- Ruckelige Bewegungen
- >200ms Latenz

**Lösungen:**

1. **WiFi-Signalstärke verbessern:**
```cpp
// Höhere TX-Power
WiFi.setOutputPower(20.5);  // Max: 20.5 dBm
```

2. **Command-Queue leeren:**
```dart
// In ConnectionManager
void clearQueue() {
  _commandQueue.clear();
}
```

3. **Netzwerk-Interferenzen reduzieren:**
- Andere WiFi-Geräte ausschalten
- 2.4GHz-Kanal wechseln
- Näher an ESP8266 gehen

---

#### Problem: ESP8266 stürzt ab / Reboot-Loop

**Symptome:**
- Ständige Neustarts
- Watchdog Timer Reset
- Keine stabile Verbindung

**Lösungen:**

1. **Watchdog Timer zurücksetzen:**
```cpp
void loop() {
  // Am Ende jeder Loop-Iteration
  yield();  // oder delay(1);
}
```

2. **Stack Overflow vermeiden:**
```cpp
// Große Arrays auf Heap statt Stack
char* buffer = (char*)malloc(1024);
// ... verwenden ...
free(buffer);
```

3. **Stromversorgung stabilisieren:**
- Kondensator (100µF) parallel zu ESP8266
- Separate Stromversorgung für Motoren
- Spannungsregler mit ausreichend Strom (>500mA)

---

#### Problem: Flutter App stürzt ab

**Symptome:**
- App schließt unerwartet
- Fehlermeldungen in Console
- Weiße Bildschirme

**Lösungen:**

1. **Null-Safety prüfen:**
```dart
// Null-Checks hinzufügen
if (_channel != null) {
  _channel!.sink.add(cmd);
}
```

2. **Exception Handling:**
```dart
try {
  await _connect();
} catch (e) {
  print('Connection error: $e');
  _scheduleReconnect();
}
```

3. **Memory Leaks vermeiden:**
```dart
@override
void dispose() {
  _timer?.cancel();
  _channel?.sink.close();
  _focusNode.dispose();
  super.dispose();
}
```

---

### Debug-Tools

#### Flutter DevTools

```bash
# DevTools starten
flutter pub global activate devtools
flutter pub global run devtools

# App im Debug-Modus starten
flutter run --debug
```

**Nützliche Features:**
- Widget Inspector: UI-Hierarchie visualisieren
- Performance: Frame-Rendering analysieren
- Network: WebSocket-Traffic überwachen
- Logging: Console-Ausgaben filtern

#### ESP8266 Serial Monitor

```cpp
// Debug-Ausgaben aktivieren
#define DEBUGGING true

if(DEBUGGING) {
  Serial.print("Distance: ");
  Serial.println(dist);
}
```

```bash
# PlatformIO Serial Monitor
pio device monitor --baud 115200

# Arduino IDE
Tools → Serial Monitor → 115200 baud
```

#### Wireshark für WebSocket-Analyse

```bash
# Filter für WebSocket-Traffic
tcp.port == 81 && websocket

# Oder spezifischer
ip.addr == 10.10.10.10 && tcp.port == 81
```

---

**Letzte Aktualisierung**: 2026-05-26