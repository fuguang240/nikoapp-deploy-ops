# NikoApp 服务部署与运维

Java 应用部署与运维实战项目：以 NikoApp（轻量 Java HTTP 服务）为载体，演示 **systemd 本地服务托管**、**Docker + MySQL 容器化部署**、**Nginx 反向代理**、**防火墙配置** 与 **生产故障排查** 的完整运维链路。

## 架构

```
                公网/局域网
                    |
                    v
             +-------------+     80
             |   Nginx     |  <-- 唯一对外入口（反代 + 内网访问控制）
             +-------------+
                    | 8080 (仅 docker 内网 backend 网络)
                    v
             +-------------+
             |  NikoApp    |  Java HTTP 服务 (app 容器 / systemd)
             |  (8080)     |
             +-------------+
                    | 3306 (仅内网)
                    v
             +-------------+
             |   MySQL     |  MySQL 8.0 + 数据卷持久化
             +-------------+
```

- **Nginx** 是唯一对外入口，后端 API 仅在内网可达（`/api/admin` 仅允许 `172.16.0.0/12` 网段）。
- **MySQL** 使用数据卷持久化，容器重建不丢数据。
- 应用支持两种部署形态：宿主机 systemd 托管 或 Docker 容器。

## 技术栈

| 领域 | 技术 |
|---|---|
| 应用 | Java 17（JDK 内置 HttpServer，无第三方依赖） |
| 容器 | Docker / Docker Compose、自定义 Dockerfile |
| 数据库 | MySQL 8.0、数据卷、健康检查 |
| 网关 | Nginx 反向代理、upstream、内网访问控制 |
| 系统 | CentOS Stream 10、systemd、firewalld |

## 方式一：本地服务托管（systemd）

```bash
# 1. 编译并安装为 systemd 服务
sudo bash scripts/deploy_local.sh

# 2. 打通防火墙，真机可访问
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload

# 3. 验证
curl http://<服务器IP>:8080/api/health
```

## 方式二：Docker Compose 容器化部署

```bash
# 一条命令拉起 MySQL + App + Nginx 三个容器
sudo bash scripts/deploy_docker.sh

# 验证（Nginx 80 端口对外）
curl http://127.0.0.1/api/health
```

## 故障排查记录（真实案例）

见 [`scripts/troubleshoot.md`](scripts/troubleshoot.md) —— 记录了一次 **Docker 服务启动失败 → 规则加载异常 → 逐层追查至内核缺失模块 → 安装加载修复** 的完整排查过程。

## 目录结构

```
nikoapp-deploy-ops/
├── app/                    # 应用源码与 Dockerfile
│   ├── Dockerfile
│   └── src/main/java/com/nikoapp/App.java
├── nginx/nginx.conf        # 反向代理与内网访问控制
├── scripts/                # 部署脚本与故障排查记录
│   ├── deploy_local.sh
│   ├── deploy_docker.sh
│   └── troubleshoot.md
└── docker-compose.yml
```

> 本项目为个人运维能力学习与展示仓库，欢迎交流指正。
