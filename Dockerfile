FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV USER=root
ENV DISPLAY=:1
ENV VNC_PORT=5901
ENV RESOLUTION=1280x800

# Install XFCE + VNC only (no novnc, no ttyd)
RUN apt-get update && apt-get install -y \
    xfce4 xfce4-goodies \
    tigervnc-standalone-server tigervnc-common \
    dbus-x11 x11-xserver-utils \
    wget curl git nano bash \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Setup VNC password
RUN mkdir -p /root/.vnc && \
    echo "123456" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create startup script
RUN echo '#!/bin/bash\n\
xrdb $HOME/.Xresources\n\
startxfce4 &' > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Expose VNC port
EXPOSE 5901

# Start VNC server
CMD ["bash", "-c", "vncserver :1 -geometry 1280x800 -depth 24 && tail -f /root/.vnc/*.log"]
