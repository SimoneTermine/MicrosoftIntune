# Export stale Intune Windows devices

## Purpose

`Export-StaleIntuneDevices.ps1` reads the Windows managed-device inventory through Microsoft Graph and exports devices whose `lastSyncDateTime` is older than a configurable threshold. The report is intended to help administrators review stale records before lifecycle cleanup.

The script is read-only. It does not retire, wipe, delete, or update devices.

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7.
- Microsoft Graph PowerShell SDK with `Microsoft.Graph.DeviceManagement`.
- A work or school account with delegated `DeviceManagementManagedDevices.Read.All` permission and admin consent.
- An Intune-licensed tenant.

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

## Usage

```powershell
Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All'
./Export-StaleIntuneDevices.ps1 -DaysSinceLastSync 90 -OutputPath './output/stale-devices.csv'
./Export-StaleIntuneDevices.ps1 -DaysSinceLastSync 60 -IncludeNeverSynced
```

If no Graph session is active, the script requests the read scope and opens an interactive sign-in. The default threshold is 90 days; the default output is a timestamped CSV in the current directory.

## Review before cleanup

A device can be intentionally offline, shared, retired outside Intune, or re-enrolled under a different record. A stale check-in alone is not sufficient reason to remove a device. Confirm the device owner, last activity, Entra record, enrollment status, and organizational retention policy before taking action.

## References

- [List managedDevices (Microsoft Graph v1.0)](https://learn.microsoft.com/graph/api/intune-devices-manageddevice-list?view=graph-rest-1.0)
- [Get-MgDeviceManagementManagedDevice](https://learn.microsoft.com/powershell/module/microsoft.graph.devicemanagement/get-mgdevicemanagementmanageddevice)
