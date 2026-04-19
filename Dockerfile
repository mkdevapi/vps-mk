# Single‑file Dockerfile for Render: Debian 12 + XFCE + noVNC + Terminal + Keep‑alive
FROM debian:12

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install all required packages (using TightVNC instead of TigerVNC)
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        # XFCE Desktop
        xfce4 xfce4-goodies \
        # TightVNC Server (includes vncpasswd)
        tightvncserver \
        # noVNC (web VNC client) and websockify
        novnc websockify \
        # Web‑based terminal with command history
        shellinabox \
        # Supervisor to manage multiple processes
        supervisor \
        # Keep‑alive utilities
        curl cron \
        # Additional tools
        sudo wget git vim htop net-tools dbus-x11 x11-utils \
        python3 python3-pip xfce4-terminal xfce4-taskmanager \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set xfce4‑terminal as the default terminal emulator
RUN update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal.wrapper

# Create a non‑root user with sudo privileges
RUN useradd -m -s /bin/bash vncuser && \
    echo "vncuser:changeme" | chpasswd && \
    usermod -aG sudo vncuser

# ------------------ VNC Setup (as vncuser) ------------------
USER vncuser
WORKDIR /home/vncuser

# Hard‑coded VNC settings (no env vars needed)
ENV VNCPWD=vncpasswd \
    VNCDISPLAY=1280x720 \
    VNCDEPTH=24

# Create VNC password file and xstartup script (vncpasswd is now available)
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

# Keep‑alive script: pings the two Render URLs every 10 minutes
RUN mkdir -p scripts && \
    echo '#!/bin/bash\n\
while true; do\n\
    echo "$(date): Pinging keep‑alive URLs..."\n\
    curl -s -o /dev/null -w "%{http_code}" https://vps-ppsd.onrender.com/ || echo "Failed"\n\
    curl -s -o /dev/null -w "%{http_code}" https://vps-mk.onrender.com/ || echo "Failed"\n\
    sleep 600\n\
done' > scripts/keepalive.sh && \
    chmod +x scripts/keepalive.sh

# Switch back to root for supervisor configuration
USER root

# ------------------ Supervisor Configuration ------------------
# Write supervisor config file directly inside the container
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
command=/bin/bash -c "websockify --web=/usr/share/novnc ${PORT:-6080} localhost:5901"\n\
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
[program:keepalive]\n\
command=/home/vncuser/scripts/keepalive.sh\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0' > /etc/supervisor/conf.d/supervisord.conf

# Expose ports (informational)
EXPOSE 5901 6080 4200

# Start supervisor (it runs in the foreground, keeping container alive)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0' > /etc/supervisor/conf.d/supervisord.conf

# Expose ports (informational)
EXPOSE 5901 6080 4200

# Start supervisor (it runs in the foreground, keeping container alive)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
