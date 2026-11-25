# Mountain

A Windows 11-looking desktop OS built on Bazzite (Fedora Atomic, KDE Plasma 6, Wayland), made with BlueBuild.

## Install

**From the installer ISO (new PC or fresh disk).** Open the newest [Release](https://github.com/borisalv-marinov/mountain/releases) named `iso-<date>`. The ISO is bigger than GitHub's 2 GiB file limit, so it comes in parts: download every `mountain.iso.partNN` and `SHA256SUMS`, then

```
cat mountain.iso.part* > mountain.iso
sha256sum -c SHA256SUMS
```

On Windows (PowerShell, in the download folder): `cmd /c "copy /b mountain.iso.part* mountain.iso"`, then compare `(Get-FileHash mountain.iso).Hash` with the number in `SHA256SUMS`.

Write `mountain.iso` to a USB stick (Fedora Media Writer, Ventoy or `dd`) and boot it. On the disk screen tick **Encrypt my data** (recommended for laptops). With an NVIDIA GPU, install from this ISO, then do the `mountain-nvidia` rebase below.

**From an existing Fedora Atomic / Bazzite install (rebase).**

```
rpm-ostree rebase ostree-unverified-registry:ghcr.io/borisalv-marinov/mountain:latest
systemctl reboot
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/borisalv-marinov/mountain:latest
systemctl reboot
```

The first rebase installs the signing keys and policy; the second switches to the signed image. With an NVIDIA GPU use `mountain-nvidia` instead of `mountain` in both commands.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/borisalv-marinov/mountain
```
