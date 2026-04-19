FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    VNC_PORT=5901 \
    NOVNC_PORT=6080 \
    WEB_PORT=8080 \
    RESOLUTION=1280x720 \
    VNC_PASSWORD=vncpass123 \
    USER=vncuser

# Install base packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 xfce4-terminal xfce4-goodies \
    tigervnc-standalone-server tigervnc-common \
    novnc websockify \
    firefox-esr \
    curl wget git htop nano sudo \
    python3 python3-numpy \
    ttyd \
    supervisor \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create non-root user
RUN useradd -m -s /bin/bash $USER && \
    echo "$USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /home/$USER/.vnc && \
    chown -R $USER:$USER /home/$USER

USER $USER
WORKDIR /home/$USER

# Set VNC password
RUN echo "$VNC_PASSWORD" | vncpasswd -f > /home/$USER/.vnc/passwd && \
    chmod 600 /home/$USER/.vnc/passwd

# Copy noVNC (Debian package may need symlink fix for clean vnc.html)
RUN sudo ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html || true

# Supervisor config for services
COPY <<EOF /home/$USER/supervisord.conf
[supervisord]
nodaemon=true
logfile=/dev/stdout
logfile_maxbytes=0

[program:xvfb]
command=Xvfb :1 -screen 0 ${RESOLUTION}x24
autorestart=true
stdout_logfile=/dev/stdout
stderr_logfile=/dev/stderr

[program:vncserver]
command=vncserver :1 -geometry ${RESOLUTION} -depth 24 -SecurityTypes None -localhost no
autorestart=true
stdout_logfile=/dev/stdout
stderr_logfile=/dev/stderr

[program:websockify]
command=websockify --web=/usr/share/novnc \( {NOVNC_PORT} localhost: \){VNC_PORT}
autorestart=true
stdout_logfile=/dev/stdout
stderr_logfile=/dev/stderr

[program:ttyd]
command=ttyd -p 7681 -i 0.0.0.0 bash
autorestart=true
stdout_logfile=/dev/stdout
stderr_logfile=/dev/stderr

[program:keepalive]
command=bash -c 'while true; do curl -s -o /dev/null http://localhost:${WEB_PORT}/ping || true; sleep 300; done'
autorestart=true
stdout_logfile=/dev/stdout
stderr_logfile=/dev/stderr
EOF

# Simple keep-alive + health endpoint server (using Python)
COPY <<EOF /home/$USER/keepalive_server.py
from http.server import BaseHTTPRequestHandler, HTTPServer
import threading
import time

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/ping':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'OK - Container alive')
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'''
            <h1>NoVNC + Terminal Ready</h1>
            <p><a href="/vnc.html" target="_blank">Open Desktop (noVNC)</a></p>
            <p><a href="/terminal" target="_blank">Open Web Terminal (ttyd)</a></p>
            <p>Keep-alive active. Your Render service should stay awake.</p>
            ''')
    def log_message(self, format, *args):
        return

def run_server():
    server = HTTPServer(('0.0.0.0', 8080), Handler)
    print("Keep-alive + UI server running on http://0.0.0.0:8080")
    server.serve_forever()

if __name__ == "__main__":
    threading.Thread(target=run_server, daemon=True).start()
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
