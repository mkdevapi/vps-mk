FROM debian:bookworm-slim

# Install packages
RUN apt-get update && \
    apt-get install -y wget curl git python3 python3-pip neofetch bash && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install ttyd
RUN wget -qO /bin/ttyd https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64 && \
    chmod +x /bin/ttyd

# Environment
ENV PORT=10000
ENV USERNAME=admin
ENV PASSWORD=admin123

# 🔥 HISTORY CONFIG (persistent during session)
RUN echo 'export HISTFILE=/root/.bash_history' >> /root/.bashrc && \
    echo 'export HISTSIZE=100000' >> /root/.bashrc && \
    echo 'export HISTFILESIZE=200000' >> /root/.bashrc && \
    echo 'export HISTCONTROL=ignoredups:erasedups' >> /root/.bashrc && \
    echo 'shopt -s histappend' >> /root/.bashrc && \
    echo 'PROMPT_COMMAND="history -a; history -n"' >> /root/.bashrc

# UI improvements
RUN echo "neofetch" >> /root/.bashrc && \
    echo "cd /root" >> /root/.bashrc && \
    echo "export PS1='\\[\\033[01;32m\\]$USERNAME@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ '" >> /root/.bashrc

# 🔥 KEEPALIVE SCRIPT (LOCAL + PUBLIC)
RUN echo '#!/bin/bash\n\
while true; do\n\
  curl -s http://localhost:$PORT > /dev/null\n\
  curl -s https://vps-mk.onrender.com > /dev/null || echo "public ping failed"\n\
  sleep 60\n\
done' > /keepalive.sh && chmod +x /keepalive.sh

EXPOSE 10000

# 🚀 START SYSTEM
CMD ["/bin/bash", "-c", "\
touch /root/.bash_history && \
/keepalive.sh & \
exec /bin/ttyd -W --font-size 16 -p ${PORT} -c ${USERNAME}:${PASSWORD} /bin/bash"]
