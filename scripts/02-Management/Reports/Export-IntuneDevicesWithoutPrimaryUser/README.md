# Export Intune Windows devices without a primary user

This read-only Microsoft Graph PowerShell report exports Windows devices managed by Microsoft Intune that have no associated primary user. Use it to find devices to review in the Intune admin center, including enrollment records that may need an owner association. Shared, kiosk, lab, and self-deploying devices can correctly have no primary user, so an empty association is a review finding rather than an automatic error.

The CSV includes device name, Windows version, serial number, manufacturer, model, enrollment type, management agent, compliance state, last Intune sync, and Intune/Entra device identifiers.

## Requirements

- PowerShell 5.1 or PowerShell 7.
- Microsoft Graph PowerShell modules `Microsoft.Graph.Authentication` and `Microsoft.Graph.DeviceManagement`.
- Delegated Microsoft Graph permission `DeviceManagementManagedDevices.Read.All`; tenant consent may be required.
- An account allowed to read managed devices in Intune.

Install the device-management module for the current user:

```powershell
Install-Module Microsoft.Graph.DeviceManagement -Scope CurrentUser
```

## Run the Intune primary user report

Run the script interactively. It connects to Microsoft Graph when no Graph session exists and requests the read-only scope above.

```powershell
./Export-IntuneDevicesWithoutPrimaryUser.ps1
```

To choose the CSV location:

```powershell
./Export-IntuneDevicesWithoutPrimaryUser.ps1 -OutputPath 'C:\Reports\DevicesWithoutPrimaryUser.csv'
```

The report queries all managed devices with Graph pagination, then filters for Windows devices with both `userId` and `userPrincipalName` empty. It does not modify device records or assign a primary user.

## Review the results

Check each record against your enrollment design before changing the primary user association. Shared and kiosk PCs, Windows Autopilot self-deploying deployments, and staging devices may not have a dedicated user. Devices with stale check-in dates or duplicate records may also need separate cleanup analysis.

## Limitations

- The report reflects Microsoft Graph's current Intune managed-device data and the account's read permissions.
- It treats a record as unassociated only when both `userId` and `userPrincipalName` are empty.
- It does not determine whether a missing association is intentional, stale, or incorrect.
- It does not remove devices or change primary-user relationships.
- Test access and CSV output with a small tenant or lab account before operational use.

## References

- [Get managedDevice with Microsoft Graph](https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-get?view=graph-rest-1.0)
- [Get-MgDeviceManagementManagedDevice](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.devicemanagement/get-mgdevicemanagementmanageddevice)
- [Microsoft Graph PowerShell authentication](https://learn.microsoft.com/en-us/powershell/microsoftgraph/authentication-commands)
