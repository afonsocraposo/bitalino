part of 'bitalino.dart';

enum BITalinoErrorType {
  ADDRESS_NULL,
  ALREADY_CONNECTING,
  BT_DEVICE_NOT_CONNECTED,
  BT_DEVICE_FAILED_CONNECT,
  BT_DEVICE_FAILED_DISCONNECT,
  DEVICE_NOT_IN_ACQUISITION_MODE,
  LOST_CONNECTION,
  BT_DEVICE_ALREADY_CONNECTED,
  CONTROLLER_FAILED_INITIALIZE,
  CONTROLLER_ALREADY_INITIALIZED,
  BLE_NOT_IMPLEMENT_ONDATA,
  TIMEOUT,
  START_FAILED,
  CUSTOM,
  BT_DEVICE_ALREADY_ACQUIRING,
  BT_DEVICE_NOT_ACQUIRING,
  BT_DEVICE_BTH,
  NOT_IMPLEMENTED_IOS
}

class BITalinoException implements Exception {
  String msg;
  final BITalinoErrorType type;

  BITalinoException([this.type, this.msg]) {
    switch (type) {
      case BITalinoErrorType.ADDRESS_NULL:
        msg = "The device address must not be null.";
        return;
      case BITalinoErrorType.ALREADY_CONNECTING:
        msg = "A connection attempt is already in process.";
        return;
      case BITalinoErrorType.BT_DEVICE_NOT_CONNECTED:
        msg = "The bluetooth device is not connected.";
        return;
      case BITalinoErrorType.BT_DEVICE_FAILED_CONNECT:
        msg = "Failed to connect to the bluetooth device.";
        return;
      case BITalinoErrorType.BT_DEVICE_FAILED_DISCONNECT:
        msg = "Failed to disconnect from the bluetooth device.";
        return;
      case BITalinoErrorType.DEVICE_NOT_IN_ACQUISITION_MODE:
        msg = "The device is not in acquisiton mode.";
        return;
      case BITalinoErrorType.LOST_CONNECTION:
        msg = "The connection to the device was lost.";
        return;
      case BITalinoErrorType.BT_DEVICE_ALREADY_CONNECTED:
        msg =
            "A bluetooth device is already connected. Disconnect that device first.";
        return;
      case BITalinoErrorType.BT_DEVICE_ALREADY_ACQUIRING:
        msg = "The bluetooth device is already in acquisiton mode.";
        return;
      case BITalinoErrorType.BT_DEVICE_NOT_ACQUIRING:
        msg = "The bluetooth device is not in acquisiton mode.";
        return;
      case BITalinoErrorType.CONTROLLER_FAILED_INITIALIZE:
        msg = "The BITalino controller failed to initialize.";
        return;
      case BITalinoErrorType.CONTROLLER_ALREADY_INITIALIZED:
        msg = "The BITalino controller was already initialized.";
        return;
      case BITalinoErrorType.BLE_NOT_IMPLEMENT_ONDATA:
        msg = "BLE connection does not implement \"onDataAvailable\".";
        return;
      case BITalinoErrorType.TIMEOUT:
        msg =
            "This method exceed the timeout limit of ${timeout.inSeconds} seconds.";
        return;
      case BITalinoErrorType.BT_DEVICE_BTH:
        msg = "CommunicationType must be BTH";
        return;
      case BITalinoErrorType.NOT_IMPLEMENTED_IOS:
        msg = "This is not implemented for IOS devices";
        return;
      case BITalinoErrorType.CUSTOM:
        return;
      default:
        msg = "Undefined exception.";
        return;
    }
  }

  String toString() => 'BITalinoException: $type - $msg';
}
