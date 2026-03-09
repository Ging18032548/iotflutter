#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <time.h>

#include <SPI.h>
#include <Adafruit_GFX.h>
#include <Adafruit_ILI9341.h>
#include <DHT.h>

void sendLEDStatus();
void updateAlert();

unsigned long lastRead = 0;
const unsigned long readInterval = 5000;

// ===== WIFI =====
const char *ssid = "Ging";
const char *password = "0979944927";

// ===== NETPIE =====
const char *mqtt_server = "mqtt.netpie.io";
const char *CLIENT_ID = "d11b321e-72b4-4953-a870-8ace815b843a";
const char *TOKEN = "rVFnT4VQ8j5AcoU2gwe6JVE7HMoRTisw";
const char *SECRET = "ktrKBgQBCDqPcrDohYDMnuRpJgPWkEkM";

WiFiClient espClient;
PubSubClient client(espClient);

// ===== Firebase =====
String firebaseURL = "https://iot-lab-15642-default-rtdb.asia-southeast1.firebasedatabase.app/senserData.json";

// ===== PMS7003 =====
HardwareSerial mySerial(2);

// ===== TFT =====
#define TFT_CS 33
#define TFT_DC 25
#define TFT_RST -1
#define TFT_MOSI 23
#define TFT_MISO 19
#define TFT_SCLK 18

Adafruit_ILI9341 tft = Adafruit_ILI9341(
    TFT_CS, TFT_DC, TFT_MOSI, TFT_SCLK, TFT_RST, TFT_MISO);

// ===== LED =====
#define RED 13
#define YELLOW 15
#define GREEN 5

// ===== DHT =====
#define DHTPIN 27
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

// ===== BUTTON + BUZZER =====
#define BUTTON_PIN 4
#define BUZZER_PIN 26

// ===== DATA =====
float temperature = 0;
float humidity = 0;
unsigned int pm2_5 = 0;

int ledRedState = 0;
int ledYellowState = 0;
int ledGreenState = 0;

bool screenOn = true;
bool lastState = HIGH;
bool screenLockedByApp = false;

unsigned long screenTimer = 0;
const unsigned long screenDuration = 10000;

// ================= WIFI =================

void connectWiFi()
{
  Serial.println("Connecting WiFi...");
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.println("WiFi Connected");
  Serial.println(WiFi.localIP());
}

// ================= MQTT =================

void reconnect()
{
  while (!client.connected())
  {
    Serial.print("Connecting NETPIE...");

    if (client.connect(CLIENT_ID, TOKEN, SECRET))
    {
      Serial.println("Connected");

      client.publish("@shadow/data/update",
                     "{\"data\":{\"status\":\"online\"}}");

      client.subscribe("@msg/control");
    }
    else
    {
      Serial.print("Failed : ");
      Serial.println(client.state());
      delay(2000);
    }
  }
}

// ================= SEND NETPIE =================

void sendToNETPIE()
{
  JsonDocument doc;
  doc["data"]["pm25"] = pm2_5;
  doc["data"]["temperature"] = temperature;
  doc["data"]["humidity"] = humidity;

  char buffer[256];
  serializeJson(doc, buffer);

  client.publish("@shadow/data/update", buffer);
  client.publish("@msg/data", buffer);

  Serial.print("Send NETPIE : ");
  Serial.println(buffer);
}

// ================= SEND FIREBASE =================

void sendToFirebase()
{
  HTTPClient http;

  time_t now = time(nullptr);
  struct tm *timeinfo = localtime(&now);

  char date[11];
  strftime(date, sizeof(date), "%Y-%m-%d", timeinfo);

  char timeStr[9];
  strftime(timeStr, sizeof(timeStr), "%H-%M-%S", timeinfo);

  String url =
      "https://iot-lab-15642-default-rtdb.asia-southeast1.firebasedatabase.app/pm25_history/" + String(date) + "/" + String(timeStr) + ".json";

  String payload = "{";

  payload += "\"pm25\":" + String(pm2_5) + ",";
  payload += "\"temperature\":" + String(temperature, 1) + ",";
  payload += "\"humidity\":" + String(humidity, 1);

  payload += "}";

  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  int httpResponseCode = http.PUT(payload);

  if (httpResponseCode > 0)
  {
    Serial.println("Firebase OK");
  }
  else
  {
    Serial.println("Firebase Error");
  }

  http.end();
}

// ================= TFT =================

void drawScreen()
{
  if (!screenOn)
    return;

  tft.fillScreen(ILI9341_BLACK);

  tft.setTextColor(ILI9341_CYAN);
  tft.setTextSize(2);
  tft.setCursor(50, 20);
  tft.println("Air Quality");

  tft.setTextSize(4);
  tft.setTextColor(ILI9341_YELLOW);
  tft.setCursor(40, 80);
  tft.print("PM2.5");

  tft.setCursor(40, 120);
  tft.setTextColor(ILI9341_WHITE);
  tft.print(pm2_5);
  tft.println(" ug/m3");

  tft.setTextSize(3);
  tft.setTextColor(ILI9341_GREEN);
  tft.setCursor(40, 170);
  tft.print("Temp: ");
  tft.print(temperature, 1);
  tft.println(" C");

  tft.setTextColor(ILI9341_CYAN);
  tft.setCursor(40, 210);
  tft.print("Hum : ");
  tft.print(humidity, 1);
  tft.println(" %");
}

// ================= BUZZER =================

void beep(int times)
{
  for (int i = 0; i < times; i++)
  {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(200);

    digitalWrite(BUZZER_PIN, LOW);
    delay(200);
  }
}

// ================= READ SENSOR =================

void readSensorData()
{
  unsigned long startTime = millis();

  while (millis() - startTime < 1000)
  {
    if (mySerial.available() >= 32)
    {
      if (mySerial.read() == 0x42 && mySerial.read() == 0x4D)
      {
        uint8_t buffer[30];

        if (mySerial.readBytes(buffer, 30) == 30)
        {
          pm2_5 = buffer[4] << 8 | buffer[5];

          temperature = dht.readTemperature();
          humidity = dht.readHumidity();

          if (isnan(temperature) || isnan(humidity))
          {
            temperature = 0;
            humidity = 0;
          }

          return;
        }
      }
    }
  }
}

// ===== callback =====
void callback(char *topic, byte *payload, unsigned int length)
{
  String message = "";

  for (int i = 0; i < length; i++)
  {
    message += (char)payload[i];
  }

  Serial.print("MQTT CMD: ");
  Serial.println(message);

  StaticJsonDocument<200> doc;
  deserializeJson(doc, message);

  String cmd = doc["cmd"];
  String value = doc["value"];

  if (cmd == "screen")
  {
    if (value == "true")
    {
      screenOn = true;
      screenLockedByApp = true;
      drawScreen();
    }
    else
    {
      screenOn = false;
      screenLockedByApp = false;
      tft.fillScreen(ILI9341_BLACK);

      digitalWrite(GREEN, LOW);
      digitalWrite(YELLOW, HIGH);
      digitalWrite(RED, LOW);

      ledGreenState = 0;
      ledYellowState = 0;
      ledRedState = 0;

      sendLEDStatus();
    }
  }
}

// ================= SETUP =================

void setup()
{
  Serial.begin(115200);

  delay(2000);
  Serial.println("\n\nESP32 Starting...");
  Serial.println("WiFi: Ging");

  connectWiFi();

  configTime(7 * 3600, 0, "pool.ntp.org");

  Serial.println("Sync time...");
  while (time(nullptr) < 100000)
  {
    delay(500);
    Serial.print(".");
  }

  Serial.println("Time OK");

  client.setServer(mqtt_server, 1883);
  client.setBufferSize(512);

  mySerial.begin(9600, SERIAL_8N1, 16, 17);

  pinMode(RED, OUTPUT);
  pinMode(YELLOW, OUTPUT);
  pinMode(GREEN, OUTPUT);

  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(BUZZER_PIN, OUTPUT);

  digitalWrite(GREEN, LOW);
  ledGreenState = 0;

  digitalWrite(YELLOW, HIGH);
  ledYellowState = 0;

  digitalWrite(RED, LOW);
  ledRedState = 0;

  dht.begin();

  tft.begin();
  tft.setRotation(1);
  tft.fillScreen(ILI9341_BLACK);

  screenOn = false;

  client.setCallback(callback);
}

// ================= LED STATUS =================

void sendLEDStatus()
{
  StaticJsonDocument<200> doc;

  doc["data"]["pm25"] = pm2_5;
  doc["data"]["temperature"] = temperature;
  doc["data"]["humidity"] = humidity;
  doc["data"]["led_red"] = ledRedState;
  doc["data"]["led_yellow"] = ledYellowState;
  doc["data"]["led_green"] = ledGreenState;
  doc["data"]["screen"] = screenOn ? 1 : 0;

  char buffer[256];
  serializeJson(doc, buffer);

  client.publish("@shadow/data/update", buffer);
  client.publish("@msg/data", buffer);

  Serial.print("Send with LED Status: ");
  Serial.println(buffer);
}

// ================= ALERT =================

void updateAlert()
{
  digitalWrite(GREEN, LOW);
  digitalWrite(YELLOW, HIGH);
  digitalWrite(RED, LOW);

  ledGreenState = 0;
  ledYellowState = 0;
  ledRedState = 0;

  if (!screenOn)
    return;

  Serial.print("PM2.5 Level: ");
  Serial.println(pm2_5);

  if (pm2_5 <= 25)
  {
    digitalWrite(GREEN, HIGH);
    ledGreenState = 1;
  }
  else if (pm2_5 <= 50)
  {
    digitalWrite(YELLOW, LOW);
    ledYellowState = 1;
  }
  else
  {
    digitalWrite(RED, HIGH);
    ledRedState = 1;
    beep(3);   // ⭐ เพิ่มตรงนี้
  }
}

// ================= LOOP =================

void loop()
{
  if (!client.connected())
  {
    reconnect();
  }

  client.loop();

  bool currentState = digitalRead(BUTTON_PIN);

  if (lastState == HIGH && currentState == LOW)
  {
    screenOn = true;
    screenTimer = millis();
    drawScreen();
  }

  lastState = currentState;

  if (millis() - lastRead >= readInterval)
  {
    lastRead = millis();

    readSensorData();
    updateAlert();
    sendLEDStatus();
    sendToFirebase();

    if (screenOn)
    {
      drawScreen();
    }

    Serial.println("Sensor Updated");
  }

  if (screenOn && !screenLockedByApp && millis() - screenTimer >= screenDuration)
  {
    tft.fillScreen(ILI9341_BLACK);
    screenOn = false;

    digitalWrite(GREEN, LOW);
    digitalWrite(YELLOW, HIGH);
    digitalWrite(RED, LOW);

    ledGreenState = 0;
    ledYellowState = 0;
    ledRedState = 0;

    sendLEDStatus();
  }

  delay(100);
}