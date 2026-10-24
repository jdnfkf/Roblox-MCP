#!/usr/bin/env bash
#=============================================================
#  tunnel.sh - 给沙箱里的 MCP server (16384) 开一个公网 https 隧道
#  用法:  bash tunnel.sh          # 前台跑(守护循环, 断了自动重连)
#        bash tunnel.sh once     # 只连一次
#
#  URL 写到 url.txt, 日志写 tunnel.log
#=============================================================
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a tunnel.log; }

: > tunnel.log
: > url.txt

connect() {
  # localhost.run 免费版: 域名随机, 每次重连都变
  # -v 才能看到 "https://xxx.lhr.life tunneled with tls termination"
  ssh -v -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o ServerAliveInterval=25 -o ServerAliveCountMax=100 \
      -o ExitOnForwardFailure=yes -o ConnectTimeout=20 \
      -R 80:localhost:16384 nokey@localhost.run 2>&1 \
    | while IFS= read -r line; do
        echo "$line" >> tunnel.log
        case "$line" in
          *"lhr.life tunneled with tls termination"*)
            U=$(echo "$line" | grep -aoE "https://[a-z0-9]+\.lhr\.life" | head -1)
            if [ -n "$U" ]; then
              echo "$U" > url.txt
              log "✅ 公网地址: $U"
            fi
            ;;
        esac
      done
}

if [ "${1:-}" = "once" ]; then
  connect
  exit 0
fi

log "守护启动 (每 5 秒检查, 断了自动重连)"
while true; do
  if [ ! -s url.txt ]; then
    log "建立隧道..."
    connect
  fi
  sleep 5
done
