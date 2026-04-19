FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install base + build tools
RUN apt-get update && apt-get install -y \
    xfce4 xfce4-goodies \
    tigervnc-standalone-server \
    novnc websockify \
    dbus-x11 x11-xserver-utils \
    curl wget git bash nano neofetch \
    build-essential cmake libjson-c-dev libwebsockets-dev \
    && apt-get clean

# 🔥 Install ttyd manually (FIX)
RUN git clone https://github.com/tsl0922/ttyd.git /opt/ttyd && \
    cd /opt/ttyd && \
    mkdir build && cd build && \
    cmake .. && make && make install

# VNC password
RUN mkdir -p /root/.vnc && \
    echo "123456" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# XFCE startup
RUN echo '#!/bin/bash\nstartxfce4 &' > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# noVNC fix
RUN git clone https://github.com/novnc/noVNC.git /opt/noVNC && \
    git clone https://github.com/novnc/websockify /opt/noVNC/utils/websockify

# Entrypoint
RUN echo '#!/bin/bash\n\
PORT=${PORT:-10000}\n\
echo "Running on port $PORT"\n\
\n\
# Start VNC\n\
vncserver :1 -geometry 1280x720 -depth 24\n\
\n\
# Terminal\n\
ttyd -p 7681 bash &\n\
\n\
# Keepalive\n\
(while true; do\n\
  curl -s https://vps-ppsd.onrender.com/ > /dev/null\n\
  curl -s https://vps-mk.onrender.com/ > /dev/null\n\
  sleep 300\n\
done) &\n\
\n\
# Start noVNC\n\
/opt/noVNC/utils/novnc_proxy --vnc localhost:5901 --listen $PORT\n\
' > /start.sh && chmod +x /start.sh

EXPOSE 10000

CMD ["/start.sh"]
