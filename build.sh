#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_INSTALL_DIR="/home"

if [ "$(id -u)" -ne 0 ]; then
    echo "本脚本需要 root 权限，请使用 sudo 运行："
    echo "sudo $0"
    exit 1
fi

if [ -x "/usr/bin/docker" ]; then
    echo "Docker 已安装，退出安装。"
    exit 0
fi

required_files=(
    "$SCRIPT_DIR/runc"
    "$SCRIPT_DIR/docker/dockerd"
    "$SCRIPT_DIR/docker/docker-proxy"
    "$SCRIPT_DIR/daemon.json"
    "$SCRIPT_DIR/containerd.service"
    "$SCRIPT_DIR/docker.service"
    "$SCRIPT_DIR/docker.socket"
    "$SCRIPT_DIR/docker-compose-linux-x86_64"
)

for required_file in "${required_files[@]}"; do
    if [ ! -f "$required_file" ]; then
        echo "缺少安装文件: $required_file"
        exit 1
    fi
done

read -r -e -p "请输入 Docker 安装目录（默认: $DEFAULT_INSTALL_DIR）: " install_dir
install_dir="${install_dir:-$DEFAULT_INSTALL_DIR}"

if [[ ! "$install_dir" =~ ^/[A-Za-z0-9._/-]*$ ]] || [[ "$install_dir" == *"//"* ]] || [[ "/$install_dir/" == *"/../"* ]]; then
    echo "安装目录必须是合法的 Linux 绝对路径，且不能包含空格或 '..'。"
    exit 1
fi

if [ "$install_dir" != "/" ]; then
    install_dir="${install_dir%/}"
fi
docker_data_root="${install_dir%/}/dockerInfo"

validate_registry_address() {
    local address="$1"
    local host port label octet
    local -a labels octets

    if [[ "$address" =~ ^(.+):([0-9]+)$ ]]; then
        host="${BASH_REMATCH[1]}"
        port="${BASH_REMATCH[2]}"
        if [ "${#port}" -gt 5 ] || ((10#$port < 1 || 10#$port > 65535)); then
            return 1
        fi
    else
        host="$address"
    fi

    if [ -z "$host" ] || [ "${#host}" -gt 253 ]; then
        return 1
    fi

    if [[ "$host" =~ ^[0-9.]+$ ]]; then
        if [[ ! "$host" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            return 1
        fi
        IFS='.' read -r -a octets <<< "$host"
        for octet in "${octets[@]}"; do
            if ((10#$octet > 255)); then
                return 1
            fi
        done
        return 0
    fi

    IFS='.' read -r -a labels <<< "$host"
    for label in "${labels[@]}"; do
        if [ "${#label}" -gt 63 ] || [[ ! "$label" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]]; then
            return 1
        fi
    done
}

private_registry=""
while true; do
    read -r -p "请输入非 HTTPS 私有仓库地址（例如 registry.example.com:5000，直接回车跳过）: " private_registry
    if [ -z "$private_registry" ]; then
        break
    fi
    if validate_registry_address "$private_registry"; then
        break
    fi
    echo "仓库地址格式不正确。请仅输入域名或 IPv4 地址及可选端口，不要包含 http://、https:// 或路径。"
done

temp_daemon_config="$(mktemp)"
trap 'rm -f "$temp_daemon_config"' EXIT

sed "s|\"data-root\": \"[^\"]*\"|\"data-root\": \"$docker_data_root\"|" \
    "$SCRIPT_DIR/daemon.json" > "$temp_daemon_config"

if [ -n "$private_registry" ]; then
    sed -i "s|\"insecure-registries\": \[\]|\"insecure-registries\": [\"$private_registry\"]|" \
        "$temp_daemon_config"
fi

# docker-proxy 尚未安装到 PATH，预校验使用随包二进制路径。
if ! "$SCRIPT_DIR/docker/dockerd" --validate \
    --userland-proxy-path="$SCRIPT_DIR/docker/docker-proxy" \
    --config-file="$temp_daemon_config"; then
    echo "daemon.json 校验失败，终止安装。"
    exit 1
fi

echo "创建 Docker 数据目录: $docker_data_root"
mkdir -p "$docker_data_root"

if [ ! -x "/usr/local/bin/runc" ]; then
    echo "安装 runc 到 /usr/local/bin/runc ..."
    install -m 0755 "$SCRIPT_DIR/runc" /usr/local/bin/runc
fi

echo "正在安装 Docker 相关文件..."
install -m 0755 "$SCRIPT_DIR"/docker/* /usr/bin/

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
install -m 0755 "$SCRIPT_DIR/docker-compose-linux-x86_64" /usr/bin/docker-compose

echo "Docker 和 Docker Compose 安装完成！"
if [ -n "$login_user" ] && [ "$login_user" != "root" ]; then
    echo "请重新登录，使 Docker 用户组权限生效。"
fi
