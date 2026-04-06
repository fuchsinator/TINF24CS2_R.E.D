#include <Wire.h>
#include <BMI160Gen.h>

// Wirering Diagram
/*
GND->GND
3v3->3v3
SDA->D1
SCL->D2
*/

#define BMI160_I2C_ADDRESS 0x68
#define ACCEL_SENSITIVITY 16384.0 // Sensitivity for ±2g in LSB/g
#define GYRO_SENSITIVITY 131.0    // Sensitivity for ±250°/s in LSB/°/s (adjust if needed)

float yaw = 0;       // Store yaw angle
unsigned long prevTime = 0; // For integration timing

void autoCalibrateAccelerometer() {
  // Configure accelerometer for auto-calibration
  Wire.beginTransmission(BMI160_I2C_ADDRESS);
  Wire.write(0x7E); // Command register
  Wire.write(0x37); // Start accelerometer offset calibration
  Wire.endTransmission();
  delay(100);

  // Wait for calibration to complete
  delay(1000);
  Serial.println("Accelerometer Auto-Calibration Complete");
}

void setup() {
  Serial.begin(115200); // Initialize Serial communication
  Wire.begin(D1, D2);   // Initialize I2C communication

  // Initialize BMI160 accelerometer
  Wire.beginTransmission(BMI160_I2C_ADDRESS);
  Wire.write(0x7E); // Command register
  Wire.write(0x11); // Set accelerometer to normal mode
  Wire.endTransmission();
  delay(100);

  // Perform accelerometer auto-calibration
  autoCalibrateAccelerometer();

  Serial.println("BMI160 Initialized and Calibrated");
  prevTime = millis(); // Initialize time for yaw integration
}

void loop() {
  int16_t ax, ay, az;
  int16_t gx, gy, gz;

  // Read accelerometer and gyroscope data
  Wire.beginTransmission(BMI160_I2C_ADDRESS);
  Wire.write(0x12); // Start register for accel + gyro
  Wire.endTransmission(false);
  Wire.requestFrom(BMI160_I2C_ADDRESS, 12); // 6 bytes accel + 6 bytes gyro

  if (Wire.available() == 12) {
    // Accelerometer
    ax = (Wire.read() | (Wire.read() << 8));
    ay = (Wire.read() | (Wire.read() << 8));
    az = (Wire.read() | (Wire.read() << 8));

    // Gyroscope
    gx = (Wire.read() | (Wire.read() << 8));
    gy = (Wire.read() | (Wire.read() << 8));
    gz = (Wire.read() | (Wire.read() << 8));
  }

  // Convert raw accelerometer values to g
  float ax_g = ax / ACCEL_SENSITIVITY;
  float ay_g = ay / ACCEL_SENSITIVITY;
  float az_g = az / ACCEL_SENSITIVITY;

  // Convert raw gyro values to °/s
  float gz_dps = gz / GYRO_SENSITIVITY;

  // Calculate tilt angles (pitch and roll) in degrees
  float pitch = atan2(ay_g, sqrt(ax_g * ax_g + az_g * az_g)) * 180.0 / PI;
  float roll = atan2(-ax_g, az_g) * 180.0 / PI;

  // Calculate yaw by integrating gyro Z-axis
  unsigned long currentTime = millis();
  float dt = (currentTime - prevTime) / 1000.0; // Convert ms to s
  prevTime = currentTime;

  yaw += gz_dps * dt; // Simple integration
  if (yaw > 360) yaw -= 360;
  if (yaw < 0) yaw += 360;

  // Print angles
  Serial.print("Pitch: ");
  Serial.print(pitch, 2);
  Serial.print("°, Roll: ");
  Serial.print(roll, 2);
  Serial.print("°, Yaw: ");
  Serial.print(yaw, 2);
  Serial.println("°");

  float vx = 0; // speed in forward direction
  float ax_car = ax_g; // assuming ax points forward in car coordinates
  vx += ax_car * 9.81 * dt; // convert g to m/s² and integrate


  delay(100);
}
