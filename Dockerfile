FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install GUI + xpra (FIXED)
RUN apt-get update && apt-get install -y \
    xfce4 xfce4-goodies \
    xpra \
    dbus-x11 x11-xserver-utils \
    curl wget bash nano neofetch \
    && apt-get clean

# XFCE startup
RUN echo '#!/bin/bash\nstartxfce4' > /start.sh && chmod +x /start.sh

# Keepalive
RUN echo '#!/bin/bash\n\
URLS=("https://vps-ppsd.onrender.com/" "https://vps-mk.onrender.com/")\n\
while true; do\n\
  for url in "${URLS[@]}"; do\n\
    curl -s $url > /dev/null\n\
    echo "Pinged $url"\n\
  done\n\
  sleep 300\n\
done' > /keepalive.sh && chmod +x /keepalive.sh

# Entrypoint (Render compatible)
RUN echo '#!/bin/bash\n\
PORT=${PORT:-10000}\n\
echo "Running on port $PORT"\n\
\n\
/keepalive.sh &\n\
\n\
exec xpra start :100 \\\n\
  --bind-tcp=0.0.0.0:$PORT \\\n\
  --html=on \\\n\
  --daemon=no \\\n\
  --start=/start.sh\n' > /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 10000

CMD ["/entrypoint.sh"]
