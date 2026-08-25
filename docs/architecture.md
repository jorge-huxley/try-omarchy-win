# Architecture

This fork retargets Try Omarchy to Windows. Two pieces exist today:

1. A reproducible x86_64 Arch Linux image containing pinned upstream Omarchy source.
2. QEMU boot scripts that run that image under Windows Hypervisor Platform.

A native Windows launcher is planned; until it lands, PowerShell scripts drive
QEMU directly. The macOS Swift/AppKit launcher remains under `macos/` untouched
as the porting reference for that work.

```text
windows\boot-omarchy.ps1
└── QEMU + Windows Hypervisor Platform
    └── project-built x86_64 Linux image
        └── Omarchy desktop
```

## What happens when the boot script runs

The script prepares a writable copy of the factory disk — a full copy, because
NTFS has no clonefile — expands it to its working size, and starts
`qemu-system-x86_64`. Because both the host CPU and the guest are x86_64,
Windows Hypervisor Platform runs the guest CPU instructions natively. QEMU
provides the virtual devices around that CPU.

Linux then boots normally from the bundled kernel and disk, and Omarchy runs
inside Linux. Graphics travel from Linux through virtio-gpu to the SDL window,
rendered in the guest by llvmpipe software OpenGL. Storage uses virtio-blk,
networking uses user-mode slirp, audio uses the QEMU intel-hda controller with
an hda-duplex codec backed by the DirectSound host audio device, and input uses
virtio keyboard and tablet devices.

## The x86_64 image

The guest image is built by this project; it is not an official prebuilt image
from Basecamp. The `guest/` builder starts with pinned official Arch Linux
packages plus Omarchy's signed stable repository, installs a pinned upstream
Omarchy source tree, and adds the small configuration layer needed for QEMU.

The result is upstream Omarchy running in a project-built x86_64 Linux image.
The image has no preconfigured user, so Omarchy's upstream owner-provisioning
flow creates the account on first boot.

## What this project changes

- The pinned Omarchy runtime trees are copied from upstream. Guest overlays add
  the QEMU integration around them: a Hyprland monitor fragment guarded by the
  `omarchy.qemu=1` kernel option, and a small display-sync daemon that keeps the
  guest mode synchronized when QEMU changes the virtual EDID.
- macOS-only pieces are removed rather than ported: the native PipeWire
  audio bridge (Windows audio is handled entirely by QEMU's DirectSound
  backend) and the ARM binary-compatibility layer (both host and guest are
  x86_64).

Nothing is overwritten while the VM runs. The packaged factory disk remains
unchanged. Normal launches use one private writable disk under
`%LOCALAPPDATA%\TryOmarchy\VM\v1`; its factory-image identity is immutable —
the boot scripts never pair a saved root filesystem with a different bundled
kernel or initramfs. When a guest build changes identity, removing that disk is
an explicitly confirmed action: `-ResetStorage` demands typing `RESET` before
deleting it. Ephemeral mode (`-Ephemeral`) uses a disposable disk. The future
native launcher will enforce the same confirmed-reset contract automatically.

## Build layout

- `guest/` reproducibly assembles the unprovisioned x86_64 image in a privileged
  AMD64 Docker container. Inputs are commit-, version-, and checksum-pinned.
- `windows/` enables Windows Hypervisor Platform and encodes the QEMU device
  model that mirrors the spec's runtime section.
- `macos/` is the frozen macOS launcher, kept as the reference for the future
  native Windows launcher.
- `dist/` is the only public output directory. It is generated and ignored by
  Git.

## Trust model

The app validates the exact guest file set, JSON schemas, hashes, sizes, pinned
upstream identity, runtime contract, kernel command line, architecture, and
factory profile before QEMU starts. It also verifies the app signature and
required QEMU features. Updates to a pinned dependency should update its digest,
contract tests, notices, and review evidence together.
