# NikoApp 部署故障排查记录（真实案例）

## 现象

执行 `docker compose up -d` 后，`nikoapp-app` 容器反复重启，状态始终为 `Restarting`，
`docker compose ps` 显示 `app` 服务 `STATUS: Restarting (1) N seconds ago`。

## 排查过程

### 第 1 步：看容器日志，定位直接报错

```bash
docker compose logs app
```

关键报错：

```
Error: Could not find or load main class com.nikoapp.App
Caused by: java.lang.ClassNotFoundException: com.nikoapp.App
```

**初步判断**：jar 构建产物有问题或镜像内路径错误。核对 Dockerfile 后排除路径问题，
但重新构建后错误依旧。

### 第 2 步：怀疑构建阶段，检查镜像内容

```bash
docker build -t nikoapp-app:debug ./app
docker run --rm --entrypoint ls nikoapp-app:debug -l /app
```

确认 `app.jar` 存在且非空，但解包查看发现 `META-INF/MANIFEST.MF` 缺失
`Main-Class` 属性。

### 第 3 步：继续追查 —— 定位规则加载异常

直接解包 jar：

```bash
jar --list --file app.jar | head
```

发现构建产物正常包含 class 文件，于是怀疑 **Dockerfile 中 `jar --create` 的执行环境**
（构建阶段）本身有问题。改用 `javac -d out` + `jar -C out .` 的标准写法，
并打印构建阶段输出，发现 `jar` 命令提示：

```
Error: Unable to read jar: /build/app.jar (No such file or directory)
```

**关键转折**：这不是应用代码问题，而是**构建阶段文件系统/内核能力异常**——
容器内 `jar` 写入时静默失败。

### 第 4 步：逐层追查至内核缺失模块

在宿主机执行：

```bash
dmesg | tail
journalctl -k | tail
```

发现大量 overlayfs / 存储驱动相关错误，进一步检查：

```bash
ls /lib/modules/$(uname -r)/kernel/fs/overlayfs/
```

该目录为空 —— **宿主内核缺少 overlayfs 相关模块**，导致 Docker 的 overlay2 存储驱动
在写层时异常，容器内文件写入静默失败。

### 第 5 步：安装加载缺失内核模块并修复

```bash
# 安装内核模块（以 kernel-modules 包为例）
dnf install -y kernel-modules-$(uname -r)

# 加载模块并确认
modprobe overlay
lsmod | grep overlay

# 重启 Docker，重建镜像与容器
systemctl restart docker
docker compose up -d --build
```

### 第 6 步：验证修复

```bash
docker compose ps          # 三个服务均为 Up (healthy)
curl http://127.0.0.1/api/health   # 返回 {"status":"ok",...}
```

## 排查经验总结

| 层 | 方法 | 本案例结论 |
|---|---|---|
| 应用层 | `docker compose logs` | 报错指向 jar 无法加载，但属表象 |
| 构建层 | 解包 jar / 检查镜像内容 | 构建产物异常，问题不在应用代码 |
| 系统层 | `dmesg` / `journalctl -k` | 定位 overlayfs 内核模块缺失 |
| 修复 | 安装内核模块 + 重启 Docker | 重建镜像后恢复正常 |

> 排查要点：**由外到内逐层追查，不放过"静默失败"**。容器内文件写入异常优先怀疑
> 存储驱动与内核模块，而不是反复重写应用代码。
