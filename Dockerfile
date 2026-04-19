FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1

RUN apt-get update && apt-get install -y \
    xfce4 xfce4-goodies \
    tigervnc-standalone-server tigervnc-common \
    dbus-x11 x11-xserver-utils \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# VNC setup
RUN mkdir -p /root/.vnc

# Password
RUN echo "123456" | vncpasswd -f > /root/.vnc/passwd && chmod 600 /root/.vnc/passwd

# FIXED xstartup (this is the main fix)
RUN echo '#!/bin/bash\n\
unset SESSION_MANAGER\n\
unset DBUS_SESSION_BUS_ADDRESS\n\
startxfce4 &' > /root/.vnc/xstartup && chmod +x /root/.vnc/xstartup

EXPOSE 5901

CMD ["bash", "-c", "vncserver :1 -geometry 1280x800 -depth 24 && tail -f /root/.vnc/*.log"]
