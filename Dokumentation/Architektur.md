# Systemarchitektur - R.E.D. Projekt (Korrigierte Version)

## Inhaltsverzeichnis
- [Übersicht](#übersicht)
- [Systemarchitektur-Diagramm](#systemarchitektur-diagramm)
- [Komponentendiagramm](#komponentendiagramm)
- [Deployment-Diagramm](#deployment-diagramm)
- [Netzwerkarchitektur](#netzwerkarchitektur)

## Übersicht

Das R.E.D. System folgt einer **Client-Server-Architektur** mit Echtzeit-Kommunikation über WebSockets. Die Architektur ist in drei Hauptschichten unterteilt:

1. **Präsentationsschicht** (Flutter Web App)
2. **Kommunikationsschicht** (WebSocket/HTTP)
3. **Steuerungsschicht** (ESP8266 + Hardware)

## Systemarchitektur-Diagramm

```plantuml
@startuml
skinparam componentStyle rectangle

package "Client Layer" {
    component [Flutter Web App] as FlutterApp
    component [Browser/Desktop] as Client
    
    package "UI Components" {
        component [Welcome Page] as Welcome
        component [Mode Selection] as ModeSelect
        component [Driving Page] as Driving
        component [Autonomous Page] as Auto
        component [Drawing Page] as Drawing
    }
    
    package "Business Logic" {
        component [ConnectionManager] as ConnMgr
        component [Physics Engine] as Physics
        component [Input Handler] as Input
        component [State Manager] as State
    }
}

package "Communication Layer" {
    component [WebSocket Protocol] as WS
    component [HTTP Fallback] as HTTP
    cloud "WiFi Network" as Network
}

package "Server Layer" {
    component [ESP8266 NodeMCU] as ESP
    
    package "ESP Components" {
        component [WebSocket Server] as WSServer
        component [Command Parser] as Parser
        component [Motor Controller] as MotorCtrl
        component [Sensor Manager] as SensorMgr
    }
}

package "Hardware Layer" {
    component [Motor A Steering] as MotorA
    component [Motor B Drive] as MotorB
    component [VL53L0X Sensor] as Sensor
    component [Power Supply] as Power
}

Client --> FlutterApp
FlutterApp --> Welcome
Welcome --> ModeSelect
ModeSelect --> Driving
ModeSelect --> Auto
ModeSelect --> Drawing

Driving --> ConnMgr
Auto --> ConnMgr
Drawing --> ConnMgr

Driving --> Physics
Driving --> Input
ConnMgr --> State

ConnMgr --> WS
ConnMgr --> HTTP
WS --> Network
HTTP --> Network

Network --> ESP
ESP --> WSServer
WSServer --> Parser
Parser --> MotorCtrl
Parser --> SensorMgr

MotorCtrl --> MotorA
MotorCtrl --> MotorB
SensorMgr --> Sensor
Power --> ESP
Power --> MotorA
Power --> MotorB
Power --> Sensor

@enduml
```

## Komponentendiagramm

```plantuml
@startuml
' DIN A4 Optimierung
skinparam dpi 150
skinparam pageMargin 10
skinparam componentStyle rectangle
skinparam backgroundColor #FEFEFE
skinparam shadowing false
skinparam nodesep 50
skinparam ranksep 40

' Farben für verschiedene Layer
skinparam package {
    BackgroundColor<<ui>> #E3F2FD
    BorderColor<<ui>> #1976D2
    BackgroundColor<<logic>> #FFF3E0
    BorderColor<<logic>> #F57C00
    BackgroundColor<<esp>> #E8F5E9
    BorderColor<<esp>> #388E3C
    BackgroundColor<<hardware>> #FCE4EC
    BorderColor<<hardware>> #C2185B
}

skinparam component {
    BackgroundColor #FFFFFF
    BorderColor #424242
    FontSize 10
}

package "Flutter Application" <<ui>> {
    component "UI Layer" as UILayer #B3E5FC {
        [WelcomePage]
        [ModeSelectionPage]
        [DrivingPage]
        [AutonomousDrivingPage]
        [DrawingPage]
    }
    
    component "Business Logic" as LogicLayer #FFE0B2 {
        [ConnectionManager] #FFCC80
        [PhysicsEngine]
        [InputHandler]
        [RouteManager]
    }
    
    component "Data Layer" as DataLayer #FFF9C4 {
        [StateManager]
        [CommandQueue] #FFD54F
    }
    
    interface "WebSocket" as IWS
    interface "HTTP" as IHTTP
}

package "ESP8266 Firmware" <<esp>> {
    component "Network Layer" as NetLayer #C8E6C9 {
        [WiFiManager]
        [WebSocketServer] #81C784
    }
    
    component "Control Layer" as CtrlLayer #A5D6A7 {
        [CommandParser] #66BB6A
        [MotorController]
        [SensorController]
    }
    
    component "Hardware Abstraction" as HAL #DCEDC8 {
        [MotorDriver]
        [I2CDriver]
        [GPIODriver]
    }
    
    interface "I2C" as II2C
    interface "GPIO" as IGPIO
}

package "Hardware" <<hardware>> {
    [DC Motors] #F48FB1
    [VL53L0X Sensor] #F48FB1
    [Power Management] #F8BBD0
}

' ===== COMMAND FLOW (Hervorgehoben) =====
[DrivingPage] -[#FF6B6B,thickness=2]-> [ConnectionManager] : <color:#FF6B6B><b>send cmd
[AutonomousDrivingPage] -[#FF6B6B,thickness=2]-> [ConnectionManager] : <color:#FF6B6B><b>send cmd
[DrawingPage] -[#FF6B6B,thickness=2]-> [ConnectionManager] : <color:#FF6B6B><b>send cmd

[ConnectionManager] -[#FF6B6B,thickness=2]-> [CommandQueue] : <color:#FF6B6B><b>queue
[ConnectionManager] -[#FF6B6B,thickness=2]-> IWS : <color:#FF6B6B><b>send

IWS -[#FF6B6B,thickness=2]-> [WebSocketServer] : <color:#FF6B6B><b>msg

[WebSocketServer] -[#FF6B6B,thickness=2]-> [CommandParser] : <color:#FF6B6B><b>receive
[CommandParser] -[#FF6B6B,thickness=2]-> [MotorController] : <color:#FF6B6B><b>motor
[CommandParser] -[#4ECDC4,thickness=2]-> [SensorController] : <color:#4ECDC4><b>sensor

[MotorController] -[#FF6B6B,thickness=2]-> [MotorDriver] : <color:#FF6B6B><b>execute
[MotorDriver] -[#FF6B6B,thickness=2]-> IGPIO : <color:#FF6B6B><b>PWM
IGPIO -[#FF6B6B,thickness=2]-> [DC Motors] : <color:#FF6B6B><b>control

' ===== Andere Verbindungen =====
[DrivingPage] --> [PhysicsEngine] : calc
[DrivingPage] --> [InputHandler] : input
[DrawingPage] --> [RouteManager] : path

[ConnectionManager] --> [StateManager] : state
[ConnectionManager] --> IHTTP : fallback

IHTTP --> [WiFiManager] : config

[SensorController] --> [I2CDriver] : read
[I2CDriver] --> II2C
II2C --> [VL53L0X Sensor] : data

[Power Management] --> [DC Motors] : power
[Power Management] --> [VL53L0X Sensor] : power

' ===== Command Flow Beschreibung =====
note right of [ConnectionManager] #FFFDE7
  <b>Send Command Flow:</b>
  ━━━━━━━━━━━━━━━━━━━━━
  <b>1.</b> User Input → UI Page
  <b>2.</b> UI → ConnectionManager
  <b>3.</b> Queue in CommandQueue
  <b>4.</b> Send via WebSocket
  <b>5.</b> ESP receives & parses
  <b>6.</b> Execute on Motors
  ━━━━━━━━━━━━━━━━━━━━━
  <color:#FF6B6B><b> Real-time execution</b></color>
end note

' ===== Legende =====
legend bottom
  <b><color:#FF6B6B>━━━</color> Command Flow</b> | <b><color:#4ECDC4>━━━</color> Sensor Flow</b> | <b><color:#424242>───</color> Data Flow</b>
end legend

@enduml
```

## Deployment-Diagramm

```plantuml
@startuml

node "User Device" {
    artifact "Flutter Web App" as App
    node "Web Browser" {
        component [Chrome/Firefox/Safari]
    }
}

cloud "WiFi Network" as Network {
    node "Access Point" {
        component [ESP8266 AP]
    }
}

node "Robot Car" {
    node "ESP8266 NodeMCU" {
        artifact "Firmware" {
            component [main.cpp]
            component [WebSocket Server]
            component [Motor Control]
        }
        
        database "Flash Memory" {
            [Program Code]
            [WiFi Config]
        }
    }
    
    node "Motor Controller" {
        component [H-Bridge]
        component [Motor A]
        component [Motor B]
    }
    
    node "Sensors" {
        component [VL53L0X]
        component [I2C Bus]
    }
    
    node "Power Supply" {
        component [Battery Pack]
        component [Voltage Regulator]
    }
}

[Chrome/Firefox/Safari] --> App
App --> [ESP8266 AP] : WebSocket Port 81
[ESP8266 AP] --> [WebSocket Server]

[WebSocket Server] --> [Motor Control]
[Motor Control] --> [H-Bridge]
[H-Bridge] --> [Motor A]
[H-Bridge] --> [Motor B]

[Motor Control] --> [I2C Bus]
[I2C Bus] --> [VL53L0X]

[Battery Pack] --> [Voltage Regulator]
[Voltage Regulator] --> [ESP8266 NodeMCU]
[Voltage Regulator] --> [Motor Controller]
[Voltage Regulator] --> [VL53L0X]

@enduml
```

## Netzwerkarchitektur

```plantuml
@startuml

actor User
node "Device" {
    component [Web Browser] as Browser
    component [Flutter App] as App
}

cloud "WiFi Network" {
    node "ESP8266 Access Point" as AP {
        component [SSID: R.E.D]
        component [IP: 10.10.10.10]
    }
}

node "ESP8266" {
    component [WebSocket Server Port 81] as WSS
    component [HTTP Server Port 80] as HTTP
}

component [Command Queue] as Queue
component [Motor Driver] as Driver
component [Sensor Reader] as Reader

User --> Browser
Browser --> App
App --> AP : WiFi Connection
AP --> WSS : WebSocket
WSS --> Queue
Queue --> Driver
Reader --> WSS

@enduml
```

## Datenfluss-Diagramm

```plantuml
@startuml

actor User
participant "Flutter UI" as UI
participant "ConnectionManager" as CM
participant "WebSocket" as WS
participant "ESP8266" as ESP
participant "Motor Controller" as MC
participant "Sensor" as Sensor

== Initialisierung ==
User -> UI : App starten
UI -> CM : initialize()
CM -> WS : connect()
WS -> ESP : Handshake
ESP --> WS : Connected
WS --> CM : onConnected()
CM --> UI : Status Update

== Manuelle Steuerung ==
User -> UI : Taste W
UI -> CM : send("forward")
CM -> WS : sendMessage()
WS -> ESP : forward
ESP -> MC : drive(1,0)
ESP --> WS : ACK
WS --> CM : ACK
CM --> UI : Confirmed

== Autonomes Fahren ==
User -> UI : Start Auto
UI -> CM : send("auto")
CM -> WS : auto
WS -> ESP : Enable Auto

loop Continuous
    ESP -> Sensor : get_distance()
    Sensor --> ESP : distance
    ESP -> MC : set_autoDrive()
    ESP -> WS : sensor_data
    WS -> CM : data
    CM -> UI : Update
end

@enduml
```

## Schichtenarchitektur

### Layer 1: Präsentationsschicht (Flutter)
- **Verantwortung**: UI/UX, Benutzereingaben, Visualisierung
- **Technologien**: Flutter, Dart, Material Design
- **Komponenten**: Pages, Widgets, Custom Painters

### Layer 2: Business Logic
- **Verantwortung**: Anwendungslogik, State Management, Physik-Simulation
- **Technologien**: Dart, Timer, ValueNotifier
- **Komponenten**: ConnectionManager, PhysicsEngine, InputHandler

### Layer 3: Kommunikationsschicht
- **Verantwortung**: Netzwerkkommunikation, Protokoll-Handling
- **Technologien**: WebSocket, HTTP
- **Komponenten**: WebSocketChannel, HTTP Client

### Layer 4: Steuerungsschicht (ESP8266)
- **Verantwortung**: Hardware-Steuerung, Sensor-Auswertung
- **Technologien**: Arduino, C++
- **Komponenten**: WebSocketServer, Motor Driver, Sensor Manager

### Layer 5: Hardware-Schicht
- **Verantwortung**: Physische Aktoren und Sensoren
- **Technologien**: DC-Motoren, ToF-Sensor, I2C
- **Komponenten**: Motors, VL53L0X, Power Supply

## Design Patterns

### 1. Singleton Pattern
**Verwendung**: ConnectionManager
```dart
class ConnectionManager {
  ConnectionManager._internal();
  static final ConnectionManager instance = ConnectionManager._internal();
}
```

### 2. Observer Pattern
**Verwendung**: ValueNotifier für Verbindungsstatus
```dart
ValueNotifier<bool> connected = ValueNotifier(false);
```

### 3. State Pattern
**Verwendung**: StatefulWidget für dynamische Pages

### 4. Command Pattern
**Verwendung**: Motor-Befehle

## Performance-Metriken

| Metrik | Zielwert | Aktuell | Status |
|--------|----------|---------|--------|
| WebSocket Latenz | <100ms | 50-100ms | ✅ |
| UI Frame Rate | 60 FPS | 60 FPS | ✅ |
| Physics Update Rate | 20 FPS | 20 FPS | ✅ |
| Reconnect Time | <3s | 1-5s | ⚠️ |
| Command Queue Size | <10 | 5 | ✅ |

---

**Letzte Aktualisierung**: 2026-05-26