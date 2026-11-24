# Docker for RDK S600 ARM64

Target: RDK OS V5.1.0 (Ubuntu Noble), Linux aarch64/arm64, systemd.

```bash
sudo ./build.sh
```

Requires internet access to Ubuntu/RDK APT repositories and download.docker.com. Installs current stable Docker CE, CLI, containerd, Buildx and the Compose plugin from the official ARM64 Ubuntu Noble repository. This is an online installer, not the original 26.1.4 offline bundle.

Existing daemon configuration and storage are preserved. Conflicting distribution packages or an unmanaged Docker daemon stop installation for manual migration. No automatic user group membership changes are made. Use `sudo docker compose`, then verify containers with `sudo docker run --rm hello-world`.

Legacy x86 assets are unused on this branch. See [Chinese instructions](README.zh-CN.md) for details. The original x86 installer remains on branch `26.1.4`.
