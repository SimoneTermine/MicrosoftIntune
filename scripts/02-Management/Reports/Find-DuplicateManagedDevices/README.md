# Find possible duplicate Intune managed devices

## Purpose

`Find-DuplicateManagedDevices.ps1` creates a CSV of Windows managed-device records that share the same non-empty serial number. The `MostRecentlySyncedRecord` column highlights the record with the latest reported sync time as a review aid.

This is a candidate report. It does not delete, retire, wipe, or update any device.

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7.
- Microsoft Graph PowerShell SDK, including `Microsoft.Graph.DeviceManagement`.
- A work or school account with delegated `DeviceManagementManagedDevices.Read.All` permission and the required admin consent.
- An Intune-licensed tenant.

Install the SDK if needed:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

## Run

```powershell
Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All'
./Find-DuplicateManagedDevices.ps1 -OutputPath './output/possible-duplicates.csv'
```

If no Graph session is active, the script requests the read scope and opens an interactive sign-in. The default output is a timestamped CSV in the current directory. Use `-Verbose` for progress detail.

## Review before cleanup

Serial numbers can be missing, duplicated by a hardware vendor, or reused after a motherboard replacement. A newer sync timestamp is only a hint. Compare each record's Intune and Entra device IDs, enrollment dates, primary user, compliance state, and recent check-in before deciding what to do. Use the Intune admin center's supported device actions for any eventual cleanup.

## References

- [List managedDevices (Microsoft Graph v1.0)](https://learn.microsoft.com/graph/api/intune-devices-manageddevice-list?view=graph-rest-1.0)
- [Get-MgDeviceManagementManagedDevice](https://learn.microsoft.com/powershell/module/microsoft.graph.devicemanagement/get-mgdevicemanagementmanageddevice)
