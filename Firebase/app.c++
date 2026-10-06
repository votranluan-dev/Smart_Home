#include "HomeSpan.h"
#include <SPI.h>
#include <MFRC522.h>
#include <ESP32Servo.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// WIFI
char ssid[] = "Dai hoc Thuy Loi";
char pass[] = "Thuyloi@2026";

// BACKEND RIENG
const char* BACKEND_DEVICE_URL = "http://172.16.4.39:8080/esp32/device";
const char* BACKEND_STATE_URL  = "http://172.16.4.39:8080/esp32/state";

const char* BACKEND_DOOR_ACCESS_URL = "http://172.16.4.39:8080/esp32/door-access";

const char* DEVICE_CODE = "home_esp32_003";
const char* DEVICE_TOKEN = "I9ZYBYwUp6Qk3mJ99vRI1Yij5i1YyNsM";

unsigned long lastBackendGet = 0;
unsigned long lastBackendPost = 0;

const unsigned long backendGetInterval = 500;
const unsigned long backendPostInterval = 1000;

int currentGasValue = 0;

bool needImmediateBackendPost = false;
unsigned long ignoreBackendLightUntil = 0;
const unsigned long localControlProtectTime = 2000;

bool lastBackendCurtainIn = false;
bool lastBackendCurtainOut = false;

bool currentCurtainIn = false;
bool currentCurtainOut = false;

// PIN
#define LED1 33
#define LED2 32

#define BTN1 25
#define BTN2 26

#define SS_PIN 17
#define RST_PIN 15
#define SCK_PIN 18
#define MOSI_PIN 16
#define MISO_PIN 19

#define SERVO_DOOR 12
#define SERVO_GARA 21

#define RAIN_PIN 23
#define SERVO_RAIN 22

#define MQ2_PIN 34
#define GAS_LED 2
#define RELAY_FAN 4
#define RELAY_BUZ 5

// NETWORK STATE
bool lastWifiConnectedState = false;

// RFID
MFRC522 rfid(SS_PIN, RST_PIN);

byte whiteCard[4] = {0x3A, 0x95, 0x76, 0x06};
byte blueTag[4]   = {0xE6, 0xF8, 0xF6, 0x05};

unsigned long lastScan = 0;
const unsigned long scanDelay = 1500;

// SERVO
Servo doorServo;
Servo garaServo;
Servo rainServo;

// DOOR
bool doorOpen = false;
bool garageOpen = false;
int openAngle = 90;
int closeAngle = 0;

// GARAGE SERVO 360
bool garaForward = true;
bool garaRunning = false;

int garaStopUs = 1542;
int garaRunUsForward = 1700;
int garaRunUsReverse = 1384;

unsigned long garaTimer = 0;
unsigned long garaRunTimeForward = 4000;
unsigned long garaRunTimeReverse = 4000;
unsigned long currentGaraRunTime = 0;

// RAIN RACK SERVO 360
bool rainRackAutoMode = true;
bool rainRackMoving = false;

enum RainRackDirection {
  RACK_STOPPED,
  RACK_MOVING_IN,
  RACK_MOVING_OUT
};

RainRackDirection rainRackDirection = RACK_STOPPED;

// 0.0 = đang ở trong hoàn toàn
// 1.0 = đang ở ngoài hoàn toàn
float rainRackPosition = 0.0;

int lastRainState = -1;

int rainRackStopUs    = 1542;
int rainRackRunOutUs  = 1800;
int rainRackRunInUs   = 1284;

unsigned long rainRackTimeOutMs = 8000;
unsigned long rainRackTimeInMs  = 9000;

unsigned long rainRackTimer = 0;
unsigned long currentRainRackRunTime = 0;

// BUTTON
bool lastBtn1 = HIGH;
bool lastBtn2 = HIGH;

unsigned long lastDebounce1 = 0;
unsigned long lastDebounce2 = 0;
const unsigned long debounceDelay = 200;

// MQ2
int gasThresholdHigh = 1800;
int gasThresholdLow  = 1400;

bool gasAlertActive = false;
bool gasAlertSent = false;
bool sensorReady = false;
bool systemEnabled = true;

unsigned long warmupTimer = 0;
unsigned long lastGasRead = 0;

// MQ2 FILTER
const int sampleCount = 20;
int gasSamples[sampleCount];
int sampleIndex = 0;

void markLocalLedChanged() {
  needImmediateBackendPost = true;
  ignoreBackendLightUntil = millis() + localControlProtectTime;
}

// ======================================================
// HOMEKIT LED
// ======================================================
struct LED : Service::LightBulb {
  int pin;
  SpanCharacteristic *power;

  LED(int p) : Service::LightBulb() {
    pin = p;

    pinMode(pin, OUTPUT);
    digitalWrite(pin, LOW);

    power = new Characteristic::On(false);
  }

  boolean update() {
    bool state = power->getNewVal();

    digitalWrite(pin, state);

    Serial.print("HomeKit dieu khien GPIO ");
    Serial.print(pin);
    Serial.print(" = ");
    Serial.println(state);

    // HomeKit / Siri dieu khien thi POST trang thai moi len backend ngay
    markLocalLedChanged();

    return true;
  }

  void setState(bool state, bool fromBackend = false) {
    power->setVal(state);
    digitalWrite(pin, state);

    Serial.print("Set GPIO ");
    Serial.print(pin);
    Serial.print(" = ");
    Serial.println(state);

    // Neu khong phai lenh tu backend thi la nut nhan/HomeKit/local
    if (!fromBackend) {
      markLocalLedChanged();
    }
  }

  void toggle() {
    bool state = !power->getVal();
    setState(state, false);
  }

  bool getState() {
    return power->getVal();
  }
};

LED *lamp1 = nullptr;
LED *lamp2 = nullptr;

// ======================================================
// WIFI STATUS
// ======================================================
void handleWiFiStatus() {
  bool wifiConnected = (WiFi.status() == WL_CONNECTED);

  if (wifiConnected != lastWifiConnectedState) {
    lastWifiConnectedState = wifiConnected;

    if (wifiConnected) {
      Serial.println("WiFi connected");
      Serial.print("IP = ");
      Serial.println(WiFi.localIP());
      Serial.print("RSSI = ");
      Serial.println(WiFi.RSSI());
    } else {
      Serial.println("WiFi disconnected - he thong chay local");
    }
  }
}

// ======================================================
// MQ2 FILTER
// ======================================================
int getFilteredGas() {
  gasSamples[sampleIndex] = analogRead(MQ2_PIN);
  sampleIndex = (sampleIndex + 1) % sampleCount;

  long sum = 0;

  for (int i = 0; i < sampleCount; i++) {
    sum += gasSamples[i];
  }

  return sum / sampleCount;
}

// ======================================================
// MQ2 ALARM CONTROL
// ======================================================
void updateGasThreshold(int newThreshold) {
  if (newThreshold <= 0) return;

  gasThresholdHigh = newThreshold;
  gasThresholdLow = gasThresholdHigh * 0.8;

  Serial.print("Muc canh bao moi = ");
  Serial.println(gasThresholdHigh);

  Serial.print("Nguong an toan lai = ");
  Serial.println(gasThresholdLow);
}

void turnGasAlarmOn() {
  digitalWrite(GAS_LED, HIGH);
  digitalWrite(RELAY_FAN, HIGH);
  digitalWrite(RELAY_BUZ, HIGH);
}

void turnGasAlarmOff() {
  digitalWrite(GAS_LED, LOW);
  digitalWrite(RELAY_FAN, LOW);
  digitalWrite(RELAY_BUZ, LOW);
}

void stopGasSystemImmediately() {
  gasAlertActive = false;
  gasAlertSent = false;

  turnGasAlarmOff();

  Serial.println("Da tat bao dong khi gas ngay lap tuc");
}

// ======================================================
// RFID CHECK
// ======================================================
bool matchUID(MFRC522::Uid *uid, byte target[], byte size) {
  if (uid->size != size) return false;

  for (byte i = 0; i < size; i++) {
    if (uid->uidByte[i] != target[i]) return false;
  }

  return true;
}

String getUidString(MFRC522::Uid *uid) {
  String uidString = "";

  for (byte i = 0; i < uid->size; i++) {
    if (uid->uidByte[i] < 0x10) {
      uidString += "0";
    }

    uidString += String(uid->uidByte[i], HEX);
  }

  uidString.toUpperCase();
  return uidString;
}

// ======================================================
// DOOR
// ======================================================
void toggleDoor() {
  if (!doorOpen) {
    doorServo.write(openAngle);
    doorOpen = true;
    Serial.println("Cua chinh mo");
  } else {
    doorServo.write(closeAngle);
    doorOpen = false;
    Serial.println("Cua chinh dong");
  }
}

// ======================================================
// GARAGE
// ======================================================
void startGarage() {
  if (garaRunning) {
    Serial.println("Gara dang chay, bo qua lenh moi");
    return;
  }

  if (garaForward) {
    Serial.println("Gara quay thuan");
    garaServo.writeMicroseconds(garaRunUsForward);
    currentGaraRunTime = garaRunTimeForward;
  } else {
    Serial.println("Gara quay nguoc");
    garaServo.writeMicroseconds(garaRunUsReverse);
    currentGaraRunTime = garaRunTimeReverse;
  }

  garaTimer = millis();
  garaRunning = true;
  garaForward = !garaForward;
}

void handleGarageStop() {
  if (garaRunning && millis() - garaTimer >= currentGaraRunTime) {
    garaServo.writeMicroseconds(garaStopUs);
    garaRunning = false;
    Serial.println("Gara dung");
  }
}

// ======================================================
// RAIN RACK SERVO 360
// ======================================================
void stopRainRack() {
  rainServo.writeMicroseconds(rainRackStopUs);
}

float clampRackPosition(float value) {
  if (value < 0.0) return 0.0;
  if (value > 1.0) return 1.0;
  return value;
}

void updateRainRackPositionByTime() {
  if (!rainRackMoving) return;

  unsigned long elapsed = millis() - rainRackTimer;

  if (rainRackDirection == RACK_MOVING_OUT) {
    float delta = (float)elapsed / (float)rainRackTimeOutMs;
    rainRackPosition += delta;
  }

  if (rainRackDirection == RACK_MOVING_IN) {
    float delta = (float)elapsed / (float)rainRackTimeInMs;
    rainRackPosition -= delta;
  }

  rainRackPosition = clampRackPosition(rainRackPosition);

  Serial.print("Vi tri sap phoi uoc luong = ");
  Serial.print(rainRackPosition * 100.0);
  Serial.println("%");
}

void stopRainRackByCommand() {
  updateRainRackPositionByTime();

  stopRainRack();

  rainRackMoving = false;
  rainRackDirection = RACK_STOPPED;

  currentCurtainIn = false;
  currentCurtainOut = false;

  lastBackendCurtainIn = false;
  lastBackendCurtainOut = false;

  needImmediateBackendPost = true;

  Serial.println("Sap phoi dung theo lenh nguoi dung");
}

void startRainRackIn() {
  // Nếu đang kéo vào mà bấm Kéo vào lần nữa thì dừng
  if (rainRackMoving && rainRackDirection == RACK_MOVING_IN) {
    stopRainRackByCommand();
    return;
  }

  // Nếu đang kéo ra thì cập nhật vị trí hiện tại trước khi đảo chiều
  if (rainRackMoving && rainRackDirection == RACK_MOVING_OUT) {
    updateRainRackPositionByTime();
    stopRainRack();
    rainRackMoving = false;
  }

  Serial.println("SAP PHOI -> KEO VAO");

  currentCurtainIn = true;
  currentCurtainOut = false;
  needImmediateBackendPost = true;

  unsigned long runTime = (unsigned long)(rainRackPosition * rainRackTimeInMs);

  // Nếu đang đứng yên và không biết vị trí chính xác, cho chạy full vào
  if (runTime < 300) {
    Serial.println("Sap phoi da o trong, khong can keo vao nua");

    currentCurtainIn = false;
    currentCurtainOut = false;
    needImmediateBackendPost = true;

    return;
  }

  Serial.print("Thoi gian keo vao = ");
  Serial.print(runTime);
  Serial.println(" ms");

  rainServo.writeMicroseconds(rainRackRunInUs);

  currentRainRackRunTime = runTime;
  rainRackTimer = millis();
  rainRackMoving = true;
  rainRackDirection = RACK_MOVING_IN;
}

void startRainRackOut() {
  // Nếu đang kéo ra mà bấm Kéo ra lần nữa thì dừng
  if (rainRackMoving && rainRackDirection == RACK_MOVING_OUT) {
    stopRainRackByCommand();
    return;
  }

  // Nếu đang kéo vào thì cập nhật vị trí hiện tại trước khi đảo chiều
  if (rainRackMoving && rainRackDirection == RACK_MOVING_IN) {
    updateRainRackPositionByTime();
    stopRainRack();
    rainRackMoving = false;
  }

  Serial.println("SAP PHOI -> KEO RA");

  currentCurtainIn = false;
  currentCurtainOut = true;
  needImmediateBackendPost = true;

  unsigned long runTime = (unsigned long)((1.0 - rainRackPosition) * rainRackTimeOutMs);

  // Nếu đang đứng yên và không biết vị trí chính xác, cho chạy full ra
  if (runTime < 300) {
    Serial.println("Sap phoi da o ngoai, khong can keo ra nua");

    currentCurtainIn = false;
    currentCurtainOut = false;
    needImmediateBackendPost = true;

    return;
  }

  Serial.print("Thoi gian keo ra = ");
  Serial.print(runTime);
  Serial.println(" ms");

  rainServo.writeMicroseconds(rainRackRunOutUs);

  currentRainRackRunTime = runTime;
  rainRackTimer = millis();
  rainRackMoving = true;
  rainRackDirection = RACK_MOVING_OUT;
}

void handleRainRackStop() {
  if (rainRackMoving && millis() - rainRackTimer >= currentRainRackRunTime) {
    updateRainRackPositionByTime();

    stopRainRack();

    rainRackMoving = false;
    rainRackDirection = RACK_STOPPED;

    currentCurtainIn = false;
    currentCurtainOut = false;

    lastBackendCurtainIn = false;
    lastBackendCurtainOut = false;

    needImmediateBackendPost = true;

    Serial.println("Sap phoi dung");
  }
}

void handleRainRackAuto() {
  if (!rainRackAutoMode) return;

  int rainState = digitalRead(RAIN_PIN);

  if (rainState != lastRainState) {
    Serial.print("Rain state = ");
    Serial.println(rainState);

    if (rainState == LOW) {
      Serial.println("CO MUA -> KEO SAP PHOI VAO");
      startRainRackIn();
    } else {
      Serial.println("KHONG MUA -> KEO SAP PHOI RA");
      startRainRackOut();
    }

    lastRainState = rainState;
  }
}

// ======================================================
// BUTTON
// ======================================================
void handleButtons() {
  bool b1 = digitalRead(BTN1);
  bool b2 = digitalRead(BTN2);

  if (b1 == LOW && lastBtn1 == HIGH && millis() - lastDebounce1 > debounceDelay) {
    if (lamp1 != nullptr) {
      lamp1->toggle();
    }

    lastDebounce1 = millis();
  }

  if (b2 == LOW && lastBtn2 == HIGH && millis() - lastDebounce2 > debounceDelay) {
    if (lamp2 != nullptr) {
      lamp2->toggle();
    }

    lastDebounce2 = millis();
  }

  lastBtn1 = b1;
  lastBtn2 = b2;
}

// ======================================================
// RFID
// ======================================================
void handleRFID() {
  if (!rfid.PICC_IsNewCardPresent()) return;
  if (!rfid.PICC_ReadCardSerial()) return;

  if (millis() - lastScan < scanDelay) {
    rfid.PICC_HaltA();
    rfid.PCD_StopCrypto1();
    return;
  }

  lastScan = millis();

  String uidString = getUidString(&rfid.uid);

  Serial.print("RFID UID = ");
  Serial.println(uidString);

  if (matchUID(&rfid.uid, whiteCard, 4)) {
    Serial.println("The trang -> mo/dong cua chinh");

    bool wasOpen = doorOpen;
    toggleDoor();

    if (wasOpen) {
      sendDoorAccessLog(
        uidString,
        "Thẻ cửa chính",
        "GRANTED",
        "Đóng cửa chính thành công"
      );
    } else {
      sendDoorAccessLog(
        uidString,
        "Thẻ cửa chính",
        "GRANTED",
        "Mở cửa chính thành công"
      );
    }
  } 
  else if (matchUID(&rfid.uid, blueTag, 4)) {
    Serial.println("The xanh -> mo/dong gara");

    bool wasGarageOpen = garageOpen;

    startGarage();

    garageOpen = !garageOpen;

    if (wasGarageOpen) {
      sendDoorAccessLog(
        uidString,
        "Thẻ gara",
        "GRANTED",
        "Đóng cửa gara thành công"
      );
    } else {
      sendDoorAccessLog(
        uidString,
        "Thẻ gara",
        "GRANTED",
        "Mở cửa gara thành công"
      );
    }
  }
  else {
    Serial.println("The khong hop le");

    sendDoorAccessLog(
      uidString,
      "Thẻ không xác định",
      "DENIED",
      "Từ chối mở cửa"
    );
  }

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}

// ======================================================
// MQ2
// ======================================================
void handleMQ2() {
  if (!sensorReady) {
    if (millis() - warmupTimer > 30000) {
      sensorReady = true;
      Serial.println("MQ2 ready");
    }

    return;
  }

  if (millis() - lastGasRead > 500) {
    lastGasRead = millis();

    int gasValue = getFilteredGas();
    currentGasValue = gasValue;

    Serial.print("Gas value = ");
    Serial.println(gasValue);

    Serial.print("Muc canh bao = ");
    Serial.println(gasThresholdHigh);

    Serial.print("Che do hoat dong = ");
    Serial.println(systemEnabled ? "BAT" : "TAT");

    if (!systemEnabled) {
      stopGasSystemImmediately();
      return;
    }

    if (!gasAlertActive && gasValue > gasThresholdHigh) {
      gasAlertActive = true;
      gasAlertSent = false;
      Serial.println("VUOT NGUONG CANH BAO GAS");
    }

    if (gasAlertActive && gasValue < gasThresholdLow) {
      gasAlertActive = false;
      gasAlertSent = false;
      Serial.println("Gas da ve muc an toan");
    }

    if (gasAlertActive) {
      turnGasAlarmOn();

      if (!gasAlertSent) {
        Serial.println("CANH BAO! Phat hien khi gas trong bep!");
        gasAlertSent = true;
      }
    } else {
      turnGasAlarmOff();
    }
  }
}

void sendDoorAccessLog(String cardUid, String cardName, String status, String message) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi chua ket noi, khong gui door access log");
    return;
  }

  HTTPClient http;
  http.begin(BACKEND_DOOR_ACCESS_URL);
  http.addHeader("Content-Type", "application/json");

  StaticJsonDocument<512> doc;

  doc["deviceCode"] = DEVICE_CODE;
  doc["deviceToken"] = DEVICE_TOKEN;
  doc["cardUid"] = cardUid;
  doc["cardName"] = cardName;
  doc["status"] = status;
  doc["message"] = message;

  String body;
  serializeJson(doc, body);

  Serial.print("POST DOOR ACCESS body = ");
  Serial.println(body);

  int code = http.POST(body);

  Serial.print("POST DOOR ACCESS code = ");
  Serial.println(code);

  if (code > 0) {
    Serial.print("Door access response = ");
    Serial.println(http.getString());
  }

  http.end();
}

// ======================================================
// BACKEND RIENG
// ======================================================
void sendStateToBackend() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  http.begin(BACKEND_STATE_URL);
  http.addHeader("Content-Type", "application/json");

  StaticJsonDocument<1024> doc;

  doc["deviceCode"] = DEVICE_CODE;
  doc["deviceToken"] = DEVICE_TOKEN;

  doc["gasValue"] = currentGasValue;

  if (lamp1 != nullptr) {
    doc["light1"] = lamp1->getState();
  }

  if (lamp2 != nullptr) {
    doc["light2"] = lamp2->getState();
  }

  doc["mq2Enabled"] = systemEnabled;
  doc["autoMode"] = rainRackAutoMode;
  doc["curtainIn"] = currentCurtainIn;
  doc["curtainOut"] = currentCurtainOut;

  bool isRaining = digitalRead(RAIN_PIN) == LOW;
  doc["isRaining"] = isRaining;

  String body;
  serializeJson(doc, body);

  int code = http.POST(body);

  Serial.print("POST backend code = ");
  Serial.println(code);
  Serial.print("POST body = ");
  Serial.println(body);

  if (code > 0) {
    Serial.print("Backend response = ");
    Serial.println(http.getString());
  }

  http.end();
}

void getCommandFromBackend() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;

  String url = String(BACKEND_DEVICE_URL) +
               "?deviceCode=" + String(DEVICE_CODE) +
               "&deviceToken=" + String(DEVICE_TOKEN);

  http.begin(url);

  int code = http.GET();

  Serial.print("GET backend code = ");
  Serial.println(code);

  if (code == 200) {
    String payload = http.getString();

    StaticJsonDocument<768> doc;
    DeserializationError error = deserializeJson(doc, payload);

    if (error) {
      Serial.print("JSON parse error: ");
      Serial.println(error.c_str());
      http.end();
      return;
    }

    bool backendLight1 = doc["light1"] | false;
    bool backendLight2 = doc["light2"] | false;

    bool backendMq2Enabled = doc["mq2Enabled"] | systemEnabled;
    bool backendAutoMode = doc["autoMode"] | rainRackAutoMode;

    bool backendCurtainIn = doc["curtainIn"] | false;
    bool backendCurtainOut = doc["curtainOut"] | false;

    int backendThreshold = gasThresholdHigh;

    if (!doc["threshold"].isNull()) {
      backendThreshold = (int)doc["threshold"].as<float>();
    }

    Serial.print("Backend mq2Enabled = ");
    Serial.println(backendMq2Enabled);

    Serial.print("Backend threshold = ");
    Serial.println(backendThreshold);

    bool allowApplyBackendLight = millis() > ignoreBackendLightUntil;

    if (allowApplyBackendLight) {
      if (lamp1 != nullptr && lamp1->getState() != backendLight1) {
        lamp1->setState(backendLight1, true);
      }

      if (lamp2 != nullptr && lamp2->getState() != backendLight2) {
        lamp2->setState(backendLight2, true);
      }
    }

    systemEnabled = backendMq2Enabled;
    rainRackAutoMode = backendAutoMode;

    updateGasThreshold(backendThreshold);

    if (!systemEnabled) {
      stopGasSystemImmediately();
    }

    if (!rainRackAutoMode) {
      if (!backendCurtainIn && !backendCurtainOut &&
          (lastBackendCurtainIn || lastBackendCurtainOut) &&
          rainRackMoving) {
        Serial.println("Backend dieu khien: DUNG SAP PHOI");
        stopRainRackByCommand();
      }

      if (backendCurtainIn && !lastBackendCurtainIn) {
        Serial.println("Backend dieu khien: KEO SAP PHOI VAO");
        startRainRackIn();
      }

      if (backendCurtainOut && !lastBackendCurtainOut) {
        Serial.println("Backend dieu khien: KEO SAP PHOI RA");
        startRainRackOut();
      }
    }

    lastBackendCurtainIn = backendCurtainIn;
    lastBackendCurtainOut = backendCurtainOut;
  } else {
    Serial.print("GET backend failed, response = ");
    Serial.println(http.getString());
  }

  http.end();
}

void handleBackend() {
  if (WiFi.status() != WL_CONNECTED) return;

  unsigned long now = millis();

  // Neu vua co thay doi tu nut nhan/HomeKit thi POST len backend ngay
  if (needImmediateBackendPost) {
    needImmediateBackendPost = false;
    lastBackendPost = now;
    sendStateToBackend();
  }

  if (now - lastBackendGet >= backendGetInterval) {
    lastBackendGet = now;
    getCommandFromBackend();
  }

  if (now - lastBackendPost >= backendPostInterval) {
    lastBackendPost = now;
    sendStateToBackend();
  }
}

// ======================================================
// SETUP
// ======================================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("===== ESP32 SMART HOME BACKEND ONLY START =====");

  // PIN MODE
  pinMode(BTN1, INPUT_PULLUP);
  pinMode(BTN2, INPUT_PULLUP);

  pinMode(RAIN_PIN, INPUT_PULLUP);

  pinMode(GAS_LED, OUTPUT);
  pinMode(RELAY_FAN, OUTPUT);
  pinMode(RELAY_BUZ, OUTPUT);

  digitalWrite(GAS_LED, LOW);
  digitalWrite(RELAY_FAN, LOW);
  digitalWrite(RELAY_BUZ, LOW);

  // SERVO
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  ESP32PWM::allocateTimer(2);
  ESP32PWM::allocateTimer(3);

  doorServo.setPeriodHertz(50);
  doorServo.attach(SERVO_DOOR, 500, 2400);
  doorServo.write(closeAngle);

  garaServo.setPeriodHertz(50);
  garaServo.attach(SERVO_GARA, 500, 2500);
  garaServo.writeMicroseconds(garaStopUs);

  rainServo.setPeriodHertz(50);
  rainServo.attach(SERVO_RAIN, 500, 2400);
  stopRainRack();

  // RFID
  SPI.begin(SCK_PIN, MISO_PIN, MOSI_PIN, SS_PIN);
  rfid.PCD_Init();
  Serial.println("RFID ready");

  // MQ2
  warmupTimer = millis();

  for (int i = 0; i < sampleCount; i++) {
    gasSamples[i] = analogRead(MQ2_PIN);
  }

  Serial.println("MQ2 warming up 30s");

  // HOMESPAN
  homeSpan.setLogLevel(1);
  homeSpan.setWifiCredentials(ssid, pass);
  homeSpan.begin(Category::Lighting, "ESP32 SmartHome");

  new SpanAccessory();

  new Service::AccessoryInformation();
  new Characteristic::Identify();

  lamp1 = new LED(LED1);
  lamp2 = new LED(LED2);

  Serial.println("HE THONG SAN SANG");
}

// ======================================================
// LOOP
// ======================================================
void loop() {
  // Local chay truoc: mat WiFi van dung duoc nut, RFID, MQ2, mua
  handleButtons();
  handleRFID();

  handleGarageStop();

  handleRainRackAuto();
  handleRainRackStop();

  handleMQ2();

  // HomeSpan quan ly WiFi/HomeKit
  homeSpan.poll();

  // Backend rieng
  handleBackend();

  // Theo doi trang thai WiFi
  handleWiFiStatus();
}