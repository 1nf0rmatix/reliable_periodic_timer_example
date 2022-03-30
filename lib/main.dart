import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';

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

  var sampleSize = 25;

  static const _defaultBpm = 240;
  static const _millisecondsPerMinute = 60000;

  var bpm = _defaultBpm;
  var tickRate = _millisecondsPerMinute / _defaultBpm;

  Timer? timer;
  Isolate? isolate;
  int millisLastTick = 0;

  double overallDeviation = 0;
  var inAccurateTicks = 0;
  // defaults to -1, since there is natural delay between starting the timer or isolate and it's first tick
  var ticksOverall = -1;

  List<String> deviationInfo = [];

  void _optimisticApproach() {
    _resetStatistics();

    timer = Timer.periodic(
      Duration(milliseconds: tickRate.floor()),
      (timer) async {
        _onTimerTick();
      },
    );
  }

  void _onTimerTick() {
    if (ticksOverall >= sampleSize) return;

    ticksOverall++;

    var now = DateTime.now().millisecondsSinceEpoch;
    var duration = now - millisLastTick;

    // ignore the very first tick since there is natural delay between setting up the timer and the first tick
    if (duration != tickRate && ticksOverall > 0) {
      var deviation = (duration - tickRate).abs();
      deviationInfo.add('Deviation in tick #$ticksOverall  - $deviation ms');

      inAccurateTicks++;
      overallDeviation += deviation;
    }

    millisLastTick = now;

    if (ticksOverall >= sampleSize) {
      _onSamplingComplete();
    }
  }

  void _pessimisticApproach() {
    _resetStatistics();

    timer = Timer.periodic(
      const Duration(microseconds: 500),
      (timer) {
        if (ticksOverall >= sampleSize) return;

        var now = DateTime.now().millisecondsSinceEpoch;
        var duration = now - millisLastTick;

        if (duration >= tickRate) {
          _onTimerTick();

          millisLastTick = now;
        }
      },
    );
  }

  Future<void> _optimisticIsolateApproach() async {
    ReceivePort receiveFromIsolatePort = ReceivePort();

    _resetStatistics();

    isolate = await Isolate.spawn(
      _optimisticIsolateTimer,
      {
        'tickRate': tickRate,
        'sendToMainThreadPort': receiveFromIsolatePort.sendPort,
      },
    );

    receiveFromIsolatePort.listen((_) {
      _onTimerTick();
    });
  }

  static Future<void> _optimisticIsolateTimer(Map data) async {
    double tickRate = data['tickRate'];
    SendPort sendToMainThreadPort = data['sendToMainThreadPort'];

    var tickCounter = 0;

    Timer.periodic(Duration(milliseconds: tickRate.floor()), (timer) {
      sendToMainThreadPort.send(tickCounter++);
    });
  }

  Future<void> _pessimisticIsolateApproach() async {
    ReceivePort receiveFromIsolatePort = ReceivePort();

    _resetStatistics();

    isolate = await Isolate.spawn(
      _pessimisticIsolateTimer,
      {
        'tickRate': tickRate,
        'sendToMainThreadPort': receiveFromIsolatePort.sendPort,
      },
    );

    receiveFromIsolatePort.listen((_) {
      _onTimerTick();
    });
  }

  static Future<void> _pessimisticIsolateTimer(Map data) async {
    double tickRate = data['tickRate'];
    SendPort sendToMainThreadPort = data['sendToMainThreadPort'];

    var tickCounter = 0;
    var millisLastTick = DateTime.now().millisecondsSinceEpoch;
    bool needsTick = true;

    var overallDeviation = 0.0;
    var inAccurateTicks = 0;

    Timer.periodic(const Duration(microseconds: 500), (timer) {
      var now = DateTime.now().millisecondsSinceEpoch;
      var duration = now - millisLastTick;

      if (duration >= tickRate && needsTick) {
        sendToMainThreadPort.send(tickCounter++);
        millisLastTick = now;
        needsTick = false;

        var deviation = (duration - tickRate).abs();

        if (deviation > 0) {
          overallDeviation += deviation;
          inAccurateTicks++;

          print('Deviation in tick $tickCounter - $deviation ms');
          print('Overall deviation ${overallDeviation / inAccurateTicks} ms');
        }
      }

      if (duration < tickRate) {
        needsTick = true;
      }
    });
  }

  void _onSamplingComplete() {
    timer?.cancel();
    timer = null;

    isolate?.kill();
    isolate = null;

    var averageDeviation = overallDeviation / inAccurateTicks;

    for (var message in deviationInfo) print(message);

    print('Ticks $ticksOverall');
    print('Inaccurate ticks $inAccurateTicks');
    print('${((inAccurateTicks / ticksOverall) * 100).toStringAsFixed(2)}% in-accuracy');
    print('Average deviation ${averageDeviation.toStringAsFixed(5)} ms');
  }

  void _resetStatistics() {
    timer?.cancel();
    millisLastTick = DateTime.now().millisecondsSinceEpoch;
    deviationInfo.clear();

    overallDeviation = 0;
    inAccurateTicks = 0;
    ticksOverall = -1;
  }

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
                initialValue: bpm.toString(),
                onChanged: (value) => setState(() {
                  bpm = int.tryParse(value) ?? bpm;
                  tickRate = _millisecondsPerMinute / bpm;
                }),
              ),
              ElevatedButton(
                onPressed: () => _optimisticApproach(),
                child: const Text('Optimistic Approach'),
              ),
              ElevatedButton(
                onPressed: () => _pessimisticApproach(),
                child: const Text('Pessimistic Approach'),
              ),
              ElevatedButton(
                onPressed: () => _optimisticIsolateApproach(),
                child: const Text('Optimistic Isolate Approach'),
              ),
              ElevatedButton(
                onPressed: () => _pessimisticIsolateApproach(),
                child: const Text('Pessimistic Isolate Approach'),
              ),
              ElevatedButton(
                onPressed: _onSamplingComplete,
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
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
