# Export Intune Windows devices reported as unencrypted

Use this read-only Microsoft Graph PowerShell report to export Windows devices that Microsoft Intune currently reports with `isEncrypted = false`. It helps endpoint administrators build a BitLocker follow-up list and compare Intune device inventory with encryption policy, compliance, and deployment status.

By default, the CSV includes only devices reported as not encrypted. Add `-IncludeUnknown` to include Windows records where Graph returned no encryption value. The `isEncrypted` field is an Intune inventory signal; validate the actual BitLocker status and policy state on the device before taking action.

## Requirements

- PowerShell 5.1 or PowerShell 7.
- Microsoft Graph PowerShell modules `Microsoft.Graph.Authentication` and `Microsoft.Graph.DeviceManagement`.
- Delegated Microsoft Graph permission `DeviceManagementManagedDevices.Read.All`; tenant consent may be required.
- An account allowed to read managed devices in Intune.

Install the device-management module for the current user:

```powershell
Install-Module Microsoft.Graph.DeviceManagement -Scope CurrentUser
```

## Export the Intune encryption report

```powershell
./Export-UnencryptedWindowsDevices.ps1
```

Include records with unknown encryption state:

```powershell
./Export-UnencryptedWindowsDevices.ps1 -IncludeUnknown
```

Choose a CSV destination:

```powershell
./Export-UnencryptedWindowsDevices.ps1 -OutputPath 'C:\Reports\UnencryptedWindowsDevices.csv' -IncludeUnknown
```

The script connects to Microsoft Graph if needed, retrieves managed devices using Graph pagination, and writes a timestamped CSV in the current directory by default. It does not enable BitLocker, escrow recovery keys, alter compliance state, or update the Intune record.

## CSV fields

The report contains device name, OS version, encryption status, serial number, manufacturer, model, owner type, management agent, compliance state, last sync, and Intune/Entra device identifiers.

## Limitations

- A stale last sync can make the encryption value outdated; check `LastSyncDateTime` before acting.
- Intune's `isEncrypted` value is not a substitute for querying BitLocker locally with `Get-BitLockerVolume` or for checking recovery-key escrow.
- Unknown values are omitted unless `-IncludeUnknown` is used.
- The report includes Windows managed-device records only; it does not assess macOS or mobile devices.
- Review findings before remediation. Shared devices, provisioning devices, and recently enrolled endpoints can have expected transitional states.

## References

- [Get managedDevice with Microsoft Graph](https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-get?view=graph-rest-1.0)
- [Get-MgDeviceManagementManagedDevice](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.devicemanagement/get-mgdevicemanagementmanageddevice)
- [Microsoft Graph PowerShell authentication](https://learn.microsoft.com/en-us/powershell/microsoftgraph/authentication-commands)
- [BitLocker overview](https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/)
