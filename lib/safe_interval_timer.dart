import 'dart:async';
import 'dart:isolate';

const millisecondsPerMinute = 60000;

class SafeIntervalTimer {
  var sampleSize = 25;

  static const _defaultBpm = 240;

  var bpm = _defaultBpm;
  var tickRate = millisecondsPerMinute / _defaultBpm;

  Timer? timer;
  Isolate? isolate;
  int millisLastTick = 0;

  double overallDeviation = 0;
  var inAccurateTicks = 0;
  // defaults to -1, since there is natural delay between starting the timer or isolate and it's first tick
  var ticksOverall = -1;

  List<String> deviationInfo = [];

  void optimisticApproach() {
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
      deviationInfo.add('Deviation in tick #$ticksOverall - $deviation ms');

      inAccurateTicks++;
      overallDeviation += deviation;
    }

    millisLastTick = now;

    if (ticksOverall >= sampleSize) {
      onSamplingComplete();
    }
  }

  void pessimisticApproach() {
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

  Future<void> optimisticIsolateApproach() async {
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

  Future<void> pessimisticIsolateApproach() async {
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

  void onSamplingComplete() {
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
}
