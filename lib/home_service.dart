import 'package:flutter/foundation.dart';

class HomeService {
  int pm25 = 0;
  double temperature = 0.0;
  double humidity = 0.0;

  bool ledRed = false;
  bool ledYellow = false;
  bool ledGreen = false;
  bool buzzer = false;

  void update(Map<String, dynamic> msg) {
    try {
      debugPrint("RAW MSG: $msg");

      var d = msg["data"] ?? msg;

      pm25 = (d["pm25"] ?? 0).toInt();
      temperature = (d["temperature"] ?? 0.0).toDouble();
      humidity = (d["humidity"] ?? 0.0).toDouble();

      debugPrint(
        "Updated -> PM2.5: $pm25 | Temp: $temperature | Hum: $humidity",
      );
      ledRed = d["led_red"] ?? false;
      ledYellow = d["led_yellow"] ?? false;
      ledGreen = d["led_green"] ?? false;
      buzzer = d["buzzer"] ?? false;
    } catch (e) {
      debugPrint("HomeService Error: $e");
    }
  }
}
