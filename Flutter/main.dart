import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'dart:math';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // start connection manager
  ConnectionManager.instance;
  runApp(const MyApp());
}

/// ================= ESP CAR CONTROLLER =================

void sendCommand(String cmd) async {
  // delegate to ConnectionManager (WebSocket). Keep HTTP fallback briefly.
  ConnectionManager.instance.send(cmd);
}

/// aktive Commands (z.B forward + left gleichzeitig)
final Set<String> activeCommands = {};

/// verhindert mehrfaches feuern bei gehaltenen Tasten
final Map<LogicalKeyboardKey, bool> keyPressed = {};

/// Timer für Command-Timeout
Timer? _globalCommandTimer;

void updateCommand() {
  if (activeCommands.isEmpty) {
    sendCommand("stop");
  } else {
    sendCommand(activeCommands.join(","));
  }
}

void _startGlobalCommandTimer() {
  _globalCommandTimer?.cancel();
  _globalCommandTimer = Timer(const Duration(milliseconds: 250), () {
    if (keyPressed.values.any((pressed) => pressed)) {
      _startGlobalCommandTimer();
      return;
    }
    if (activeCommands.isNotEmpty) {
      activeCommands.clear();
      updateCommand();
    }
  });
}

/// Keyboard Support (F12 Browser!!)
void handleKey(RawKeyEvent event) {
  final key = event.logicalKey;
  final isDown = event is RawKeyDownEvent;

  if (keyPressed[key] == isDown) return;
  keyPressed[key] = isDown;

  if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
    isDown ? activeCommands.add('forward') : activeCommands.remove('forward');
  } else if (key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.keyS) {
    isDown ? activeCommands.add('backward') : activeCommands.remove('backward');
  } else if (key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.keyA) {
    isDown ? activeCommands.add('left') : activeCommands.remove('left');
  } else if (key == LogicalKeyboardKey.arrowRight ||
      key == LogicalKeyboardKey.keyD) {
    isDown ? activeCommands.add('right') : activeCommands.remove('right');
  } else if (key == LogicalKeyboardKey.space) {
    if (isDown) {
      activeCommands.clear();
    }
  } else {
    final keyLabel = key.keyLabel.toUpperCase();
    switch (keyLabel) {
      case 'ARROW UP':
      case 'W':
        isDown
            ? activeCommands.add('forward')
            : activeCommands.remove('forward');
        break;
      case 'ARROW DOWN':
      case 'S':
        isDown
            ? activeCommands.add('backward')
            : activeCommands.remove('backward');
        break;
      case 'ARROW LEFT':
      case 'A':
        isDown ? activeCommands.add('left') : activeCommands.remove('left');
        break;
      case 'ARROW RIGHT':
      case 'D':
        isDown ? activeCommands.add('right') : activeCommands.remove('right');
        break;
      case 'SPACE':
        if (isDown) {
          activeCommands.clear();
        }
        break;
      default:
        break;
    }
  }

  updateCommand();

  if (isDown) {
    _startGlobalCommandTimer();
  }
}
// ============ Route Playback ============

enum SegmentType {
  straight, //Straight line
  leftCurve, //Curve to the left
  rightCurve, //Curve to the right
  sharpLeft, // sharp Curve to the left (first steering)
  sharpRight, // sharp Curve to the right (first steering)
}

class RouteSegment {
  final Offset start; //starting point
  final Offset end; //ending point
  final double distance; //length of segment
  final double angle; //angle
  final double curvature; //curvature of segment
  final SegmentType type; // which segment type

  RouteSegment({
    required this.start,
    required this.end,
    required this.distance,
    required this.angle,
    required this.curvature,
    required this.type,
  });

  double angleDifference(RouteSegment next) {
    // calculate the difference between the current and next segment's angles
    double diff = next.angle - this.angle;
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;
    return diff;
  }
}

enum PlaybackState {
  //Which status in the UI
  idle,
  playing,
  paused,
  completed,
  error,
}

class RouteCommand {
  // Command
  final String command;
  final int duration;
  final int segmentIndex;

  RouteCommand({
    required this.command,
    required this.duration,
    required this.segmentIndex,
  });
}

// ============ Route Processing ============

class RouteProcessor {
  static List<RouteSegment> processRoute(List<Offset> points) {
    List<Offset> cleanPoints = _cleanPoints(points);
    List<Offset> smoothPoints = _smoothPoints(cleanPoints);
    List<RouteSegment> segments = _createSegments(smoothPoints);
    _analyzeVectors(segments);
    _classifySegments(segments);
    return segments;
  }

  static List<Offset> _cleanPoints(List<Offset> points) {
    List<Offset> cleaned = [];
    const double minDistance = 30.0;

    for (var point in points) {
      if (point == Offset.zero) continue;

      if (cleaned.isEmpty) {
        cleaned.add(point);
        continue;
      }

      double dist = (point - cleaned.last).distance;
      if (dist >= minDistance) {
        cleaned.add(point);
      }
    }

    return cleaned;
  }

  static List<Offset> _smoothPoints(List<Offset> points) {
    if (points.length < 3) return points;

    List<Offset> smoothed = [points.first];

    // 5-point window — makes gradual curves distinct from straight segments
    for (int i = 1; i < points.length - 1; i++) {
      final int lo = (i - 2).clamp(0, points.length - 1);
      final int hi = (i + 2).clamp(0, points.length - 1);
      final int count = hi - lo + 1;
      double sumX = 0, sumY = 0;
      for (int j = lo; j <= hi; j++) {
        sumX += points[j].dx;
        sumY += points[j].dy;
      }
      smoothed.add(Offset(sumX / count, sumY / count));
    }

    smoothed.add(points.last);
    return smoothed;
  }

  static List<RouteSegment> _createSegments(List<Offset> points) {
    List<RouteSegment> segments = [];

    for (int i = 0; i < points.length - 1; i++) {
      Offset start = points[i];
      Offset end = points[i + 1];
      double distance = (end - start).distance;

      segments.add(
        RouteSegment(
          start: start,
          end: end,
          distance: distance,
          angle: 0.0,
          curvature: 0.0,
          type: SegmentType.straight,
        ),
      );
    }

    return segments;
  }

  static void _analyzeVectors(List<RouteSegment> segments) {
    for (int i = 0; i < segments.length; i++) {
      var seg = segments[i];

      double dx = seg.end.dx - seg.start.dx;
      double dy = seg.end.dy - seg.start.dy;
      double angle = atan2(dy, dx) * 180 / pi;
      if (angle < 0) angle += 360;

      double curvature = 0.0;
      if (i > 0 && i < segments.length - 1) {
        double prevAngle = segments[i - 1].angle;
        double nextAngle = segments[i + 1].angle;
        double angleDiff = _normalizeAngle(nextAngle - prevAngle);
        curvature = angleDiff / 180.0;
      }

      segments[i] = RouteSegment(
        start: seg.start,
        end: seg.end,
        distance: seg.distance,
        angle: angle,
        curvature: curvature,
        type: seg.type,
      );
    }
  }

  static void _classifySegments(List<RouteSegment> segments) {
    for (int i = 0; i < segments.length - 1; i++) {
      var seg = segments[i];
      var next = segments[i + 1];

      double angleDiff = seg.angleDifference(next);

      // Positive diff = clockwise (right), negative = counter-clockwise (left)
      SegmentType type;
      if (angleDiff.abs() < 3) {
        type = SegmentType.straight;
      } else if (angleDiff > 20) {
        type = SegmentType.sharpRight;
      } else if (angleDiff > 0) {
        type = SegmentType.rightCurve;
      } else if (angleDiff < -20) {
        type = SegmentType.sharpLeft;
      } else {
        type = SegmentType.leftCurve;
      }

      segments[i] = RouteSegment(
        start: seg.start,
        end: seg.end,
        distance: seg.distance,
        angle: seg.angle,
        curvature: seg.curvature,
        type: type,
      );
    }
  }

  static double _normalizeAngle(double angle) {
    while (angle > 180) angle -= 360;
    while (angle < -180) angle += 360;
    return angle;
  }
}

// ============ Command Generation ============

class CommandGenerator {
  static List<RouteCommand> generateCommands(
    List<RouteSegment> segments,
    double speedMultiplier,
  ) {
    List<RouteCommand> commands = [];

    // Merge consecutive same-type curve segments so a corner that spans
    // multiple segments after smoothing produces exactly ONE turn command.
    final merged = _mergeConsecutiveCurves(segments);

    for (int i = 0; i < merged.length; i++) {
      var seg = merged[i];

      // Full-throttle car: duration = distance on canvas × scale / speed.
      // 30 px segment ≈ 120 ms at 1x — keeps short routes under 3 seconds.
      int baseDuration = (seg.distance * 4).round();
      int duration = (baseDuration / speedMultiplier).round();

      // 80 ms minimum — below this the hardware barely reacts
      if (duration < 80) duration = 80;

      switch (seg.type) {
        case SegmentType.straight:
          commands.add(
            RouteCommand(
              command: "forward",
              duration: duration,
              segmentIndex: i,
            ),
          );
          break;

        case SegmentType.leftCurve:
        case SegmentType.rightCurve:
          final turnCmd = seg.type == SegmentType.leftCurve ? "left" : "right";
          final turnDuration = (duration * 0.9).round();
          final driveDuration = duration - turnDuration;
          commands.add(
            RouteCommand(
              command: turnCmd,
              duration: turnDuration,
              segmentIndex: i,
            ),
          );
          commands.add(
            RouteCommand(
              command: "forward",
              duration: driveDuration,
              segmentIndex: i,
            ),
          );
          break;

        case SegmentType.sharpLeft:
        case SegmentType.sharpRight:
          final sharpTurnCmd = seg.type == SegmentType.sharpLeft
              ? "left"
              : "right";
          final sharpTurnDuration = (duration * 5.0).round();
          commands.add(
            RouteCommand(
              command: sharpTurnCmd,
              duration: sharpTurnDuration,
              segmentIndex: i,
            ),
          );
          break;
      }
    }

    return commands;
  }

  // Merge runs of the same curve direction into one segment so that a corner
  // spanning multiple smoothed segments produces exactly one turn command.
  static List<RouteSegment> _mergeConsecutiveCurves(
    List<RouteSegment> segments,
  ) {
    if (segments.isEmpty) return segments;

    final result = <RouteSegment>[];
    var current = segments[0];

    for (int i = 1; i < segments.length; i++) {
      final next = segments[i];
      final isCurve = current.type != SegmentType.straight;

      if (isCurve && next.type == current.type) {
        // Absorb the next segment: extend end point and accumulate distance.
        current = RouteSegment(
          start: current.start,
          end: next.end,
          distance: current.distance + next.distance,
          angle: current.angle,
          curvature: current.curvature,
          type: current.type,
        );
      } else {
        result.add(current);
        current = next;
      }
    }
    result.add(current);
    return result;
  }
}

// ---------------- Connection Manager & UI ----------------

class ConnectionManager {
  ConnectionManager._internal() {
    // Don't auto-connect on startup - wait for user action
    // _start();
  }

  static final ConnectionManager instance = ConnectionManager._internal();

  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _sendThrottleTimer;
  Timer? _keepAliveTimer;
  String? _pendingCommand;
  String? _lastSentCommand;
  int _tokens = 2;
  final int _maxTokens = 2;
  final Duration _tokenRefillInterval = const Duration(milliseconds: 200);
  DateTime _lastTokenRefill = DateTime.now();
  int _reconnectSeconds = 1;
  final String wsUrl = 'ws://10.10.10.10:81/';
  final String wsFallback = 'ws://localhost:8080/';
  bool _isConnecting = false;

  void _start() {
    _connect();
  }

  Future<void> connectNow() async {
    await _connect();
  }

  Future<void> _connect() async {
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      _channel?.sink.close(ws_status.goingAway);
    } catch (_) {}

    // Try main URL
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;

      connected.value = true;
      _reconnectSeconds = 1;
      _isConnecting = false;
      _startKeepAlive();

      _channel!.stream.listen(
        (message) {
          // ignore: avoid_print
          print('WS recv: $message');
        },
        onDone: () {
          connected.value = false;
          _isConnecting = false;
          _stopKeepAlive();
          _scheduleReconnect();
        },
        onError: (e) {
          connected.value = false;
          _isConnecting = false;
          _stopKeepAlive();
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
      return;
    } catch (_) {}

    // Try fallback (local proxy) for testing
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsFallback));
      await _channel!.ready;

      connected.value = true;
      _reconnectSeconds = 1;
      _isConnecting = false;
      _startKeepAlive();

      _channel!.stream.listen(
        (message) {
          // ignore: avoid_print
          print('WS recv: $message');
        },
        onDone: () {
          connected.value = false;
          _isConnecting = false;
          _stopKeepAlive();
          _scheduleReconnect();
        },
        onError: (e) {
          connected.value = false;
          _isConnecting = false;
          _stopKeepAlive();
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (_) {
      connected.value = false;
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final seconds = _reconnectSeconds;
    _reconnectTimer = Timer(Duration(seconds: seconds), () => _connect());
    _reconnectSeconds = (_reconnectSeconds * 2).clamp(1, 30);
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_channel != null && connected.value) {
        try {
          _channel!.sink.add('ping');
        } catch (_) {}
      }
    });
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  void dispose() {
    try {
      _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _reconnectTimer?.cancel();
    _sendThrottleTimer?.cancel();
    _keepAliveTimer?.cancel();
    connected.dispose();
  }

  void _refillTokens() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastTokenRefill);
    final int cycles =
        elapsed.inMilliseconds ~/ _tokenRefillInterval.inMilliseconds;
    if (cycles <= 0) return;

    _tokens = (_tokens + cycles).clamp(0, _maxTokens);
    _lastTokenRefill = _lastTokenRefill.add(
      Duration(milliseconds: _tokenRefillInterval.inMilliseconds * cycles),
    );
  }

  Duration _timeUntilNextToken() {
    final elapsed = DateTime.now().difference(_lastTokenRefill).inMilliseconds;
    final int remaining = _tokenRefillInterval.inMilliseconds - elapsed;
    return Duration(
      milliseconds: remaining.clamp(0, _tokenRefillInterval.inMilliseconds),
    );
  }

  void _scheduleTokenTimer() {
    _sendThrottleTimer?.cancel();
    _sendThrottleTimer = Timer(_timeUntilNextToken(), () {
      _sendThrottleTimer = null;
      _refillTokens();
      if (_pendingCommand != null &&
          _pendingCommand != _lastSentCommand &&
          _tokens > 0) {
        _flushPendingCommand();
        _tokens--;
      }
      if (_tokens == 0 && _pendingCommand != _lastSentCommand) {
        _scheduleTokenTimer();
      }
    });
  }

  void _flushPendingCommand() {
    if (_pendingCommand == null) return;
    if (_pendingCommand == _lastSentCommand) return;

    final cmd = _pendingCommand!;
    _lastSentCommand = cmd;

    try {
      if (_channel != null) {
        _channel!.sink.add(cmd);
        // ignore: avoid_print
        print('WS sent: $cmd');
      } else {
        // fallback to HTTP
        final url = Uri.parse('http://10.10.10.10/move?cmd=$cmd');
        http
            .get(url)
            .then((r) {
              // ignore: avoid_print
              print('HTTP fallback sent: $cmd | ${r.statusCode}');
            })
            .catchError((e) {
              // ignore: avoid_print
              print('Fallback error: $e');
            });
      }
    } catch (e) {
      // ignore: avoid_print
      print('Send error: $e');
    }
  }

  void send(String cmd) {
    _pendingCommand = cmd;

    // Start connection if not already connected
    if (_channel == null && !_isConnecting) {
      _start();
    }

    _refillTokens();
    if (_pendingCommand != _lastSentCommand && _tokens > 0) {
      _flushPendingCommand();
      _tokens--;
    }

    if (_tokens == 0 &&
        _pendingCommand != _lastSentCommand &&
        _sendThrottleTimer == null) {
      _scheduleTokenTimer();
    }
  }
}

class ConnectionStatus extends StatelessWidget {
  const ConnectionStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectionManager.instance.connected,
      builder: (context, connected, _) {
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            tooltip: connected ? 'Online' : 'Offline',
            onPressed: () => ConnectionManager.instance.connectNow(),
            icon: Icon(
              connected ? Icons.check_circle : Icons.cancel,
              color: connected ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
        );
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  //App-Header
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'R.E.D.',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 138, 18, 18),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (ctx) => const WelcomePage(),
        '/modes': (ctx) => const ModeSelectionPage(),
        '/drive': (ctx) => const DrivingPage(),
        '/draw': (ctx) => const DrawingPage(),
        '/autonomous': (ctx) => const AutonomousDrivingPage(),
      },
    );
  }
}

/* ---------------- WelcomePage (stateful for animations) ---------------- */
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  // Steering of animated car
  bool animateCar = false;

  @override
  void initState() {
    super.initState();
    //car drives into the frame after 3 Sekundens delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          animateCar = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final orientation = MediaQuery.of(context).orientation;
          final isLandscape =
              orientation == Orientation.landscape ||
              constraints.maxWidth > 800;

          // picture size adaptiv
          final double imageHeight = isLandscape
              ? (constraints.maxHeight * 0.5)
              : 160;
          final double imageMaxWidth = isLandscape
              ? constraints.maxWidth * 0.35
              : constraints.maxWidth * 0.45;

          return Container(
            decoration: BoxDecoration(
              // linear gradient for Background
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFB71C1C), // top (red)
                  const Color.fromARGB(255, 57, 57, 57), // botton (dark grey)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16,
                  ),
                  child: isLandscape
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // left column: Text + Button
                            Expanded(
                              flex: 5,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Welcome to R.E.D.',
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Choose your mode to start',
                                    textAlign: TextAlign.left,
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 18),
                                  //Navigation
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pushNamed(context, '/modes'),
                                    child: const Text('Mode'),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Right column: flag + car
                            Expanded(
                              flex: 6,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final imageMaxWidth =
                                      constraints.maxWidth * 0.65;
                                  final imageHeight = constraints.maxHeight * 1;

                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Flag: position to the left top corner
                                      Positioned(
                                        left: imageMaxWidth * 0.06,
                                        top: imageHeight * 0.08,
                                        child: Image.asset(
                                          'assets/images/Checkerflag.png',
                                          width: imageMaxWidth * 0.5,
                                          fit: BoxFit.contain,
                                        ),
                                      ),

                                      // car: drives into the frame from the right side
                                      AnimatedPositioned(
                                        duration: const Duration(
                                          milliseconds: 900,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        right: animateCar
                                            ? 0
                                            : -constraints.maxWidth * 0.75,
                                        bottom: 0,
                                        child: SizedBox(
                                          width: imageMaxWidth,
                                          height: imageHeight,
                                          child: Image.asset(
                                            'assets/images/ferrari.png',
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                      : Column(
                          //column view
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Welcome to R.E.D.',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Choose your mode to start',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 18),
                            // pictures construced netxt to each other
                            LayoutBuilder(
                              builder: (context, inner) {
                                final wide = inner.maxWidth > 600;
                                if (wide) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: inner.maxWidth * 0.4,
                                        ),
                                        child: Image.asset(
                                          'assets/images/Checkerflag.png',
                                          fit: BoxFit.contain,
                                          height: 160,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: inner.maxWidth * 0.4,
                                        ),
                                        child: Image.asset(
                                          'assets/images/ferrari.png',
                                          fit: BoxFit.contain,
                                          height: 160,
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  return Column(
                                    children: [
                                      Image.asset(
                                        'assets/images/Checkerflag.png',
                                        fit: BoxFit.contain,
                                        height: 140,
                                      ),
                                      const SizedBox(height: 8),
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 900,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        margin: EdgeInsets.only(
                                          left: animateCar
                                              ? 0
                                              : -inner.maxWidth * 0.7,
                                        ),
                                        child: Image.asset(
                                          'assets/images/ferrari.png',
                                          fit: BoxFit.contain,
                                          height: 140,
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/modes'),
                              child: const Text('Choose your mode'),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/* ---------------- ModeSelectionPage ---------------- */
class ModeSelectionPage extends StatelessWidget {
  const ModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose mode')),
      //List of all mdoes for choosing
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Driving'),
            subtitle: const Text('Drive with easy controls'),
            onTap: () => Navigator.pushNamed(context, '/drive'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.brush),
            title: const Text('Drawing the route'),
            subtitle: const Text('Draw the route the car should follow'),
            onTap: () => Navigator.pushNamed(context, '/draw'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.smart_toy),
            title: const Text('Autonomous Driving'),
            subtitle: const Text('Let the car drive autonomously with sensors'),
            onTap: () => Navigator.pushNamed(context, '/autonomous'),
          ),
        ],
      ),
    );
  }
}

/* ---------------- ModePage ---------------- */
class ModePage extends StatelessWidget {
  final String title;
  const ModePage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title, textAlign: TextAlign.center)),
    );
  }
}

/* ---------------- DrivingPage (Buttons, Reverse on long brake) ---------------- */
class DrivingPage extends StatefulWidget {
  const DrivingPage({super.key});

  @override
  State<DrivingPage> createState() => _DrivingPageState();
}

//Setting up all Variables for Beginn
class _DrivingPageState extends State<DrivingPage> {
  Timer? _timer;
  Timer? _reverseTimer;
  Timer? _commandTimer;
  double speed = 0.0; // positive = forward, negative = reverse (km/h)
  double throttle = 0.0; // -1..1 (driven by button / reverse)
  double brake = 0.0; // 0..1
  double steering = 0.0; // -1..1

  // Button beginning state flags
  bool accelerating = false;
  bool braking = false;
  bool steerLeft = false;
  bool steerRight = false;
  bool reversing = false; // enabled after long brake
  bool lightOn = false; //Lights switched off

  final FocusNode _focusNode = FocusNode();

  // New: invert controls toggle
  bool controlsInverted = false;

  // --- Input wrappers that respect the inverted flag ---
  void _inputAccelerate(bool down) {
    // If inverted, accelerate input becomes braking, otherwise normal
    if (controlsInverted) {
      // behave like brake press
      _pressBrake(down, fromVirtual: true);
    } else {
      _pressAccelerate(down, fromVirtual: true);
    }
  }

  void _inputBrake(bool down) {
    if (controlsInverted) {
      // behave like accelerate press
      _pressAccelerate(down, fromVirtual: true);
    } else {
      _pressBrake(down, fromVirtual: true);
    }
  }

  void _inputSteerLeft(bool down) {
    if (controlsInverted) {
      _pressSteerRight(down);
    } else {
      _pressSteerLeft(down);
    }
  }

  void _inputSteerRight(bool down) {
    if (controlsInverted) {
      _pressSteerLeft(down);
    } else {
      _pressSteerRight(down);
    }
  }

  void _handleDrivingKey(RawKeyEvent event) {
    final key = event.logicalKey;
    final isDown = event is RawKeyDownEvent;

    if (keyPressed[key] == isDown) return;
    keyPressed[key] = isDown;

    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      controlsInverted ? _inputBrake(isDown) : _inputAccelerate(isDown);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      controlsInverted ? _inputAccelerate(isDown) : _inputBrake(isDown);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.keyA) {
      _inputSteerLeft(isDown);
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      _inputSteerRight(isDown);
    } else if (key == LogicalKeyboardKey.space && isDown) {
      setState(() {
        accelerating = false;
        braking = false;
        steerLeft = false;
        steerRight = false;
        reversing = false;
      });
      activeCommands.clear();
      updateCommand();
    }

    // Watchdog: on web, keyup can be missed when the browser loses focus.
    // If no key is still held after 500 ms, send stop automatically.
    if (isDown) {
      _startCommandTimer();
    }
  }

  @override
  void initState() {
    super.initState();

    _focusNode.requestFocus();

    // Physik-Loop (~20 FPS)
    _timer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _updatePhysics(),
    );
  }

  void _updatePhysics() {
    const double dt = 0.05; // Sekunden pro Tick

    // Wenn reversing aktiv, throttle = -1 (Rückwärts), sonst 0..1 vorne
    if (reversing) {
      throttle = -1.0;
      brake = 0.0;
    } else {
      throttle = accelerating ? 1.0 : 0.0;
      brake = braking ? 1.0 : 0.0;
    }

    // Lenken: solange gedrückt, lenke mit Rate; wenn losgelassen, zurück zur Mitte (Dämpfung)
    const double steerRate = 1.5; // pro Sekunde
    const double steerReturnRate = 2.5;
    if (steerLeft && !steerRight) {
      steering -= steerRate * dt;
    } else if (steerRight && !steerLeft) {
      steering += steerRate * dt;
    } else {
      if (steering > 0) {
        steering -= steerReturnRate * dt;
        if (steering < 0) steering = 0;
      } else if (steering < 0) {
        steering += steerReturnRate * dt;
        if (steering > 0) steering = 0;
      }
    }
    steering = steering.clamp(-1.0, 1.0);

    // einfache Beschleunigung: positive throttle beschleunigt vorwärts, negative rückwärts
    final double accel =
        throttle * 6.0 - brake * 10.0 - speed.sign * (speed.abs() * 0.04);
    speed += accel * dt * 3.6; // skaliere zu km/h

    // Begrenzungen: Rückwärts langsamer (−80..320)
    if (speed > 30) speed = 30;
    if (speed < -30) speed = -30;

    // kleine Deadzone: wenn nahe 0 und kein throttle/brake, setze exakt 0
    if (!accelerating && !braking && !reversing && speed.abs() < 0.5) {
      speed = 0.0;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reverseTimer?.cancel();
    _commandTimer?.cancel();
    super.dispose();
  }

  // Safety watchdog: if keyboard focus is lost and keyup is never received,
  // stop the car after 500 ms of inactivity — but only when no key is tracked as held.
  void _startCommandTimer() {
    _commandTimer?.cancel();
    _commandTimer = Timer(const Duration(milliseconds: 500), () {
      if (!keyPressed.values.any((pressed) => pressed)) {
        if (activeCommands.isNotEmpty) {
          activeCommands.clear();
          updateCommand();
        }
      }
    });
  }

  String _speedText() => '${speed.abs().toInt()} km/h';
  String _rpmText() => '${(speed.abs() * 30).toInt()} rpm';

  // Helfer für gedrückt/losgelassen Verhalten
  void _pressAccelerate(bool down, {bool fromVirtual = false}) {
    if (down) {
      setState(() {
        accelerating = true;
        reversing = false;
      });
      activeCommands.add("forward");
      updateCommand();
    } else {
      setState(() => accelerating = false);
      activeCommands.remove("forward");
      updateCommand();
    }
  }

  void _pressBrake(bool down, {bool fromVirtual = false}) {
    if (down) {
      setState(() => braking = true);

      activeCommands.add("backward");
      updateCommand();

      _reverseTimer?.cancel();
      _reverseTimer = Timer(const Duration(milliseconds: 700), () {
        if (braking && speed.abs() < 1.0) {
          setState(() => reversing = true);
        }
      });
    } else {
      _reverseTimer?.cancel();

      setState(() {
        braking = false;
        reversing = false;
      });

      activeCommands.remove("backward");
      updateCommand();
    }
  }

  void _pressSteerLeft(bool down) {
    if (down) {
      setState(() => steerLeft = true);
      activeCommands.add("left");
      updateCommand();
    } else {
      setState(() => steerLeft = false);
      activeCommands.remove("left");
      updateCommand();
    }
  }

  void _pressSteerRight(bool down) {
    if (down) {
      setState(() => steerRight = true);
      activeCommands.add("right");
      updateCommand();
    } else {
      setState(() => steerRight = false);
      activeCommands.remove("right");
      updateCommand();
    }
  }

  Widget _controlButton({
    required Widget child,
    required void Function(bool) onHold,
    double width = 240,
    double height = 120,
    Color? color,
  }) {
    // Listener with opaque hit-testing fires onPointerUp unconditionally — unlike
    // GestureDetector whose onTapUp is swallowed once reclassified as long-press.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onHold(true),
      onPointerUp: (_) => onHold(false),
      onPointerCancel: (_) => onHold(false),
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        decoration: BoxDecoration(
          color: color ?? Colors.white12,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Center(child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rot-Grau Verlauf
    final gradientTop = Colors.red.shade700;
    final gradientBottom = Colors.grey.shade900;

    final theme = Theme.of(context);
    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: _handleDrivingKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Driving'),
          centerTitle: true,
          actions: const [ConnectionStatus()],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [gradientTop, gradientBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Hauptinhalt: HUD oben + Track in der Mitte
                Column(
                  children: [
                    // HUD: Speed / RPM + Gear Anzeige
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _speedText(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _rpmText(),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Gear: ${reversing || speed < 0 ? 'R' : 'D'}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Mode: Arcade',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Platzhalter für Rennstrecke / Auto-View
                    Expanded(
                      child: Center(
                        child: Transform.rotate(
                          angle: steering * 0.6 * (reversing ? -1 : 1),
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.6,
                            height: MediaQuery.of(context).size.height * 0.28,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                              boxShadow: lightOn
                                  ? [
                                      BoxShadow(
                                        color: const Color.fromARGB(
                                          255,
                                          239,
                                          4,
                                          4,
                                        ).withOpacity(0.7),
                                        blurRadius: 38,
                                        spreadRadius: 8,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.directions_car_filled,
                                size: 80,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 80,
                    ), // Platz für die overlaid Buttons am unteren Rand
                  ],
                ),

                // Linke Seite: Lenkung (vertikal zentriert)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Linke Seite
                        _controlButton(
                          onHold: controlsInverted
                              ? _inputAccelerate
                              : _inputSteerLeft,
                          width: 110,
                          height: 60,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                controlsInverted
                                    ? Icons.arrow_upward
                                    : Icons.chevron_left,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                controlsInverted ? 'Accelerate' : 'Left',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),

                        _controlButton(
                          onHold: controlsInverted
                              ? _inputBrake
                              : _inputSteerRight,
                          width: 110,
                          height: 60,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                controlsInverted
                                    ? Icons.arrow_downward
                                    : Icons.chevron_right,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                controlsInverted ? 'Brake' : 'Right',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Rechte Seite: Gas / Bremse (vertikal zentriert)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Rechte Seite
                        _controlButton(
                          onHold: controlsInverted
                              ? _inputSteerLeft
                              : _inputAccelerate,
                          width: 130,
                          height: 70,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                controlsInverted
                                    ? Icons.chevron_left
                                    : Icons.arrow_upward,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                controlsInverted ? 'Left' : 'Accelerate',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),

                        _controlButton(
                          onHold: controlsInverted
                              ? _inputSteerRight
                              : _inputBrake,
                          width: 130,
                          height: 70,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                controlsInverted
                                    ? Icons.chevron_right
                                    : Icons.arrow_downward,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                controlsInverted
                                    ? 'Right'
                                    : (reversing ? 'Reverse' : 'Brake'),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                          color: reversing
                              ? Colors.orange.withOpacity(0.22)
                              : Colors.black.withOpacity(0.18),
                        ),
                      ],
                    ),
                  ),
                ),

                // Fußzeile: Utility-Buttons (bottom)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              controlsInverted = !controlsInverted;
                            });
                          },
                          icon: Icon(
                            Icons.compare_arrows,
                            color: controlsInverted
                                ? const Color.fromARGB(255, 255, 0, 0)
                                : null,
                          ),
                          label: Text(
                            controlsInverted
                                ? 'Inverted ON'
                                : 'Invert Controls',
                          ),
                        ),

                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              lightOn = !lightOn;
                              //Hardwarecode einsetzten
                            });
                          },
                          icon: Icon(
                            lightOn ? Icons.lightbulb : Icons.lightbulb_outline,
                            color: lightOn ? Colors.yellow : Colors.white,
                          ),
                          label: Text(lightOn ? 'Light on' : 'Light off'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- DrawingPage (Draw) ---------------- */
class DrawingPage extends StatefulWidget {
  const DrawingPage({super.key});

  @override
  State<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  final List<Offset> _points = [];

  // Playback-Variables
  PlaybackState _playbackState = PlaybackState.idle;
  List<RouteSegment> _segments = [];
  List<RouteCommand> _commands = [];
  int _currentCommandIndex = 0;
  final double _speedMultiplier = 1.0;
  Timer? _playbackTimer;

  // ========== PLAYBACK Control ==========

  void _startPlayback() async {
    // Clear any leftover driving-mode state so no stale commands leak into playback
    activeCommands.clear();
    keyPressed.clear();

    // is there a route available
    if (_points.length < 2) {
      _showMessage('Please draw a route.');
      return;
    }

    // is the car connected
    if (!ConnectionManager.instance.connected.value) {
      _showMessage('No connection to the car.');
      return;
    }

    // set playing status
    setState(() {
      _playbackState = PlaybackState.playing;
      _currentCommandIndex = 0;
    });

    // analyse route; process points into segments
    _segments = RouteProcessor.processRoute(_points);

    // generate commands based on segments
    _commands = CommandGenerator.generateCommands(_segments, _speedMultiplier);

    // execute command
    _executeNextCommand();
  }

  void _pausePlayback() {
    // set status paused
    setState(() {
      _playbackState = PlaybackState.paused;
    });

    // stop timer; no further commands
    _playbackTimer?.cancel();

    // stop car
    sendCommand('stop');
  }

  void _resumePlayback() {
    // status back on play
    setState(() {
      _playbackState = PlaybackState.playing;
    });

    // execute next command
    _executeNextCommand();
  }

  void _stopPlayback() {
    // Back to the beginning
    setState(() {
      _playbackState = PlaybackState.idle;
      _currentCommandIndex = 0;
    });

    // stop timer
    _playbackTimer?.cancel();

    // stop car
    sendCommand('stop');
  }

  void _executeNextCommand() {
    // check if state is playing
    if (_playbackState != PlaybackState.playing) return;

    // check connection
    if (!ConnectionManager.instance.connected.value) {
      _pausePlayback();
      _showMessage('Connection lost.');
      return;
    }

    // check whether end is reached
    if (_currentCommandIndex >= _commands.length) {
      _stopPlayback();
      setState(() {
        _playbackState = PlaybackState.completed;
      });
      _showMessage('Route completed.');
      return;
    }

    // get current command
    var cmd = _commands[_currentCommandIndex];

    // send command to car
    sendCommand(cmd.command);

    // start timer for next command
    _playbackTimer = Timer(Duration(milliseconds: cmd.duration), () {
      // if time is up, next command
      setState(() {
        _currentCommandIndex++;
      });
      _executeNextCommand();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    // Clear when closing page
    _playbackTimer?.cancel();
    if (_playbackState == PlaybackState.playing) {
      sendCommand('stop');
    }
    super.dispose();
  }

  // ========== UI KOMPONENTS ==========

  Widget _buildPlaybackControls() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildProgressIndicator(),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [_buildPlayPauseButton(), _buildStopButton()],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    // Calculate Process
    double progress = _commands.isEmpty
        ? 0.0
        : _currentCommandIndex / _commands.length;

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade700,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
        SizedBox(height: 4),
        // Text with current segment number
        Text(
          'Segment ${_currentCommandIndex + 1} / ${_commands.length}',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPlayPauseButton() {
    bool isPlaying = _playbackState == PlaybackState.playing;
    bool isPaused = _playbackState == PlaybackState.paused;
    bool canPlay =
        _points.length > 1 &&
        (_playbackState == PlaybackState.idle || isPaused);

    return ElevatedButton.icon(
      // paused → Resume, otherwise → Start or Pause
      onPressed: canPlay
          ? (isPaused ? _resumePlayback : _startPlayback)
          : (isPlaying ? _pausePlayback : null),
      icon: Icon(
        isPlaying ? Icons.pause : Icons.play_arrow,
        color: Colors.white,
      ),
      label: Text(
        isPlaying ? 'Pause' : (isPaused ? 'Resume' : 'Play'),
        style: TextStyle(color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPlaying
            ? Colors.orange.shade700
            : Colors.green.shade700,
        minimumSize: Size(120, 50),
      ),
    );
  }

  Widget _buildStopButton() {
    bool canStop =
        _playbackState == PlaybackState.playing ||
        _playbackState == PlaybackState.paused;

    return ElevatedButton.icon(
      onPressed: canStop ? _stopPlayback : null,
      icon: Icon(Icons.stop, color: Colors.white),
      label: Text('Stop', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade700,
        minimumSize: Size(120, 50),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Draw Route'),
        actions: const [ConnectionStatus()],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade700, Colors.grey.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Draw a path on the screen. Use Clear to reset.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 1),
                    color: const Color.fromARGB(52, 255, 255, 255),
                    borderRadius: BorderRadius.circular(8),
                  ),

                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            final box = context.findRenderObject() as RenderBox;
                            final localPos = box.globalToLocal(
                              details.globalPosition,
                            );

                            // Grenzen des Zeichenfelds
                            final minX = 0.0;
                            final minY = 0.0;
                            final maxX = constraints.maxWidth;
                            final maxY = constraints.maxHeight;

                            // Nur hinzufügen, wenn innerhalb
                            if (localPos.dx >= minX &&
                                localPos.dx <= maxX &&
                                localPos.dy >= minY &&
                                localPos.dy <= maxY) {
                              _points.add(localPos);
                            }
                          });
                        },
                        onPanEnd: (_) => _points.add(Offset.zero),
                        child: CustomPaint(
                          painter: _RoutePlaybackPainter(
                            points: _points,
                            segments: _segments,
                            currentSegmentIndex: _currentCommandIndex,
                            isPlaying: _playbackState == PlaybackState.playing,
                          ),
                          child: Container(),
                        ),
                      );
                    },
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: _buildPlaybackControls(),
              ),

              SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton.icon(
                  onPressed: () => setState(() {
                    _points.clear();
                    _stopPlayback();
                  }),
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutePlaybackPainter extends CustomPainter {
  final List<Offset> points;
  final List<RouteSegment> segments;
  final int currentSegmentIndex;
  final bool isPlaying;

  _RoutePlaybackPainter({
    required this.points,
    required this.segments,
    required this.currentSegmentIndex,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // draw complete route
    _drawCompletePath(canvas);

    // when playback active
    if (isPlaying && segments.isNotEmpty) {
      // already driven segments
      _drawCompletedSegments(canvas);

      // current segment
      if (currentSegmentIndex < segments.length) {
        _drawCurrentSegment(canvas);
        _drawCarPosition(canvas);
      }
    }

    // draw points
    _drawPoints(canvas);
  }

  void _drawCompletePath(Canvas canvas) {
    final paint = Paint()
      ..color = const Color.fromARGB(255, 44, 27, 27)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    bool started = false;

    for (var p in points) {
      if (p == Offset.zero) {
        started = false;
        continue;
      }
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawCompletedSegments(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.green.shade400
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // draw segment to current
    for (int i = 0; i < currentSegmentIndex && i < segments.length; i++) {
      var seg = segments[i];
      canvas.drawLine(seg.start, seg.end, paint);
    }
  }

  void _drawCurrentSegment(Canvas canvas) {
    var seg = segments[currentSegmentIndex];

    final paint = Paint()
      ..color = Colors.yellow.shade600
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(seg.start, seg.end, paint);
  }

  void _drawCarPosition(Canvas canvas) {
    var seg = segments[currentSegmentIndex];

    // car as red dot
    final paint = Paint()
      ..color = Colors.red.shade700
      ..style = PaintingStyle.fill;

    canvas.drawCircle(seg.start, 8, paint);

    // direction arrow
    final arrowPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // calculate arrow direction
    double angle = seg.angle * pi / 180;
    Offset arrowEnd = seg.start + Offset(cos(angle) * 15, sin(angle) * 15);

    canvas.drawLine(seg.start, arrowEnd, arrowPaint);
  }

  void _drawPoints(Canvas canvas) {
    final paintDot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final p in points) {
      if (p == Offset.zero) continue;
      canvas.drawCircle(p, 2.5, paintDot);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePlaybackPainter oldDelegate) {
    // draw new
    return oldDelegate.currentSegmentIndex != currentSegmentIndex ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.points.length != points.length;
  }
}

/* ---------------- AutonomousDrivingPage ---------------- */
class AutonomousDrivingPage extends StatefulWidget {
  const AutonomousDrivingPage({super.key});

  @override
  State<AutonomousDrivingPage> createState() => _AutonomousDrivingPageState();
}

class _AutonomousDrivingPageState extends State<AutonomousDrivingPage> {
  bool isRunning = false;
  double maxSpeed = 15.0;
  bool _sensorCheckDone = false;

  @override
  void initState() {
    super.initState();
    ConnectionManager.instance.connected.addListener(_onConnectionChanged);
    if (ConnectionManager.instance.connected.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSensorPopup();
      });
    }
  }

  @override
  void dispose() {
    ConnectionManager.instance.connected.removeListener(_onConnectionChanged);
    if (isRunning) _stopAutonomous();
    super.dispose();
  }

  void _onConnectionChanged() {
    if (!mounted) return;
    if (ConnectionManager.instance.connected.value) {
      if (!_sensorCheckDone) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSensorPopup();
        });
      }
    } else {
      setState(() {
        _sensorCheckDone = false;
        isRunning = false;
      });
    }
  }

  Future<void> _showSensorPopup() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sensor-Prüfung'),
        content: const Text('Ist ein Sensor im Auto verbaut?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nein'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ja'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _sensorCheckDone = true);
    if (result == true) {
      ConnectionManager.instance.send('sensorOn');
    }
  }

  void _startAutonomous() {
    if (!_sensorCheckDone) return;
    setState(() => isRunning = true);
    ConnectionManager.instance.send('auto');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Autonomous mode started'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _stopAutonomous() {
    setState(() => isRunning = false);
    // Send stop command
    ConnectionManager.instance.send('autoStop');
    sendCommand('stop');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Autonomous mode stopped'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _emergencyStop() {
    setState(() => isRunning = false);
    // Send emergency stop
    ConnectionManager.instance.send('emergency_stop');
    sendCommand('stop');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('EMERGENCY STOP ACTIVATED!'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Color _getDistanceColor(double distance) {
    if (distance < 20) return Colors.red;
    if (distance < 40) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Autonomous Driving'),
        centerTitle: true,
        actions: const [ConnectionStatus()],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade700, Colors.grey.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Sensor Visualization
                  Card(
                    color: Colors.black26,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Sensor Readings',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Sensor visualization layout
                          SizedBox(
                            height: 250,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Car icon in center
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isRunning
                                          ? Colors.greenAccent
                                          : Colors.white24,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.directions_car,
                                    size: 50,
                                    color: isRunning
                                        ? Colors.greenAccent
                                        : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Control Buttons
                  if (!_sensorCheckDone)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Bitte verbinde dich mit dem Auto für die Sensor-Prüfung.',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (!isRunning)
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: _sensorCheckDone ? _startAutonomous : null,
                        icon: const Icon(Icons.play_arrow, size: 32),
                        label: const Text(
                          'START AUTONOMOUS MODE',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: _stopAutonomous,
                        icon: const Icon(Icons.stop, size: 32),
                        label: const Text(
                          'STOP AUTONOMOUS MODE',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            255,
                            79,
                            21,
                          ),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Emergency Stop Button (always visible)
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _emergencyStop,
                      icon: const Icon(Icons.warning, size: 32),
                      label: const Text(
                        'EMERGENCY STOP',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper widget for sensor display
class _SensorDisplay extends StatelessWidget {
  final double distance;
  final String label;
  final Color color;

  const _SensorDisplay({
    required this.distance,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "20 cm",
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
