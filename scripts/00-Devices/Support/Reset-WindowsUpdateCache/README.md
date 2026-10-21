# Reset the Windows Update download cache with PowerShell

Reset-WindowsUpdateCache.ps1 is a manual Windows Update troubleshooting script for Windows 10 and Windows 11 devices. It renames the Windows Update Download cache so Windows can recreate it, which can help when update downloads are damaged or stuck.

## What the script changes

The script stops the Background Intelligent Transfer Service (BITS) and Windows Update service, renames only the SoftwareDistribution Download folder to a timestamped backup, creates a new empty Download folder, and restores services that were running before the operation.

It does not delete the backup, reset the catroot2 folder, remove Windows Update policy, or change service startup types. The DataStore folder is left in place.

## Run the script

Open an elevated 64-bit PowerShell session. Preview the operation first:

    ./Reset-WindowsUpdateCache.ps1 -WhatIf

When no Windows update is installing and you are ready to proceed:

    ./Reset-WindowsUpdateCache.ps1

The script uses PowerShell ShouldProcess with a high confirmation impact. Review the confirmation before allowing the cache rename.

## Prerequisites

- Windows 10 or Windows 11.
- Elevated administrator PowerShell.
- No update installation or servicing operation in progress.
- Enough free disk space to retain the renamed cache until the device has successfully scanned and downloaded updates again.

## After the reset

Trigger a Windows Update scan using your normal management workflow, such as Intune update policy, Windows Autopatch, or Configuration Manager. Confirm that the update downloads and installs before deleting the timestamped Download backup.

## Limitations and safety

- This is a targeted support action. Do not assign it as an automatic broad Intune remediation.
- Resetting the download cache requires update files to be downloaded again and can increase network usage.
- The script does not decide whether an update failure was caused by cache corruption.
- If a service cannot be stopped or restarted, review the warning and restore service health manually.
- Use the script only after collecting relevant Windows Update diagnostics and during a suitable maintenance window.

## References

- Microsoft Support: [Troubleshoot problems updating Windows](https://support.microsoft.com/en-us/windows/deployment/updates-lifecycle/troubleshoot-problems-updating-windows)
- Microsoft Learn: [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)
