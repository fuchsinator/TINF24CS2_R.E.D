import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Send a command to the ESP car
void sendCommand(String cmd) async {
  try {
    final url = Uri.parse('http://10.10.10.10/move?cmd=$cmd');
    final response = await http.get(url);
    print('Sent: $cmd | Response: ${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: CarControlPage());
  }
}

class CarControlPage extends StatefulWidget {
  @override
  _CarControlPageState createState() => _CarControlPageState();
}

class _CarControlPageState extends State<CarControlPage> {
  FocusNode _focusNode = FocusNode();

  /// Stores active commands for sending to ESP car
  Set<String> activeCommands = {};

  /// Track key pressed state to avoid multiple repeated RawKeyDownEvents
  Map<LogicalKeyboardKey, bool> keyPressed = {};

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
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

    switch (key.keyLabel) {
      case 'Arrow Up':
        isDown ? activeCommands.add("forward") : activeCommands.remove("forward");
        break;
      case 'Arrow Down':
        isDown ? activeCommands.add("backward") : activeCommands.remove("backward");
        break;
      case 'Arrow Left':
        isDown ? activeCommands.add("left") : activeCommands.remove("left");
        break;
      case 'Arrow Right':
        isDown ? activeCommands.add("right") : activeCommands.remove("right");
        break;
      case ' ':
        if (isDown) activeCommands.clear();
        break;
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
        appBar: AppBar(title: Text('ESP Car Control')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              controlButton("forward", "Forward"),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  controlButton("left", "Left"),
                  SizedBox(width: 10),
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
                      child: Text("Stop"),
                    ),
                  ),
                  SizedBox(width: 10),
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
