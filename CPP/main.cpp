#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <WebSocketsServer.h>
#include <Wire.h>
#include <VL53L0X.h>

VL53L0X sensor;

// WIFI parameters
#define WIFI_SSID "R.E.D"
IPAddress apIP(10,10,10,10);
WebSocketsServer ws(81); // WebSocket port

// Motor pins
const int Motor_A_white = D1; // On/Off
const int Motor_A_blue = D3;  // Direction
const int Motor_B_green = D2; // On/Off
const int Motor_B_yellow = D4;// Direction

//TOF200c-VL53L0X 
const int SDA_green = D6;// SDA
const int SCL_white = D5;// SCL

// Current motor state
int currentDirection = 0; // 0 = stop, 1 = forward, 2 = backward
int currentTurn = 0;      // 0 = straight, 1 = left, 2 = right

// autonomous mode state
bool currentMode = 0; // 0 = manual, 1 = autonomous
bool turnBool = 1; // for autonomous turning

//time the motors will drive in ms per command (default 10)
int driveTime = 10;

//Check if Sensor is on, has to be clicked in Flutter with Popup
bool sensorMode = 0;

#define DEBUGGING true

void handleWSEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t len) {
  if(type == WStype_TEXT) {
    String msg = String((char*)payload);
    Serial.println("WS recv: "+msg);
    // parse exactly as HTTP handler did:
    if(msg.indexOf("forward")>=0) currentDirection=1;
    if(msg.indexOf("backward")>=0) currentDirection=2;
    if(msg.indexOf("left")>=0) currentTurn=1;
    if(msg.indexOf("right")>=0) currentTurn=2;
    if(msg.indexOf("stop")>=0){ currentDirection=0; currentTurn=0;}
    if(msg.indexOf("auto")>=0) currentMode=1;
    if(msg.indexOf("autoStop")>=0) currentMode=0;
    if(msg.indexOf("sensorOn")>=0) sensorMode=1;
    if(msg.indexOf("sensorOff")>=0) sensorMode=0;
    ws.sendTXT(num, "ACK");           // optional ack
  }
}

/*Drive function:#
  direction: no move = 0; forwards = 1; backwards = 2
  turn: no turn = 0; left = 1; right = 2
*/
void drive(int direction, int turn){
  //turning
  if(turn == 0) //no turn
  {
    digitalWrite(Motor_A_white, LOW);
  }else if (turn == 1) //left
  {
    digitalWrite(Motor_A_white, HIGH);
    digitalWrite(Motor_A_blue, HIGH);
  }else if (turn == 2) //right
  {
    digitalWrite(Motor_A_white, HIGH);
    digitalWrite(Motor_A_blue, LOW);
  }else
  {
    if(DEBUGGING){
      Serial.print("no turning option set");
    }
  }
  //driving
  if(direction == 0) // no move
  {
    digitalWrite(Motor_B_green, LOW);
  }else if(direction == 1) //forwards
  {
    digitalWrite(Motor_B_green, HIGH);
    digitalWrite(Motor_B_yellow, LOW);
  }else if (direction == 2) //backwards
  {
    digitalWrite(Motor_B_green, HIGH);
    digitalWrite(Motor_B_yellow, HIGH);
  }else
  {
    if(DEBUGGING){
      Serial.print("no direction option set");
    }
  }
  delay(driveTime);
}

void sensor_init(bool long_range, bool high_speed) {
  if(sensorMode){
    Wire.begin(SDA_green, SCL_white);   // SDA, SCL
    delay(1000);           // let sensor boot

    sensor.setTimeout(500);

    if (!sensor.init()) {
      Serial.println("VL53L0X init FAILED");
      while (1) {
        delay(10);
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
}

int get_distance() {
  int dist = sensor.readRangeSingleMillimeters();
  if (sensor.timeoutOccurred()) {
    Serial.println("Sensor timeout");
    return -1;
  }
  return dist;
}

int set_autoDrive(int dist) {
  //When car 20cm away from obsticle cars drives backwards and turns 
  if (dist < 250 && dist > 50){
    Serial.println("Backwards");
    turnBool = !turnBool;
    drive(2, 0);
    delay(100);
  }else{
    Serial.println("Forwards");
    drive(1,0);
  }
  return 0;
}

void setup() {
  Serial.begin(115200);

  sensor_init(true, false);
  Serial.println("All good with sensor!");

  // Motor pins
  pinMode(Motor_A_white, OUTPUT); digitalWrite(Motor_A_white, LOW);
  pinMode(Motor_A_blue, OUTPUT);  digitalWrite(Motor_A_blue, LOW);
  pinMode(Motor_B_green, OUTPUT); digitalWrite(Motor_B_green, LOW);
  pinMode(Motor_B_yellow, OUTPUT);digitalWrite(Motor_B_yellow, LOW);

  // Setup AP
  WiFi.mode(WIFI_AP);
  WiFi.softAPConfig(apIP,apIP, IPAddress(255,255,255,0));
  WiFi.softAP(WIFI_SSID);
  ws.begin();
  ws.onEvent(handleWSEvent);

  if(DEBUGGING){
    Serial.println("ESP8266 server is online");
    Serial.printf("WiFi AP SSID: %s, IP: %s\n", WIFI_SSID, WiFi.softAPIP().toString().c_str());
  }
}

void loop() {
  ws.loop();
  if (currentMode && sensorMode){
    currentDirection = 1;
    currentTurn = 0;
    int dist = get_distance();
    set_autoDrive(dist);
    Serial.println(dist);
    yield();
  }else{
    drive(currentDirection,currentTurn);
  }
}