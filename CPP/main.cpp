#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>

// WIFI parameters
#define WIFI_SSID "R.E.D"
IPAddress apIP(10, 10, 10, 10); // IP of the ESP AP
ESP8266WebServer webServer(80);  // HTTP server

// Motor pins
const int Motor_A_white = D1; // On/Off
const int Motor_A_blue = D3;  // Direction
const int Motor_B_green = D2; // On/Off
const int Motor_B_yellow = D4;// Direction

// Current motor state
int currentDirection = 0; // 0 = stop, 1 = forward, 2 = backward
int currentTurn = 0;      // 0 = straight, 1 = left, 2 = right

#define DEBUGGING true

// Function to handle /move requests
void handleMove() {
  if (!webServer.hasArg("cmd")) {
    webServer.send(400, "text/plain", "No command provided");
    if(DEBUGGING) Serial.println("Received /move request but no cmd argument");
    return;
  }

  String cmds = webServer.arg("cmd"); // e.g., "forward,left"
  if(DEBUGGING){
    Serial.print("Received command(s): ");
    Serial.println(cmds);
  }

  if (cmds.indexOf("forward") >= 0) currentDirection = 1;
  if (cmds.indexOf("backward") >= 0) currentDirection = 2;
  if (cmds.indexOf("left") >= 0) currentTurn = 1;
  if (cmds.indexOf("right") >= 0) currentTurn = 2;
  if (cmds.indexOf("stop") >= 0){
    currentDirection = 0;
    currentTurn = 0;
  }

  if(DEBUGGING){
    Serial.print("Parsed direction: ");
    Serial.print(currentDirection);
    Serial.print(", turn: ");
    Serial.println(currentTurn);
  }

  // **Add CORS header**
  webServer.sendHeader("Access-Control-Allow-Origin", "*"); // Allow any origin
  webServer.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  webServer.sendHeader("Access-Control-Allow-Headers", "Content-Type");

  webServer.send(200, "text/plain", "OK");
}

// Minimal drive function
/*Drive function:#
  direction: no move = 0; forwards = 1; backwards = 2
  turn: no turn = 0; left = 1; right = 2
  speed: from 1-100
  duration: in ms
*/
void drive(int direction, int turn){
  digitalWrite(Motor_B_green, HIGH);
  digitalWrite(Motor_A_white, HIGH);
  //turning
  if(turn == 0) //no turn
  {
    digitalWrite(Motor_A_white, LOW);
  }else if (turn == 1) //left
  {
    digitalWrite(Motor_A_blue, HIGH);
  }else if (turn == 2) //right
  {
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
    digitalWrite(Motor_B_yellow, LOW);
  }else if (direction == 2) //backwards
  {
    digitalWrite(Motor_B_yellow, HIGH);
  }else
  {
    if(DEBUGGING){
      Serial.print("no direction option set");
    }
  }
  delay(5);
  digitalWrite(Motor_B_green, LOW);
  digitalWrite(Motor_A_white, LOW);
}

void setup() {
  Serial.begin(115200);

  // Motor pins
  pinMode(Motor_A_white, OUTPUT); digitalWrite(Motor_A_white, LOW);
  pinMode(Motor_A_blue, OUTPUT);  digitalWrite(Motor_A_blue, LOW);
  pinMode(Motor_B_green, OUTPUT); digitalWrite(Motor_B_green, LOW);
  pinMode(Motor_B_yellow, OUTPUT);digitalWrite(Motor_B_yellow, LOW);

  // Setup AP
  WiFi.mode(WIFI_AP);
  WiFi.softAPConfig(apIP, apIP, IPAddress(255, 255, 255, 0));
  WiFi.softAP(WIFI_SSID, NULL, 1, false); //hidden=true

  // Setup /move endpoint
  webServer.on("/move", handleMove);
  webServer.on("/move", HTTP_OPTIONS, []() {
    webServer.sendHeader("Access-Control-Allow-Origin", "*");
    webServer.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    webServer.sendHeader("Access-Control-Allow-Headers", "Content-Type");
    webServer.send(204); // No Content
  });
  webServer.begin();

  if(DEBUGGING){
    Serial.println("ESP8266 server is online");
    Serial.printf("WiFi AP SSID: %s, IP: %s\n", WIFI_SSID, WiFi.softAPIP().toString().c_str());
  }
}

void loop() {
  webServer.handleClient();
  handleMove();
  drive(currentDirection, currentTurn); // continuously update motor state
}
