# ---------- Base ----------
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PORT=10000

# ---------- System deps ----------
RUN apt-get update && apt-get install -y \
    curl ca-certificates git nano vim htop \
    python3 python3-pip bash \
    build-essential python3-dev \
    && rm -rf /var/lib/apt/lists/*

# ---------- Install Node 18 (modern, stable) ----------
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && node -v && npm -v

WORKDIR /app

# ---------- Install runtime deps ----------
RUN npm install node-pty ws

# ---------- Create dirs ----------
RUN mkdir -p /app/logs

# ---------- Server (safe JS, no optional chaining) ----------
RUN cat << 'EOF' > /app/server.js
const http = require("http");
const WebSocket = require("ws");
const pty = require("node-pty");
const fs = require("fs");

const PORT = process.env.PORT || 10000;

const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end("VPS Terminal Running");
});

const wss = new WebSocket.Server({ server });

let sessions = {};

function createSession(id) {
  const shell = pty.spawn("/bin/bash", [], {
    name: "xterm-color",
    cols: 100,
    rows: 30,
    cwd: "/root",
    env: process.env
  });

  const logFile = "/app/logs/" + id + ".log";

  shell.onData(function (data) {
    try { fs.appendFileSync(logFile, data); } catch (e) {}
    if (sessions[id] && sessions[id].ws) {
      try { sessions[id].ws.send(data); } catch (e) {}
    }
  });

  sessions[id] = { shell: shell, ws: null };
}

wss.on("connection", function (ws) {
  const id = "sess_" + Date.now();
  createSession(id);
  sessions[id].ws = ws;

  ws.send("Connected: " + id + "\r\n");

  ws.on("message", function (msg) {
    if (sessions[id] && sessions[id].shell) {
      sessions[id].shell.write(msg.toString());
    }
  });

  ws.on("close", function () {
    // keep shell alive (persistent)
    if (sessions[id]) {
      sessions[id].ws = null;
    }
  });
});

server.listen(PORT, function () {
  console.log("Running on port " + PORT);
});
EOF

# ---------- Keepalive (fixed, includes your URL) ----------
RUN cat << 'EOF' > /app/keepalive.sh
#!/bin/bash
while true
do
  curl -s https://vps-ppsd.onrender.com/ > /dev/null
  curl -s https://vps-1-r1f7.onrender.com/ > /dev/null
  curl -s https://vps-mk.onrender.com/ > /dev/null
  sleep 180
done
EOF

RUN chmod +x /app/keepalive.sh

# ---------- Expose ----------
EXPOSE 10000

# ---------- Start ----------
CMD bash -c "/app/keepalive.sh & node /app/server.js"
