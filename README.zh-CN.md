# RDK S600 ARM64 Docker 一键安装

本分支 `codex/rdk-s600-arm64` 面向 D-Robotics RDK S600、RDK OS V5.1.0（Ubuntu Noble）、aarch64/arm64 和 systemd。

## 安装

```bash
git clone --branch codex/rdk-s600-arm64 https://github.com/learnSH/docker_wa.git
cd docker_wa
sudo ./build.sh
```

也可将本分支文件复制到设备后执行 `sudo ./build.sh`。需要联网访问系统 APT 源和 download.docker.com；本分支不是离线安装包。安装当前 stable 源中的 Docker CE、CLI、containerd、Buildx 和 Compose 插件，不固定为 26.1.4。

脚本检查系统、架构和冲突软件包，然后配置 Docker 官方 ARM64 Noble 软件源，安装并启用服务。发现旧版发行版 Docker、独立 containerd/runc 或手工安装的 dockerd 时停止，避免自动移除已有运行环境。执行失败可修复网络或包冲突后重试。

保留已有 /etc/docker/daemon.json；新安装默认数据目录为 /var/lib/docker，日志策略使用 Docker 默认值。不会自动配置 HTTP 私有仓库或加入 docker 用户组。Compose 使用 `docker compose`。

## 验证

```bash
sudo systemctl is-active containerd docker
sudo docker version
sudo docker compose version
sudo docker run --rm hello-world
```

安装脚本验证服务及客户端/服务端版本；hello-world 需要额外访问容器镜像仓库，由用户按需执行。RDK 内核的容器网络、cgroup 和存储驱动兼容性以设备实际运行容器为准。

本分支中的旧 x86 离线资源不再用于安装。x86 离线安装请使用原 `26.1.4` 分支。

官方安装说明：https://docs.docker.com/engine/install/ubuntu/
