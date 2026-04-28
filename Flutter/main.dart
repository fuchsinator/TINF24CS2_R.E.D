import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

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

    try {
      // try main WS URL first
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Wait a bit to see if connection succeeds
      await Future.delayed(const Duration(milliseconds: 100));

      connected.value = true;
      _reconnectSeconds = 1;
      _isConnecting = false;

      _channel!.stream.listen(
        (message) {
          // handle incoming messages if needed
          // ignore: avoid_print
          print('WS recv: $message');
        },
        onDone: () {
          connected.value = false;
          _isConnecting = false;
          _scheduleReconnect();
        },
        onError: (e) {
          connected.value = false;
          _isConnecting = false;
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
      return;
    } catch (e) {
      // try fallback (local proxy) for testing
      try {
        _channel = WebSocketChannel.connect(Uri.parse(wsFallback));

        // Wait a bit to see if connection succeeds
        await Future.delayed(const Duration(milliseconds: 100));

        connected.value = true;
        _reconnectSeconds = 1;
        _isConnecting = false;

        _channel!.stream.listen(
          (message) {
            print('WS recv: $message');
          },
          onDone: () {
            connected.value = false;
            _isConnecting = false;
            _scheduleReconnect();
          },
          onError: (e) {
            connected.value = false;
            _isConnecting = false;
            _scheduleReconnect();
          },
          cancelOnError: false,
        );
        return;
      } catch (e2) {
        // Both connections failed - this is OK, just schedule reconnect
        connected.value = false;
        _isConnecting = false;
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final seconds = _reconnectSeconds;
    _reconnectTimer = Timer(Duration(seconds: seconds), () => _connect());
    _reconnectSeconds = (_reconnectSeconds * 2).clamp(1, 30);
  }

  void dispose() {
    try {
      _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _reconnectTimer?.cancel();
    _sendThrottleTimer?.cancel();
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

  void _startCommandTimer() {
    _commandTimer?.cancel();
    _commandTimer = Timer(const Duration(milliseconds: 10), () {
      activeCommands.clear();
      updateCommand();
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
        activeCommands.add("forward");
        updateCommand();
        _startCommandTimer();
      });
    } else {
      setState(() {
        accelerating = false;
        activeCommands.remove("forward");
      });
    }
  }

  void _pressBrake(bool down, {bool fromVirtual = false}) {
    if (down) {
      setState(() => braking = true);

      activeCommands.add("backward");
      updateCommand();
      _startCommandTimer();

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
    }
  }

  void _pressSteerLeft(bool down) {
    if (down) {
      setState(() => steerLeft = true);
      activeCommands.add("left");
      updateCommand();
      _startCommandTimer();
    } else {
      setState(() => steerLeft = false);
      activeCommands.remove("left");
    }
  }

  void _pressSteerRight(bool down) {
    if (down) {
      setState(() => steerRight = true);
      activeCommands.add("right");
      updateCommand();
      _startCommandTimer();
    } else {
      setState(() => steerRight = false);
      activeCommands.remove("right");
    }
  }

  Widget _controlButton({
    required Widget child,
    required void Function(bool) onHold,
    double width = 240,
    double height = 120,
    Color? color,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onHold(true),
      onTapUp: (_) => onHold(false),
      onTapCancel: () => onHold(false),
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
      onKey: handleKey,
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
                          painter: _RoutePainter(_points),
                          child: Container(),
                        ),
                      );
                    },
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _points.clear()),
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Beispiel: export points length
                        final count = _points
                            .where((p) => p != Offset.zero)
                            .length;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Points: $count')),
                        );
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<Offset> points;
  _RoutePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = const Color.fromARGB(255, 44, 27, 27)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final paintDot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path();
    bool started = false;
    for (final p in points) {
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
    canvas.drawPath(path, paintLine);
    for (final p in points) {
      if (p == Offset.zero) continue;
      canvas.drawCircle(p, 2.5, paintDot);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) => true;
}

/* ---------------- AutonomousDrivingPage ---------------- */
class AutonomousDrivingPage extends StatefulWidget {
  const AutonomousDrivingPage({super.key});

  @override
  State<AutonomousDrivingPage> createState() => _AutonomousDrivingPageState();
}

class _AutonomousDrivingPageState extends State<AutonomousDrivingPage> {
  bool isRunning = false;
  double maxSpeed = 15.0; // km/h

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    if (isRunning) {
      _stopAutonomous();
    }
    super.dispose();
  }

  void _startAutonomous() {
    setState(() => isRunning = true);
    // Send command to ESP32
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
                  if (!isRunning)
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: _startAutonomous,
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
