# Docker 26.1.4 Offline Installer

[简体中文](README.zh-CN.md)

This repository provides an interactive offline installer for Docker Engine 26.1.4 and Docker Compose on x86_64 Linux systems that use systemd.

## Requirements

- A 64-bit x86 Linux system
- systemd
- Bash
- Root or `sudo` access
- Docker must not already be installed at `/usr/bin/docker`

The required Docker, containerd, runc, and Docker Compose binaries are included in the repository, so the installation itself does not require internet access.

## Installation

Clone the `26.1.4` branch and run the installer with root privileges:

```bash
git clone --branch 26.1.4 https://github.com/learnSH/docker_wa.git
cd docker_wa
sudo ./build.sh
```

The installer asks for two values:

1. **Docker storage base directory**: press Enter to use `/home`. Docker data will then be stored in `/home/dockerInfo`.
2. **Non-HTTPS private registry**: press Enter to skip it, or enter a hostname/IPv4 address with an optional port, such as `registry.example.com:5000` or `192.168.1.20:5000`.

Do not include `http://`, `https://`, credentials, or a path in the private registry value. Invalid values are rejected and prompted again.

> [!WARNING]
> A registry added through this prompt is written to Docker's `insecure-registries` setting. Use this only for a trusted non-HTTPS registry. HTTPS registries do not need this setting; authenticate to them separately with `docker login`.

## Installed Files

The script installs:

- Docker and containerd binaries in `/usr/bin/`
- runc in `/usr/local/bin/runc`
- Docker Compose in `/usr/bin/docker-compose`
- systemd units in `/usr/lib/systemd/system/`
- Docker daemon configuration in `/etc/docker/daemon.json`
- Docker data in `<storage-base-directory>/dockerInfo`

It also creates the `docker` group, adds the user who invoked `sudo` to that group, and enables and starts the `containerd` and `docker` services.

## Docker Daemon Configuration

The generated `/etc/docker/daemon.json` uses these defaults:

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

Before installation, the script updates `data-root`, optionally adds the private registry, and validates the final configuration with the bundled `dockerd` binary.

## Verification

After installation, verify the services and command-line tools:

```bash
systemctl is-active containerd docker
docker version
docker-compose version
docker info
```

Log out and sign in again before using Docker without `sudo`, so the new `docker` group membership takes effect.

## Notes

- If `/usr/bin/docker` already exists, the installer exits without modifying the system.
- The installer overwrites `/etc/docker/daemon.json` with the generated configuration.
- The packaged binaries target x86_64 Linux and cannot run on ARM or macOS.
