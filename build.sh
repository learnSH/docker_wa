#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "请使用 sudo ./build.sh 运行。" >&2
    exit 1
fi
if [ "$(uname -s)" != Linux ] || [ "$(uname -m)" != aarch64 ]; then
    echo "本分支仅支持 Linux ARM64（RDK S600）。" >&2
    exit 1
fi
. /etc/os-release
if [ "${NAME:-}" != "RDK OS" ] || [ "${VERSION_ID:-}" != V5.1.0 ]; then
    echo "本安装脚本面向 RDK OS V5.1.0（Ubuntu Noble 基础系统）。" >&2
    exit 1
fi
if [ ! -d /run/systemd/system ]; then
    echo "需要运行中的 systemd。" >&2
    exit 1
fi
if [ "$(dpkg --print-architecture)" != arm64 ]; then
    echo "需要 arm64 用户空间。" >&2
    exit 1
fi
# Existing runtimes may own running workloads; replacing them needs a migration.
for package in docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc; do
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -qx 'install ok installed'; then
        echo "发现冲突软件包 $package，请先规划迁移并卸载该包后重试。" >&2
        exit 1
    fi
done
if command -v dockerd >/dev/null && ! dpkg-query -W -f='${Status}' docker-ce 2>/dev/null | grep -qx 'install ok installed'; then
    echo "发现非 Docker CE 软件包管理的 dockerd，请先迁移现有安装。" >&2
    exit 1
fi
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl iptables
# RDK S600 kernels expose legacy netfilter; nftables cannot initialize NAT.
iptables-legacy -t nat -L -n >/dev/null
ip6tables-legacy -t nat -L -n >/dev/null
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
install -d -m 0755 /etc/apt/keyrings
key_download="$(mktemp)"
trap 'rm -f "$key_download"' EXIT
curl --fail --show-error --silent --location --retry 3 --retry-all-errors --connect-timeout 15 --max-time 120 \
    https://download.docker.com/linux/ubuntu/gpg -o "$key_download"
install -m 0644 "$key_download" /etc/apt/keyrings/docker.asc
cat > /etc/apt/sources.list.d/docker.sources <<'SOURCES'
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: arm64
Signed-By: /etc/apt/keyrings/docker.asc
SOURCES
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now containerd docker
systemctl is-active --quiet docker
docker version
docker compose version
printf '\n安装完成。运行 sudo docker run --rm hello-world 验证容器运行。\n'
