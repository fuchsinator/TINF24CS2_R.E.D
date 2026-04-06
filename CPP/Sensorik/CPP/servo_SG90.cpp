#include <Servo.h>

Servo myservo;

void setup() {
  Serial.begin(115200);
  myservo.attach(D4);
}

void loop() {
  int i = 0;
  while(i<1){
    i++;
    myservo.write(0);
    delay(800);
    myservo.write(90);
    myservo.write(180);
    delay(800);
    myservo.write(90);
  }
  delay(4000);
}
