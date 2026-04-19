FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    VNC_PORT=5901 \
    NOVNC_PORT=6080 \
    WEB_PORT=8080 \
    RESOLUTION=1280x720 \
    VNC_PASSWORD=vncpass123 \
    USER=vncuser

# Update and install minimal required packages (much lighter)
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 xfce4-terminal \
    tigervnc-standalone-server tigervnc-common \
    novnc websockify \
    x11-utils dbus-x11 \
    curl wget git htop nano sudo \
    python3 python3-pip \
    snapd \
    supervisor \
    && rm -rf /var/lib/apt/lists/* && apt-get clean

# Install ttyd via snap (most reliable method on Debian 12)
RUN systemctl enable --now snapd.socket && \
    snap install ttyd --classic || echo "ttyd snap install attempted"

# Create user
RUN useradd -m -s /bin/bash $USER && \
    echo "$USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /home/$USER/.vnc /home/$USER/.config/xfce4

USER $USER
WORKDIR /home/$USER

# VNC password
RUN echo "$VNC_PASSWORD" | vncpasswd -f > \~/.vnc/passwd && chmod 600 \~/.vnc/passwd

# Proper xstartup for XFCE (fixes common Debian 12 VNC black screen issues)
COPY <<'EOF' \~/.vnc/xstartup
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
vncconfig -iconic &
startxfce4 &
EOF

RUN chmod +x \~/.vnc/xstartup

# Supervisor configuration
COPY <<EOF /home/$USER/supervisord.conf
[supervisord]
nodaemon=true
logfile=/dev/stdout
logfile_maxbytes=0

[program:xvfb]
command=Xvfb :1 -screen 0 ${RESOLUTION}x24 -ac
autorestart=true

[program:vncserver]
command=vncserver :1 -geometry ${RESOLUTION} -depth 24 -SecurityTypes None -localhost no
autorestart=true
environment=HOME="/home/vncuser",USER="vncuser"

[program:websockify]
command=websockify --web=/usr/share/novnc \( {NOVNC_PORT} localhost: \){VNC_PORT}
autorestart=true

[program:ttyd]
command=/snap/bin/ttyd -p 7681 -i 0.0.0.0 /bin/bash
autorestart=true

[program:keepalive]
command=bash -c 'while true; do curl -fsS -o /dev/null http://localhost:${WEB_PORT}/ping || true; sleep 240; done'
autorestart=true
EOF

# Simple status + keepalive server
COPY <<EOF /home/$USER/keepalive_server.py
from http.server import BaseHTTPRequestHandler, HTTPServer
import threading, time

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/ping':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'OK')
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(f'''
            <h1>VPS Ready on Render</h1>
            <p><a href="/vnc.html" target="_blank">→ Open Desktop (noVNC)</a></p>
            <p><a href="/terminal" target="_blank">→ Open Web Terminal</a></p>
            <p>Keep-alive active | Password: {__import__('os').environ.get('VNC_PASSWORD', 'vncpass123')}</p>
            '''.encode())

if __name__ == "__main__":
    threading.Thread(target=lambda: HTTPServer(('0.0.0.0', 8080), Handler).serve_forever(), daemon=True).start()
    while True: time.sleep(60)
EOF

# Entrypoint
COPY <<'EOF' /home/$USER/entrypoint.sh
#!/bin/bash
set -e

echo "Starting services..."

# Start supervisor (XVFB + VNC + websockify + ttyd + keepalive)
supervisord -c /home/$USER/supervisord.conf &

# Start keepalive + status page
python3 /home/$USER/keepalive_server.py &

echo "=================================================="
echo "✅ Container is ready!"
echo "🌐 Desktop:   https://YOUR-APP.onrender.com/vnc.html"
echo "🖥️  Terminal: https://YOUR-APP.onrender.com/terminal"
echo "🔄 Keep-alive running"
echo "VNC Password: $VNC_PASSWORD"
echo "=================================================="

tail -f /dev/null
EOF

RUN chmod +x /home/$USER/entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/home/$USER/entrypoint.sh"]    threading.Thread(target=run_server, daemon=True).start()
    # Keep main thread alive for supervisor
    while True:
        time.sleep(60)
EOF

# Expose port for Render (Web Service)
EXPOSE 8080

# Entrypoint script
COPY <<EOF /home/$USER/entrypoint.sh
#!/bin/bash
set -e

# Start Xvfb + VNC + services via supervisor
supervisord -c /home/$USER/supervisord.conf &

# Start keep-alive Python server in background
python3 /home/$USER/keepalive_server.py &

echo "=================================================="
echo "✅ Setup complete!"
echo "🌐 Access Desktop: http://YOUR-RENDER-URL/vnc.html"
echo "🖥️  Access Terminal: http://YOUR-RENDER-URL/terminal  (or directly :7681 if exposed)"
echo "🔄 Keep-alive ping running every 5 min"
echo "Password for VNC: $VNC_PASSWORD"
echo "=================================================="

# Keep container running
tail -f /dev/null
EOF

RUN chmod +x /home/$USER/entrypoint.sh

ENTRYPOINT ["/home/$USER/entrypoint.sh"]
