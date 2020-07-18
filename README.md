# BITalino
<p>
  <img src="https://img.shields.io/badge/version-0.0.3-blue.svg" />
</p>

Open source Flutter plugin that integrates the communication with BITalino devices.
Made by [Afonso Raposo](https://afonsoraposo.com).

See the an example app [here](https://github.com/Afonsocraposo/buttons_tabbar/tree/master/example/example.dart).

Tested with a BITalino2 device with BTH connection. BLE not working currently.

### Currently supporting:

This plugin uses the available native APIs available at https://bitalino.com/en/development/apis.

|Plaftorm       |Supported| Native Repository           |
|---------------|:-------:|:---------------------------:|
|Android	|   ✅    |[revolution-android-api](https://github.com/BITalinoWorld/revolution-android-api)         	|
|IOS	    	|   ❌    | -            		|

I don't possess an IOS device nor Swift knowledge, therefore, I'm not able to implement IOS support at the moment. **Feel free to contribute!**
You can always contact me for more details regarding this.

## Examples

### Start controller and connect to device
```dart
BITalinoController bitalinoController = BITalinoController();
try {
  await bitalinoController.initialize(CommunicationType.BTH,
    onDataAvailable: (BITalinoFrame frame) {
      print(frame.identifier);  // [String]
      print(frame.sequence);    // [int]
      print(frame.analog);      // [List<int>]
      print(frame.digital);     // [List<int>]
    },
  );
} on PlatformException catch (Exception) {
  print("Initialization failed: ${Exception.message}");
}
```

### Start acquisition
Start acquiring analog channels: A0, A1, A2, A3, A4, and A5, with a Sampling Rate of 10Hz.
The CommuncationType must be BTH.
```dart
bool success = await bitalinoController.start([0,1,2,3,4,5], Frequency.HZ10),);
```
During acquisiton, the onDataAvailable callback is called.

### Stop acquisition
```dart
bool success = await bitalinoController.stop();
```

### Get the device state
```dart
BITalinoState state = await bitalinoController.state();
print(state.identifier);        // [String]
print(state.battery);           // [int]
print(state.batteryThreshold);  // [int]
print(state.analog);            // [List<int>]
print(state.digital);           // [List<int>]
```

### Disconnect from device
```dart
bool success = await bitalinoController.disconnect();
```

### Dispose controller
When you're done using the controller, dispose it.
```dart
bool success = await bitalinoController.dispose();
```

## Future

If you have any suggestion or problem, let me know and I'll try to improve or fix it.
Also, **feel free to contribute** to this project! :)

## Versioning

- v0.0.3 - 18 July 2020
- v0.0.2 - 18 July 2020
- v0.0.1 - 18 July 2020

## License

GNU General Public License v3.0, see the [LICENSE.md](https://github.com/Afonsocraposo/bitalino/tree/master/LICENSE) file for details.


