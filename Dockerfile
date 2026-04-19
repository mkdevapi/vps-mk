FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PORT=10000

# Install packages
RUN apt update && apt install -y \
    curl git nano vim python3 \
    nodejs npm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install dependencies
RUN npm install node-pty ws

# Create folders
RUN mkdir -p /app/logs

# ---------------- SERVER.JS ----------------
RUN cat << 'EOF' > /app/server.js
const http = require("http");
const WebSocket = require("ws");
const pty = require("node-pty");
const fs = require("fs");

const PORT = process.env.PORT || 10000;

const server = http.createServer((req, res) => {
  res.writeHead(200);
  res.end("VPS Terminal Running");
});

const wss = new WebSocket.Server({ server });

let sessions = {};

function createSession(id) {
  const shell = pty.spawn("/bin/bash", [], {
    name: "xterm-color",
    cols: 80,
    rows: 24,
    cwd: "/root",
    env: process.env
  });

  const logFile = "/app/logs/" + id + ".log";

  shell.onData(data => {
    fs.appendFileSync(logFile, data);
    if (sessions[id]?.ws) {
      sessions[id].ws.send(data);
    }
  });

  sessions[id] = { shell, ws: null };
}

wss.on("connection", ws => {
  const id = "sess_" + Date.now();

  createSession(id);
  sessions[id].ws = ws;

  ws.send("Connected: " + id + "\r\n");

  ws.on("message", msg => {
    sessions[id].shell.write(msg);
  });

  ws.on("close", () => {
    // DO NOT kill shell → persistent
    sessions[id].ws = null;
  });
});

server.listen(PORT, () => {
  console.log("Running on port " + PORT);
});
EOF

# ---------------- KEEPALIVE ----------------
RUN cat << 'EOF' > /app/keepalive.sh
#!/bin/bash

while true
do
  curl -s https://vps-ppsd.onrender.com/ > /dev/null
  curl -s https://vps-1-r1f7.onrender.com/ > /dev/null
  sleep 180
done
EOF

RUN chmod +x /app/keepalive.sh

# Expose port
EXPOSE 10000

# Start services
CMD bash -c "/app/keepalive.sh & node /app/server.js"
