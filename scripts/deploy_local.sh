#!/usr/bin/env bash
# 方式一：本地服务托管（systemd）部署 NikoApp
# 使用：sudo bash scripts/deploy_local.sh
set -euo pipefail

APP_JAR="${APP_JAR:-/opt/nikoapp/app.jar}"
APP_PORT="${APP_PORT:-8080}"
SRC_DIR="$(cd "$(dirname "$0")/../app/src" && pwd)"

echo "[1/4] 编译应用..."
rm -rf /tmp/nikoapp-out
mkdir -p /tmp/nikoapp-out /opt/nikoapp
javac -d /tmp/nikoapp-out "${SRC_DIR}"/com/nikoapp/App.java
jar --create --file "${APP_JAR}" --main-class com.nikoapp.App -C /tmp/nikoapp-out .

echo "[2/4] 安装 systemd 服务..."
cat > /etc/systemd/system/nikoapp.service <<EOF
[Unit]
Description=NikoApp Java Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/java -jar ${APP_JAR}
Environment=APP_PORT=${APP_PORT}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now nikoapp

echo "[3/4] 打通防火墙（真机可访问）..."
firewall-cmd --permanent --add-port="${APP_PORT}/tcp"
firewall-cmd --reload

echo "[4/4] 验证..."
systemctl status nikoapp --no-pager | head -n 5
sleep 1
curl -s "http://127.0.0.1:${APP_PORT}/api/health" && echo
