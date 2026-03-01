// Simple WebSocket -> HTTP proxy for testing
// Usage:
// 1) npm install ws node-fetch@2
// 2) node ws_proxy.js

const WebSocket = require('ws');
const fetch = require('node-fetch');

const PORT = 8080;
const TARGET_HOST = 'http://10.10.10.10'; // your ESP HTTP endpoint

const wss = new WebSocket.Server({ port: PORT }, () => {
  console.log(`WebSocket proxy listening on ws://localhost:${PORT}`);
});

wss.on('connection', (ws) => {
  console.log('Client connected');

  ws.on('message', async (message) => {
    const cmd = message.toString();
    console.log('Received cmd:', cmd);

    // forward to ESP
    try {
      const url = `${TARGET_HOST}/move?cmd=${encodeURIComponent(cmd)}`;
      const resp = await fetch(url);
      const text = await resp.text();
      console.log('Forwarded to ESP:', url, 'status', resp.status);
      ws.send(JSON.stringify({ ok: true, status: resp.status, body: text }));
    } catch (e) {
      console.error('Forward error', e);
      ws.send(JSON.stringify({ ok: false, error: String(e) }));
    }
  });

  ws.on('close', () => console.log('Client disconnected'));
});
