# Run once from an elevated PowerShell. Reboot required.
dism /online /enable-feature /featurename:HypervisorPlatform /all /norestart
Write-Host "Windows Hypervisor Platform enabling; REBOOT to finish."
