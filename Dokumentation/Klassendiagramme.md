# Klassendiagramme - R.E.D. Projekt (Korrigierte Version)

## Inhaltsverzeichnis
- [Flutter App - Vollständiges Klassendiagramm](#flutter-app---vollständiges-klassendiagramm)
- [ConnectionManager - Detailansicht](#connectionmanager---detailansicht)
- [UI-Komponenten](#ui-komponenten)
- [ESP8266 Firmware - Klassenstruktur](#esp8266-firmware---klassenstruktur)

## Flutter App - Vollständiges Klassendiagramm

```plantuml
@startuml

class MyApp {
  + build(BuildContext): Widget
}

class ConnectionManager {
  - {static} instance: ConnectionManager
  - _channel: WebSocketChannel
  - _reconnectTimer: Timer
  - _reconnectSeconds: int
  - _isConnecting: bool
  + connected: ValueNotifier<bool>
  + wsUrl: String
  + wsFallback: String
  __
  - ConnectionManager._internal()
  + connectNow(): void
  + send(String): void
  + dispose(): void
  - _connect(): void
  - _scheduleReconnect(): void
}

class ConnectionStatus {
  + build(BuildContext): Widget
}

class WelcomePage {
  + createState(): State
}

class _WelcomePageState {
  - animateCar: bool
  __
  + initState(): void
  + build(BuildContext): Widget
}

class ModeSelectionPage {
  + build(BuildContext): Widget
}

class DrivingPage {
  + createState(): State
}

class _DrivingPageState {
  - _timer: Timer
  - _reverseTimer: Timer
  - speed: double
  - throttle: double
  - brake: double
  - steering: double
  - accelerating: bool
  - braking: bool
  - steerLeft: bool
  - steerRight: bool
  - reversing: bool
  - lightOn: bool
  - _focusNode: FocusNode
  - controlsInverted: bool
  - _pressedKeys: Map
  __
  + initState(): void
  + dispose(): void
  - _updatePhysics(): void
  - _handleKeyboardEvent(KeyEvent): KeyEventResult
  - _inputAccelerate(bool): void
  - _inputBrake(bool): void
  - _inputSteerLeft(bool): void
  - _inputSteerRight(bool): void
  + build(BuildContext): Widget
}

class DrawingPage {
  + createState(): State
}

class _DrawingPageState {
  - _points: List
  __
  + build(BuildContext): Widget
}

class _RoutePainter {
  - points: List
  __
  + _RoutePainter(List)
  + paint(Canvas, Size): void
  + shouldRepaint(_RoutePainter): bool
}

class AutonomousDrivingPage {
  + createState(): State
}

class _AutonomousDrivingPageState {
  - isRunning: bool
  - maxSpeed: double
  __
  + initState(): void
  + dispose(): void
  - _startAutonomous(): void
  - _stopAutonomous(): void
  - _emergencyStop(): void
  + build(BuildContext): Widget
}

class _SensorDisplay {
  - distance: double
  - label: String
  - color: Color
  __
  + _SensorDisplay(double, String, Color)
  + build(BuildContext): Widget
}

MyApp --> WelcomePage
WelcomePage --> _WelcomePageState
WelcomePage --> ModeSelectionPage
ModeSelectionPage --> DrivingPage
ModeSelectionPage --> AutonomousDrivingPage
ModeSelectionPage --> DrawingPage
DrivingPage --> _DrivingPageState
DrawingPage --> _DrawingPageState
AutonomousDrivingPage --> _AutonomousDrivingPageState

_DrivingPageState --> ConnectionManager
_DrawingPageState --> ConnectionManager
_AutonomousDrivingPageState --> ConnectionManager

_DrawingPageState --> _RoutePainter
_AutonomousDrivingPageState --> _SensorDisplay

ConnectionStatus --> ConnectionManager

note right of ConnectionManager
  Singleton Pattern
  Manages WebSocket connection
  Auto-reconnect with exponential backoff
end note

note right of _DrivingPageState
  Physics Simulation
  - 20 FPS update rate
  - Realistic acceleration
  - Momentum & friction
end note

@enduml
```

## ConnectionManager - Detailansicht

```plantuml
@startuml

class ConnectionManager {
  - {static} instance: ConnectionManager
  - _channel: WebSocketChannel
  - _reconnectTimer: Timer
  - _reconnectSeconds: int
  - _isConnecting: bool
  + connected: ValueNotifier<bool>
  + wsUrl: String
  + wsFallback: String
  __
  - ConnectionManager._internal()
  + connectNow(): void
  + send(String): void
  + dispose(): void
  - _connect(): void
  - _scheduleReconnect(): void
}

class WebSocketChannel {
  + stream: Stream
  + sink: WebSocketSink
  + close(): void
}

class Timer {
  + cancel(): void
  + {static} periodic(Duration, callback): Timer
}

class ValueNotifier {
  + value: T
  + addListener(VoidCallback): void
  + removeListener(VoidCallback): void
  + notifyListeners(): void
}

ConnectionManager --> WebSocketChannel : uses
ConnectionManager --> Timer : uses
ConnectionManager --> ValueNotifier : uses

note right of ConnectionManager::_connect
  Connection Logic:
  1. Check if already connecting
  2. Create WebSocketChannel
  3. Setup stream listeners
  4. Handle errors
  5. Update connected status
end note

note right of ConnectionManager::_scheduleReconnect
  Reconnect Strategy:
  - Exponential backoff
  - Initial: 2 seconds
  - Max: 30 seconds
  - Formula: min(seconds * 2, 30)
end note

@enduml
```

## UI-Komponenten

```plantuml
@startuml

package "Pages" {
  class WelcomePage {
    + createState(): State
  }
  
  class _WelcomePageState {
    - animateCar: bool
    __
    + initState(): void
    + build(BuildContext): Widget
  }
  
  class ModeSelectionPage {
    + build(BuildContext): Widget
  }
  
  class DrivingPage {
    + createState(): State
  }
  
  class _DrivingPageState {
    - speed: double
    - throttle: double
    - brake: double
    - steering: double
    - accelerating: bool
    - braking: bool
    - steerLeft: bool
    - steerRight: bool
    - reversing: bool
    - lightOn: bool
    - controlsInverted: bool
    - _timer: Timer
    - _reverseTimer: Timer
    - _focusNode: FocusNode
    - _pressedKeys: Map
    __
    + initState(): void
    + dispose(): void
    - _updatePhysics(): void
    - _handleKeyboardEvent(KeyEvent): KeyEventResult
    + build(BuildContext): Widget
  }
  
  class DrawingPage {
    + createState(): State
  }
  
  class _DrawingPageState {
    - _points: List
    __
    + build(BuildContext): Widget
  }
  
  class AutonomousDrivingPage {
    + createState(): State
  }
  
  class _AutonomousDrivingPageState {
    - isRunning: bool
    - maxSpeed: double
    __
    + initState(): void
    + dispose(): void
    - _startAutonomous(): void
    - _stopAutonomous(): void
    - _emergencyStop(): void
    + build(BuildContext): Widget
  }
}

package "Custom Widgets" {
  class ConnectionStatus {
    + build(BuildContext): Widget
  }
  
  class _SensorDisplay {
    - distance: double
    - label: String
    - color: Color
    __
    + _SensorDisplay(double, String, Color)
    + build(BuildContext): Widget
  }
  
  class _RoutePainter {
    - points: List
    __
    + _RoutePainter(List)
    + paint(Canvas, Size): void
    + shouldRepaint(_RoutePainter): bool
  }
}

WelcomePage --> _WelcomePageState
DrivingPage --> _DrivingPageState
DrawingPage --> _DrawingPageState
AutonomousDrivingPage --> _AutonomousDrivingPageState

_DrawingPageState --> _RoutePainter
_AutonomousDrivingPageState --> _SensorDisplay

note right of _DrivingPageState
  Input Handling:
  - Keyboard: WASD + Arrows
  - Touch: Virtual buttons
  - Simultaneous input support
  - Duplicate key prevention
end note

note right of _RoutePainter
  Custom Painter:
  - Extends CustomPainter
  - Draws on Canvas
  - Efficient repainting
end note

@enduml
```

## ESP8266 Firmware - Klassenstruktur

```plantuml
@startuml

package "Arduino Framework" {
  class Arduino {
    + setup(): void
    + loop(): void
    + delay(int): void
    + digitalWrite(int, int): void
    + pinMode(int, int): void
  }
}

package "Libraries" {
  class WiFi {
    + mode(wifi_mode): void
    + softAP(ssid): void
    + softAPConfig(ip, gateway, subnet): void
    + softAPIP(): IPAddress
  }
  
  class WebSocketsServer {
    - _port: uint16_t
    __
    + WebSocketsServer(uint16_t)
    + begin(): void
    + loop(): void
    + onEvent(callback): void
    + sendTXT(uint8_t, String): void
    + broadcastTXT(String): void
  }
  
  class VL53L0X {
    - io_timeout: uint16_t
    __
    + init(): bool
    + setTimeout(uint16_t): void
    + setSignalRateLimit(float): bool
    + readRangeSingleMillimeters(): uint16_t
    + timeoutOccurred(): bool
  }
  
  class Wire {
    + begin(sda, scl): void
    + beginTransmission(address): void
    + write(data): void
    + endTransmission(): void
    + requestFrom(address, quantity): void
    + read(): uint8_t
  }
}

package "Main Program" {
  class MainProgram {
    - sensor: VL53L0X
    - ws: WebSocketsServer
    - currentDirection: int
    - currentTurn: int
    - currentMode: bool
    - turnBool: bool
    - driveTime: int
    __
    + setup(): void
    + loop(): void
    + handleWSEvent(num, type, payload, len): void
    + drive(direction, turn): void
    + sensor_init(long_range, high_speed): void
    + get_distance(): int
    + set_autoDrive(dist): int
  }
}

MainProgram --> Arduino
MainProgram --> WiFi
MainProgram --> WebSocketsServer
MainProgram --> VL53L0X
MainProgram --> Wire

note right of MainProgram::handleWSEvent
  WebSocket Event Handler
  Parses commands:
  - "forward" → direction=1
  - "backward" → direction=2
  - "left" → turn=1
  - "right" → turn=2
  - "stop" → direction=0, turn=0
  - "auto" → currentMode=1
  - "autoStop" → currentMode=0
end note

note right of MainProgram::drive
  Motor Control
  Parameters:
  - direction: 0=stop, 1=forward, 2=backward
  - turn: 0=straight, 1=left, 2=right
end note

@enduml
```

## Datenmodelle

```plantuml
@startuml

class Command {
  + action: String
  + direction: int
  + turn: int
  + autonomous: bool
  __
  + Command.fromString(String): Command
  + toString(): String
}

class SensorData {
  + frontDistance: double
  + backDistance: double
  + leftDistance: double
  + rightDistance: double
  + timestamp: DateTime
  __
  + SensorData(double, double, double, double)
  + toJson(): Map
  + fromJson(Map): SensorData
}

class VehicleState {
  + speed: double
  + throttle: double
  + brake: double
  + steering: double
  + accelerating: bool
  + braking: bool
  + reversing: bool
  + gear: String
  __
  + VehicleState()
  + reset(): void
  + update(double): void
}

class RoutePoint {
  + x: double
  + y: double
  + angle: double
  + distance: double
  __
  + RoutePoint(double, double)
  + toOffset(): Offset
  + distanceTo(RoutePoint): double
}

class ConnectionState {
  + isConnected: bool
  + status: String
  + reconnectAttempts: int
  + lastConnected: DateTime
  __
  + ConnectionState()
  + updateStatus(bool): void
}

Command --> VehicleState
SensorData --> VehicleState
RoutePoint --> Command
ConnectionState --> Command

note right of Command
  Command Format:
  - "forward"
  - "backward,left"
  - "stop"
  - "auto"
end note

note right of SensorData
  Sensor Values:
  - Range: 50-2000mm
  - Update: ~10Hz
  - Format: JSON
end note

@enduml
```

## Vererbungshierarchie

```plantuml
@startuml

abstract class Widget {
  + build(BuildContext): Widget
}

abstract class StatelessWidget {
  + build(BuildContext): Widget
}

abstract class StatefulWidget {
  + createState(): State
}

abstract class State {
  + initState(): void
  + dispose(): void
  + build(BuildContext): Widget
}

abstract class CustomPainter {
  + paint(Canvas, Size): void
  + shouldRepaint(CustomPainter): bool
}

Widget <|-- StatelessWidget
Widget <|-- StatefulWidget

StatelessWidget <|-- MyApp
StatelessWidget <|-- ConnectionStatus
StatelessWidget <|-- ModeSelectionPage

StatefulWidget <|-- WelcomePage
StatefulWidget <|-- DrivingPage
StatefulWidget <|-- DrawingPage
StatefulWidget <|-- AutonomousDrivingPage

State <|-- _WelcomePageState
State <|-- _DrivingPageState
State <|-- _DrawingPageState
State <|-- _AutonomousDrivingPageState

CustomPainter <|-- _RoutePainter

WelcomePage ..> _WelcomePageState : creates
DrivingPage ..> _DrivingPageState : creates
DrawingPage ..> _DrawingPageState : creates
AutonomousDrivingPage ..> _AutonomousDrivingPageState : creates

note top of Widget
  Flutter Widget Tree
  All UI components inherit
  from Widget base class
end note

note bottom of CustomPainter
  Custom Rendering
  Used for drawing routes
  on canvas
end note

@enduml
```

---

**Letzte Aktualisierung**: 2026-05-26