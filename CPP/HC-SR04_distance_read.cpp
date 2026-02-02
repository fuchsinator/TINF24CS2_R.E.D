#include <Arduino.h>
// HC-SR04 with ESP8266
// TRIG -> GPIO5 (D1)
// ECHO -> GPIO4 (D2)  (via voltage divider!)

#define TRIG_PIN D1   // GPIO5 (D1)
#define ECHO_PIN D2   // GPIO4 (D2)

long duration;
float distance_cm;

void setup() {
  Serial.begin(115200);

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

  digitalWrite(TRIG_PIN, LOW);
}

void loop() {
  // Send ultrasonic pulse
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);

  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  // Read echo time (timeout added for safety)
  duration = pulseIn(ECHO_PIN, HIGH, 30000); // 30ms timeout

  if (duration == 0) {
    Serial.println("No echo received");
  } else {
    distance_cm = (duration * 0.0343) / 2;
    Serial.print("Distance: ");
    Serial.print(distance_cm);
    Serial.println(" cm");
  }

  delay(500);
}
