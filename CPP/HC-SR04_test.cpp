#include <Arduino.h>
#define TRIG_PIN 5   // GPIO5
#define ECHO_PIN 4   // GPIO4

void setup() {
  Serial.begin(115200);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
}

void loop() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  unsigned long d = pulseIn(ECHO_PIN, HIGH, 30000);

  Serial.print("Echo time: ");
  Serial.print(d);
  Serial.println(" us");

  delay(500);
}

