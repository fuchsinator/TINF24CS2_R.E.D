import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// Base URL for the ESP controller. Change to your device IP for production.
// For local testing you can set this to 'http://127.0.0.1:8000'.
const String espBaseUrl = 'http://127.0.0.1:8000';

/// Send a command to the ESP car
Future<void> sendCommand(String cmd) async {
  try {
    final url = Uri.parse('$espBaseUrl/move?cmd=$cmd');
    final response = await http.get(url);
    // ignore: avoid_print
    print('Sent: $cmd | Response: ${response.body}');
  } catch (e) {
    // ignore: avoid_print
    print('Error: $e');
  }
}

class CarControlPage extends StatefulWidget {
  const CarControlPage({super.key});

  @override
  _CarControlPageState createState() => _CarControlPageState();
}

class _CarControlPageState extends State<CarControlPage> {
  final FocusNode _focusNode = FocusNode();

  /// Stores active commands for sending to ESP car
  final Set<String> activeCommands = {};

  /// Track key pressed state to avoid multiple repeated RawKeyDownEvents
  final Map<LogicalKeyboardKey, bool> keyPressed = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  /// Send current command to the car
  void updateCommand() {
    if (activeCommands.isEmpty) {
      sendCommand("stop");
    } else {
      sendCommand(activeCommands.join(","));
    }
  }

  /// Handle keyboard events
  void _handleKey(RawKeyEvent event) {
    final key = event.logicalKey;
    final isDown = event is RawKeyDownEvent;

    // Only react to a key change (ignore repeats)
    if (keyPressed[key] == isDown) return;
    keyPressed[key] = isDown;

    if (key == LogicalKeyboardKey.arrowUp) {
      isDown ? activeCommands.add("forward") : activeCommands.remove("forward");
    } else if (key == LogicalKeyboardKey.arrowDown) {
      isDown ? activeCommands.add("backward") : activeCommands.remove("backward");
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      isDown ? activeCommands.add("left") : activeCommands.remove("left");
    } else if (key == LogicalKeyboardKey.arrowRight) {
      isDown ? activeCommands.add("right") : activeCommands.remove("right");
    } else if (key == LogicalKeyboardKey.space) {
      if (isDown) activeCommands.clear();
    }

    updateCommand();
  }

  /// Builds a touch button for movement
  Widget controlButton(String command, String label) {
    return GestureDetector(
      onTapDown: (_) {
        activeCommands.add(command);
        updateCommand();
      },
      onTapUp: (_) {
        activeCommands.remove(command);
        updateCommand();
      },
      onTapCancel: () {
        activeCommands.remove(command);
        updateCommand();
      },
      child: ElevatedButton(
        onPressed: () {},
        child: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKey,
      child: Scaffold(
        appBar: AppBar(title: const Text('ESP Car Control')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              controlButton("forward", "Forward"),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  controlButton("left", "Left"),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTapDown: (_) {
                      activeCommands.clear();
                      updateCommand();
                    },
                    onTapUp: (_) {
                      activeCommands.clear();
                      updateCommand();
                    },
                    onTapCancel: () {
                      activeCommands.clear();
                      updateCommand();
                    },
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text("Stop"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  controlButton("right", "Right"),
                ],
              ),
              controlButton("backward", "Backward"),
            ],
          ),
        ),
      ),
    );
  }
}
