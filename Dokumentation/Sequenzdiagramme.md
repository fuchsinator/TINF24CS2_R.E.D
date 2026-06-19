# Sequenzdiagramme - R.E.D. Projekt

## Inhaltsverzeichnis
- [Übersicht](#übersicht)
- [1. Verbindungsaufbau](#1-verbindungsaufbau)
- [2. Manuelle Steuerung](#2-manuelle-steuerung)
- [3. Autonomes Fahren](#3-autonomes-fahren)
- [4. Zeichenmodus](#4-zeichenmodus)
- [5. Fehlerbehandlung](#5-fehlerbehandlung)
- [6. Sensor-Datenübertragung](#6-sensor-datenübertragung)

## Übersicht

Diese Sequenzdiagramme zeigen die zeitliche Abfolge der Interaktionen zwischen den verschiedenen Komponenten des R.E.D. Systems.

## 1. Verbindungsaufbau

```plantuml
@startuml
skinparam backgroundColor #FEFEFE
skinparam sequenceMessageAlign center

actor User
participant "Flutter UI" as UI
participant "ConnectionManager" as CM
participant "WebSocket" as WS
participant "ESP8266" as ESP
participant "Motor Controller" as MC

User -> UI : App starten
activate UI

UI -> CM : initialize()
activate CM

CM -> WS : connect("ws://10.10.10.10:81")
activate WS

WS -> ESP : WebSocket Handshake
activate ESP

ESP --> WS : Connection Accepted
WS --> CM : onConnected()
CM --> UI : connectionStatus = true

UI --> User : "Verbunden" anzeigen

note right of ESP
  ESP8266 läuft als
  Access Point und
  WebSocket Server
end note

deactivate ESP
deactivate WS
deactivate CM
deactivate UI

@enduml
```

## 2. Manuelle Steuerung

```plantuml
@startuml
skinparam backgroundColor #FEFEFE

actor User
participant "Flutter UI" as UI
participant "InputHandler" as IH
participant "ConnectionManager" as CM
participant "CommandQueue" as Queue
participant "WebSocket" as WS
participant "ESP8266" as ESP
participant "CommandParser" as Parser
participant "MotorController" as MC

User -> UI : Taste "W" drücken
activate UI

UI -> IH : handleKeyPress('w')
activate IH

IH -> CM : sendCommand("forward")
activate CM

CM -> Queue : enqueue("forward")
activate Queue
Queue --> CM : queued
deactivate Queue

CM -> WS : send("forward")
activate WS

WS -> ESP : "forward"
activate ESP

ESP -> Parser : parse("forward")
activate Parser

Parser -> MC : setMotors(speed: 1.0, direction: 0)
activate MC

MC --> Parser : OK
deactivate MC

Parser --> ESP : Command executed
deactivate Parser

ESP --> WS : ACK
deactivate ESP

WS --> CM : onMessage(ACK)
deactivate WS

CM --> IH : Command confirmed
deactivate CM

IH --> UI : Update UI
deactivate IH

UI --> User : Visuelles Feedback
deactivate UI

note right of MC
  Motor A: Lenkung
  Motor B: Antrieb
  forward = beide vorwärts
end note

@enduml
```

## 3. Autonomes Fahren

```plantuml
@startuml
skinparam backgroundColor #FEFEFE

actor User
participant "Flutter UI" as UI
participant "ConnectionManager" as CM
participant "WebSocket" as WS
participant "ESP8266" as ESP
participant "CommandParser" as Parser
participant "MotorController" as MC
participant "SensorController" as SC
participant "VL53L0X" as Sensor

User -> UI : "Auto Mode" aktivieren
activate UI

UI -> CM : sendCommand("auto")
activate CM

CM -> WS : send("auto")
activate WS

WS -> ESP : "auto"
activate ESP

ESP -> Parser : parse("auto")
activate Parser

Parser -> MC : enableAutoMode()
activate MC
MC --> Parser : Auto mode ON
deactivate Parser

loop Kontinuierlich (alle 100ms)
    MC -> SC : getDistance()
    activate SC
    
    SC -> Sensor : readDistance()
    activate Sensor
    Sensor --> SC : distance (mm)
    deactivate Sensor
    
    SC --> MC : distance
    deactivate SC
    
    alt Hindernis erkannt (< 200mm)
        MC -> MC : stop()
        MC -> MC : turnRight()
        MC -> MC : forward()
    else Freie Fahrt
        MC -> MC : forward()
    end
    
    MC -> ESP : sensorData(distance)
    ESP -> WS : send(sensorData)
    WS -> CM : onMessage(sensorData)
    CM -> UI : updateSensorDisplay(distance)
    UI --> User : Distanz anzeigen
end

deactivate MC
deactivate ESP
deactivate WS
deactivate CM
deactivate UI

@enduml
```

## 4. Zeichenmodus

```plantuml
@startuml
skinparam backgroundColor #FEFEFE

actor User
participant "DrawingPage" as UI
participant "RouteManager" as RM
participant "ConnectionManager" as CM
participant "WebSocket" as WS
participant "ESP8266" as ESP
participant "MotorController" as MC

User -> UI : Zeichnet Pfad auf Canvas
activate UI

UI -> RM : addPoint(x, y)
activate RM
RM -> RM : calculatePath()
RM --> UI : pathUpdated
deactivate RM

User -> UI : "Start Drawing" drücken
UI -> RM : getCommandSequence()
activate RM

RM -> RM : convertPathToCommands()
RM --> UI : commands[]
deactivate RM

loop Für jeden Command
    UI -> CM : sendCommand(cmd)
    activate CM
    
    CM -> WS : send(cmd)
    activate WS
    
    WS -> ESP : command
    activate ESP
    
    ESP -> MC : executeCommand(cmd)
    activate MC
    MC --> ESP : executed
    deactivate MC
    
    ESP --> WS : ACK
    deactivate ESP
    
    WS --> CM : ACK
    deactivate WS
    
    CM --> UI : commandExecuted
    deactivate CM
    
    UI -> UI : updateProgress()
    UI --> User : Fortschritt anzeigen
    
    UI -> UI : wait(commandDuration)
end

UI --> User : "Zeichnung abgeschlossen"
deactivate UI

note right of RM
  RouteManager konvertiert
  Canvas-Koordinaten in
  Motor-Befehle:
  - forward
  - backward
  - left
  - right
end note

@enduml
```

## 5. Fehlerbehandlung

```plantuml
@startuml
skinparam backgroundColor #FEFEFE

participant "ConnectionManager" as CM
participant "WebSocket" as WS
participant "ESP8266" as ESP
participant "Flutter UI" as UI
actor User

== Verbindungsverlust ==

CM -> WS : send(command)
activate CM
activate WS

WS -x ESP : Connection Lost
note right: Netzwerkfehler

WS --> CM : onError(ConnectionLost)
deactivate WS

CM -> CM : connectionStatus = false
CM -> UI : showError("Verbindung verloren")
activate UI
UI --> User : Fehlermeldung anzeigen
deactivate UI

CM -> CM : startReconnectTimer()

loop Reconnect Attempts (max 5)
    CM -> WS : reconnect()
    activate WS
    
    alt Reconnect erfolgreich
        WS -> ESP : connect()
        activate ESP
        ESP --> WS : Connected
        deactivate ESP
        WS --> CM : onConnected()
        deactivate WS
        CM -> UI : showSuccess("Verbunden")
        activate UI
        UI --> User : "Verbindung wiederhergestellt"
        deactivate UI
    else Reconnect fehlgeschlagen
        WS --> CM : onError()
        deactivate WS
        CM -> CM : wait(2s)
    end
end

alt Max Attempts erreicht
    CM -> UI : showError("Verbindung fehlgeschlagen")
    activate UI
    UI --> User : "Bitte ESP8266 prüfen"
    deactivate UI
end

deactivate CM

@enduml
```

## 6. Sensor-Datenübertragung

```plantuml
@startuml
skinparam backgroundColor #FEFEFE

participant "ESP8266" as ESP
participant "SensorController" as SC
participant "VL53L0X" as Sensor
participant "WebSocket" as WS
participant "ConnectionManager" as CM
participant "Flutter UI" as UI

loop Kontinuierlich (20 Hz)
    ESP -> SC : readSensor()
    activate ESP
    activate SC
    
    SC -> Sensor : getDistance()
    activate Sensor
    
    Sensor -> Sensor : I2C Read
    Sensor --> SC : distance (mm)
    deactivate Sensor
    
    SC --> ESP : sensorData
    deactivate SC
    
    ESP -> ESP : formatJSON()
    note right
      {
        "type": "sensor",
        "distance": 150,
        "timestamp": 12345
      }
    end note
    
    ESP -> WS : send(sensorData)
    activate WS
    
    WS -> CM : onMessage(sensorData)
    activate CM
    
    CM -> CM : parseSensorData()
    CM -> UI : updateSensorDisplay(distance)
    activate UI
    
    UI -> UI : updateVisualization()
    UI -> UI : checkWarnings()
    
    alt Hindernis nah (< 100mm)
        UI -> UI : showWarning()
    end
    
    deactivate UI
    deactivate CM
    deactivate WS
    deactivate ESP
    
    ESP -> ESP : delay(50ms)
end

@enduml
```

---

## Legende

| Symbol | Bedeutung |
|--------|-----------|
| → | Synchroner Aufruf |
| --> | Rückgabe |
| -x | Fehler/Abbruch |
| activate/deactivate | Komponente aktiv |
| loop | Wiederholte Ausführung |
| alt/else | Bedingte Ausführung |
| note | Zusätzliche Information |

---

**Letzte Aktualisierung**: 2026-05-26