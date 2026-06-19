# 📚 Dokumentations-Index - R.E.D. Projekt

Willkommen zur vollständigen Dokumentation des R.E.D. (Remote Electric Drive) Projekts!

## 🗂️ Dokumentationsstruktur

### 1. 📖 Hauptdokumentation
**Datei**: [`../README.md`](../README.md)

**Inhalt**:
- Projektübersicht
- Features und Fahrmodi
- Systemarchitektur (Übersicht)
- Technologie-Stack
- Installation und Setup
- Verwendung
- Team und Projektstatus

**Für wen**: Alle - Einstieg ins Projekt

---

### 2. 🏗️ Systemarchitektur
**Datei**: [`Architektur.md`](Architektur.md)

**Inhalt**:
- Detaillierte Systemarchitektur-Diagramme
- Komponentendiagramm
- Deployment-Diagramm
- Netzwerkarchitektur
- Datenfluss-Diagramme
- Schichtenarchitektur
- Design Patterns
- Performance-Metriken

**Diagramme**: 6 PlantUML-Diagramme
**Für wen**: Entwickler, Architekten

---

### 3. 🔄 Sequenzdiagramme
**Datei**: [`Sequenzdiagramme.md`](Sequenzdiagramme.md)

**Inhalt**:
- WebSocket-Verbindungsaufbau
- Manuelle Steuerung (Driving Mode)
- Autonomes Fahren
- Drawing Mode
- Fehlerbehandlung und Reconnect
- Sensor-Datenübertragung
- Multi-Command Sequenz
- Timing-Diagramm

**Diagramme**: 7 PlantUML-Sequenzdiagramme
**Für wen**: Entwickler, die Abläufe verstehen wollen

---

### 4. 📦 Klassendiagramme
**Datei**: [`Klassendiagramme.md`](Klassendiagramme.md)

**Inhalt**:
- Flutter App - Vollständiges Klassendiagramm
- ConnectionManager - Detailansicht
- UI-Komponenten
- ESP8266 Firmware - Klassenstruktur
- Datenmodelle
- Vererbungshierarchie

**Diagramme**: 6 PlantUML-Klassendiagramme
**Für wen**: Entwickler, Code-Reviewer

---

### 5. 🎯 Use-Cases und Aktivitäten
**Datei**: [`Use-Cases-und-Aktivitaeten.md`](Use-Cases-und-Aktivitaeten.md)

**Inhalt**:
- Use-Case-Diagramm (Gesamtsystem)
- Detaillierte Use-Case-Beschreibungen
- Aktivitätsdiagramme:
  - Manuelle Steuerung
  - Autonomes Fahren
  - Route zeichnen und abfahren
  - Verbindungsmanagement
- Zustandsdiagramme:
  - Verbindungsstatus
  - Fahrzeugzustand
  - Autonomer Modus

**Diagramme**: 8 PlantUML-Diagramme
**Für wen**: Product Owner, Tester, Entwickler

---

### 6. 🔧 Technische Dokumentation
**Datei**: [`Technische-Dokumentation.md`](Technische-Dokumentation.md)

**Inhalt**:
- API-Dokumentation (WebSocket-Protokoll)
- Hardware-Dokumentation:
  - Komponenten-Liste
  - Schaltplan
  - Pin-Belegung
  - Sensor-Konfiguration
  - Motor-Steuerung
  - Stromversorgung
- Entwickler-Guide:
  - Entwicklungsumgebung
  - Code-Struktur
  - Coding Standards
  - Git Workflow
- Performance-Optimierung
- Troubleshooting

**Für wen**: Entwickler, Hardware-Ingenieure

---

### 7. 🧪 Test-Dokumentation
**Datei**: [`Test-Dokumentation.md`](Test-Dokumentation.md)

**Inhalt**:
- Test-Strategie und Test-Pyramide
- Test-Kategorien und Coverage-Ziele
- Flutter Tests (Setup und Struktur)
- ESP8266 Tests (Setup und Struktur)
- Integration Tests
- Test-Ausführung (Befehle)
- Continuous Integration

**Für wen**: Tester, QA, Entwickler

---

### 8. ▶️ Test-Ausführung Anleitung
**Datei**: [`Test-Ausfuehrung-Anleitung.md`](Test-Ausfuehrung-Anleitung.md)

**Inhalt**:
- Schritt-für-Schritt Anleitungen
- Flutter Tests ausführen
- ESP8266 Tests ausführen
- Diagramme visualisieren
- Troubleshooting
- Test-Checkliste
- Schnellstart-Guide

**Für wen**: Alle, die Tests ausführen wollen

---

## 📊 Diagramm-Übersicht

### Gesamt: 27 UML-Diagramme

| Typ | Anzahl | Dateien |
|-----|--------|---------|
| Systemarchitektur | 6 | Architektur.md |
| Sequenzdiagramme | 7 | Sequenzdiagramme.md |
| Klassendiagramme | 6 | Klassendiagramme.md |
| Use-Case-Diagramme | 1 | Use-Cases-und-Aktivitaeten.md |
| Aktivitätsdiagramme | 4 | Use-Cases-und-Aktivitaeten.md |
| Zustandsdiagramme | 3 | Use-Cases-und-Aktivitaeten.md |

### Diagramme visualisieren

**Methode 1: VS Code Extension**
1. Installiere "PlantUML" Extension
2. Öffne eine .md Datei
3. Drücke `Alt+D` (Windows/Linux) oder `Cmd+D` (macOS)

**Methode 2: Online**
- Gehe zu: http://www.plantuml.com/plantuml/uml/
- Kopiere PlantUML-Code aus Dokumentation
- Füge ein und klicke "Submit"

**Methode 3: Lokal**
```bash
java -jar plantuml.jar Dokumentation/*.md
```

---

## 🧪 Test-Dateien

### Flutter Tests

```
Flutter/test/
├── unit/
│   ├── connection_manager_test.dart  (11 Tests)
│   └── physics_test.dart             (21 Tests)
├── widget/
│   └── (zu erstellen)
└── integration/
    └── (zu erstellen)
```

**Ausführen**:
```bash
cd Flutter
flutter test
```

### ESP8266 Tests

```
CPP/test/
├── test_motors.cpp    (14 Tests)
└── test_sensor.cpp    (12 Tests)
```

**Ausführen**:
```bash
cd CPP
pio test
```

---

## 🎯 Schnellzugriff

### Für Entwickler
1. Start: [`../README.md`](../README.md)
2. Architektur: [`Architektur.md`](Architektur.md)
3. Klassen: [`Klassendiagramme.md`](Klassendiagramme.md)
4. API: [`Technische-Dokumentation.md`](Technische-Dokumentation.md#api-dokumentation)

### Für Tester
1. Test-Strategie: [`Test-Dokumentation.md`](Test-Dokumentation.md)
2. Test-Ausführung: [`Test-Ausfuehrung-Anleitung.md`](Test-Ausfuehrung-Anleitung.md)
3. Troubleshooting: [`Test-Ausfuehrung-Anleitung.md`](Test-Ausfuehrung-Anleitung.md#troubleshooting)

### Für Hardware-Ingenieure
1. Hardware-Doku: [`Technische-Dokumentation.md`](Technische-Dokumentation.md#hardware-dokumentation)
2. Schaltplan: [`Technische-Dokumentation.md`](Technische-Dokumentation.md#schaltplan)
3. Pin-Belegung: [`Technische-Dokumentation.md`](Technische-Dokumentation.md#pin-belegung-esp8266)

### Für Product Owner
1. Features: [`../README.md`](../README.md#features)
2. Use-Cases: [`Use-Cases-und-Aktivitaeten.md`](Use-Cases-und-Aktivitaeten.md)
3. Status: [`../README.md`](../README.md#projektstatus)

---

## 📈 Dokumentations-Statistiken

| Metrik | Wert |
|--------|------|
| Gesamt-Dateien | 8 |
| Gesamt-Zeilen | ~5.000 |
| UML-Diagramme | 27 |
| Code-Beispiele | 50+ |
| Test-Dateien | 4 |
| Gesamt-Tests | 58 |

---

## 🔄 Aktualisierungen

| Datum | Version | Änderungen |
|-------|---------|------------|
| 2026-05-26 | 1.0.0 | Initiale vollständige Dokumentation |
| | | - Alle Diagramme erstellt |
| | | - Tests implementiert |
| | | - Anleitungen geschrieben |

---

## 📝 Dokumentations-Richtlinien

### Für Mitwirkende

Wenn du die Dokumentation aktualisierst:

1. **Markdown-Format** verwenden
2. **PlantUML** für Diagramme
3. **Code-Beispiele** mit Syntax-Highlighting
4. **Screenshots** im PNG-Format
5. **Versionierung** im Git

### Dokumentations-Template

```markdown
# Titel

## Inhaltsverzeichnis
- [Abschnitt 1](#abschnitt-1)
- [Abschnitt 2](#abschnitt-2)

## Abschnitt 1

Beschreibung...

### Code-Beispiel

\`\`\`dart
// Code hier
\`\`\`

### Diagramm

\`\`\`plantuml
@startuml
// PlantUML Code
@enduml
\`\`\`

---

**Letzte Aktualisierung**: YYYY-MM-DD
```

---

## 🤝 Beitragen

Verbesserungsvorschläge für die Dokumentation?

1. Issue auf GitHub erstellen
2. Pull Request mit Änderungen
3. Dokumentation reviewen lassen
4. Merge nach Approval

---

## 📞 Kontakt

**Team**: TINF24CS2 - DHBW

**Projekt-Repository**: GitHub (Link einfügen)

**Fragen?** Erstelle ein Issue oder kontaktiere das Team.

---

**Viel Erfolg mit dem R.E.D. Projekt! 🚗💨**

---

**Letzte Aktualisierung**: 2026-05-26