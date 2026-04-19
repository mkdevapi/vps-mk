FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PORT=10000

# Install core tools (real VPS feel)
RUN apt update && apt install -y \
    curl wget git nano vim htop \
    python3 python3-pip \
    nodejs npm \
    bash ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create working dir
WORKDIR /app

# Install minimal runtime for terminal handling
RUN npm install -g \
    node-pty \
    ws

# Create directories for logs & sessions
RUN mkdir -p /app/logs /app/sessions

# ---- Embedded Server (NO external files needed) ----
RUN printf '%s\n' "\
const http = require('http');\
const WebSocket = require('ws');\
const pty = require('node-pty');\
const fs = require('fs');\
\
const PORT = process.env.PORT || 10000;\
const server = http.createServer((req,res)=>{\
  res.writeHead(200); res.end('VPS Terminal Running');\
});\
\
const wss = new WebSocket.Server({ server });\
let sessions = {};\
\
function createSession(id){\
  const shell = pty.spawn('/bin/bash', [], {\
    name: 'xterm-color',\
    cols: 80,\
    rows: 24,\
    cwd: '/root',\
    env: process.env\
  });\
\
  const logFile = '/app/logs/' + id + '.log';\
\
  shell.onData(data => {\
    fs.appendFileSync(logFile, data);\
    if (sessions[id]?.ws) sessions[id].ws.send(data);\
  });\
\
  sessions[id] = { shell, ws: null };\
}\
\
wss.on('connection', ws => {\
  const id = 'sess_' + Date.now();\
  createSession(id);\
  sessions[id].ws = ws;\
\
  ws.send('Session: ' + id + '\\r\\n');\
\
  ws.on('message', msg => {\
    sessions[id].shell.write(msg);\
  });\
\
  ws.on('close', () => {\
    // DO NOT kill shell → persistent\
    sessions[id].ws = null;\
  });\
});\
\
server.listen(PORT, ()=>console.log('Running on '+PORT));\
" > /app/server.js

# ---- Keepalive Script (auto-run) ----
RUN printf '%s\n' "\
#!/bin/bash\
while true\
do\
  curl -s https://vps-ppsd.onrender.com/ > /dev/null\
  curl -s https://vps-1-r1f7.onrender.com/ > /dev/null\
  sleep 180\
done\
" > /app/keepalive.sh && chmod +x /app/keepalive.sh

# Expose port (Render uses env PORT)
EXPOSE 10000

# Start keepalive + terminal server
CMD bash -c "/app/keepalive.sh & node /app/server.js"
