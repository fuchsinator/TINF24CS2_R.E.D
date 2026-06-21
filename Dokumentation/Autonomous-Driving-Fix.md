# Autonomous Driving - Obstacle Avoidance Fix

## *DOKU* Änderungsdokumentation
**Datum:** 19.06.2026  
**Autor:** Alexa van der Meulen  
**Datei:** `CPP/main.cpp`  
**Funktion:** `set_autoDrive(int dist)`  
**Status:** *WARNUNG* REVIEW BENÖTIGT

---

## *BUG* Problem-Analyse

### Ursprüngliches Problem
Der autonome Fahrmodus erkannte zwar Hindernisse, **fuhr aber nicht um sie herum**:

```cpp
// VORHER - FEHLERHAFT
int set_autoDrive(int dist) {
  if (dist < 250 && dist > 50){
    Serial.println("Backwards");
    turnBool = !turnBool;
    drive(2, 0);        // *NEU* Nur rückwärts, KEIN Lenken!
    delay(100);         // *NEU* Zu kurz
  } else {
    Serial.println("Forwards");
    drive(1, 0);
  }
  return 0;
}
```

### Identifizierte Fehler

| # | Problem | Impact | Priorität |
|---|---------|--------|-----------|
| 1 | **Kein Lenkbefehl** | Auto fährt direkt wieder ins Hindernis | *KRITISCH* KRITISCH |
| 2 | `turnBool` nicht verwendet | Variable wird gesetzt aber ignoriert | *KRITISCH* KRITISCH |
| 3 | Zu kurze Rückwärts-Zeit (100ms) | Nicht genug Abstand zum Hindernis | *HOCH* HOCH |
| 4 | Keine Distanz-Differenzierung | Gleiche Reaktion bei 6cm und 24cm | *HOCH* MITTEL |
| 5 | Endlosschleifen-Gefahr | Kann in Ecken stecken bleiben | *HOCH* MITTEL |

### Beobachtetes Verhalten
```
1. Auto fährt vorwärts
2. Hindernis bei 25cm erkannt
3. Auto fährt 100ms rückwärts (ohne zu lenken)
4. Auto fährt wieder vorwärts
5. *NEIN* Fährt direkt wieder ins gleiche Hindernis
6. *SCHLEIFE* Endlosschleife
```

---

## *JA* Implementierte Lösung

### Neue Logik mit abgestufter Reaktion

```cpp
int set_autoDrive(int dist) {
  //When car detects obstacle: drive backwards, turn, then continue
  
  if (dist < 100 && dist > 50) {
    // EMERGENCY: Very close (5-10cm) - strong avoidance
    Serial.println("EMERGENCY - Too close! Strong avoidance");
    
    // 1. Drive backwards
    drive(2, 0);
    delay(500);  // Longer reverse to create distance
    
    // 2. Turn (alternating left/right using turnBool)
    drive(0, turnBool ? 1 : 2);  // 1 = left, 2 = right
    delay(600);  // Time to turn significantly
    
    // 3. Toggle direction for next obstacle
    turnBool = !turnBool;
    
  } else if (dist < 250 && dist >= 100) {
    // WARNING: Medium distance (10-25cm) - normal avoidance
    Serial.println("Warning - Obstacle ahead, avoiding");
    
    // 1. Drive backwards
    drive(2, 0);
    delay(300);  // Medium reverse
    
    // 2. Turn (alternating left/right using turnBool)
    drive(0, turnBool ? 1 : 2);  // 1 = left, 2 = right
    delay(400);  // Time to turn
    
    // 3. Toggle direction for next obstacle
    turnBool = !turnBool;
    
  } else {
    // CLEAR: No obstacle (> 25cm) - drive forward
    Serial.println("Clear - Moving forward");
    drive(1, 0);
  }
  
  return 0;
}
```

---

## *FIX* Änderungen im Detail

### 1. **Lenkbefehle hinzugefügt** *JA*
```cpp
drive(0, turnBool ? 1 : 2);  // *NEU* NEU: Lenken nach rückwärts
```
- Parameter 1: `0` = kein Vorwärts/Rückwärts
- Parameter 2: `1` = links, `2` = rechts
- `turnBool` wechselt zwischen links/rechts

### 2. **turnBool wird jetzt verwendet** *JA*
```cpp
drive(0, turnBool ? 1 : 2);  // *NEU* Verwendet turnBool für Richtung
turnBool = !turnBool;         // *NEU* Wechselt für nächstes Mal
```

### 3. **Längere Zeiten** *JA*
| Aktion | Vorher | Nachher | Grund |
|--------|--------|---------|-------|
| Rückwärts (Notfall) | 100ms | 500ms | Mehr Abstand schaffen |
| Lenken (Notfall) | 0ms | 600ms | Zeit zum Drehen |
| Rückwärts (Normal) | 100ms | 300ms | Ausreichend Abstand |
| Lenken (Normal) | 0ms | 400ms | Zeit zum Drehen |

### 4. **Abgestufte Reaktion** *JA*
```
Distanz < 10cm  *DANN* NOTFALL: 500ms rückwärts + 600ms lenken
Distanz 10-25cm *DANN* WARNUNG: 300ms rückwärts + 400ms lenken
Distanz > 25cm  *DANN* FREI: Vorwärts fahren
```

---

## *ZIEL* Erwartetes Verhalten (nach Fix)

### Szenario 1: Hindernis bei 8cm (Notfall)
```
1. Sensor misst 8cm
2. "EMERGENCY - Too close! Strong avoidance"
3. Rückwärts fahren (500ms)
4. Lenken links (600ms) [beim ersten Mal]
5. Vorwärts fahren
6. *JA* Hindernis umfahren
```

### Szenario 2: Hindernis bei 20cm (Warnung)
```
1. Sensor misst 20cm
2. "Warning - Obstacle ahead, avoiding"
3. Rückwärts fahren (300ms)
4. Lenken rechts (400ms) [beim zweiten Mal, da turnBool gewechselt]
5. Vorwärts fahren
6. *JA* Hindernis umfahren
```

### Szenario 3: Freie Fahrt (> 25cm)
```
1. Sensor misst 50cm
2. "Clear - Moving forward"
3. Vorwärts fahren
4. *JA* Weiterfahren
```

---

## *WARNUNG* Zu testende Szenarien

### Test 1: Einzelnes Hindernis
- [ ] Auto fährt auf Wand zu
- [ ] Stoppt bei 25cm
- [ ] Fährt rückwärts
- [ ] Lenkt (links oder rechts)
- [ ] Fährt weiter ohne erneute Kollision

### Test 2: Mehrere Hindernisse
- [ ] Auto weicht erstem Hindernis nach links aus
- [ ] Auto weicht zweitem Hindernis nach rechts aus (turnBool gewechselt)
- [ ] Abwechselndes Verhalten funktioniert

### Test 3: Enge Ecke
- [ ] Auto erkennt Hindernis vorne
- [ ] Weicht aus
- [ ] Findet Weg aus Ecke (durch abwechselndes Lenken)

### Test 4: Notfall vs. Warnung
- [ ] Bei 8cm: Längere Reaktion (500ms + 600ms)
- [ ] Bei 20cm: Kürzere Reaktion (300ms + 400ms)
- [ ] Unterschiedliches Verhalten erkennbar

---

## *ANALYSE* Code-Review Checkliste

### Funktionalität
- [ ] Lenkbefehle korrekt implementiert?
- [ ] `turnBool` wird verwendet?
- [ ] Zeiten ausreichend lang?
- [ ] Abgestufte Reaktion sinnvoll?

### Logik
- [ ] Distanz-Schwellwerte korrekt? (100mm = 10cm, 250mm = 25cm)
- [ ] `drive()` Parameter korrekt? (direction, turn)
- [ ] `turnBool` Toggle-Logik korrekt?

### Edge Cases
- [ ] Was passiert bei `dist < 50mm`? (Zu nah, Sensor-Minimum)
- [ ] Was passiert bei `dist > 8000mm`? (Sensor-Maximum)
- [ ] Was passiert bei Sensor-Timeout? (return -1)

### Performance
- [ ] `delay()` Zeiten nicht zu lang? (blockiert Loop)
- [ ] Sensor-Auslesen schnell genug?
- [ ] `yield()` im Loop vorhanden? *JA* (Zeile 186)

---

## *STATISTIK* Vergleich Vorher/Nachher

| Aspekt | Vorher | Nachher |
|--------|--------|---------|
| **Lenken** | *NEIN* Nein | *JA* Ja (links/rechts abwechselnd) |
| **turnBool Nutzung** | *NEIN* Nicht verwendet | *JA* Verwendet für Richtung |
| **Rückwärts-Zeit** | 100ms | 300-500ms (abgestuft) |
| **Lenk-Zeit** | 0ms | 400-600ms (abgestuft) |
| **Distanz-Stufen** | 1 (5-25cm) | 2 (5-10cm, 10-25cm) |
| **Umfahren möglich** | *NEIN* Nein | *JA* Ja (theoretisch) |

---

## *ALARM* Bekannte Einschränkungen

### 1. Keine Rückwärts-Sensor
- Auto kann beim Rückwärtsfahren gegen Hindernisse fahren
- **Risiko:** Stecken bleiben zwischen zwei Hindernissen

### 2. Nur Frontsensor
- Keine 360° Sicht
- **Risiko:** Seitliche Hindernisse werden nicht erkannt

### 3. Blocking Delays
- `delay()` blockiert kompletten Loop
- **Risiko:** Keine WebSocket-Befehle während Ausweichmanöver

### 4. Keine Pfadplanung
- Rein reaktiv, keine Vorausplanung
- **Risiko:** Kann in komplexen Umgebungen stecken bleiben

---

## *IDEE* Mögliche Verbesserungen (Future)

### Kurzfristig
1. **Rückwärts-Sensor hinzufügen** *DANN* Sicheres Rückwärtsfahren
2. **Delay-Zeiten kalibrieren** *DANN* Optimale Werte durch Tests finden
3. **Stuck-Detection** *DANN* Erkennen wenn Auto stecken bleibt

### Mittelfristig
1. **Non-blocking Delays** *DANN* `millis()` statt `delay()`
2. **State Machine** *DANN* Saubere Zustandsverwaltung
3. **Mehrere Sensoren** *DANN* 360° Sicht

### Langfristig
1. **Pfadplanung** *DANN* A* oder ähnlicher Algorithmus
2. **Mapping** *DANN* Raum kartieren
3. **Lernende Algorithmen** *DANN* Verhalten optimieren

---

## *NOTIZ* Test-Protokoll (auszufüllen)

### Hardware-Setup
- [ ] ESP8266 funktioniert
- [ ] VL53L0X Sensor verbunden (SDA: D6, SCL: D5)
- [ ] Motoren funktionieren (Motor A: Lenken, Motor B: Fahren)
- [ ] Batterie geladen

### Software-Setup
- [ ] Code kompiliert ohne Fehler
- [ ] Upload auf ESP8266 erfolgreich
- [ ] Serial Monitor zeigt Distanz-Werte
- [ ] WebSocket-Verbindung funktioniert

### Test-Durchführung
**Datum:** ___________  
**Tester:** ___________

| Test | Ergebnis | Notizen |
|------|----------|---------|
| Einzelnes Hindernis | *OFFEN* Pass / *OFFEN* Fail | |
| Mehrere Hindernisse | *OFFEN* Pass / *OFFEN* Fail | |
| Enge Ecke | *OFFEN* Pass / *OFFEN* Fail | |
| Notfall vs. Warnung | *OFFEN* Pass / *OFFEN* Fail | |

### Beobachtungen
```
[Hier Notizen eintragen]
```

---

## *REVIEW* Review Request

**An:** Team R.E.D. (Sebastian, Jonathan, Vera)  
**Von:** Alexa  
**Betreff:** Code-Review: Autonomous Driving Obstacle Avoidance

Hallo zusammen,

ich habe den autonomen Fahrmodus überarbeitet, da das Auto vorher **nicht um Hindernisse herumgefahren ist**.

**Hauptproblem:** Es fehlten die Lenkbefehle - das Auto fuhr nur rückwärts und dann direkt wieder ins gleiche Hindernis.

**Was ich geändert habe:**
1. *JA* Lenkbefehle hinzugefügt (`drive(0, turnBool ? 1 : 2)`)
2. *JA* `turnBool` wird jetzt verwendet (abwechselnd links/rechts)
3. *JA* Längere Zeiten (300-500ms rückwärts, 400-600ms lenken)
4. *JA* Abgestufte Reaktion (Notfall < 10cm, Warnung 10-25cm)

**Bitte prüft:**
- Sind die Distanz-Schwellwerte sinnvoll? (100mm, 250mm)
- Sind die Zeiten ausreichend? (300-600ms)
- Funktioniert die Logik theoretisch?
- Seht ihr Edge Cases die ich übersehen habe?

**Datei:** `CPP/main.cpp`, Funktion `set_autoDrive()`

Wäre super wenn ihr mal drüberschauen könntet, bevor wir es testen! *AUTO*

Danke!  
Alexa

---

**Status:** *WARNUNG* WARTET AUF REVIEW  
**Nächster Schritt:** Hardware-Test nach Review