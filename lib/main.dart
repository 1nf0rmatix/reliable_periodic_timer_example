import 'package:flutter/material.dart';

import 'safe_interval_timer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  var safeIntervalTimer = SafeIntervalTimer();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(80.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_counter.toString()),
              ),
              TextFormField(
                initialValue: safeIntervalTimer.bpm.toString(),
                onChanged: (value) => setState(() {
                  safeIntervalTimer.bpm = int.tryParse(value) ?? safeIntervalTimer.bpm;
                  safeIntervalTimer.intervalInMilliseconds = millisecondsPerMinute / safeIntervalTimer.bpm;
                }),
              ),
              ElevatedButton(
                onPressed: () => safeIntervalTimer.optimisticApproach(),
                child: const Text('Optimistic Approach'),
              ),
              ElevatedButton(
                onPressed: () => safeIntervalTimer.pessimisticApproach(),
                child: const Text('Pessimistic Approach'),
              ),
              ElevatedButton(
                onPressed: () => safeIntervalTimer.optimisticIsolateApproach(),
                child: const Text('Optimistic Isolate Approach'),
              ),
              ElevatedButton(
                onPressed: () => safeIntervalTimer.pessimisticIsolateApproach(),
                child: const Text('Pessimistic Isolate Approach'),
              ),
              ElevatedButton(
                onPressed: safeIntervalTimer.onSamplingComplete,
                child: const Text('CANCEL'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _counter++;
          });
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
