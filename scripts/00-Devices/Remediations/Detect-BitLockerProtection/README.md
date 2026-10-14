# Detect BitLocker protection state

## Purpose

This detection-only script reports whether the Windows operating-system volume is fully encrypted and BitLocker protection is on. It returns only state information; it does not read, print, or export recovery passwords.

The script does not enable encryption or change key protectors. Encryption and recovery-key escrow depend on tenant policy, hardware readiness, and the organization's recovery process, so remediation should be designed separately.

## Intune configuration

Create a detection-only Remediations package and upload `Detect-BitLockerProtection.ps1`. Run in 64-bit PowerShell as `SYSTEM`. The script exits `0` when the OS volume is fully encrypted and protection is on; otherwise it exits `1` and includes the observed volume state.

## Prerequisites and limitations

- Windows 10 or Windows 11 with the BitLocker PowerShell feature available.
- The BitLocker PowerShell module must expose `Get-BitLockerVolume`.
- This checks only `$env:SystemDrive`; it does not inspect data volumes.
- A state other than fully encrypted/protection on is a review signal and may be expected during provisioning, maintenance, or recovery.
- It does not confirm that the recovery key is escrowed in Microsoft Entra ID or Active Directory.
- Test on representative hardware before using the results as a compliance control.

## References

- [Get-BitLockerVolume](https://learn.microsoft.com/powershell/module/bitlocker/get-bitlockervolume)
- [BitLocker overview](https://learn.microsoft.com/windows/security/operating-system-security/data-protection/bitlocker/)
