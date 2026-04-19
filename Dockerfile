FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV VNC_PORT=5901
ENV NOVNC_PORT=6080

# Install XFCE + VNC + noVNC dependencies
RUN apt-get update && apt-get install -y \
    xfce4 xfce4-goodies \
    tigervnc-standalone-server tigervnc-common \
    novnc websockify \
    dbus-x11 x11-xserver-utils \
    wget curl git nano bash \
    python3 \
    && apt-get clean

# Setup VNC password
RUN mkdir -p /root/.vnc && \
    echo "123456" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create startup script
RUN echo '#!/bin/bash\n\
xrdb $HOME/.Xresources\n\
startxfce4 &' > /root/.vnc/xstartup && chmod +x /root/.vnc/xstartup

# noVNC setup
RUN mkdir -p /opt/novnc/utils/websockify && \
    ln -s /usr/share/novnc/* /opt/novnc/ && \
    ln -s /usr/share/websockify /opt/novnc/utils/websockify

# Start script
RUN echo '#!/bin/bash\n\
vncserver :1 -geometry 1280x720 -depth 24\n\
websockify --web=/opt/novnc/ 0.0.0.0:6080 localhost:5901' > /start.sh && \
chmod +x /start.sh

EXPOSE 6080

CMD ["/start.sh"]
