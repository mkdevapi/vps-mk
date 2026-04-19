# Single‑file Dockerfile for Render: Debian 12 + XFCE + noVNC (npm) + Terminal + Keep‑alive
FROM debian:12

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system packages
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        # XFCE Desktop
        xfce4 xfce4-goodies \
        # TightVNC Server (includes vncpasswd)
        tightvncserver \
        # Web terminal
        shellinabox \
        # Supervisor for process management
        supervisor \
        # Keep‑alive utilities
        curl cron \
        # Node.js (for @novnc/novnc and static server)
        nodejs npm \
        # Additional tools
        sudo wget git vim htop net-tools dbus-x11 x11-utils \
        python3 python3-pip xfce4-terminal xfce4-taskmanager \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set xfce4‑terminal as default terminal emulator
RUN update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal.wrapper

# Create non‑root user
RUN useradd -m -s /bin/bash vncuser && \
    echo "vncuser:changeme" | chpasswd && \
    usermod -aG sudo vncuser

# ------------------ VNC Setup (as vncuser) ------------------
USER vncuser
WORKDIR /home/vncuser

# Hard‑coded VNC settings
ENV VNCPWD=vncpasswd \
    VNCDISPLAY=1280x720 \
    VNCDEPTH=24

# Create VNC password file and xstartup script
RUN mkdir -p .vnc && \
    echo "${VNCPWD}" | vncpasswd -f > .vnc/passwd && \
    chmod 600 .vnc/passwd && \
    echo '#!/bin/sh\n\
xrdb $HOME/.Xresources\n\
xsetroot -solid grey\n\
export XKL_XMODMAP_DISABLE=1\n\
/etc/X11/Xsession\n\
startxfce4 &\n' > .vnc/xstartup && \
    chmod +x .vnc/xstartup

# Keep‑alive script (pings Render URLs every 10 minutes)
RUN mkdir -p scripts && \
    echo '#!/bin/bash\n\
while true; do\n\
    echo "$(date): Pinging keep‑alive URLs..."\n\
    curl -s -o /dev/null -w "%{http_code}" https://vps-ppsd.onrender.com/ || echo "Failed"\n\
    curl -s -o /dev/null -w "%{http_code}" https://vps-mk.onrender.com/ || echo "Failed"\n\
    sleep 600\n\
done' > scripts/keepalive.sh && \
    chmod +x scripts/keepalive.sh

# Switch back to root for remaining setup
USER root

# ------------------ Install @novnc/novnc via npm ------------------
# Create a directory for the web interface
RUN mkdir -p /opt/web && \
    cd /opt/web && \
    npm init -y && \
    npm install @novnc/novnc

# Create a custom index.html that embeds noVNC and Shellinabox in tabs
RUN echo '<!DOCTYPE html>\n\
<html>\n\
<head>\n\
    <meta charset="utf-8">\n\
    <title>VNC + Terminal</title>\n\
    <style>\n\
        body { margin: 0; padding: 0; font-family: sans-serif; }\n\
        .tabs { display: flex; background: #2d2d2d; }\n\
        .tab { padding: 10px 20px; color: white; cursor: pointer; border: none; background: transparent; }\n\
        .tab:hover { background: #444; }\n\
        .tab.active { background: #1e1e1e; }\n\
        .panel { display: none; height: calc(100vh - 40px); width: 100%; border: none; }\n\
        .panel.active { display: block; }\n\
        iframe { width: 100%; height: 100%; border: none; }\n\
    </style>\n\
</head>\n\
<body>\n\
    <div class="tabs">\n\
        <button class="tab active" onclick="showPanel(\'vnc\')">Desktop (VNC)</button>\n\
        <button class="tab" onclick="showPanel(\'term\')">Terminal</button>\n\
    </div>\n\
    <div id="vnc" class="panel active">\n\
        <iframe src="/novnc/vnc.html?autoconnect=true&resize=scale"></iframe>\n\
    </div>\n\
    <div id="term" class="panel">\n\
        <iframe src="/shellinabox/"></iframe>\n\
    </div>\n\
    <script>\n\
        function showPanel(name) {\n\
            document.querySelectorAll(".panel").forEach(p => p.classList.remove("active"));\n\
            document.querySelectorAll(".tab").forEach(t => t.classList.remove("active"));\n\
            document.getElementById(name).classList.add("active");\n\
            event.target.classList.add("active");\n\
        }\n\
    </script>\n\
</body>\n\
</html>' > /opt/web/index.html

# Create a simple Node.js server to serve the static files and proxy /shellinabox
RUN echo 'const http = require("http");\n\
const fs = require("fs");\n\
const path = require("path");\n\
const url = require("url");\n\
const { createProxyMiddleware } = require("http-proxy-middleware");\n\
\n\
const PORT = process.env.PORT || 8080;\n\
\n\
// Proxy configuration for shellinabox\n\
const shellProxy = createProxyMiddleware({\n\
    target: "http://localhost:4200",\n\
    changeOrigin: true,\n\
    ws: true,\n\
    pathRewrite: { "^/shellinabox": "" }\n\
});\n\
\n\
const server = http.createServer((req, res) => {\n\
    const parsedUrl = url.parse(req.url);\n\
    \n\
    // Proxy /shellinabox requests\n\
    if (parsedUrl.pathname.startsWith("/shellinabox")) {\n\
        return shellProxy(req, res);\n\
    }\n\
    \n\
    // Serve static files (noVNC and index.html)\n\
    let filePath = path.join("/opt/web", parsedUrl.pathname);\n\
    if (filePath === "/opt/web/" || parsedUrl.pathname === "/") {\n\
        filePath = "/opt/web/index.html";\n\
    }\n\
    \n\
    fs.readFile(filePath, (err, data) => {\n\
        if (err) {\n\
            res.writeHead(404);\n\
            res.end("Not found");\n\
            return;\n\
        }\n\
        res.writeHead(200);\n\
        res.end(data);\n\
    });\n\
});\n\
\n\
server.listen(PORT, () => {\n\
    console.log(`Web server listening on port ${PORT}`);\n\
});' > /opt/web/server.js

# Install http-proxy-middleware for proxying shellinabox
RUN cd /opt/web && npm install http-proxy-middleware

# ------------------ Supervisor Configuration ------------------
RUN mkdir -p /var/log/supervisor && \
    echo '[supervisord]\n\
nodaemon=true\n\
user=root\n\
logfile=/var/log/supervisor/supervisord.log\n\
pidfile=/var/run/supervisord.pid\n\
\n\
[program:vnc]\n\
command=/bin/bash -c "su - vncuser -c '\''vncserver :1 -geometry 1280x720 -depth 24 -localhost no'\''"\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0\n\
\n\
[program:websockify]\n\
command=/bin/bash -c "cd /opt/web/node_modules/@novnc/novnc && ./utils/novnc_proxy --listen 6080 --vnc localhost:5901"\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0\n\
\n\
[program:shellinabox]\n\
command=/bin/bash -c "shellinaboxd -t -s /:LOGIN -p 4200 --no-beep"\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0\n\
\n\
[program:webserver]\n\
command=/bin/bash -c "cd /opt/web && node server.js"\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0\n\
\n\
[program:keepalive]\n\
command=/home/vncuser/scripts/keepalive.sh\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0' > /etc/supervisor/conf.d/supervisord.conf

# Expose the port Render will use (informational)
EXPOSE 8080

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
