import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
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
  BITalinoController bitalinoController = BITalinoController();
  int sequence = 0;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    try {
      await bitalinoController.initialize(CommunicationType.BTH,
          onDataAvailable: (BITalinoFrame frame) {
        print(
            "Sequence: ${frame.sequence}, dS: ${frame.sequence - sequence}, analog: ${frame.analog}, digital: ${frame.digital}");
        sequence = frame.sequence;
      });
    } on PlatformException catch (Exception) {
      print(Exception.message);
      print("Initialization failed");
    }
  }

  _notify(dynamic text) {
    _scaffoldKey.currentState.showSnackBar(
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
            RaisedButton(
              onPressed: () async {
                _notify(
                  await bitalinoController.connect(
                    "20:16:07:18:17:02",
                    onConnectionLost: () {
                      _notify("Connection lost");
                    },
                  ),
                );
              },
              child: Text("Connect"),
            ),
            RaisedButton(
              onPressed: () async {
                _notify(await bitalinoController.version());
              },
              child: Text("version"),
            ),
            RaisedButton(
              onPressed: () async {
                _notify(await bitalinoController.isBitalino2());
              },
              child: Text("bitalino2?"),
            ),
            RaisedButton(
              onPressed: () async {
                _notify(await bitalinoController.disconnect());
              },
              child: Text("Disconnect"),
            ),
            RaisedButton(
              onPressed: () async {
                _notify(
                  await bitalinoController.start([
                    0,
                  ], Frequency.HZ10),
                );
              },
              child: Text("start"),
            ),
            RaisedButton(
              onPressed: () async {
                _notify(await bitalinoController.stop());
              },
              child: Text("stop"),
            ),
          ],
        ),
      ),
    );
  }
}
