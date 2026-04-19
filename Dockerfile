FROM debian:bookworm-slim

# install deps
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates wget curl git bash tmux neofetch && \
    rm -rf /var/lib/apt/lists/*

# install ttyd
RUN wget -qO /usr/local/bin/ttyd \
    https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64 && \
    chmod +x /usr/local/bin/ttyd

# env
ENV PORT=10000
ENV USERNAME=admin
ENV PASSWORD=admin123

# history + prompt
RUN echo 'export HISTFILE=/root/.bash_history' >> /root/.bashrc && \
    echo 'export HISTSIZE=50000' >> /root/.bashrc && \
    echo 'export HISTFILESIZE=100000' >> /root/.bashrc && \
    echo 'shopt -s histappend' >> /root/.bashrc && \
    echo 'PROMPT_COMMAND="history -a; history -n"' >> /root/.bashrc && \
    echo "neofetch" >> /root/.bashrc && \
    echo "cd /root" >> /root/.bashrc && \
    echo "export PS1='\\[\\033[01;32m\\]$USERNAME@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ '" >> /root/.bashrc

# copy start script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 10000

# start (no nested shells, no '.' command)
CMD ["/start.sh"]
