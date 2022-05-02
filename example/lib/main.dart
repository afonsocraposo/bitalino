import 'package:bitalino_example/chart.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:bitalino/bitalino.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  BITalinoController bitalinoController;
  int sequence = 0;
  List<SensorValue> data = [];
  DateTime previousTime;
  TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  Future<void> initPlatformState(bool bth) async {
    bitalinoController = BITalinoController(
      controller.text,
      bth ? CommunicationType.BTH : CommunicationType.BLE,
    );
    try {
      await bitalinoController.initialize();
      _notify("Initialized: ${bth ? "BTH" : "BLE"}");
    } catch (e) {
      _notify("Initialization failed");
    }
  }

  _notify(dynamic text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text.toString(),
        ),
        duration: Duration(
          seconds: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Expanded(
              child: ListView(
                children: <Widget>[
                  TextField(
                    decoration: InputDecoration(hintText: "MAC/UUI"),
                    textAlign: TextAlign.center,
                    controller: controller,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            initPlatformState(true);
                          },
                          child: Text("BTH"),
                        ),
                      ),
                      SizedBox(
                        width: 16,
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            initPlatformState(false);
                          },
                          child: Text("BLE"),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            bool connected = await bitalinoController.connect(
                                onConnectionLost: () {
                              _notify('Connection lost');
                            });
                            _notify(
                              "Connected: $connected",
                            );
                          },
                          child: Text("Connect"),
                        ),
                      ),
                      SizedBox(
                        width: 16,
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            bool disconnected =
                                await bitalinoController.disconnect();
                            _notify("Disconnected: $disconnected");
                          },
                          child: Text("Disconnect"),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            previousTime = DateTime.now();
                            bool started = await bitalinoController.start(
                              [
                                0,
                              ],
                              Frequency.HZ10,
                              numberOfSamples: 10,
                              onDataAvailable: (frame) {
                                if (data.length >= 30) data.removeAt(0);
                                setState(() {
                                  data.add(SensorValue(previousTime,
                                      frame.analog[0].toDouble()));
                                  previousTime =
                                      DateTime.fromMillisecondsSinceEpoch(
                                          previousTime.millisecondsSinceEpoch +
                                              1000 ~/ 10);
                                });
                              },
                            );
                            _notify("Started: $started");
                          },
                          child: Text("Start"),
                        ),
                      ),
                      SizedBox(
                        width: 16,
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            bool stopped = await bitalinoController.stop();
                            _notify("Stopped: $stopped");
                          },
                          child: Text("Stop"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Chart(data),
              ),
            )
          ],
        ),
      ),
    );
  }
}
