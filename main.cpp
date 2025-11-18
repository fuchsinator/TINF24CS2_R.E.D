#include <Arduino.h>
#include <random>

//Gets the html main page from file
#define String main_html = #include "html\\main_page.html"

//set debugging on/off
#define DEBUGGING true

//set Baudrate
#define BAUD 115200

//set global vars
#define SOUND_VELOCITY 0.034
//Pins for HC-SR04 (Sonar sensor)
const int trigPin = D6;
const int echoPin = D5;
//Pins for driving
//Motor A (front)
const int Motor_A_blue = D1;
const int Motor_A_white = D3;
//Motor B (back)
const int Motor_B_yellow = D4;
const int Motor_B_green = D2;


void setup() {
  Serial.begin(BAUD);
  //Pins for HC-SR04 (Sonar sensor)
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  //Pins for driving
  pinMode(Motor_A_blue, OUTPUT);
  digitalWrite(Motor_A_blue, LOW);
  pinMode(Motor_A_white, OUTPUT);
  digitalWrite(Motor_A_white, LOW);
  pinMode(Motor_B_yellow, OUTPUT);
  digitalWrite(Motor_B_yellow, LOW);
  pinMode(Motor_B_green, OUTPUT);
  digitalWrite(Motor_B_green, LOW);
}

float get_distance_from_Sonar(){
  long duration = 0;
  //clear trigger pin
  digitalWrite(trigPin, LOW);
  //Time of an interval
  delayMicroseconds(2);
  //Admit a soundwave for 10 microseconds from trigger pin
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
  
  //gets durations from the echo pin and calculate the distance
  duration = pulseIn(echoPin, HIGH);
  float distanceCm = duration * SOUND_VELOCITY/2;

  //print debugging info in serial connection
  if(DEBUGGING){
    Serial.print("Distance in CM: ");
    Serial.println(distanceCm);
  }

  //retruns the distance in cm as float
  return distanceCm;
}


/*Drive function:
  Turn: no turn = 0; left = 1; right = 2
  direction: forwards = 0; backwards = 1
  speed: from 1-100
  duration: in ms
*/
void drive(int direction, int turn, int speed, int duration){
  if(direction == 0) //drive forwards
  {
    digitalWrite(Motor_B_yellow, LOW);
  }else if (direction == 1) //drive backwards
  {
    digitalWrite(Motor_B_yellow, HIGH);
  }else
  {
    if(DEBUGGING){
      Serial.print("no direction option set");
    }
  }
  if(turn == 0) //no turn
  {
  }else if (turn == 1) //turn left
  {
    digitalWrite(Motor_A_white, LOW);
  }else if (turn == 2) //turn right
  {
    digitalWrite(Motor_A_white, HIGH);
  }else
  {
    if(DEBUGGING){
      Serial.print("no turning option set");
    }
  }
  for(int i = 0; i<=100; i++){
    digitalWrite(Motor_A_blue, HIGH);
    delay(duration/100*(100-speed)/100 );
    digitalWrite(Motor_B_green, HIGH);
    delay(duration/100*speed/100);
    digitalWrite(Motor_B_green, LOW);
  }
  digitalWrite(Motor_A_blue, LOW);
}

void loop() {
  //drive(0, 1, 50, 2000);
  digitalWrite(Motor_A_white, LOW);
  digitalWrite(Motor_A_blue, HIGH);
  digitalWrite(Motor_A_white, HIGH);
  digitalWrite(Motor_A_blue, HIGH);
  delay(1000);
}
