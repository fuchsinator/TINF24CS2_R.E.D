#include <Wire.h>
#include <VL53L0X.h>

//Diagramm
/*
TOF200c-VL53L0X -> ESP8266
VIN -> 3v3
GND -> GND
SDA -> D2
SCL -> D1
*/

VL53L0X sensor;

void sensor_init(bool long_range, bool high_speed) {
  Wire.begin(D2, D1);   // SDA, SCL
  delay(100);           // let sensor boot

  sensor.setTimeout(500);

  if (!sensor.init()) {
    Serial.println("VL53L0X init FAILED");
    while (1) {
      delay(1000);
      yield();          // keep WDT happy
    }
  }

  if (long_range) {
    sensor.setSignalRateLimit(0.1);
    sensor.setVcselPulsePeriod(
      VL53L0X::VcselPeriodPreRange, 18);
    sensor.setVcselPulsePeriod(
      VL53L0X::VcselPeriodFinalRange, 14);
  }

  uint32_t budget = high_speed ? 20000 : 200000;
  sensor.setMeasurementTimingBudget(budget);
}

int get_distance() {
  int d = sensor.readRangeSingleMillimeters();
  if (sensor.timeoutOccurred()) {
    Serial.println("Sensor timeout");
    return -1;
  }
  return d;
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\nBooting…");
  sensor_init(true, false);
}

void loop() {
  int d = get_distance();
  if (sensor.timeoutOccurred() || d >= 8190) {
    // ungültige Messung
    Serial.println("kein Echo");
  } else {
    Serial.print(d);
    Serial.println(" mm");
  }
  delay(10);
  yield();
}
