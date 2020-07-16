import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

part 'bitalinoFrame.dart';

final MethodChannel _channel =
    const MethodChannel('com.afonsoraposo.bitalino/bitalino');

final int timeOutSeconds = 10;

enum CommunicationType {
  UNKNOWN,
  BTH,
  BLE,
  DUAL,
}

enum BITalinoException { NOT_CONNECTED }

int serializeCommunicationType(CommunicationType communicationType) {
  switch (communicationType) {
    case CommunicationType.UNKNOWN:
      return 0;
    case CommunicationType.BTH:
      return 1;
    case CommunicationType.BLE:
      return 2;
    case CommunicationType.DUAL:
      return 3;
  }
  throw ArgumentError('Unknown ResolutionPreset value');
}

Uint32List serializeAnalogChannels(List<int> analogChannels) {
  return Uint32List.fromList(analogChannels);
}

typedef onBITalinoDataAvailable = Function(BITalinoFrame frame);

class BITalinoController {
  bool connected = false;
  String connectedDevice;
  CommunicationType communicationType;
  StreamSubscription<dynamic> _dataStreamSubscription;

  Future<void> initialize(communicationType,
      {onBITalinoDataAvailable onDataAvailable}) async {
    this.communicationType = communicationType;

    if (communicationType == CommunicationType.BLE && onDataAvailable != null)
      throw Exception('BLE connection does not implement "onDataAvailable"');

    await _channel.invokeMethod("initialize", <String, dynamic>{
      "type": serializeCommunicationType(communicationType)
    }).timeout(Duration(seconds: timeOutSeconds), onTimeout: () => false);

    if (communicationType == CommunicationType.BTH) {
      const EventChannel bitalinoEventChannel =
          EventChannel('com.afonsoraposo.bitalino/dataStream');
      _dataStreamSubscription =
          bitalinoEventChannel.receiveBroadcastStream().listen(
        (dynamic bitalinoData) {
          onDataAvailable(BITalinoFrame._fromPlatformData(bitalinoData));
        },
      );
    }
  }

  Future<bool> connect(String address) async {
    connected = await _channel
        .invokeMethod("connect", <String, dynamic>{"address": address});
    if (connected) {
      connectedDevice = address;
    } else {
      connectedDevice = null;
    }
    return connected;
  }

  Future<bool> version() async {
    return await _channel.invokeMethod("version");
  }

  Future<bool> disconnect() async {
    if (connected) {
      if (!(await _channel.invokeMethod("disconnect"))) {
        connectedDevice = null;
        connected = false;
      }
    }
    return connected;
  }

  Future<bool> dispose() async {
    _dataStreamSubscription?.cancel();
    return await _channel.invokeMethod("dispose");
  }

  Future<int> battery() async {
    if (connected) {
      return await _channel.invokeMethod("battery");
    } else {
      throw Exception("There is no connected device");
    }
  }

  Future<bool> start(List<int> analogChannels, int sampleRate) async {
    if (connected) {
      return await _channel.invokeMethod("start", <String, dynamic>{
        "analogChannels": serializeAnalogChannels(analogChannels),
        "sampleRate": sampleRate,
      });
    } else {
      throw Exception("There is no connected device");
    }
  }

  Future<bool> stop() async {
    if (connected) {
      return await _channel.invokeMethod("stop");
    } else {
      throw Exception("There is no connected device");
    }
  }

  // TODO: wrap everything with try catch, add timeout for everyone, handle device disconnect
}
