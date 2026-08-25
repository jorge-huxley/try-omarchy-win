# Windows bring-up

Prerequisites:

1. Enable Windows Hypervisor Platform once from an elevated PowerShell, then
   reboot:

   ```powershell
   powershell -File windows\enable-whpx.ps1
   ```

2. Install QEMU:

   ```powershell
   winget install --id Software.QEMU
   ```

3. Docker Desktop is only needed when rebuilding the guest image.

Build the factory image (the first run pulls the pinned Arch Linux builder
image and downloads packages; expect tens of minutes):

```sh
bash guest/build-container.sh
```

Run the guest contract tests:

```sh
bash guest/test
```

Boot the built image:

```powershell
powershell -File windows\boot-omarchy.ps1
```

Flags:

- `-Ephemeral` — boot a disposable temporary disk copy; state is discarded on exit.
- `-ResetStorage` — delete `%LOCALAPPDATA%\TryOmarchy\VM\v1` after typing `RESET`;
  the next boot re-runs first-boot provisioning.

Persistent VM data lives at `%LOCALAPPDATA%\TryOmarchy\VM\v1`.

Limitation: graphics render on CPU (llvmpipe); video playback is slow.
