Test WebSocket setup for R.E.D. Flutter app

Overview
- The Flutter app now uses WebSocket to send control commands to the ESP.
- A local WebSocket -> HTTP proxy is included for testing (`tools/ws_proxy.js`).

Quick start (local test)
1) Install Node deps and start proxy (forwards WS to HTTP `http://10.10.10.10/move?cmd=...`):

```powershell
cd Flutter\tools
npm install ws node-fetch@2
npm start
```

2) Run the Flutter app in Chrome:

```powershell
cd C:\Users\jonat\RED\TINF24CS2_R.E.D\Flutter
flutter pub get
flutter run -d chrome
```

- The ConnectionManager first tries `ws://10.10.10.10:81/` and falls back to `ws://localhost:8080/` (proxy).
- If the proxy is running, the app will connect and the `ConnectionStatus` icon turns green.
- Use arrow keys or on-screen buttons to send commands. The proxy logs forwarded HTTP requests.

Production notes
- For lowest latency, implement a WebSocket server on the ESP or on a local bridge that accepts the same simple command strings (e.g. `forward,left`).
- Consider switching to JSON messages with ack/sequence numbers for reliability.

Troubleshooting
- If ConnectionStatus stays offline: ensure Node proxy running (`ws://localhost:8080`) or ESP WS server reachable at `ws://10.10.10.10:81/`.
- Check Flutter console for `WS sent:` logs and proxy console for forwarded requests.
