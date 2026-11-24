# Offline Docker for Linux ARM64

This branch bundles Linux ARM64 binaries; use branch `26.1.4` for x86-64. The installer requires an aarch64 kernel and running systemd, without restrictions on distribution name, release version or package manager.

Copy the complete branch to the device and run:

```bash
sudo bash ./build.sh
```

Installs the bundled Docker Engine 26.1.4 ARM64 archive, standalone runc 1.2.5, and Compose v2.29.7 without network access. The archive is extracted automatically into a temporary directory. Bash, tar, gzip, systemctl, sed, groupadd, usermod and basic file utilities must already be installed; missing dependencies must be supplied offline.

The script exits if the docker command already exists. System dependencies are not prechecked individually; command failures stop installation and report an error. It prompts for the storage base directory (default `/home`, producing `/home/dockerInfo`) and an optional non-HTTPS registry. It replaces `/etc/docker/daemon.json` using the local template, installs and starts the bundled systemd services, and adds the sudo user to the docker group. Log in again for group membership to take effect.

Both `docker compose` and `docker-compose` are available. Buildx is not installed. Verify with `sudo docker version`, `sudo docker compose version`, and `sudo systemctl is-active containerd docker`. To test containers offline, import a prepackaged ARM64 image with `docker load`; the installer does not pull images.

See [Chinese instructions](README.zh-CN.md) for details.
