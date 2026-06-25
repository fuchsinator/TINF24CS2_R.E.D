

#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <WebSocketsServer.h>
#include <Wire.h>
#include <VL53L0X.h>

// ============ Sensor object ============
VL53L0X sensor;

// ============ WiFi / WebSocket ============

#define WIFI_SSID "R.E.D"             // Access point name (no password)
IPAddress apIP(10, 10, 10, 10);       // Static IP of the ESP8266 AP
WebSocketsServer ws(81);              // WebSocket server on port 81

// ============ Motor pins ============

// Motor A controls the steering axle
const int Motor_A_white  = D1;  // Steering motor: ON / OFF
const int Motor_A_blue   = D3;  // Steering motor: direction (HIGH = left, LOW = right)

// Motor B controls the drive axle
const int Motor_B_green  = D2;  // Drive motor: ON / OFF
const int Motor_B_yellow = D4;  // Drive motor: direction (LOW = forward, HIGH = backward)

// ============ Sensor pins (I2C) ============

const int SDA_green = D6;  // I2C data line
const int SCL_white = D5;  // I2C clock line

// ============ State variables ============

// Current motor command received from Flutter
int currentDirection = 0;  // 0 = stop  | 1 = forward  | 2 = backward
int currentTurn      = 0;  // 0 = straight | 1 = left | 2 = right

// Driving mode
bool currentMode = false;  // false = manual, true = autonomous

// Alternates the avoidance turn direction left / right on each obstacle
bool turnBool = true;

// Minimum time (ms) the motor pins stay active per drive() call
int driveTime = 10;

// Sensor state — both must be true for autonomous mode to run
bool sensorMode        = false;  // set to true by Flutter popup ("sensorOn" command)
bool sensorInitialized = false;  // set to true after successful sensor_init()

// Enable / disable Serial debug output
#define DEBUGGING true

// ============ Drive function ============

/*
 * Sets the steering and drive motors to the requested state.
 *
 * direction: 0 = stop | 1 = forward | 2 = backward
 * turn:      0 = straight | 1 = left | 2 = right
 *
 * The motor pins remain in their last state after this function returns,
 * so the car keeps moving until drive() is called again with direction = 0.
 */
void drive(int direction, int turn) {

  // --- Steering (Motor A) ---
  if (turn == 0) {
    // No steering: turn motor A off, wheels return to straight
    digitalWrite(Motor_A_white, LOW);

  } else if (turn == 1) {
    // Steer left: motor A on, direction HIGH
    digitalWrite(Motor_A_white, HIGH);
    digitalWrite(Motor_A_blue,  HIGH);

  } else if (turn == 2) {
    // Steer right: motor A on, direction LOW
    digitalWrite(Motor_A_white, HIGH);
    digitalWrite(Motor_A_blue,  LOW);
  }

  // --- Drive (Motor B) ---
  if (direction == 0) {
    // Stop: drive motor B off
    digitalWrite(Motor_B_green, LOW);

  } else if (direction == 1) {
    // Forward: motor B on, direction LOW
    digitalWrite(Motor_B_green,  HIGH);
    digitalWrite(Motor_B_yellow, LOW);

  } else if (direction == 2) {
    // Backward: motor B on, direction HIGH
    digitalWrite(Motor_B_green,  HIGH);
    digitalWrite(Motor_B_yellow, HIGH);
  }

  // Hold the current motor state for driveTime milliseconds
  delay(driveTime);
}

// ============ Sensor functions ============

/*
 * Initialises the VL53L0X sensor in long-range, high-accuracy mode.
 * Called once when Flutter sends the "sensorOn" command.
 * On failure, sensorMode is reset to false so autonomous mode stays disabled.
 */
void sensor_init() {
  Wire.begin(SDA_green, SCL_white);  // Start I2C on the defined pins
  delay(500);                        // Wait for sensor to boot

  sensor.setTimeout(500);            // Abort a reading after 500 ms

  if (!sensor.init()) {
    Serial.println("VL53L0X init FAILED");
    sensorMode = false;              // Keep autonomous mode locked out
    return;
  }

  // Long-range configuration: increases maximum detection distance
  sensor.setSignalRateLimit(0.1);
  sensor.setVcselPulsePeriod(VL53L0X::VcselPeriodPreRange,   18);
  sensor.setVcselPulsePeriod(VL53L0X::VcselPeriodFinalRange, 14);

  // High-accuracy timing budget: 200 ms per measurement
  sensor.setMeasurementTimingBudget(200000);

  sensorInitialized = true;
  Serial.println("VL53L0X ready");
}

/*
 * Returns the current distance to the nearest object in millimetres.
 * Returns -1 if the sensor is not initialised or a timeout occurs.
 */
int get_distance() {
  if (!sensorInitialized) return -1;

  int dist = sensor.readRangeSingleMillimeters();

  if (sensor.timeoutOccurred()) {
    Serial.println("Sensor timeout");
    return -1;
  }

  return dist;
}

// ============ Autonomous driving ============

/*
 * Decides how the car should react based on the measured distance.
 *
 * Three obstacle zones — the car reverses and steers simultaneously so it
 * actually changes direction (Motor B backward + Motor A steering at the
 * same time). turnBool alternates the avoidance direction left / right.
 *
 * dist <= 0           → sensor error: stop and wait
 * dist <  50  mm      → EMERGENCY  : sharp reverse + turn (600 ms)
 * dist <  100 mm      → DANGER     : reverse + turn       (400 ms)
 * dist <  250 mm      → WARNING    : gentle reverse + turn (250 ms)
 * dist >= 250 mm      → CLEAR      : drive forward
 */
void set_autoDrive(int dist) {

  // Sensor error or timeout: stop until the next valid reading
  if (dist <= 0) {
    drive(0, 0);
    return;
  }

  if (dist < 50) {
    // EMERGENCY — obstacle closer than 5 cm
    Serial.println("EMERGENCY - Very close! Strong avoidance");
    drive(2, turnBool ? 1 : 2);  // Reverse and steer simultaneously
    delay(600);                   // Hold manoeuvre for 600 ms
    turnBool = !turnBool;         // Alternate turn direction for next obstacle

  } else if (dist < 100) {
    // DANGER — obstacle 5–10 cm away
    Serial.println("DANGER - Obstacle close, avoiding");
    drive(2, turnBool ? 1 : 2);
    delay(400);
    turnBool = !turnBool;

  } else if (dist < 250) {
    // WARNING — obstacle 10–25 cm away
    Serial.println("WARNING - Obstacle ahead, gentle avoidance");
    drive(2, turnBool ? 1 : 2);
    delay(250);
    turnBool = !turnBool;

  } else {
    // CLEAR — path is free, drive straight forward
    drive(1, 0);
  }
}

// ============ WebSocket event handler ============

/*
 * Receives text commands from the Flutter app and updates the motor state.
 *
 * Supported commands:
 *   forward    → drive forward
 *   backward   → drive backward
 *   left       → steer left
 *   right      → steer right
 *   stop       → stop all motors
 *   auto       → enable autonomous mode
 *   autoStop   → disable autonomous mode
 *   sensorOn   → enable sensor and initialise it (once)
 *   sensorOff  → disable sensor
 *
 * Every message is acknowledged with "ACK".
 */
void handleWSEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t len) {
  if (type == WStype_TEXT) {
    String msg = String((char*)payload);
    Serial.println("WS recv: " + msg);

    // Manual driving commands
    if (msg.indexOf("forward")  >= 0) currentDirection = 1;
    if (msg.indexOf("backward") >= 0) currentDirection = 2;
    if (msg.indexOf("left")     >= 0) currentTurn = 1;
    if (msg.indexOf("right")    >= 0) currentTurn = 2;
    if (msg.indexOf("stop")     >= 0) { currentDirection = 0; currentTurn = 0; }

    // Mode commands
    if (msg.indexOf("auto")     >= 0) currentMode = true;
    if (msg.indexOf("autoStop") >= 0) currentMode = false;

    // Sensor commands — init is deferred until "sensorOn" is received
    // so the sensor is only started when the user confirms it is installed
    if (msg.indexOf("sensorOn")  >= 0) {
      sensorMode = true;
      if (!sensorInitialized) sensor_init();  // Initialise only once
    }
    if (msg.indexOf("sensorOff") >= 0) sensorMode = false;

    ws.sendTXT(num, "ACK");  // Acknowledge every message
  }
}

// ============ Setup ============

void setup() {
  Serial.begin(115200);

  // Initialise motor pins and set all outputs LOW (motors off)
  pinMode(Motor_A_white,  OUTPUT); digitalWrite(Motor_A_white,  LOW);
  pinMode(Motor_A_blue,   OUTPUT); digitalWrite(Motor_A_blue,   LOW);
  pinMode(Motor_B_green,  OUTPUT); digitalWrite(Motor_B_green,  LOW);
  pinMode(Motor_B_yellow, OUTPUT); digitalWrite(Motor_B_yellow, LOW);

  // Start WiFi access point with a static IP
  WiFi.mode(WIFI_AP);
  WiFi.softAPConfig(apIP, apIP, IPAddress(255, 255, 255, 0));
  WiFi.softAP(WIFI_SSID);

  // Start WebSocket server and register the event handler
  ws.begin();
  ws.onEvent(handleWSEvent);

  if (DEBUGGING) {
    Serial.println("ESP8266 server is online");
    Serial.printf("WiFi AP SSID: %s, IP: %s\n", WIFI_SSID, WiFi.softAPIP().toString().c_str());
  }
}

// ============ Main loop ============

void loop() {
  ws.loop();  // Process incoming WebSocket messages

  if (currentMode && sensorMode) {
    // Autonomous mode: measure distance and react
    int dist = get_distance();
    set_autoDrive(dist);
    if (DEBUGGING) Serial.println(dist);
    yield();  // Keep the ESP8266 watchdog timer happy

  } else {
    // Manual mode: execute the last command received from Flutter
    drive(currentDirection, currentTurn);
  }
}
