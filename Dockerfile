FROM debian:bookworm-slim

# Install required packages
RUN apt-get update && \
    apt-get install -y wget curl git python3 python3-pip neofetch bash tmux && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install ttyd
RUN wget -qO /usr/local/bin/ttyd https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64 && \
    chmod +x /usr/local/bin/ttyd

# Environment
ENV PORT=10000
ENV USERNAME=admin
ENV PASSWORD=admin123

# 🔥 History settings (session-friendly)
RUN echo 'export HISTFILE=/root/.bash_history' >> /root/.bashrc && \
    echo 'export HISTSIZE=50000' >> /root/.bashrc && \
    echo 'export HISTFILESIZE=100000' >> /root/.bashrc && \
    echo 'shopt -s histappend' >> /root/.bashrc && \
    echo 'PROMPT_COMMAND="history -a; history -n"' >> /root/.bashrc

# UI tweaks
RUN echo "neofetch" >> /root/.bashrc && \
    echo "cd /root" >> /root/.bashrc && \
    echo "export PS1='\\[\\033[01;32m\\]$USERNAME@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ '" >> /root/.bashrc

# 🔥 Keepalive script
RUN printf '#!/bin/bash\nwhile true; do curl -s http://localhost:$PORT > /dev/null; sleep 60; done\n' > /keepalive.sh && \
    chmod +x /keepalive.sh

EXPOSE 10000

# 🚀 Final startup (FIXED)
CMD ["/bin/bash","-lc", "\
touch /root/.bash_history; \
/keepalive.sh & \
tmux new -d -s main; \
exec ttyd -W --font-size 16 -p ${PORT} -c ${USERNAME}:${PASSWORD} tmux attach -t main"]
