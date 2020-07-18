part of 'bitalino.dart';

/// Object that has the current state returned by the bluetooth device.
class BITalinoState {
  BITalinoState._fromPlatformData(Map<dynamic, dynamic> data)
      : identifier = data['identifier'],
        battery = data['battery'],
        batteryThreshold = data['batteryThreshold'],
        analog = List<int>.from(data['analog']),
        digital = List<int>.from(data['digital']);

  /// MAC address of the device that sent the frame.
  final String identifier;

  /// Current battery value.
  final int battery;

  /// Current battery threshold value.
  final int batteryThreshold;

  /// List with all the analog channel values of the frame.
  final List<int> analog;

  /// List with all the digital channel values of the frame.
  final List<int> digital;
}
