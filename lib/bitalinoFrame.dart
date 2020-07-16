part of 'bitalino.dart';

class BITalinoFrame {
  BITalinoFrame._fromPlatformData(Map<dynamic, dynamic> data)
      : identifier = data['identifier'],
        sequence = data['sequence'],
        analog = List<int>.from(data['analog']),
        digital = List<int>.from(data['digital']);

  final String identifier;

  final int sequence;

  final List<int> analog;

  final List<int> digital;
}
