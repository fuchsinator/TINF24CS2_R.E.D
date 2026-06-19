# Use-Case und Aktivitätsdiagramme - R.E.D. Projekt (Korrigierte Version)

## Inhaltsverzeichnis
- [Use-Case-Diagramm: Gesamtsystem](#use-case-diagramm-gesamtsystem)
- [Use-Case-Diagramm: Manuelle Steuerung](#use-case-diagramm-manuelle-steuerung)
- [Use-Case-Diagramm: Autonomes Fahren](#use-case-diagramm-autonomes-fahren)
- [Aktivitätsdiagramm: Autonomes Fahren](#aktivitätsdiagramm-autonomes-fahren)
- [Aktivitätsdiagramm: Drawing Mode](#aktivitätsdiagramm-drawing-mode)
- [Aktivitätsdiagramm: Verbindungsmanagement](#aktivitätsdiagramm-verbindungsmanagement)

## Use-Case-Diagramm: Gesamtsystem

```plantuml
@startuml

left to right direction

actor "Benutzer" as User
actor "ESP8266" as ESP

rectangle "R.E.D. System" {
  usecase "App starten" as UC1
  usecase "Verbindung herstellen" as UC2
  usecase "Manuell steuern" as UC3
  usecase "Autonom fahren" as UC4
  usecase "Route zeichnen" as UC5
  usecase "Sensordaten anzeigen" as UC6
  usecase "Einstellungen ändern" as UC7
}

User --> UC1
User --> UC2
User --> UC3
User --> UC4
User --> UC5
User --> UC6
User --> UC7

UC2 ..> ESP : <<communicate>>
UC3 ..> ESP : <<communicate>>
UC4 ..> ESP : <<communicate>>
UC5 ..> ESP : <<communicate>>
UC6 ..> ESP : <<communicate>>

UC3 ..> UC2 : <<include>>
UC4 ..> UC2 : <<include>>
UC5 ..> UC2 : <<include>>

@enduml
```

## Use-Case-Diagramm: Manuelle Steuerung

```plantuml
@startuml

left to right direction

actor "Benutzer" as User

rectangle "Manuelle Steuerung" {
  usecase "Vorwärts fahren" as UC1
  usecase "Rückwärts fahren" as UC2
  usecase "Links lenken" as UC3
  usecase "Rechts lenken" as UC4
  usecase "Bremsen" as UC5
  usecase "Geschwindigkeit anpassen" as UC6
  usecase "Notbremse" as UC7
}

User --> UC1
User --> UC2
User --> UC3
User --> UC4
User --> UC5
User --> UC6
User --> UC7

UC1 ..> UC6 : <<include>>
UC2 ..> UC6 : <<include>>
UC3 ..> UC6 : <<include>>
UC4 ..> UC6 : <<include>>

note right of UC6
  Physik-Engine berechnet
  Geschwindigkeit basierend
  auf Beschleunigung und
  Reibung (20 FPS)
end note

@enduml
```

## Use-Case-Diagramm: Autonomes Fahren

```plantuml
@startuml

left to right direction

actor "Benutzer" as User
actor "VL53L0X Sensor" as Sensor

rectangle "Autonomes Fahren" {
  usecase "Autonomen Modus starten" as UC1
  usecase "Hindernisse erkennen" as UC2
  usecase "Ausweichen" as UC3
  usecase "Vorwärts fahren" as UC4
  usecase "Rückwärts fahren" as UC5
  usecase "Drehen" as UC6
  usecase "Notfall-Stop" as UC7
  usecase "Status überwachen" as UC8
}

User --> UC1
User --> UC7
User --> UC8

UC1 ..> UC2 : <<include>>
UC2 ..> UC3 : <<extend>>
UC3 ..> UC5 : <<include>>
UC3 ..> UC6 : <<include>>
UC2 ..> UC4 : <<extend>>

Sensor --> UC2

note right of UC2
  Sensor misst Distanz
  alle 100ms
  Schwellwert: 250mm
end note

@enduml
```

## Aktivitätsdiagramm: Autonomes Fahren

```plantuml
@startuml

start

:Benutzer startet autonomen Modus;

:ESP8266 aktiviert Sensor-Loop;

repeat
  :VL53L0X misst Distanz;
  
  if (Distanz < 250mm?) then (ja)
    :Rückwärts fahren (500ms);
    :Zufällige Drehrichtung wählen;
    :Drehen (300-700ms);
  else (nein)
    :Vorwärts fahren;
  endif
  
  :Sensordaten an App senden;
  :App aktualisiert Anzeige;
  
  :Warte 100ms;
  
repeat while (Modus aktiv?) is (ja)
->nein;

:Motoren stoppen;

stop

@enduml
```

## Aktivitätsdiagramm: Drawing Mode

```plantuml
@startuml

start

:Benutzer öffnet Drawing Mode;

:Canvas wird initialisiert;

partition "Zeichnen" {
  repeat
    :Benutzer berührt Canvas;
    :Punkt wird gespeichert;
    :Linie wird gezeichnet;
  repeat while (Zeichnen aktiv?) is (ja)
  ->nein;
}

:Benutzer drückt "Start";

partition "Route verarbeiten" {
  :Punkte in Befehle umwandeln;
  
  repeat
    :Nächsten Punkt berechnen;
    
    if (Richtungsänderung?) then (ja)
      :Drehbefehl senden;
      :Warte auf Bestätigung;
    endif
    
    :Vorwärts-Befehl senden;
    :Fortschritt aktualisieren;
    
  repeat while (Weitere Punkte?) is (ja)
  ->nein;
}

:Stop-Befehl senden;

:Erfolg anzeigen;

stop

@enduml
```

## Aktivitätsdiagramm: Verbindungsmanagement

```plantuml
@startuml

start

:App wird gestartet;

:ConnectionManager initialisieren;

:WebSocket-Verbindung aufbauen;

if (Verbindung erfolgreich?) then (ja)
  :Status auf "Connected" setzen;
  :Reconnect-Timer zurücksetzen;
  
  partition "Aktive Verbindung" {
    repeat
      :Auf Nachrichten warten;
      
      if (Nachricht empfangen?) then (ja)
        :Nachricht verarbeiten;
        :UI aktualisieren;
      endif
      
      if (Fehler aufgetreten?) then (ja)
        :Fehler loggen;
        :Verbindung trennen;
        stop
      endif
      
    repeat while (Verbindung aktiv?) is (ja)
    ->nein;
  }
  
else (nein)
  :Fehler anzeigen;
endif

:Reconnect-Timer starten;

:Warte (2^n Sekunden);

:Reconnect-Versuch;

if (Max. Versuche erreicht?) then (ja)
  :Fehler anzeigen;
  stop
else (nein)
  :Nächster Versuch;
  backward :WebSocket-Verbindung aufbauen;
endif

@enduml
```

---

## Use-Case-Beschreibungen

### UC1: App starten
**Akteure**: Benutzer  
**Vorbedingung**: App ist installiert  
**Nachbedingung**: App ist gestartet, Hauptmenü wird angezeigt  
**Hauptszenario**:
1. Benutzer öffnet die App
2. System lädt Konfiguration
3. System zeigt Hauptmenü mit drei Optionen

### UC2: Verbindung herstellen
**Akteure**: Benutzer, ESP8266  
**Vorbedingung**: ESP8266 ist eingeschaltet und im WLAN  
**Nachbedingung**: WebSocket-Verbindung ist aktiv  
**Hauptszenario**:
1. Benutzer wählt einen Fahrmodus
2. System baut WebSocket-Verbindung auf (ws://192.168.178.77:81)
3. ESP8266 bestätigt Verbindung
4. System zeigt "Connected" Status

**Alternativszenario**:
- 3a. Verbindung schlägt fehl
  - System startet Reconnect-Timer
  - System versucht erneut nach 2^n Sekunden

### UC3: Manuell steuern
**Akteure**: Benutzer  
**Vorbedingung**: Verbindung ist aktiv  
**Nachbedingung**: Fahrzeug hat sich bewegt  
**Hauptszenario**:
1. Benutzer drückt Taste (W/A/S/D)
2. System startet Physik-Engine
3. System sendet Befehle an ESP8266
4. ESP8266 steuert Motoren
5. System aktualisiert Geschwindigkeitsanzeige

### UC4: Autonom fahren
**Akteure**: Benutzer, VL53L0X Sensor  
**Vorbedingung**: Verbindung ist aktiv, Sensor funktioniert  
**Nachbedingung**: Fahrzeug fährt autonom  
**Hauptszenario**:
1. Benutzer startet autonomen Modus
2. ESP8266 aktiviert Sensor-Loop
3. System misst kontinuierlich Distanz
4. System weicht Hindernissen aus
5. System sendet Sensordaten an App

**Alternativszenario**:
- 3a. Sensor-Fehler
  - System zeigt Fehlermeldung
  - System stoppt autonomen Modus

### UC5: Route zeichnen
**Akteure**: Benutzer  
**Vorbedingung**: Verbindung ist aktiv  
**Nachbedingung**: Fahrzeug folgt gezeichneter Route  
**Hauptszenario**:
1. Benutzer zeichnet Route auf Canvas
2. System speichert Punkte
3. Benutzer startet Route
4. System konvertiert Punkte in Befehle
5. System sendet Befehle sequenziell
6. System zeigt Fortschritt

---

**Letzte Aktualisierung**: 2026-05-26
