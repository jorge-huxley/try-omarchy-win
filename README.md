# Try Omarchy on Windows

Run the upstream [Omarchy](https://github.com/basecamp/omarchy) desktop in a hardware-accelerated VM on Windows — no Linux setup.

Try Omarchy builds a reproducible x86_64 Arch Linux factory image containing a pinned revision of upstream Omarchy, then boots it locally under QEMU with Windows Hypervisor Platform.

Try Omarchy is not official or affiliated with Omarchy.

## Requirements

- Windows 10 or 11 on x64
- Virtualization enabled in your firmware (VT-x/AMD-V)
- The optional **Windows Hypervisor Platform** feature — enable it once with
  [`windows/enable-whpx.ps1`](windows/enable-whpx.ps1) from an elevated PowerShell, then reboot
- About 25 GB of free disk space
- Docker Desktop, only if you want to rebuild the image yourself

## Quick start

1. Enable WHPX, then reboot (one time):

   ```powershell
   powershell -File windows\enable-whpx.ps1
   ```

2. Install QEMU (one time):

   ```powershell
   winget install --id Software.QEMU
   ```

3. Build the factory image (first run downloads packages; expect tens of minutes):

   ```sh
   bash guest/build-container.sh
   ```

4. Boot Omarchy:

   ```powershell
   powershell -File windows\boot-omarchy.ps1
   ```

An SDL window opens, SDDM starts, and Omarchy's owner-provisioning form creates
your account on first boot. Later launches reuse the persistent disk under
`%LOCALAPPDATA%\TryOmarchy\VM\v1`.

## Development

See [`windows/README.md`](windows/README.md) for build, test, and boot details,
and [`guest/README.md`](guest/README.md) for the image pipeline contract.
[`docs/architecture.md`](docs/architecture.md) documents the stack and trust
model. The legacy macOS launcher under `macos/` is retained only as a porting
reference for the future native Windows launcher.

## Project status and support

Try Omarchy is pre-1.0 and under active development. It is an independent
open-source project and is not affiliated with or endorsed by Basecamp. Omarchy
and bundled dependencies retain their own licenses; see
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

Report ordinary bugs through [GitHub Issues](https://github.com/jorge-huxley/try-omarchy-win/issues). Report suspected vulnerabilities using the private process in [`SECURITY.md`](SECURITY.md), not a public issue.

Try Omarchy's original code is licensed under the [MIT License](LICENSE).

Derived from [@martiano](https://x.com/martiano)'s
[try-omarchy](https://github.com/themartiano/try-omarchy).
