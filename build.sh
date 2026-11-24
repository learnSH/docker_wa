#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_INSTALL_DIR="/home"

if [ "$(id -u)" -ne 0 ]; then
    echo "本脚本需要 root 权限，请使用 sudo 运行："
    echo "sudo $0"
    exit 1
fi

if [ "$(uname -s)" != Linux ] || [ "$(uname -m)" != aarch64 ]; then
    echo "本分支仅支持 Linux ARM64。" >&2
    exit 1
fi
if command -v docker >/dev/null; then
    echo "Docker 已安装，退出安装。"
    exit 0
fi

required_files=(
    "$SCRIPT_DIR/runc"
    "$SCRIPT_DIR/docker-26.1.4.tgz"
    "$SCRIPT_DIR/daemon.json"
    "$SCRIPT_DIR/containerd.service"
    "$SCRIPT_DIR/docker.service"
    "$SCRIPT_DIR/docker.socket"
    "$SCRIPT_DIR/docker-compose-linux-aarch64"
)

for required_file in "${required_files[@]}"; do
    if [ ! -f "$required_file" ]; then
        echo "缺少安装文件: $required_file"
        exit 1
    fi
done

install_workspace="$(mktemp -d)"
trap 'rm -rf "$install_workspace"' EXIT
tar -xzf "$SCRIPT_DIR/docker-26.1.4.tgz" -C "$install_workspace"
read -r -e -p "请输入 Docker 安装目录（默认: ${DEFAULT_INSTALL_DIR}）: " install_dir
install_dir="${install_dir:-$DEFAULT_INSTALL_DIR}"

if [[ ! "$install_dir" =~ ^/[A-Za-z0-9._/-]*$ ]] || [[ "$install_dir" == *"//"* ]] || [[ "/$install_dir/" == *"/../"* ]]; then
    echo "安装目录必须是合法的 Linux 绝对路径，且不能包含空格或 '..'。"
    exit 1
fi

if [ "$install_dir" != "/" ]; then
    install_dir="${install_dir%/}"
fi
docker_data_root="${install_dir%/}/dockerInfo"

read -r -p "请输入非 HTTPS 私有仓库地址（例如 registry.example.com:5000，直接回车跳过）: " private_registry
if [[ ! "$private_registry" =~ ^[A-Za-z0-9.:-]*$ ]]; then
    echo "仓库地址请填写主机名或 IP 及可选端口，不要包含协议前缀或路径。"
    exit 1
fi

temp_daemon_config="$install_workspace/daemon.json"

sed "s|\"data-root\": \"[^\"]*\"|\"data-root\": \"$docker_data_root\"|" \
    "$SCRIPT_DIR/daemon.json" > "$temp_daemon_config"

if [ -n "$private_registry" ]; then
    sed -i "s|\"insecure-registries\": \[\]|\"insecure-registries\": [\"$private_registry\"]|" \
        "$temp_daemon_config"
fi

if ! "$install_workspace/docker/dockerd" --validate --config-file="$temp_daemon_config"; then
    echo "daemon.json 校验失败，终止安装。"
    exit 1
fi

echo "创建 Docker 数据目录: $docker_data_root"
mkdir -p "$docker_data_root"

echo "安装 runc 到 /usr/local/bin/runc ..."
install -m 0755 "$SCRIPT_DIR/runc" /usr/local/bin/runc

echo "正在安装 Docker 相关文件..."
install -m 0755 "$install_workspace"/docker/* /usr/bin/

echo "正在安装 Docker 配置..."
install -d -m 0755 /etc/docker
install -m 0644 "$temp_daemon_config" /etc/docker/daemon.json

echo "daemon.json 配置已更新:"
cat /etc/docker/daemon.json

echo "正在安装 Docker systemd 服务..."
install -m 0644 "$SCRIPT_DIR/containerd.service" /usr/lib/systemd/system/containerd.service
install -m 0644 "$SCRIPT_DIR/docker.service" /usr/lib/systemd/system/docker.service
install -m 0644 "$SCRIPT_DIR/docker.socket" /usr/lib/systemd/system/docker.socket

echo "创建 Docker 用户组..."
groupadd -f docker

login_user="${SUDO_USER:-}"
if [ -n "$login_user" ] && [ "$login_user" != "root" ]; then
    echo "将用户 $login_user 添加到 Docker 组..."
    usermod -aG docker "$login_user"
else
    echo "未检测到 sudo 登录用户，跳过添加 Docker 用户组成员。"
fi

echo "启动 Docker 服务..."
systemctl daemon-reload
systemctl enable containerd docker
systemctl start containerd docker

echo "安装 Docker Compose..."
install -d -m 0755 /usr/local/lib/docker/cli-plugins
install -m 0755 "$SCRIPT_DIR/docker-compose-linux-aarch64" /usr/local/lib/docker/cli-plugins/docker-compose
ln -sfn /usr/local/lib/docker/cli-plugins/docker-compose /usr/bin/docker-compose

systemctl is-active --quiet containerd docker
docker version
docker compose version

echo "Docker 和 Docker Compose 安装完成！"
if [ -n "$login_user" ] && [ "$login_user" != "root" ]; then
    echo "请重新登录，使 Docker 用户组权限生效。"
fi
