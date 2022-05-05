import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

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
  /// 1 Hz
  HZ1,

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
  // throw ArgumentError('Unknown CommunicationType');
}

int serializeFrequency(Frequency frequency) {
  switch (frequency) {
    case Frequency.HZ1:
      return 1;
    case Frequency.HZ10:
      return 10;
    case Frequency.HZ100:
      return 100;
    case Frequency.HZ1000:
      return 1000;
  }
  // throw ArgumentError('Unknown Frequency value');
}

Uint32List serializeChannels(List<int> analogChannels) {
  return Uint32List.fromList(analogChannels);
}

typedef OnBITalinoDataAvailable = Function(BITalinoFrame frame);
typedef OnConnectionLost = Function();

class BITalinoController {
  /// Address of the device.
  /// [Android]: MAC address
  /// [IOS]: BITalino UUID
  late String address;

  /// Indicates if the controller is initialized.
  /// Returns true if the controller is initialized and false if it's not.
  bool initialized = false;

  /// Indicates if the controller is connected to a device.
  /// Returns true if a device is connected and false if it's not.
  bool connected = false;

  /// Indicates if the controller is trying to connect to a device.
  /// Returns true if it's trying to connect and false if it's not.
  bool _connecting = false;

  /// Indicates if the device is recording data.
  /// Returns true if it's recording and false if it's not.
  bool recording = false;

  /// Indicates the type of bluetooth communication: [CommunicationType.BTH] or [CommunicationType.BLE].
  late CommunicationType communicationType;

  StreamSubscription<dynamic>? _dataStreamSubscription;

  /// Callback when the connection is lost.
  OnConnectionLost? _onConnectionLost;

  /// Callback when data is available during recording.
  OnBITalinoDataAvailable? _onBITalinoDataAvailable;

  /// Controls a BITalino device.
  ///
  /// The device MAC address (Android) or UUID (IOS), and the [CommunicationType] must be provided.
  ///
  /// Throws [BITalinoException(BITalinoErrorType.NOT_IMPLEMENTED_IOS)] if the [CommunicationType.BTH] is used on IOS devices.
  /// Throws [BITalinoException(BITalinoErrorType.ADDRESS_NULL)] if the provided address is null.
  /// Throws [BITalinoException(BITalinoErrorType.INVALID_ADDRESS)] if the provided MAC address is invalid.
  /// Throws [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  BITalinoController(String address, CommunicationType communicationType) {
    if (address.isEmpty)
      throw BITalinoException(BITalinoErrorType.ADDRESS_NULL);
    if (Platform.isIOS && communicationType == CommunicationType.BTH) {
      throw BITalinoException(BITalinoErrorType.NOT_IMPLEMENTED_IOS);
    }
    if (Platform.isAndroid) {
      RegExp regExp = new RegExp(r"^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$");
      if (!regExp.hasMatch(address))
        throw BITalinoException(BITalinoErrorType.INVALID_ADDRESS);
    }

    _channel.setMethodCallHandler(this._didReceiveTranscript);
    this.communicationType = communicationType;
    this.address = address;
  }

  // handles method calls from native side
  Future<void> _didReceiveTranscript(MethodCall call) async {
    switch (call.method) {
      case "lostConnection":
        _onConnectionLost?.call();
        _disconnectVars();
        return;
      default:
        throw MissingPluginException();
    }
  }

  // resets variables when the device is disconnected
  void _disconnectVars() {
    connected = false;
    recording = false;
    this._onConnectionLost = null;
  }

  /// Initializes the [BITalinoController].
  /// Throws [BITalinoErrorType.CONTROLLER_FAILED_INITIALIZE] if the controller fails to initialize.
  ///
  /// Throws [BITalinoException(BITalinoErrorType.CONTROLLER_FAILED_INITIALIZE)] if the controller failed to initialize.
  /// Throws [BITalinoException(BITalinoErrorType.CONTROLLER_ALREADY_INITIALIZED)] if the controller was already initialize before.
  /// Throws [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<void> initialize() async {
    late bool initialized;
    try {
      if (Platform.isAndroid) {
        initialized = await _channel.invokeMethod(
            "initialize", <String, dynamic>{
          "type": serializeCommunicationType(communicationType)
        }).timeout(timeout);
      } else if (Platform.isIOS) {
        initialized = await _channel.invokeMethod("initialize",
            <String, dynamic>{"address": address}).timeout(timeout);
      }
    } on TimeoutException {
      throw BITalinoException(BITalinoErrorType.TIMEOUT);
    } catch (e) {
      print(e.toString());
      throw BITalinoException(BITalinoErrorType.CONTROLLER_FAILED_INITIALIZE);
    }

    if (!initialized)
      throw BITalinoException(BITalinoErrorType.CONTROLLER_FAILED_INITIALIZE);

    this.initialized = true;
    const EventChannel bitalinoEventChannel =
        EventChannel('com.afonsoraposo.bitalino/dataStream');
    _dataStreamSubscription =
        bitalinoEventChannel.receiveBroadcastStream().listen(
      (dynamic bitalinoData) {
        if (_onBITalinoDataAvailable != null)
          _onBITalinoDataAvailable!(
              BITalinoFrame._fromPlatformData(bitalinoData));
      },
    );
  }

  /// Connects to a BITalino device address.
  /// Returns [true] if the device is connected successfully, [false] otherwise.
  ///
  /// A valid bluetooth device address must be provided.
  /// A [onConnectionLost] callback can also be provided.
  ///
  /// Throws [BITalinoException(BITalinoErrorType.ALREADY_CONNECTING)] if a connection attempt is already in progress.
  /// Throws [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_ALREADY_CONNECTED)] if a device is already connected.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_FAILED_CONNECT)] if the device fails to connect.
  /// Throws [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<bool> connect({OnConnectionLost? onConnectionLost}) async {
    if (_connecting)
      throw BITalinoException(BITalinoErrorType.ALREADY_CONNECTING);
    if (connected)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_ALREADY_CONNECTED);

    try {
      _connecting = true;
      if (Platform.isAndroid) {
        connected = await _channel.invokeMethod(
            "connect", <String, dynamic>{"address": address}).timeout(timeout);
      } else if (Platform.isIOS) {
        connected = await _channel.invokeMethod("connect").timeout(timeout);
      }
    } on TimeoutException {
      _connecting = false;
      throw BITalinoException(BITalinoErrorType.TIMEOUT);
    } catch (e) {
      _connecting = false;
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_FAILED_CONNECT);
    }
    _connecting = false;
    if (connected) {
      _onConnectionLost = onConnectionLost;
      return true;
    } else {
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_FAILED_CONNECT);
    }
  }

  Future<BITalinoDescription> _getDescription() async {
    if (Platform.isIOS)
      throw BITalinoException(BITalinoErrorType.NOT_IMPLEMENTED_IOS);

    try {
      return BITalinoDescription._fromPlatformData(await (_channel
          .invokeMethod("description")
          .timeout(timeout) as FutureOr<Map<dynamic, dynamic>>));
    } on TimeoutException {
      throw BITalinoException(BITalinoErrorType.TIMEOUT);
    } catch (e) {
      throw BITalinoException(BITalinoErrorType.CUSTOM, e.toString());
    }
  }

  /// Returns the BITalino device firmware.
  ///
  /// Throws [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_CANNOT_BE_RECORDING)] if the device is recording.
  /// Throws [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<String?> version() async {
    if (!connected)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED);
    if (recording)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_CANNOT_BE_RECORDING);

    if (Platform.isAndroid)
      return (await _getDescription()).fwVersion;
    else if (Platform.isIOS)
      return await (_channel.invokeMethod("version").timeout(timeout)
          as FutureOr<String?>);
    return null;
  }

  /// Returns [true] if the connected device is BITalino2, [false] otherwise.
  ///
  /// Throws [BITalinoException(BITalinoErrorType.NOT_IMPLEMENTED_IOS)] if this method is called on IOS devices.
  /// Throws [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_CANNOT_BE_RECORDING)] if the device is recording.
  /// Throws [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<bool> isBITalino2() async {
    if (Platform.isIOS)
      throw BITalinoException(BITalinoErrorType.NOT_IMPLEMENTED_IOS);
    if (!connected)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED);
    if (recording)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_CANNOT_BE_RECORDING);
    else if (Platform.isAndroid) return (await _getDescription()).isBitalino2;
    return false;
  }

  /// Disconnects the controller from the connected device.
  /// Returns [true] if the device is disconnected successfully, [false] otherwise.
  ///
  /// Throws [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Throws [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<bool> disconnect() async {
    if (!connected)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED);

    if (recording) await stop();
    try {
      bool disconnected =
          await _channel.invokeMethod("disconnect").timeout(timeout);
      if (disconnected) _disconnectVars();
      return disconnected;
    } on TimeoutException {
      throw BITalinoException(BITalinoErrorType.TIMEOUT);
    } catch (e) {
      throw BITalinoException(BITalinoErrorType.CUSTOM, e.toString());
    }
  }

  /// Disposes the controller. Must be called to avoid memory leaks.
  /// Returns [true] if the controller is disposed successfully, [false] otherwise.
  ///
  /// Throws [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Throws [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<bool> dispose() async {
    try {
      if (recording) await stop();
    } catch (e) {
      print(e.toString());
    }
    if (connected) await disconnect();
    _dataStreamSubscription?.cancel();
    _channel.setMethodCallHandler(null);
    _disconnectVars();
    try {
      bool disposed;
      if (Platform.isAndroid)
        disposed = await _channel.invokeMethod("dispose").timeout(timeout);
      else
        disposed = true;
      if (disposed) this.initialized = false;
      return disposed;
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
  /// Throws [BITalinoException(BITalinoErrorType.NOT_IMPLEMENTED_IOS)] if this method is called on IOS devices.
  /// Throws [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_CANNOT_BE_RECORDING)] if the device is recording.
  /// Throws [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<BITalinoState> state() async {
    if (Platform.isIOS)
      throw BITalinoException(BITalinoErrorType.NOT_IMPLEMENTED_IOS);
    if (!connected)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED);
    if (recording)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_CANNOT_BE_RECORDING);

    try {
      return BITalinoState._fromPlatformData(await (_channel
          .invokeMethod("state")
          .timeout(timeout) as FutureOr<Map<dynamic, dynamic>>));
    } on TimeoutException {
      throw BITalinoException(BITalinoErrorType.TIMEOUT);
    } catch (e) {
      throw BITalinoException(BITalinoErrorType.CUSTOM, e.toString());
    }
  }

  /// Sets the battery threshold value of the connected device.
  /// Returns [true] if the battery threshold is set successfully, [false] otherwise.
  ///
  /// Throws [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Throws [BITalinoException(BITalinoErrorType.BAT_THRESHOLD_INVALID)] if the battery threshold value is invalid.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_CANNOT_BE_RECORDING)] if the device is recording.
  /// Throws [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<bool> setBatteryThreshold(int threshold) async {
    if (threshold < 0 && threshold > 63)
      throw BITalinoException(BITalinoErrorType.BAT_THRESHOLD_INVALID);
    if (!connected)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED);
    if (recording)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_CANNOT_BE_RECORDING);

    try {
      return await (_channel.invokeMethod("batteryThreshold", <String, dynamic>{
        "threshold": threshold
      }).timeout(timeout) as FutureOr<bool>);
    } on TimeoutException {
      throw BITalinoException(BITalinoErrorType.TIMEOUT);
    } catch (e) {
      throw BITalinoException(BITalinoErrorType.CUSTOM, e.toString());
    }
  }

  /// Starts recording on the connected bluetooth device.
  /// Returns [true] if the acquisition started successfully, [false] otherwise.
  ///
  /// [analogChannels] is a [List<int>] of the active analog channels.
  /// While recording, the [OnBITalinoDataAvailable] callback is called.
  /// On IOS, the [numberOfSamples] per chunk of data received must be provided.
  ///
  /// Throws [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Throws [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_ALREADY_RECORDING)] if the connected bluetooth device is already recording.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_BTH)] if [CommunicationType.BTH] is not selected.
  Future<bool> start(List<int> analogChannels, Frequency sampleRate,
      {int numberOfSamples = 50,
      OnBITalinoDataAvailable? onDataAvailable}) async {
    if (Platform.isIOS && numberOfSamples <= 0)
      throw BITalinoException(BITalinoErrorType.MISSING_PARAMETER);
    if (!connected)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED);
    if (recording)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_ALREADY_RECORDING);

    _onBITalinoDataAvailable = onDataAvailable;
    try {
      if (Platform.isAndroid) {
        recording = await _channel.invokeMethod("start", <String, dynamic>{
          "analogChannels": serializeChannels(analogChannels),
          "sampleRate": serializeFrequency(sampleRate),
        }).timeout(timeout);
      } else if (Platform.isIOS) {
        recording = await _channel.invokeMethod("start", <String, dynamic>{
          "analogChannels": serializeChannels(analogChannels),
          "sampleRate": serializeFrequency(sampleRate),
          "numberOfSamples": numberOfSamples,
        }).timeout(timeout);
      }
      return recording;
    } on TimeoutException {
      throw BITalinoException(BITalinoErrorType.TIMEOUT);
    } catch (e) {
      throw BITalinoException(BITalinoErrorType.CUSTOM, e.toString());
    }
  }

  /// Stops recording on the connected bluetooth device.
  /// Returns [true] if the acquisition was stopped successfully, [false] otherwise.
  ///
  /// Throws [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Throws [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_RECORDING)] if the connected bluetooth device is not recording.
  Future<bool> stop() async {
    if (!connected)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED);
    if (!recording)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_RECORDING);

    try {
      bool stopped = await _channel.invokeMethod("stop").timeout(timeout);
      recording = !stopped;
      if (stopped) _onBITalinoDataAvailable = null;
      return stopped;
    } on TimeoutException {
      throw BITalinoException(BITalinoErrorType.TIMEOUT);
    } catch (e) {
      throw BITalinoException(BITalinoErrorType.CUSTOM, e.toString());
    }
  }

  /// Assigns the digital output states.
  /// Returns [true] if the command is sent successfully, [false] otherwise.
  /// An array with the digital channels to enable set as 1, and the digital channels to disable set as 0.
  ///
  /// Throws [BITalinoException(BITalinoErrorType.INVALID_DIGITAL_CHANNELS)] if the digital channels array is invalid.
  /// Throws [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_CANNOT_BE_RECORDING)] if the device is recording.
  /// Throws [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<bool> setDigitalOutputs(List<int> digitalChannels) async {
    if (digitalChannels.length > 4)
      throw BITalinoException(BITalinoErrorType.INVALID_DIGITAL_CHANNELS);
    if (digitalChannels.length != 4 &&
        !(digitalChannels.length == 2 &&
            Platform.isAndroid &&
            await isBITalino2()))
      throw BITalinoException(BITalinoErrorType.INVALID_DIGITAL_CHANNELS);

    if (!connected)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED);
    if (recording)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_CANNOT_BE_RECORDING);

    try {
      return await (_channel.invokeMethod("trigger", <String, dynamic>{
        "digitalChannels": serializeChannels(digitalChannels),
      }).timeout(timeout) as FutureOr<bool>);
    } on TimeoutException {
      throw BITalinoException(BITalinoErrorType.TIMEOUT);
    } catch (e) {
      throw BITalinoException(BITalinoErrorType.CUSTOM, e.toString());
    }
  }

  /// Assigns the analog (PWM) output value. (BITalino 2 only)
  /// Returns [true] if the command is sent successfully, [false] otherwise.
  ///
  /// Throws [BITalinoException(BITalinoErrorType.NOT_IMPLEMENTED_IOS)] if this method is called on IOS devices.
  /// Throws [BITalinoException(BITalinoErrorType.NOT_BITALINO2)] if the device is not BITalino2.
  /// Throws [BITalinoException(BITalinoErrorType.TIMEOUT)] if the timeout limit is reached.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED)] if a device is not connected.
  /// Throws [BITalinoException(BITalinoErrorType.BT_DEVICE_CANNOT_BE_RECORDING)] if the device is recording.
  /// Throws [BITalinoException(BITalinoErrorType.CUSTOM)] if a native exception was raised.
  Future<bool> pwm(int pwmOutput) async {
    if (Platform.isIOS)
      throw BITalinoException(BITalinoErrorType.NOT_IMPLEMENTED_IOS);
    if (Platform.isAndroid && !(await isBITalino2()))
      throw BITalinoException(BITalinoErrorType.NOT_BITALINO2);
    if (!connected)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_NOT_CONNECTED);
    if (recording)
      throw BITalinoException(BITalinoErrorType.BT_DEVICE_CANNOT_BE_RECORDING);

    try {
      return await (_channel.invokeMethod("pwm", <String, dynamic>{
        "pwmOutput": pwmOutput,
      }).timeout(timeout) as FutureOr<bool>);
    } on TimeoutException {
      throw BITalinoException(BITalinoErrorType.TIMEOUT);
    } catch (e) {
      throw BITalinoException(BITalinoErrorType.CUSTOM, e.toString());
    }
  }
}
