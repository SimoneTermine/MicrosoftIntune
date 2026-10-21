# Export Intune app installation failures by device

Use this read-only PowerShell report to investigate Microsoft Intune app installation failures. It exports device-level app installation status from Microsoft Graph, then filters the report for failed or error states. The CSV includes app ID and version, device name and ID, installation state and detail, error code, last modified time, and user information when available.

The Intune app install failure report helps endpoint administrators identify which devices failed an app deployment and compare returned error codes across the fleet.

## Requirements and permissions

- PowerShell 5.1 or PowerShell 7.
- Microsoft.Graph.Authentication PowerShell module.
- Delegated Microsoft Graph permission DeviceManagementApps.Read.All. Tenant consent and Intune RBAC access may be required.
- An active Intune license and access to Microsoft Graph.

Install the authentication module:

    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser

## Run the Intune app installation failure report

    .\Export-IntuneAppInstallFailures.ps1

Export every installation state for troubleshooting:

    .\Export-IntuneAppInstallFailures.ps1 -IncludeAllStatuses

Choose the CSV destination:

    .\Export-IntuneAppInstallFailures.ps1 -OutputPath C:\Reports\IntuneAppFailures.csv -TimeoutSeconds 900

The script requests the OrgDeviceInstallStatus report from the Intune Graph export API, waits for the export job to finish, downloads the temporary archive, and writes matching rows to CSV. Temporary report files are removed after the CSV is created.

## Important scope notes

- The OrgDeviceInstallStatus report covers Intune app installation statuses by device; it is not limited to Win32 apps. The script reports states returned by Intune and does not retry, reinstall, or remediate applications.
- Intune report data can lag behind a device’s current state.
- It uses device-level installation status. Review the Intune admin center and client logs before changing deployments.
- The CSV may contain user principal names, device identifiers, app deployment details, and error codes. Handle it as operational data.
- The report uses the Microsoft Graph beta export endpoint, which Microsoft may change.

## References

- [Intune reports and properties available using Microsoft Graph](https://learn.microsoft.com/en-us/intune/device-management/reports/ref-graph-available-reports)
- [Export Intune reports using Microsoft Graph APIs](https://learn.microsoft.com/en-us/intune/device-management/reports/export-graph-apis)
