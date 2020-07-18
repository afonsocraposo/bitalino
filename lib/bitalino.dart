import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

part 'bitalinoFrame.dart';
part 'bitalinoState.dart';
part 'bitalinoDescription.dart';
part 'bitalinoException.dart';

final MethodChannel _channel =
    const MethodChannel('com.afonsoraposo.bitalino/bitalino');

final Duration timeout = Duration(seconds: 10);

enum CommunicationType {
  // UNKNOWN, not implemented

  /// Bluetooth
  BTH,

  /// Bluetooth Low Energy
  BLE,

  // DUAL, not implemented
}

/// Frequency in Hz
enum Frequency {
  /// 10 Hz
  HZ10,

  /// 100 Hz
  HZ100,

  /// 1000 Hz
  HZ1000,
}

int serializeCommunicationType(CommunicationType communicationType) {
  switch (communicationType) {
    //case CommunicationType.UNKNOWN:
    //return 0;
    case CommunicationType.BTH:
      return 1;
    case CommunicationType.BLE:
      return 2;
    //case CommunicationType.DUAL:
    //return 3;
  }
  throw ArgumentError('Unknown CommunicationType');
}

int serializeFrequency(Frequency frequency) {
  switch (frequency) {
    case Frequency.HZ10:
      return 10;
    case Frequency.HZ100:
      return 100;
    case Frequency.HZ1000:
      return 1000;
  }
  throw ArgumentError('Unknown Frequency value');
}

Uint32List serializeChannels(List<int> analogChannels) {
  return Uint32List.fromList(analogChannels);
}

typedef OnBITalinoDataAvailable = Function(BITalinoFrame frame);
typedef OnConnectionLost = Function();

class BITalinoController {
  /// Indicates if the controller is connected to a device.
  /// Returns true if a device is connected and false if it's not.
  bool connected = false;

  /// Indicates if the controller is trying to connect to a device.
  /// Returns true if it's trying to connect and false if it's not.
  bool _connecting = false;

  /// Indicates if the device is acquiring data.
  /// Returns true if it's acquiring and false if it's not.
  bool acquiring = false;

  /// Returns the address of the connected device.
  String connectedDevice;

  /// Indicates the type of bluetooth communication: [CommunicationType.BTH] or [CommunicationType.BLE].
  CommunicationType communicationType;

  StreamSubscription<dynamic> _dataStreamSubscription;

  /// Callback when the connection is lost.
  OnConnectionLost _onConnectionLost;

  /// Controls a BITalino device.
  BITalinoController() {
    _channel.setMethodCallHandler(this._didRecieveTranscript);
  }

  Future<void> _didRecieveTranscript(MethodCall call) async {
    // type inference will work here avoiding an explicit cast
    //final String arguments = call.arguments;
    switch (call.method) {
      case "lostConnection":
        if (_onConnectionLost != null) _onConnectionLost();
        _disconnectVars();
        return;
      default:
        throw MissingPluginException();
    }
  }

  /// Initializes the [BITalinoController].
  /// Returns [true] if the controller is initialized successfully, [false] otherwise.
  ///
  /// The [CommunicationType] must be provided.
  /// If the [CommunicationType.BTH] is selected, a [OnBITalinoDataAvailable] callback can be provided.
  ///
  /// [CommunicationType.BLE] might not be working.
  ///
  /// Returns [BITalinoException(BITalinoErrorType.BLE_NOT_IMPLEMENT_ONDATA)] if the [OnBITalinoDataAvailable] callback is provided with [CommunicationType.BLE].
  /// Returns [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Returns [BITalinoException(BITalinoErrorType.CONTROLLER_FAILED_INITIALIZE)] if the controller failed to initialize.
  /// Returns [BITalinoException(BITalinoErrorType.CONTROLLER_ALREADY_INITIALIZED)] if the controller was already initialize before.
  /// Returns [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<void> initialize(communicationType,
      {OnBITalinoDataAvailable onDataAvailable}) async {
    if (this.communicationType == null) {
      this.communicationType = communicationType;
      if (communicationType == CommunicationType.BLE && onDataAvailable != null)
        throw BITalinoException(BITalinoErrorType.BLE_NOT_IMPLEMENT_ONDATA);

      bool success;
      try {
        success = await _channel.invokeMethod("initialize", <String, dynamic>{
          "type": serializeCommunicationType(communicationType)
        }).timeout(timeout);
      } on TimeoutException {
        throw BITalinoException(BITalinoErrorType.TIMEOUT);
      } catch (e) {
        throw BITalinoException(BITalinoErrorType.CONTROLLER_FAILED_INITIALIZE);
      }

      if (success) {
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
      } else {
        throw BITalinoException(BITalinoErrorType.CONTROLLER_FAILED_INITIALIZE);
      }
    } else {
      throw BITalinoException(BITalinoErrorType.CONTROLLER_ALREADY_INITIALIZED);
    }
  }

  /// Connects to a BITalino device address.
  /// Returns [true] if the device is connected successfully, [false] otherwise.
  ///
  /// A valid bluetooth device address must be provided.
  /// A [onConnectionLost] callback can also be provided.
  ///
  /// Returns [BITalinoException(BITalinoErrorType.ADDRESS_NULL)] if the address provided is null.
  /// Returns [BITalinoException(BITalinoErrorType.ALREADY_CONNECTING)] if a connection attempt is already in progress.
  /// Returns [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Returns [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Returns [BITalinoException(BITalinoErrorType.BT_DEVICE_ALREADY_CONNECTED)] if a device is already connected.
  /// Returns [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<bool> connect(String address,
      {OnConnectionLost onConnectionLost}) async {
    if (address == null)
      throw BITalinoException(BITalinoErrorType.ADDRESS_NULL);
    if (_connecting)
      throw BITalinoException(BITalinoErrorType.ALREADY_CONNECTING);
    if (!connected) {
      try {
        _connecting = true;
        connected = await _channel.invokeMethod(
            "connect", <String, dynamic>{"address": address}).timeout(timeout);
      } on TimeoutException {
        _connecting = false;
        throw BITalinoException(BITalinoErrorType.TIMEOUT);
      } catch (e) {
        _connecting = false;
        throw BITalinoException(BITalinoErrorType.BT_DEVICE_FAILED_CONNECT);
      }
      if (connected) {
        connectedDevice = address;
        _onConnectionLost = onConnectionLost;
      } else {
        _connecting = false;
        throw BITalinoException(BITalinoErrorType.BT_DEVICE_FAILED_CONNECT);
      }
      _connecting = false;
      return connected;
    } else {
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_ALREADY_CONNECTED);
    }
  }

  Future<BITalinoDescription> _getDescription() async {
    if (connected) {
      try {
        return BITalinoDescription._fromPlatformData(
            await _channel.invokeMethod("description").timeout(timeout));
      } on TimeoutException {
        throw BITalinoException(BITalinoErrorType.TIMEOUT);
      } catch (e) {
        throw BITalinoException(BITalinoErrorType.CUSTOM, e.toString());
      }
    } else {
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED);
    }
  }

  /// Returns the BITalino device firmware.
  ///
  /// Returns [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Returns [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Returns [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<String> version() async {
    return (await _getDescription()).fwVersion;
  }

  /// Returns [true] if the connected device is BITalino2, [false] otherwise.
  ///
  /// Returns [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Returns [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Returns [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<bool> isBitalino2() async {
    return (await _getDescription()).isBitalino2;
  }

  /// Disconnects the controller from the connected device.
  /// Returns [true] if the device is disconnected successfully, [false] otherwise.
  ///
  /// Returns [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Returns [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Returns [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<bool> disconnect() async {
    if (connected) {
      try {
        if (!(await _channel.invokeMethod("disconnect").timeout(timeout))) {
          if (_onConnectionLost != null) _onConnectionLost();
          _disconnectVars();
        }
      } on TimeoutException {
        throw BITalinoException(BITalinoErrorType.TIMEOUT);
      } catch (e) {
        throw BITalinoException(BITalinoErrorType.CUSTOM, e.toString());
      }
    } else {
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED);
    }
    return connected;
  }

  void _disconnectVars() {
    connectedDevice = null;
    connected = false;
    acquiring = false;
    this._onConnectionLost = null;
  }

  /// Disposes the controller. Must be called to avoid memory leaks.
  /// Returns [true] if the controller is disposed successfully, [false] otherwise.
  ///
  /// Returns [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Returns [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<bool> dispose() async {
    _dataStreamSubscription?.cancel();
    communicationType = null;
    _disconnectVars();
    try {
      return await _channel.invokeMethod("dispose").timeout(timeout);
    } on TimeoutException {
      throw BITalinoException(BITalinoErrorType.TIMEOUT);
    } catch (e) {
      throw BITalinoException(BITalinoErrorType.CUSTOM, e.toString());
    }
  }

  /// Returns the [BITalinoState] of the connected device.
  /// The [BITalinoState] object has properties:
  /// - identifier        [String]
  /// - battery           [int]
  /// - batteryThreshold  [int]
  /// - analog            [List<int>]
  /// - digital           [List<int>]
  ///
  /// Returns [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Returns [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Returns [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<BITalinoState> state() async {
    if (connected) {
      try {
        return BITalinoState._fromPlatformData(
            await _channel.invokeMethod("state").timeout(timeout));
      } on TimeoutException {
        throw BITalinoException(BITalinoErrorType.TIMEOUT);
      } catch (e) {
        throw BITalinoException(BITalinoErrorType.CUSTOM, e.toString());
      }
    } else {
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED);
    }
  }

  /// Sets the battery threshold value of the connected device.
  /// Returns [true] if the battery threshold is set successfully, [false] otherwise.
  ///
  /// Returns [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Returns [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Returns [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<bool> setBatteryThreshold(int threshold) async {
    if (connected) {
      try {
        return await _channel.invokeMethod(
            "batteryThreshold", {"threshold": threshold}).timeout(timeout);
      } on TimeoutException {
        throw BITalinoException(BITalinoErrorType.TIMEOUT);
      } catch (e) {
        throw BITalinoException(BITalinoErrorType.CUSTOM, e.toString());
      }
    } else {
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED);
    }
  }

  /// Starts acquiring on the connected bluetooth device.
  /// Returns [true] if the acquisition started successfully, [false] otherwise.
  ///
  /// [CommunicationType.BTH] is required.
  /// analogChannels is a [List<int>] of the active analog channels.
  /// While acquiring, the [OnBITalinoDataAvailable] callback is called.
  ///
  /// Returns [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Returns [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Returns [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  /// Returns [BITalinoException(BITalinoErrorType.BT_DEVICE_ALREADY_ACQUIRING)] if the connected bluetooth device is already acquiring.
  /// Returns [BITalinoException(BITalinoErrorType.BT_DEVICE_BTH)] if [CommunicationType.BTH] is not selected.
  Future<bool> start(List<int> analogChannels, Frequency sampleRate) async {
    if (connected) {
      if (communicationType == CommunicationType.BTH) {
        if (!acquiring) {
          try {
            if (await _channel.invokeMethod("start", <String, dynamic>{
              "analogChannels": serializeChannels(analogChannels),
              "sampleRate": serializeFrequency(sampleRate),
            }).timeout(timeout)) {
              acquiring = true;
            } else {
              acquiring = false;
            }
            return acquiring;
          } on TimeoutException {
            throw BITalinoException(BITalinoErrorType.TIMEOUT);
          } catch (e) {
            throw BITalinoException(BITalinoErrorType.CUSTOM, e.toString());
          }
        } else {
          throw BITalinoException(
              BITalinoErrorType.BT_DEVICE_ALREADY_ACQUIRING);
        }
      } else {
        throw BITalinoException(BITalinoErrorType.BT_DEVICE_BTH);
      }
    } else {
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED);
    }
  }

  /// Stops acquiring on the connected bluetooth device.
  /// Returns [true] if the acquisition was stopped successfully, [false] otherwise.
  ///
  /// Returns [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Returns [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Returns [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  /// Returns [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_ACQUIRING)] if the connected bluetooth device is not acquiring.
  Future<bool> stop() async {
    if (connected) {
      if (acquiring) {
        try {
          return await _channel.invokeMethod("stop").timeout(timeout);
        } on TimeoutException {
          throw BITalinoException(BITalinoErrorType.TIMEOUT);
        } catch (e) {
          throw BITalinoException(BITalinoErrorType.CUSTOM, e.toString());
        }
      } else {
        throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_ACQUIRING);
      }
    } else {
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED);
    }
  }

  /// Assigns the digital output states.
  /// Returns [true] if the command is sent successfully, [false] otherwise.
  /// An array with the digital channels to enable set as 1, and the digital channels to disable set as 0.
  ///
  /// Returns [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Returns [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Returns [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<bool> trigger(List<int> digitalChannels) async {
    if (connected) {
      try {
        return await _channel.invokeMethod("trigger", <String, dynamic>{
          "digitalChannels": serializeChannels(digitalChannels),
        }).timeout(timeout);
      } on TimeoutException {
        throw BITalinoException(BITalinoErrorType.TIMEOUT);
      } catch (e) {
        throw BITalinoException(BITalinoErrorType.CUSTOM, e.toString());
      }
    } else {
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED);
    }
  }

  /// Assigns the analog (PWM) output value. (BITalino 2 only)
  /// Returns [true] if the command is sent successfully, [false] otherwise.
  Future<bool> pwm(int pwmOutput) async {
    if (connected) {
      try {
        return await _channel.invokeMethod("pwm", <String, dynamic>{
          "pwmOutput": pwmOutput,
        }).timeout(timeout);
      } on TimeoutException {
        throw BITalinoException(BITalinoErrorType.TIMEOUT);
      } catch (e) {
        throw BITalinoException(BITalinoErrorType.CUSTOM, e.toString());
      }
    } else {
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED);
    }
  }
}
