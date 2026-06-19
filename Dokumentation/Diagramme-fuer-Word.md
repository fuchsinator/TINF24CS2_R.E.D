# R.E.D. Projekt - Alle Diagramme für Word

**Anleitung**: Diese Datei kann direkt in Word kopiert werden. Die Diagramme sind als Text-Beschreibungen formatiert.

---

## 1. SYSTEMARCHITEKTUR-ÜBERSICHT

### Schichtenmodell

```
┌─────────────────────────────────────────────────────────────┐
│                   CLIENT LAYER (Flutter)                     │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  UI Components:                                       │   │
│  │  - Welcome Page                                       │   │
│  │  - Mode Selection Page                               │   │
│  │  - Driving Page                                      │   │
│  │  - Autonomous Driving Page                           │   │
│  │  - Drawing Page                                      │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Business Logic:                                      │   │
│  │  - ConnectionManager (Singleton)                     │   │
│  │  - Physics Engine                                    │   │
│  │  - Input Handler                                     │   │
│  │  - State Manager                                     │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│              COMMUNICATION LAYER                             │
│  ┌──────────────┐         ┌──────────────┐                 │
│  │  WebSocket   │         │ HTTP Fallback│                 │
│  │  Port 81     │         │  Port 80     │                 │
│  └──────────────┘         └──────────────┘                 │
│                                                              │
│         WiFi Network: 10.10.10.0/24                         │
│         SSID: R.E.D                                         │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│                SERVER LAYER (ESP8266)                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  ESP8266 Components:                                  │   │
│  │  - WebSocket Server                                   │   │
│  │  - Command Parser                                     │   │
│  │  - Motor Controller                                   │   │
│  │  - Sensor Manager                                     │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│                   HARDWARE LAYER                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Motor A  │  │ Motor B  │  │ VL53L0X  │  │  Power   │   │
│  │(Steering)│  │ (Drive)  │  │ (Sensor) │  │  Supply  │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**Beschreibung**:
- **Client Layer**: Flutter Web-App mit UI-Komponenten und Business Logic
- **Communication Layer**: WebSocket (primär) und HTTP (Fallback) über WiFi
- **Server Layer**: ESP8266 mit Firmware für Steuerung und Sensorik
- **Hardware Layer**: Motoren, Sensoren und Stromversorgung

---

## 2. KOMPONENTEN-DIAGRAMM

### Flutter Application Komponenten

```
Flutter Application
├── UI Layer
│   ├── WelcomePage
│   ├── ModeSelectionPage
│   ├── DrivingPage
│   ├── AutonomousDrivingPage
│   └── DrawingPage
│
├── Business Logic Layer
│   ├── ConnectionManager (Singleton)
│   ├── PhysicsEngine
│   ├── InputHandler
│   └── RouteManager
│
└── Data Layer
    ├── StateManager
    └── CommandQueue
```

### ESP8266 Firmware Komponenten

```
ESP8266 Firmware
├── Network Layer
│   ├── WiFiManager
│   └── WebSocketServer
│
├── Control Layer
│   ├── CommandParser
│   ├── MotorController
│   └── SensorController
│
└── Hardware Abstraction
    ├── MotorDriver
    ├── I2CDriver
    └── GPIODriver
```

**Verbindungen**:
- UI Layer → Business Logic Layer → Data Layer
- Data Layer → WebSocket/HTTP → Network Layer
- Network Layer → Control Layer → Hardware Abstraction
- Hardware Abstraction → Physische Hardware

---

## 3. DEPLOYMENT-DIAGRAMM

### Physische Verteilung

```
┌─────────────────────────────────────┐
│        USER DEVICE                  │
│  ┌───────────────────────────────┐  │
│  │  Web Browser                  │  │
│  │  (Chrome/Firefox/Safari)      │  │
│  │  ┌─────────────────────────┐  │  │
│  │  │  Flutter Web App        │  │  │
│  │  │  - UI Components        │  │  │
│  │  │  - Business Logic       │  │  │
│  │  └─────────────────────────┘  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
              ↓ WiFi
┌─────────────────────────────────────┐
│      WIFI NETWORK                   │
│  Access Point: R.E.D                │
│  IP: 10.10.10.10                    │
│  Subnet: 255.255.255.0              │
└─────────────────────────────────────┘
              ↓ WebSocket (Port 81)
┌─────────────────────────────────────┐
│        ROBOT CAR                    │
│  ┌───────────────────────────────┐  │
│  │  ESP8266 NodeMCU              │  │
│  │  ┌─────────────────────────┐  │  │
│  │  │  Firmware               │  │  │
│  │  │  - WebSocket Server     │  │  │
│  │  │  - Motor Control        │  │  │
│  │  │  - Sensor Manager       │  │  │
│  │  └─────────────────────────┘  │  │
│  │  ┌─────────────────────────┐  │  │
│  │  │  Flash Memory           │  │  │
│  │  │  - Program Code         │  │  │
│  │  │  - WiFi Config          │  │  │
│  │  └─────────────────────────┘  │  │
│  └───────────────────────────────┘  │
│              ↓                      │
│  ┌───────────────────────────────┐  │
│  │  Motor Controller             │  │
│  │  - H-Bridge (L298N)           │  │
│  │  - Motor A (Steering)         │  │
│  │  - Motor B (Drive)            │  │
│  └───────────────────────────────┘  │
│              ↓                      │
│  ┌───────────────────────────────┐  │
│  │  Sensors                      │  │
│  │  - VL53L0X (ToF)              │  │
│  │  - I2C Bus                    │  │
│  └───────────────────────────────┘  │
│              ↓                      │
│  ┌───────────────────────────────┐  │
│  │  Power Supply                 │  │
│  │  - Battery Pack (7.4V)        │  │
│  │  - Voltage Regulator (3.3V)   │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

**Hardware-Spezifikationen**:
- **ESP8266**: NodeMCU, 80MHz, 4MB Flash
- **Motor Controller**: L298N H-Bridge
- **Sensor**: VL53L0X Time-of-Flight (50-2000mm)
- **Power**: 7.4V Li-Ion Battery, 3.3V Regulator

---

## 4. SEQUENZDIAGRAMM: WebSocket-Verbindung

```
User          Flutter App    ConnectionManager    WebSocket    ESP8266
 |                |                  |                |            |
 |--App öffnen--->|                  |                |            |
 |                |--initialize()--->|                |            |
 |                |                  |--connect()---->|            |
 |                |                  |                |--Handshake->|
 |                |                  |                |<-101 OK----|
 |                |                  |<-onConnected()-|            |
 |                |<-Status: Grün----|                |            |
 |                |                  |                |            |
 |--Taste W------>|                  |                |            |
 |                |--send("forward")->                |            |
 |                |                  |--"forward"---->|            |
 |                |                  |                |--drive(1,0)->|
 |                |                  |                |<---ACK-----|
 |                |                  |<---ACK---------|            |
 |                |<-Confirmed-------|                |            |
```

**Ablauf**:
1. User öffnet App
2. ConnectionManager initialisiert WebSocket
3. Verbindung zu ESP8266 wird hergestellt
4. Status-Indikator wird grün
5. User drückt Taste → Befehl wird gesendet
6. ESP8266 führt Befehl aus und bestätigt

---

## 5. SEQUENZDIAGRAMM: Autonomes Fahren

```
User    AutonomousPage    ConnectionManager    ESP8266    VL53L0X    Motors
 |            |                  |                |          |          |
 |--Start---->|                  |                |          |          |
 |            |--send("auto")-->|                |          |          |
 |            |                  |--"auto"------->|          |          |
 |            |                  |                |--enable->|          |
 |            |                  |                |          |          |
 |            |                  |                |<-Loop Start---------|
 |            |                  |                |          |          |
 |            |                  |                |--measure->|          |
 |            |                  |                |<-450mm---|          |
 |            |                  |                |          |          |
 |            |                  |                |--if dist>=250mm---->|
 |            |                  |                |          |--forward->|
 |            |                  |                |          |          |
 |            |                  |<-sensor_data---|          |          |
 |            |<-update----------|                |          |          |
 |            |                  |                |          |          |
 |            |                  |                |--measure->|          |
 |            |                  |                |<-150mm---|          |
 |            |                  |                |          |          |
 |            |                  |                |--if dist<250mm----->|
 |            |                  |                |          |--backward>|
 |            |                  |                |          |--turn---->|
 |            |                  |                |          |          |
 |            |                  |                |<-Loop End-----------|
 |            |                  |                |          |          |
 |--Stop----->|                  |                |          |          |
 |            |--send("autoStop")>                |          |          |
 |            |                  |--"autoStop"--->|          |          |
 |            |                  |                |--disable->|          |
 |            |                  |                |          |--stop--->|
```

**Logik**:
- **Distanz >= 250mm**: Vorwärts fahren
- **Distanz < 250mm**: Rückwärts fahren und drehen
- **Distanz < 50mm**: Stoppen (zu nah)

---

## 6. KLASSENDIAGRAMM: Flutter App

### ConnectionManager (Singleton)

```
┌─────────────────────────────────────┐
│      ConnectionManager              │
├─────────────────────────────────────┤
│ - static instance: ConnectionManager│
│ - connected: ValueNotifier<bool>    │
│ - _channel: WebSocketChannel?       │
│ - _reconnectTimer: Timer?           │
│ - _reconnectSeconds: int = 2        │
│ + wsUrl: String                     │
│ + wsFallback: String                │
├─────────────────────────────────────┤
│ - ConnectionManager._internal()     │
│ + connectNow(): void                │
│ + send(String cmd): void            │
│ + dispose(): void                   │
│ - _connect(): void                  │
│ - _scheduleReconnect(): void        │
└─────────────────────────────────────┘
```

### DrivingPage State

```
┌─────────────────────────────────────┐
│      _DrivingPageState              │
├─────────────────────────────────────┤
│ - speed: double                     │
│ - throttle: double                  │
│ - brake: double                     │
│ - steering: double                  │
│ - accelerating: bool                │
│ - braking: bool                     │
│ - steerLeft: bool                   │
│ - steerRight: bool                  │
│ - reversing: bool                   │
│ - _timer: Timer?                    │
│ - _focusNode: FocusNode             │
│ - _pressedKeys: Map<Key, bool>      │
├─────────────────────────────────────┤
│ + initState(): void                 │
│ + dispose(): void                   │
│ + build(BuildContext): Widget       │
│ - _updatePhysics(): void            │
│ - _handleKeyboardEvent(KeyEvent)    │
│ - _inputAccelerate(bool): void      │
│ - _inputBrake(bool): void           │
│ - _inputSteerLeft(bool): void       │
│ - _inputSteerRight(bool): void      │
└─────────────────────────────────────┘
```

---

## 7. USE-CASE-DIAGRAMM

### Akteure und Use-Cases

```
Benutzer                    System R.E.D.                    ESP8266
   |                              |                              |
   |--Mit Auto verbinden--------->|                              |
   |                              |--WebSocket Handshake-------->|
   |                              |                              |
   |--Auto manuell steuern------->|                              |
   |  ├─Vorwärts fahren           |--send("forward")------------>|
   |  ├─Rückwärts fahren          |--send("backward")----------->|
   |  ├─Links lenken              |--send("left")--------------->|
   |  ├─Rechts lenken             |--send("right")-------------->|
   |  └─Notbremse                 |--send("stop")--------------->|
   |                              |                              |
   |--Autonomen Modus starten---->|                              |
   |                              |--send("auto")--------------->|
   |                              |<-Sensor-Daten----------------|
   |<-Distanz-Anzeige-------------|                              |
   |                              |                              |
   |--Route zeichnen------------->|                              |
   |--Route abfahren------------->|                              |
   |                              |--Befehls-Sequenz------------>|
   |                              |                              |
   |--Verbindungsstatus anzeigen->|                              |
   |<-Status (Grün/Rot)-----------|                              |
```

**Hauptfunktionen**:
1. **Verbindungsverwaltung**: Automatisches Connect/Reconnect
2. **Manuelle Steuerung**: WASD/Pfeiltasten/Touch
3. **Autonomes Fahren**: Sensor-basierte Navigation
4. **Route-Planung**: Zeichnen und Abfahren von Routen
5. **Monitoring**: Echtzeit-Status und Sensordaten

---

## 8. AKTIVITÄTSDIAGRAMM: Manuelle Steuerung

```
[Start]
   ↓
[Benutzer öffnet App]
   ↓
[Wählt "Driving Mode"]
   ↓
[Initialisiere Physics Engine]
   ↓
[Starte Input Handler]
   ↓
┌─────────────────────────────┐
│  Warte auf Eingabe          │
└─────────────────────────────┘
   ↓
[Taste gedrückt?]
   ├─ Ja → [Erfasse Taste]
   │         ↓
   │       [W/↑?] → [accelerating = true]
   │       [S/↓?] → [braking = true]
   │       [A/←?] → [steerLeft = true]
   │       [D/→?] → [steerRight = true]
   │       [Space?] → [Notbremse]
   │         ↓
   │       [Update Physics (20 FPS)]
   │         ↓
   │       [Berechne Geschwindigkeit]
   │       [Berechne Lenkung]
   │       [Wende Reibung an]
   │         ↓
   │       [speed ≠ 0?]
   │         ├─ Ja → [Sende Befehl an ESP8266]
   │         │         ↓
   │         │       [Motoren bewegen sich]
   │         │         ↓
   │         └─ Nein → [Motoren stoppen]
   │         ↓
   │       [Aktualisiere UI]
   │       [Zeige Geschwindigkeit]
   │       [Zeige RPM]
   │         ↓
   └─ Zurück zu "Warte auf Eingabe"
   │
   ↓
[Taste losgelassen?]
   ├─ Ja → [Setze Flag auf false]
   │         ↓
   │       [Beginne Verzögerung]
   │         ↓
   └─ Zurück zu "Warte auf Eingabe"
   │
   ↓
[Benutzer verlässt Mode?]
   ├─ Ja → [Stoppe Physics Engine]
   │         ↓
   │       [Sende "stop"]
   │         ↓
   │       [Ende]
   │
   └─ Nein → Zurück zu "Warte auf Eingabe"
```

---

## 9. ZUSTANDSDIAGRAMM: Verbindungsstatus

```
[Disconnected]
    ↓ _connect()
[Connecting]
    ↓ WebSocket OK
[Connected] ←──────────┐
    ↓ Connection Lost  │
[Disconnected]         │
    ↓ Timer Expired    │
[Reconnecting] ────────┘
    (Exponential Backoff: 2s, 4s, 8s, 16s, 30s max)
```

**Status-Beschreibungen**:
- **Disconnected**: Keine Verbindung, roter Indikator
- **Connecting**: Verbindungsaufbau läuft, oranger Indikator
- **Connected**: Aktive Verbindung, grüner Indikator
- **Reconnecting**: Automatischer Wiederverbindungsversuch

---

## 10. ZUSTANDSDIAGRAMM: Fahrzeugzustand

```
[Stopped]
speed = 0, gear = N
    ↓ W gedrückt
[Accelerating]
speed > 0, gear = D
    ↓ W losgelassen
[Cruising]
speed > 0, Reibung aktiv
    ↓ S gedrückt
[Braking]
brake > 0, speed sinkt
    ↓ speed = 0
[Stopped]
    ↓ S gehalten (700ms)
[Reversing]
speed < 0, gear = R
    ↓ S losgelassen
[Braking]
    ↓ speed = 0
[Stopped]

[Jederzeit: Space] → [Emergency Stop] → [Stopped]
```

**Physik-Parameter**:
- Max Speed: ±30 km/h
- Acceleration: 0.5 per tick
- Friction: 0.3 per tick
- Update Rate: 20 FPS (50ms)

---

## 11. NETZWERK-TOPOLOGIE

```
Internet
   ↓ (optional)
[User Device]
   ├─ Laptop
   ├─ Smartphone
   └─ Tablet
   ↓ WiFi (2.4GHz)
[ESP8266 Access Point]
   SSID: R.E.D
   IP: 10.10.10.10
   Channel: Auto
   Security: Open (Demo)
   ↓
[ESP8266 NodeMCU]
   ├─ WebSocket Server (Port 81)
   ├─ HTTP Server (Port 80)
   └─ mDNS (red.local)
   ↓
[Hardware]
   ├─ Motors (via GPIO)
   ├─ Sensors (via I2C)
   └─ Power Management
```

**Netzwerk-Details**:
- **Protokoll**: WebSocket (ws://)
- **Latenz**: 50-100ms
- **Reichweite**: ~50m
- **Max Clients**: 4 gleichzeitig

---

## 12. DATENFLUSS-DIAGRAMM

```
User Input
   ↓
[Input Handler]
   ├─ Keyboard Events
   ├─ Touch Events
   └─ Mouse Events
   ↓
[Physics Engine]
   ├─ Calculate Speed
   ├─ Calculate Steering
   └─ Apply Friction
   ↓
[Command Generator]
   ├─ "forward"
   ├─ "backward"
   ├─ "left"
   ├─ "right"
   └─ "stop"
   ↓
[ConnectionManager]
   ├─ Command Queue
   └─ WebSocket Channel
   ↓
[Network]
   ↓
[ESP8266]
   ├─ Command Parser
   └─ Motor Controller
   ↓
[Motors]
   ├─ Motor A (Steering)
   └─ Motor B (Drive)

[Sensors] → [ESP8266] → [WebSocket] → [ConnectionManager] → [UI Update]
```

---

## ZUSAMMENFASSUNG

### Projekt-Statistiken
- **Gesamt-Diagramme**: 27
- **Klassen (Flutter)**: 13
- **Komponenten (ESP8266)**: 8
- **Use-Cases**: 15
- **Zustände**: 6

### Technologie-Stack
- **Frontend**: Flutter 3.10.0, Dart
- **Backend**: ESP8266, Arduino C++
- **Kommunikation**: WebSocket, HTTP
- **Hardware**: L298N, VL53L0X, DC Motors

### Performance-Ziele
- WebSocket Latenz: <100ms ✅
- UI Frame Rate: 60 FPS ✅
- Physics Update: 20 FPS ✅
- Sensor Read Rate: 10 Hz ✅

---

**Ende der Diagramm-Dokumentation**

**Letzte Aktualisierung**: 2026-05-26