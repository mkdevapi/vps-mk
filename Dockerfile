FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install GUI + xpra + basics
RUN apt-get update && apt-get install -y \
    xfce4 xfce4-goodies \
    xpra xpra-html5 \
    dbus-x11 x11-xserver-utils \
    curl wget bash nano neofetch \
    && apt-get clean

# XFCE start script
RUN echo '#!/bin/bash\nstartxfce4' > /start.sh && chmod +x /start.sh

# Keepalive script
RUN echo '#!/bin/bash\n\
URLS=("https://vps-ppsd.onrender.com/" "https://vps-mk.onrender.com/")\n\
while true; do\n\
  for url in "${URLS[@]}"; do\n\
    curl -s $url > /dev/null\n\
    echo "Pinged $url"\n\
  done\n\
  sleep 300\n\
done' > /keepalive.sh && chmod +x /keepalive.sh

# Start script (Render compatible)
RUN echo '#!/bin/bash\n\
PORT=${PORT:-14500}\n\
echo "Starting Xpra on port $PORT"\n\
\n\
# Start keepalive in background\n\
/keepalive.sh &\n\
\n\
# Start xpra (single process, foreground)\n\
exec xpra start :100 \\\n\
  --bind-tcp=0.0.0.0:$PORT \\\n\
  --html=on \\\n\
  --daemon=no \\\n\
  --exit-with-children=yes \\\n\
  --start=/start.sh\n' > /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 10000

CMD ["/entrypoint.sh"]
