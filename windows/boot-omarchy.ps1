# Boot the built Omarchy factory image under QEMU/WHPX.
# Usage: powershell -File windows\boot-omarchy.ps1 [-Ephemeral] [-ResetStorage]
param(
  [string]$GuestDir = (Join-Path $PSScriptRoot "..\dist\guest"),
  [string]$DiskDir = (Join-Path $env:LOCALAPPDATA "TryOmarchy\VM\v1"),
  [switch]$Ephemeral,
  [switch]$ResetStorage
)
$ErrorActionPreference = "Stop"

$qemu = Get-Command qemu-system-x86_64.exe -ErrorAction SilentlyContinue
if (-not $qemu) { $qemuPath = Join-Path $env:ProgramFiles "qemu\qemu-system-x86_64.exe" } else { $qemuPath = $qemu.Source }
if (-not (Test-Path $qemuPath)) { throw "qemu-system-x86_64.exe not found; install QEMU (winget install Software.QEMU)" }

$spec = Get-Content (Join-Path $GuestDir "build-spec.json") | ConvertFrom-Json
$kernelCmdline = $spec.runtime.kernelCommandLine -replace "console=hvc0", "console=ttyS0 console=tty1"
$expandedMiB = $spec.runtime.storage.expandedSizeMiB

if ($ResetStorage -and (Test-Path $DiskDir)) {
  $answer = Read-Host "Delete persistent VM state at $DiskDir? Type RESET to confirm"
  if ($answer -ne "RESET") { throw "reset aborted" }
  Remove-Item -Recurse -Force $DiskDir
}

$tmp = $null
try {
  if ($Ephemeral) {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("try-omarchy-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $diskPath = Join-Path $tmp "disk.raw"
  } else {
    New-Item -ItemType Directory -Force -Path $DiskDir | Out-Null
    $diskPath = Join-Path $DiskDir "disk.raw"
  }
  if (-not (Test-Path $diskPath)) {
    Copy-Item (Join-Path $GuestDir "rootfs.ext4") $diskPath   # full copy: NTFS has no clonefile
    fsutil sparse setflag $diskPath | Out-Null   # allocate on write; hosts without 24 GiB spare still boot
    $fs = [IO.File]::Open($diskPath, "Open", "ReadWrite")
    try { $fs.SetLength([int64]$expandedMiB * 1MB) } finally { $fs.Dispose() }
    Write-Host "Prepared writable disk: $diskPath"
  }

  & $qemuPath `
    -accel whpx `
    -machine q35 -cpu qemu64 -smp 4 -m 4096 `
    -drive "file=$diskPath,format=raw,if=virtio" `
    -kernel (Join-Path $GuestDir "vmlinuz-linux") `
    -initrd (Join-Path $GuestDir "initramfs-linux.img") `
    -serial "file=$(Join-Path $DiskDir 'serial.log')" `
    -append $kernelCmdline `
    -device virtio-gpu-pci `
    -device virtio-keyboard-pci -device virtio-tablet-pci `
    -device virtio-net-pci,netdev=n0 -netdev user,id=n0 `
    -device virtio-rng-pci -device virtio-balloon-pci `
    -device intel-hda -device "hda-duplex,audiodev=snd" -audiodev dsound,id=snd `
    -display sdl,gl=off
} finally {
  if ($tmp -and (Test-Path $tmp)) { Remove-Item -Recurse -Force $tmp }
}
