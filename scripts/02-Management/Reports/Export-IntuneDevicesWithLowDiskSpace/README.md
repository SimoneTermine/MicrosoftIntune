# Export Microsoft Intune devices with low disk space

Export-IntuneDevicesWithLowDiskSpace.ps1 creates a CSV report of Windows devices managed by Microsoft Intune that have less free storage than a selected threshold. It uses Microsoft Graph managed-device inventory and also reports devices where storage data is unavailable.

## Report fields

The CSV includes device name, primary user UPN, manufacturer, model, serial number, Windows version, compliance state, last Intune sync time, free and total storage in GiB, free-space percentage, and a flag showing whether storage data was available.

The default threshold is 20 GiB. Devices below the threshold and devices without usable storage data are included.

## Requirements and permissions

- PowerShell with the Microsoft.Graph.Authentication module.
- Microsoft Graph delegated permission DeviceManagementManagedDevices.Read.All with consent.
- An Intune license and permission to read managed-device inventory.

The script prompts for Microsoft Graph sign-in when no Graph context is already active. An existing context must include the required permission.

## Run the report

    .Export-IntuneDevicesWithLowDiskSpace.ps1

Use a different free-space threshold and save to a chosen path:

    .Export-IntuneDevicesWithLowDiskSpace.ps1 -MinimumFreeSpaceGB 15 -OutputPath C:ReportsIntune-LowDiskSpace.csv

The script follows Graph pagination and reads all managed devices. It only exports Windows devices and makes no changes to Intune or the endpoints.

## Use the report

Review low-storage devices before feature updates, application deployments, or other operations that need temporary disk space. Treat the report as a starting point for triage; confirm free space on the device before cleaning files or changing deployment assignments.

## Limitations

- Storage values are reported by Intune managed-device inventory and may be missing or stale for devices that have not synced recently.
- This report uses GiB (1,073,741,824 bytes), not decimal GB.
- The script does not delete files, run Disk Cleanup, or remediate storage.
- Serial numbers and user names can be sensitive inventory data. Store and share the CSV according to your organization's data handling requirements.

## References

- Microsoft Graph: [List managedDevices](https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-list?view=graph-rest-1.0)
- Microsoft Graph: [managedDevice resource](https://learn.microsoft.com/en-us/graph/api/resources/intune-devices-manageddevice?view=graph-rest-1.0)
- Microsoft Learn: [Microsoft Graph permissions reference](https://learn.microsoft.com/en-us/graph/permissions-reference)
