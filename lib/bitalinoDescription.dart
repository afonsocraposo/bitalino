part of 'bitalino.dart';

class BITalinoDescription {
  BITalinoDescription._fromPlatformData(Map<dynamic, dynamic> data)
      : fwVersion = data['fwVersion'],
        isBitalino2 = data['isBITalino2'];

  final String fwVersion;
  final bool isBitalino2;
}
