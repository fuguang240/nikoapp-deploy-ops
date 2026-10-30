#!/usr/bin/env bash
# 方式二：Docker Compose 容器化部署（MySQL + App + Nginx）
# 使用：sudo bash scripts/deploy_docker.sh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "[1/2] 构建并启动容器..."
docker compose up -d --build

echo "[2/2] 验证..."
sleep 3
echo "--- Nginx 80 端口（唯一对外入口）---"
curl -s http://127.0.0.1/api/health && echo
echo "--- 容器状态 ---"
docker compose ps
