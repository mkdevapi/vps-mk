#!/usr/bin/env bash
set -e

# ensure history file exists
touch /root/.bash_history

# start keepalive in background (safe)
(
  while true; do
    curl -fsS "http://127.0.0.1:${PORT}" >/dev/null 2>&1 || true
    sleep 60
  done
) &

# start tmux session (idempotent)
tmux has-session -t main 2>/dev/null || tmux new -d -s main

# IMPORTANT: exec ttyd as PID 1 and attach tmux
exec /usr/local/bin/ttyd -W --font-size 16 \
  -p "${PORT}" -c "${USERNAME}:${PASSWORD}" \
  tmux attach -t main
