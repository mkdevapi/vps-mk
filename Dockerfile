FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    VNC_PORT=5901 \
    NOVNC_PORT=6080 \
    VNC_PW=vncpassword

# Install XFCE, VNC, noVNC, Firefox, and Supervisor
RUN apt-get update && \
    apt-get install -y \
        xfce4 \
        xfce4-goodies \
        tightvncserver \
        novnc \
        websockify \
        firefox \
        dbus-x11 \
        supervisor \
        wget \
        net-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set VNC password and create startup script
RUN mkdir -p /root/.vnc && \
    echo "$VNC_PW" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd && \
    echo '#!/bin/bash\n\
xrdb $HOME/.Xresources\n\
startxfce4 &' > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Create Supervisor config inline
RUN mkdir -p /etc/supervisor/conf.d/ && \
    echo '[supervisord]' > /etc/supervisor/conf.d/supervisord.conf && \
    echo 'nodaemon=true' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'user=root' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo '' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo '[program:vnc]' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'command=bash -c "vncserver :1 -geometry 1280x720 -depth 24 && tail -f /root/.vnc/*.log"' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'priority=10' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo '' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo '[program:novnc]' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'command=bash -c "/usr/share/novnc/utils/launch.sh --vnc localhost:5901 --listen 6080"' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'priority=20' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'startretries=3' >> /etc/supervisor/conf.d/supervisord.conf

EXPOSE 6080

CMD ["/usr/bin/supervisord"]
