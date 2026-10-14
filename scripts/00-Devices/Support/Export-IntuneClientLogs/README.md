# Export Intune client logs

## Purpose

`Export-IntuneClientLogs.ps1` creates a local ZIP support bundle containing the Intune Management Extension log files and `dsregcmd /status` output. An optional switch exports the Device Management Enterprise Diagnostics Provider Admin event log.

The bundle is created on the device and is not uploaded or sent anywhere by the script.

## Prerequisites

- Windows 10 or Windows 11.
- Windows PowerShell 5.1 or later.
- Local administrator or `SYSTEM` rights to read event logs and the IME log folder.
- Sufficient free space in the output directory.

## Usage

Run from an elevated PowerShell session:

```powershell
./Export-IntuneClientLogs.ps1
./Export-IntuneClientLogs.ps1 -IncludeDeviceManagementEventLog
./Export-IntuneClientLogs.ps1 -OutputDirectory 'C:\Temp\IntuneLogs' -IncludeDeviceManagementEventLog
```

The default output directory is `C:\ProgramData\IntuneSupportBundles`. Each run creates a timestamped ZIP. The script can also run as an Intune device script, but it is intended primarily for support collection on a specific device.

## Data handling

Logs and `dsregcmd /status` can contain tenant identifiers, device identifiers, user names, configuration details, and timestamps. Review the ZIP before sharing it, follow your organization's support-data retention rules, and delete the bundle when it is no longer needed. The optional event log may contain additional user and device information.

## Limitations

- The script collects local logs only; it does not retrieve Intune service-side diagnostics.
- It does not run the Microsoft MDM diagnostic tool or create an MDM diagnostic CAB.
- A missing IME folder is recorded in the bundle and does not by itself stop collection.
