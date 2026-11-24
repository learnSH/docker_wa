# Linux ARM64 Docker 离线安装

本分支 `codex/rdk-s600-arm64` 提供 Linux ARM64 安装包，x86-64 安装包使用 `26.1.4` 分支。当前脚本要求 aarch64 内核和运行中的 systemd，不限制发行版名称、版本或包管理器。

安装使用仓库内的 Docker Engine 26.1.4 ARM64 压缩包、独立 runc 1.2.5 和 Compose v2.29.7，不访问 APT 源、Docker 下载站或镜像仓库。系统须提供 Bash、tar、gzip、systemctl、sed、groupadd、usermod 及基础文件操作命令；缺少依赖时请先通过离线系统软件包补齐。

## 安装

将本分支的完整文件复制到设备，进入目录执行：

```bash
sudo bash ./build.sh
```

无需手动解压 `docker-26.1.4.tgz`，脚本会解压到临时目录，退出时清理。

安装时输入 Docker 存储根目录，默认 `/home`，实际数据目录为 `/home/dockerInfo`。非 HTTPS 私有仓库可以直接回车跳过，也可输入 `192.168.1.20:5000` 或 `registry.example.com:5000`，不能包含协议前缀或路径。输入只检查基本字符，最终配置由随包 dockerd 校验，不联网解析或连接。

检测到已有 docker 命令时直接退出。脚本不逐项预检系统依赖，执行失败时停止并显示错误。

## 安装行为

- 安装 Docker 压缩包内的程序到 `/usr/bin/`，独立 runc 到 `/usr/local/bin/runc`。
- 根据本地 `daemon.json` 生成并覆盖 `/etc/docker/daemon.json`，设置数据目录、日志轮转及可选的 `insecure-registries`。非 HTTPS 仓库仅适用于可信网络。
- 安装仓库内的 systemd 服务文件，启用并启动 containerd 和 Docker。
- 创建 docker 组，将 sudo 登录用户加入该组；重新登录后生效。
- 安装 Compose 插件，同时提供 `docker compose` 和 `docker-compose` 两种命令。不安装 Buildx。

## 验证

```bash
sudo systemctl is-active containerd docker
sudo docker version
sudo docker compose version
sudo docker info
```

验证容器运行需要提前准备 ARM64 镜像归档，在设备上使用 `sudo docker load -i <镜像归档.tar>` 导入，再运行该镜像。安装脚本不会拉取 hello-world 或其他镜像。内核的容器网络、cgroup 和存储驱动兼容性仍需在实际设备上验证。
