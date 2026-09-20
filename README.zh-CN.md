# Docker 26.1.4 离线安装工具

[English](README.md)

本仓库提供一个交互式离线安装脚本，用于在采用 systemd 的 x86_64 Linux 系统上安装 Docker Engine 26.1.4 和 Docker Compose。

## 环境要求

- 64 位 x86 Linux 系统
- systemd
- Bash
- root 或 `sudo` 权限
- `/usr/bin/docker` 中尚未安装 Docker

仓库已经包含 Docker、containerd、runc 和 Docker Compose 所需的二进制文件，因此执行安装时不需要访问互联网。

## 安装方法

克隆 `26.1.4` 分支，然后使用 root 权限运行安装脚本：

```bash
git clone --branch 26.1.4 https://github.com/learnSH/docker_wa.git
cd docker_wa
sudo ./build.sh
```

安装过程中需要确认两个配置：

1. **Docker 存储根目录**：直接回车使用 `/home`，最终 Docker 数据目录为 `/home/dockerInfo`。
2. **非 HTTPS 私有仓库**：直接回车跳过；也可以输入域名或 IPv4 地址及可选端口，例如 `registry.example.com:5000` 或 `192.168.1.20:5000`。

私有仓库地址不能包含 `http://`、`https://`、认证信息或路径。格式错误时，脚本会提示并要求重新输入。

> [!WARNING]
> 通过此提示添加的仓库会写入 Docker 的 `insecure-registries` 配置。该功能仅应用于可信网络中的非 HTTPS 仓库。HTTPS 仓库不需要此配置，认证请单独使用 `docker login`。

## 安装内容

脚本会安装以下内容：

- Docker 和 containerd 二进制文件：`/usr/bin/`
- runc：`/usr/local/bin/runc`
- Docker Compose：`/usr/bin/docker-compose`
- systemd 服务文件：`/usr/lib/systemd/system/`
- Docker daemon 配置：`/etc/docker/daemon.json`
- Docker 数据：`<存储根目录>/dockerInfo`

脚本还会创建 `docker` 用户组，将执行 `sudo` 的用户加入该组，并启用和启动 `containerd`、`docker` 服务。

## Docker Daemon 配置

生成的 `/etc/docker/daemon.json` 默认配置如下：

```json
{
    "data-root": "/home/dockerInfo",
    "insecure-registries": [],
    "live-restore": true,
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "50m",
        "max-file": "3"
    }
}
```

安装前，脚本会更新 `data-root`，按需添加私有仓库，并使用随包的 `dockerd` 校验最终配置。

## 安装验证

安装完成后，可以运行以下命令检查服务和命令行工具：

```bash
systemctl is-active containerd docker
docker version
docker-compose version
docker info
```

如需不使用 `sudo` 运行 Docker，请先退出并重新登录，使新的 `docker` 用户组权限生效。

## 注意事项

- 如果 `/usr/bin/docker` 已经存在，安装脚本会直接退出，不会修改系统。
- 安装脚本会使用生成的配置覆盖 `/etc/docker/daemon.json`。
- 随包二进制文件仅适用于 x86_64 Linux，不能在 ARM 或 macOS 上运行。
