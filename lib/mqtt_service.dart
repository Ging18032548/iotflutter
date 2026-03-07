import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  late MqttServerClient client;

  Function(Map<String, dynamic>)? onData;
  VoidCallback? onConnected; // ✅ HomePage ใช้ตรงนี้
  VoidCallback? onDisconnected; // ✅ HomePage ใช้ตรงนี้

  MQTTService() {
    client = MqttServerClient.withPort(
      "mqtt.netpie.io",
      "8aa74802-6ee8-4910-8189-7664b5ca6c18",
      1883,
    );
  }

  Future connect() async {
    client.secure = false;
    client.keepAlivePeriod = 20;
    client.autoReconnect = true;
    client.setProtocolV311();
    client.logging(on: false);
    client.onBadCertificate = (Object cert) => true;
    // ✅ กำหนดที่นี่ที่เดียว แล้วเรียก callback ของ HomePage ต่อ
    client.onConnected = () {
      debugPrint("✅ MQTT Connected");
      onConnected?.call();
    };
    client.onDisconnected = () {
      debugPrint("❌ MQTT Disconnected");
      onDisconnected?.call();
    };
    client.onAutoReconnect = () {
      debugPrint("🔄 MQTT Reconnecting...");
    };
    client.onAutoReconnected = () {
      debugPrint("✅ MQTT Auto-Reconnected");
      onConnected?.call();
    };

    final connMessage =
    MqttConnectMessage()
        .withClientIdentifier("8aa74802-6ee8-4910-8189-7664b5ca6c18")
        .authenticateAs(
          "xZybzsQuLFk1DYdX2mu5xfve3ebVY6q9",
          "PinicPz6BzVXLYhefSPeoGyDr6cxhxuU",
        )
        .startClean();

    client.connectionMessage = connMessage;

    try {
      await client.connect();
    } on SocketException catch (e) {
      debugPrint("MQTT Socket Error: $e");
      client.disconnect();
      return;
    } on NoConnectionException catch (e) {
      debugPrint("MQTT No Connection: $e");
      client.disconnect();
      return;
    } catch (e) {
      debugPrint("MQTT Connect Error: $e");
      client.disconnect();
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      client.subscribe("@msg/data", MqttQos.atMostOnce);
      client.subscribe("@msg/control/ack", MqttQos.atMostOnce);

      client.updates!.listen((event) {
        final recMess = event[0].payload as MqttPublishMessage;
        final message = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );
        debugPrint("📨 MQTT DATA: $message");
        try {
          var data = jsonDecode(message);
          if (onData != null) onData!(data);
        } catch (e) {
          debugPrint("MQTT JSON Error: $e");
        }
      });
    } else {
      debugPrint("MQTT Failed: ${client.connectionStatus}");
      client.disconnect();
    }
  }

  void publish(String topic, String payload) {
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint("MQTT not connected, cannot publish");
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    debugPrint("📤 Published to $topic: $payload");
  }
}
