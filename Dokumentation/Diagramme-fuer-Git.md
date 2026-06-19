# R.E.D. Projekt - Diagramme (Git-optimiert)

> **Hinweis**: Diese Datei ist für die Anzeige auf GitHub/GitLab optimiert.
> Alle Diagramme sind als ASCII-Art und Markdown-Tabellen dargestellt.

---

## 📊 Inhaltsverzeichnis

- [1. Systemarchitektur](#1-systemarchitektur)
- [2. Komponenten-Übersicht](#2-komponenten-übersicht)
- [3. Deployment](#3-deployment)
- [4. Sequenzdiagramme](#4-sequenzdiagramme)
- [5. Klassenstruktur](#5-klassenstruktur)
- [6. Use-Cases](#6-use-cases)
- [7. Zustandsdiagramme](#7-zustandsdiagramme)

---

## 1. Systemarchitektur

### 1.1 Schichtenmodell

```
┌─────────────────────────────────────────────────────────────┐
│                   CLIENT LAYER (Flutter)                     │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  UI Components                                       │    │
│  │  • Welcome Page                                      │    │
│  │  • Mode Selection Page                              │    │
│  │  • Driving Page                                     │    │
│  │  • Autonomous Driving Page                          │    │
│  │  • Drawing Page                                     │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Business Logic                                      │    │
│  │  • ConnectionManager (Singleton)                    │    │
│  │  • Physics Engine (20 FPS)                          │    │
│  │  • Input Handler (Keyboard + Touch)                 │    │
│  │  • State Manager                                    │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                            ↕ WebSocket/HTTP
┌─────────────────────────────────────────────────────────────┐
│              COMMUNICATION LAYER                             │
│                                                               │
│  WebSocket (ws://10.10.10.10:81)  ←→  HTTP Fallback (:80)  │
│                                                               │
│  WiFi Network: 10.10.10.0/24 | SSID: R.E.D                  │
└─────────────────────────────────────────────────────────────┘
                            ↕ Commands
┌─────────────────────────────────────────────────────────────┐
│                SERVER LAYER (ESP8266)                        │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  ESP8266 Components                                  │    │
│  │  • WebSocket Server                                  │    │
│  │  • Command Parser                                    │    │
│  │  • Motor Controller                                  │    │
│  │  • Sensor Manager                                    │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                            ↕ GPIO/I2C
┌─────────────────────────────────────────────────────────────┐
│                   HARDWARE LAYER                             │
│                                                               │
│  Motor A     Motor B      VL53L0X       Power Supply        │
│  (Steering)  (Drive)      (ToF Sensor)  (7.4V Battery)      │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Datenfluss

| Schritt | Von | Nach | Protokoll | Latenz |
|---------|-----|------|-----------|--------|
| 1 | User Input | Flutter UI | Event | <1ms |
| 2 | Flutter UI | Physics Engine | Function Call | <1ms |
| 3 | Physics Engine | ConnectionManager | Function Call | <1ms |
| 4 | ConnectionManager | ESP8266 | WebSocket | 50-100ms |
| 5 | ESP8266 | Motors | GPIO | <1ms |
| 6 | Sensor | ESP8266 | I2C | ~20ms |
| 7 | ESP8266 | Flutter UI | WebSocket | 50-100ms |

**Gesamt-Latenz**: ~100-200ms (User Input → Motor Reaktion)

---

## 2. Komponenten-Übersicht

### 2.1 Flutter Application

```
Flutter App
│
├── 📱 UI Layer
│   ├── WelcomePage
│   ├── ModeSelectionPage
│   ├── DrivingPage ⭐
│   ├── AutonomousDrivingPage
│   └── DrawingPage
│
├── 🧠 Business Logic
│   ├── ConnectionManager (Singleton)
│   ├── PhysicsEngine
│   ├── InputHandler
│   └── RouteManager
│
└── 💾 Data Layer
    ├── StateManager
    └── CommandQueue
```

### 2.2 ESP8266 Firmware

```
ESP8266 Firmware
│
├── 🌐 Network Layer
│   ├── WiFiManager
│   └── WebSocketServer
│
├── 🎮 Control Layer
│   ├── CommandParser
│   ├── MotorController
│   └── SensorController
│
└── 🔧 Hardware Abstraction
    ├── MotorDriver
    ├── I2CDriver
    └── GPIODriver
```

### 2.3 Komponenten-Interaktion

| Komponente | Abhängigkeiten | Schnittstellen |
|------------|----------------|----------------|
| **DrivingPage** | ConnectionManager, PhysicsEngine, InputHandler | Widget, State |
| **ConnectionManager** | WebSocketChannel, Timer | Singleton, send() |
| **PhysicsEngine** | Timer (50ms) | _updatePhysics() |
| **InputHandler** | KeyboardListener, GestureDetector | Event Callbacks |
| **WebSocketServer** | WiFi, WebSockets Library | handleWSEvent() |
| **MotorController** | GPIO Pins | drive(direction, turn) |
| **SensorController** | I2C, VL53L0X | get_distance() |

---

## 3. Deployment

### 3.1 Physische Architektur

```
┌──────────────────────────────────────────────────────────┐
│  USER DEVICE (Laptop/Smartphone/Tablet)                  │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Web Browser (Chrome/Firefox/Safari)               │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │  Flutter Web App                             │  │  │
│  │  │  • main.dart (1559 lines)                    │  │  │
│  │  │  • 13 Classes                                │  │  │
│  │  │  • Material Design 3                         │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
                        ↓ WiFi (2.4GHz)
┌──────────────────────────────────────────────────────────┐
│  WIFI ACCESS POINT                                        │
│  • SSID: R.E.D                                           │
│  • IP: 10.10.10.10                                       │
│  • Subnet: 255.255.255.0                                 │
│  • Security: Open (Demo) / WPA2 (Production)            │
└──────────────────────────────────────────────────────────┘
                        ↓ WebSocket (Port 81)
┌──────────────────────────────────────────────────────────┐
│  ROBOT CAR                                                │
│  ┌────────────────────────────────────────────────────┐  │
│  │  ESP8266 NodeMCU                                   │  │
│  │  • CPU: 80MHz                                      │  │
│  │  • RAM: 80KB                                       │  │
│  │  • Flash: 4MB                                      │  │
│  │  • Firmware: main.cpp (183 lines)                 │  │
│  └────────────────────────────────────────────────────┘  │
│                        ↓                                  │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Motor Controller (L298N H-Bridge)                 │  │
│  │  • Motor A: Steering (D1, D2)                      │  │
│  │  • Motor B: Drive (D3, D4)                         │  │
│  │  • Voltage: 5-12V                                  │  │
│  └────────────────────────────────────────────────────┘  │
│                        ↓                                  │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Sensors                                           │  │
│  │  • VL53L0X ToF (D5=SCL, D6=SDA)                    │  │
│  │  • Range: 50-2000mm                                │  │
│  │  • Accuracy: ±3%                                   │  │
│  └────────────────────────────────────────────────────┘  │
│                        ↓                                  │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Power Supply                                      │  │
│  │  • Battery: 7.4V Li-Ion (2x 18650)                │  │
│  │  • Regulator: LM2596 (3.3V output)                │  │
│  │  • Capacity: 2000mAh (~4h runtime)                │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

### 3.2 Pin-Belegung ESP8266

| GPIO | Pin | Funktion | Verbindung | Beschreibung |
|------|-----|----------|------------|--------------|
| GPIO5 | D1 | OUTPUT | Motor A Enable | Lenkung Ein/Aus |
| GPIO4 | D2 | OUTPUT | Motor A Direction | Lenkung Links/Rechts |
| GPIO0 | D3 | OUTPUT | Motor B Enable | Antrieb Ein/Aus |
| GPIO2 | D4 | OUTPUT | Motor B Direction | Antrieb Vor/Zurück |
| GPIO14 | D5 | I2C SCL | VL53L0X SCL | Sensor Clock |
| GPIO12 | D6 | I2C SDA | VL53L0X SDA | Sensor Data |
| 3.3V | 3V3 | POWER | VL53L0X VIN | Sensor Stromversorgung |
| GND | GND | GROUND | Common Ground | Gemeinsame Masse |

---

## 4. Sequenzdiagramme

### 4.1 WebSocket-Verbindungsaufbau

```
User          Flutter App    ConnectionManager    WebSocket    ESP8266
 │                │                  │                │            │
 │   App öffnen   │                  │                │            │
 ├───────────────>│                  │                │            │
 │                │   initialize()   │                │            │
 │                ├─────────────────>│                │            │
 │                │                  │   connect()    │            │
 │                │                  ├───────────────>│            │
 │                │                  │                │ Handshake  │
 │                │                  │                ├───────────>│
 │                │                  │                │  101 OK    │
 │                │                  │                │<───────────┤
 │                │                  │ onConnected()  │            │
 │                │                  │<───────────────┤            │
 │                │  Status: Grün    │                │            │
 │                │<─────────────────┤                │            │
 │                │                  │                │            │
 │   Taste W      │                  │                │            │
 ├───────────────>│                  │                │            │
 │                │ send("forward")  │                │            │
 │                ├─────────────────>│                │            │
 │                │                  │   "forward"    │            │
 │                │                  ├───────────────>│            │
 │                │                  │                │ drive(1,0) │
 │                │                  │                ├───────────>│
 │                │                  │                │    ACK     │
 │                │                  │                │<───────────┤
 │                │                  │      ACK       │            │
 │                │                  │<───────────────┤            │
 │                │   Confirmed      │                │            │
 │                │<─────────────────┤                │            │
```

### 4.2 Autonomes Fahren

```
User    AutonomousPage    ESP8266    VL53L0X    Motors
 │            │              │          │          │
 │   Start    │              │          │          │
 ├───────────>│              │          │          │
 │            │ send("auto") │          │          │
 │            ├─────────────>│          │          │
 │            │              │  enable  │          │
 │            │              ├─────────>│          │
 │            │              │          │          │
 │            │              │ ╔════════╧════════╗ │
 │            │              │ ║  Loop Start     ║ │
 │            │              │ ╚════════╤════════╝ │
 │            │              │          │          │
 │            │              │ measure  │          │
 │            │              ├─────────>│          │
 │            │              │  450mm   │          │
 │            │              │<─────────┤          │
 │            │              │          │          │
 │            │              │ if dist >= 250mm    │
 │            │              ├────────────────────>│
 │            │              │          │  forward │
 │            │              │          │          │
 │            │ sensor_data  │          │          │
 │            │<─────────────┤          │          │
 │   update   │              │          │          │
 │<───────────┤              │          │          │
 │            │              │          │          │
 │            │              │ measure  │          │
 │            │              ├─────────>│          │
 │            │              │  150mm   │          │
 │            │              │<─────────┤          │
 │            │              │          │          │
 │            │              │ if dist < 250mm     │
 │            │              ├────────────────────>│
 │            │              │          │ backward │
 │            │              │          │   turn   │
 │            │              │          │          │
 │            │              │ ╔════════╧════════╗ │
 │            │              │ ║  Loop End       ║ │
 │            │              │ ╚════════╤════════╝ │
 │            │              │          │          │
 │   Stop     │              │          │          │
 ├───────────>│              │          │          │
 │            │send("autoStop")         │          │
 │            ├─────────────>│          │          │
 │            │              │ disable  │          │
 │            │              ├─────────>│          │
 │            │              │          │   stop   │
 │            │              ├────────────────────>│
```

**Autonome Logik**:
- **dist >= 250mm**: Vorwärts fahren
- **50mm < dist < 250mm**: Rückwärts + Drehen
- **dist <= 50mm**: Stoppen (zu nah)

---

## 5. Klassenstruktur

### 5.1 ConnectionManager (Singleton)

```dart
class ConnectionManager {
  // Singleton Instance
  static final ConnectionManager instance = ConnectionManager._internal();
  
  // State
  ValueNotifier<bool> connected = ValueNotifier(false);
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  int _reconnectSeconds = 2;
  
  // Configuration
  String wsUrl = "ws://10.10.10.10:81";
  String wsFallback = "http://10.10.10.10";
  
  // Methods
  void connectNow() { /* ... */ }
  void send(String cmd) { /* ... */ }
  void dispose() { /* ... */ }
  void _connect() { /* ... */ }
  void _scheduleReconnect() { /* ... */ }
}
```

**Verwendung**:
```dart
final cm = ConnectionManager.instance;
cm.send("forward");
```

### 5.2 DrivingPage State

| Attribut | Typ | Beschreibung |
|----------|-----|--------------|
| `speed` | double | Aktuelle Geschwindigkeit (-30 bis +30 km/h) |
| `throttle` | double | Gas-Pedal (0.0 bis 1.0) |
| `brake` | double | Bremse (0.0 bis 1.0) |
| `steering` | double | Lenkung (-1.0 bis +1.0) |
| `accelerating` | bool | Beschleunigt gerade? |
| `braking` | bool | Bremst gerade? |
| `steerLeft` | bool | Lenkt nach links? |
| `steerRight` | bool | Lenkt nach rechts? |
| `reversing` | bool | Rückwärtsgang aktiv? |
| `_timer` | Timer? | Physics Update Timer (50ms) |
| `_focusNode` | FocusNode | Keyboard Focus |
| `_pressedKeys` | Map | Gedrückte Tasten |

**Methoden**:
- `_updatePhysics()`: Physik-Berechnung (20 FPS)
- `_handleKeyboardEvent()`: Tastatur-Eingabe
- `_inputAccelerate()`: Gas geben
- `_inputBrake()`: Bremsen
- `_inputSteerLeft()`: Links lenken
- `_inputSteerRight()`: Rechts lenken

### 5.3 Klassenbeziehungen

```
MyApp
  └── WelcomePage
       └── ModeSelectionPage
            ├── DrivingPage
            │    ├── uses ConnectionManager
            │    ├── uses PhysicsEngine
            │    └── uses InputHandler
            │
            ├── AutonomousDrivingPage
            │    └── uses ConnectionManager
            │
            └── DrawingPage
                 ├── uses ConnectionManager
                 └── uses _RoutePainter
```

---

## 6. Use-Cases

### 6.1 Übersicht

| ID | Use-Case | Akteur | Priorität | Status |
|----|----------|--------|-----------|--------|
| UC1 | Mit Auto verbinden | Benutzer | Hoch | ✅ |
| UC2 | Auto manuell steuern | Benutzer | Hoch | ✅ |
| UC3 | Vorwärts fahren | Benutzer | Hoch | ✅ |
| UC4 | Rückwärts fahren | Benutzer | Hoch | ✅ |
| UC5 | Links lenken | Benutzer | Hoch | ✅ |
| UC6 | Rechts lenken | Benutzer | Hoch | ✅ |
| UC7 | Notbremse aktivieren | Benutzer | Hoch | ✅ |
| UC8 | Autonomen Modus starten | Benutzer | Mittel | ✅ |
| UC9 | Hindernisse erkennen | System | Mittel | ✅ |
| UC10 | Automatisch ausweichen | System | Mittel | ✅ |
| UC11 | Route zeichnen | Benutzer | Niedrig | ✅ |
| UC12 | Route abfahren | System | Niedrig | ✅ |
| UC13 | Sensordaten anzeigen | System | Mittel | ✅ |
| UC14 | Verbindungsstatus anzeigen | System | Hoch | ✅ |
| UC15 | Automatisch wiederherstellen | System | Hoch | ✅ |

### 6.2 UC2: Auto manuell steuern (Detailliert)

**Beschreibung**: Benutzer steuert das Auto manuell über Tastatur oder Touch

**Akteure**: Benutzer

**Vorbedingungen**:
- ✅ Verbindung zum Auto ist hergestellt
- ✅ Driving Mode ist aktiv
- ✅ Batterie ist geladen

**Hauptablauf**:
1. Benutzer wählt "Driving Mode"
2. App zeigt Steuerungsoberfläche
3. Benutzer drückt Taste (W/A/S/D) oder Touch-Button
4. App sendet entsprechenden Befehl
5. ESP8266 empfängt und führt Befehl aus
6. UI zeigt visuelles Feedback

**Nachbedingungen**:
- ✅ Auto bewegt sich entsprechend der Eingabe
- ✅ Geschwindigkeit und Lenkung werden aktualisiert
- ✅ UI zeigt aktuellen Status

**Alternativabläufe**:
- **3a**: Mehrere Tasten gleichzeitig → Kombinierte Befehle
- **4a**: Verbindung unterbrochen → Befehl wird in Queue gespeichert
- **5a**: Motor-Fehler → Fehler wird angezeigt

**Eingaben**:
- Tastatur: W, A, S, D, Pfeiltasten, Leertaste
- Touch: Virtual Buttons
- Maus: Click & Hold

**Ausgaben**:
- Visuelles Feedback (Glow-Effekt)
- Geschwindigkeitsanzeige
- RPM-Anzeige
- Gang-Anzeige (D/R/N)

---

## 7. Zustandsdiagramme

### 7.1 Verbindungsstatus

```
     ┌─────────────┐
     │ Disconnected│ ◄─────────────┐
     │ (Red LED)   │               │
     └──────┬──────┘               │
            │ _connect()           │
            ▼                      │
     ┌─────────────┐               │
     │ Connecting  │               │
     │ (Orange LED)│               │
     └──────┬──────┘               │
            │ WebSocket OK         │
            ▼                      │
     ┌─────────────┐               │
     │  Connected  │               │
     │ (Green LED) │               │
     └──────┬──────┘               │
            │ Connection Lost      │
            ▼                      │
     ┌─────────────┐               │
     │ Reconnecting│───────────────┘
     │ (Orange LED)│ Timer Expired
     └─────────────┘
```

**Reconnect-Strategie**: Exponential Backoff
- 1. Versuch: 2 Sekunden
- 2. Versuch: 4 Sekunden
- 3. Versuch: 8 Sekunden
- 4. Versuch: 16 Sekunden
- 5+ Versuch: 30 Sekunden (Maximum)

### 7.2 Fahrzeugzustand

```
     ┌─────────────┐
     │   Stopped   │ ◄─────────────────────┐
     │ speed = 0   │                       │
     │ gear = N    │                       │
     └──────┬──────┘                       │
            │ W pressed                    │
            ▼                              │
     ┌─────────────┐                       │
     │Accelerating │                       │
     │ speed > 0   │                       │
     │ gear = D    │                       │
     └──────┬──────┘                       │
            │ W released                   │
            ▼                              │
     ┌─────────────┐                       │
     │  Cruising   │                       │
     │ friction    │                       │
     └──────┬──────┘                       │
            │ S pressed                    │
            ▼                              │
     ┌─────────────┐                       │
     │   Braking   │                       │
     │ brake > 0   │                       │
     └──────┬──────┘                       │
            │ speed = 0                    │
            ├──────────────────────────────┘
            │ S held (700ms)
            ▼
     ┌─────────────┐
     │  Reversing  │
     │ speed < 0   │
     │ gear = R    │
     └──────┬──────┘
            │ S released
            └──────────────────────────────┐
                                           │
     ┌─────────────┐                       │
     │ Emergency   │ ◄─────────────────────┘
     │    Stop     │   Space pressed
     │ (any state) │
     └─────────────┘
```

**Physik-Parameter**:
| Parameter | Wert | Einheit |
|-----------|------|---------|
| Max Speed Forward | +30 | km/h |
| Max Speed Reverse | -30 | km/h |
| Acceleration | 0.5 | per tick |
| Friction | 0.3 | per tick |
| Update Rate | 20 | FPS |
| Reverse Delay | 700 | ms |

### 7.3 Autonomer Modus

```
     ┌─────────────┐
     │    Idle     │
     │ currentMode │
     │     = 0     │
     └──────┬──────┘
            │ "Start Autonomous"
            ▼
     ┌─────────────────────────────────────┐
     │           Active                     │
     │        currentMode = 1               │
     │                                      │
     │  ┌──────────┐                        │
     │  │Measuring │                        │
     │  │  Sensor  │                        │
     │  └────┬─────┘                        │
     │       │                              │
     │       ├─ dist >= 250mm ──> Forward  │
     │       │                              │
     │       ├─ dist < 250mm ───> Avoiding │
     │       │                    (Backward │
     │       │                     + Turn)  │
     │       │                              │
     │       └─ Timeout ────────> Error    │
     │                                      │
     └──────────────┬───────────────────────┘
                    │ "Emergency Stop"
                    ▼
     ┌─────────────┐
     │    Idle     │
     └─────────────┘
```

**Sensor-Schwellwerte**:
| Bereich | Distanz | Aktion |
|---------|---------|--------|
| Zu nah | < 50mm | Stoppen |
| Hindernis | 50-250mm | Rückwärts + Drehen |
| Frei | >= 250mm | Vorwärts |
| Fehler | -1 | Fehler anzeigen |

---

## 8. Performance-Metriken

### 8.1 Latenz-Analyse

| Komponente | Latenz | Ziel | Status |
|------------|--------|------|--------|
| User Input → UI | <1ms | <5ms | ✅ |
| UI → Physics Engine | <1ms | <5ms | ✅ |
| Physics Engine Update | 50ms | 50ms | ✅ |
| ConnectionManager → WebSocket | 5-10ms | <20ms | ✅ |
| WebSocket → ESP8266 | 50-100ms | <100ms | ✅ |
| ESP8266 → Motors | <1ms | <5ms | ✅ |
| **Gesamt (User → Motor)** | **~100ms** | **<150ms** | ✅ |

### 8.2 Durchsatz

| Metrik | Wert | Einheit |
|--------|------|---------|
| UI Frame Rate | 60 | FPS |
| Physics Update Rate | 20 | FPS |
| WebSocket Messages/sec | 20 | msg/s |
| Sensor Read Rate | 10 | Hz |
| Command Queue Size | 5 | commands |
| Max Queue Size | 10 | commands |

### 8.3 Ressourcen-Nutzung

#### Flutter App
| Ressource | Verwendung | Maximum |
|-----------|------------|---------|
| Memory | ~50MB | 100MB |
| CPU | 5-10% | 20% |
| Network | 1-5 KB/s | 10 KB/s |

#### ESP8266
| Ressource | Verwendung | Maximum |
|-----------|------------|---------|
| Flash | 45KB | 4MB |
| RAM | 40KB | 80KB |
| CPU | 60% | 100% |
| Power | 500mA | 1A |

---

## 9. Zusammenfassung

### 9.1 Projekt-Statistiken

| Kategorie | Anzahl |
|-----------|--------|
| **Code** | |
| Flutter Zeilen | 1,559 |
| ESP8266 Zeilen | 183 |
| Test Zeilen | 500+ |
| **Architektur** | |
| Klassen (Flutter) | 13 |
| Komponenten (ESP8266) | 8 |
| Diagramme | 27 |
| **Features** | |
| Fahrmodi | 3 |
| Input-Methoden | 3 |
| Sensoren | 1 |
| Motoren | 2 |

### 9.2 Technologie-Stack

```
Frontend:  Flutter 3.10.0 + Dart
Backend:   ESP8266 + Arduino C++
Protocol:  WebSocket + HTTP
Hardware:  L298N + VL53L0X + DC Motors
Network:   WiFi 2.4GHz
```

### 9.3 Erfolgs-Metriken

| Metrik | Ziel | Erreicht | Status |
|--------|------|----------|--------|
| WebSocket Latenz | <100ms | 50-100ms | ✅ |
| UI Frame Rate | 60 FPS | 60 FPS | ✅ |
| Physics Update | 20 FPS | 20 FPS | ✅ |
| Test Coverage | 85% | 83% | ⚠️ |
| Code Quality | A | A | ✅ |
| Documentation | 100% | 100% | ✅ |

---

**Letzte Aktualisierung**: 2026-05-26  
**Version**: 1.0.0  
**Team**: TINF24CS2 - DHBW

---

> 💡 **Tipp**: Diese Datei ist für GitHub/GitLab optimiert.  
> Für Word/PDF-Export nutze: `Diagramme-fuer-Word.md`  
> Für PlantUML-Diagramme nutze: `Architektur-FIXED.md`