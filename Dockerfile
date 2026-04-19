FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV VNC_PORT=5901
ENV NOVNC_PORT=8080

# Install XFCE + VNC + noVNC
RUN apt-get update && apt-get install -y \
    xfce4 xfce4-goodies \
    tigervnc-standalone-server tigervnc-common \
    dbus-x11 x11-xserver-utils \
    novnc websockify \
    supervisor \
    wget curl git nano \
    fonts-dejavu \
    && apt-get clean

# Create VNC directory
RUN mkdir -p /root/.vnc

# Set VNC password
RUN echo "123456" | vncpasswd -f > /root/.vnc/passwd && chmod 600 /root/.vnc/passwd

# Create xstartup
RUN echo '#!/bin/bash\n\
xrdb $HOME/.Xresources\n\
startxfce4 &' > /root/.vnc/xstartup && chmod +x /root/.vnc/xstartup

# Supervisor config
RUN mkdir -p /etc/supervisor/conf.d

RUN echo "[supervisord]\n\
nodaemon=true\n\
\n\
[program:vnc]\n\
command=/usr/bin/vncserver :1 -geometry 1280x720 -depth 24\n\
autorestart=true\n\
\n\
[program:novnc]\n\
command=/usr/share/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 8080\n\
autorestart=true\n" > /etc/supervisor/conf.d/supervisord.conf

EXPOSE 8080

CMD ["/usr/bin/supervisord"]
