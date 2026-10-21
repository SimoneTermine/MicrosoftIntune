# Export Intune noncompliant devices and settings to CSV

Export Microsoft Intune noncompliant device settings, policy names, operating system details, status, and error codes to a CSV file with this read-only PowerShell script. The report is useful when an Intune compliance summary shows affected devices but administrators need the setting-level reason behind each noncompliant result.

The script uses the Microsoft Graph Intune export API and the NoncompliantDevicesAndSettingsV3 report.

## Requirements and permissions

- PowerShell 5.1 or PowerShell 7.
- Microsoft.Graph.Authentication PowerShell module.
- Delegated Microsoft Graph permissions DeviceManagementConfiguration.Read.All and DeviceManagementManagedDevices.Read.All. Tenant consent and Intune RBAC access may be required.
- An active Intune license and connectivity to Microsoft Graph.

Install the authentication module:

    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser

## Run the Intune compliance report

    .\Export-IntuneNoncompliantSettings.ps1

Choose a CSV destination:

    .\Export-IntuneNoncompliantSettings.ps1 -OutputPath C:\Reports\NoncompliantSettings.csv -TimeoutSeconds 900

The script creates a report export job, waits for completion, downloads the temporary archive, and saves the CSV. Temporary report files are deleted after export.

## CSV fields

The report includes device ID and name, OS and OS version, compliance policy, setting name, setting status, error code, and UPN when returned by Intune. The exact values and report freshness depend on the Intune reporting service.

## Limitations and data handling

- This is a report of Intune’s current reporting data; it does not query devices directly or correct compliance issues.
- Some report columns may be empty depending on policy type or reporting state.
- Review the reported policy and setting in Intune before changing assignments or device configuration.
- The CSV can contain usernames, device identifiers, policy details, and security posture. Store and share it accordingly.
- The script uses the Microsoft Graph beta export endpoint, which may change.

## References

- [Intune reports and properties available using Microsoft Graph](https://learn.microsoft.com/en-us/intune/device-management/reports/ref-graph-available-reports)
- [Export Intune reports using Microsoft Graph APIs](https://learn.microsoft.com/en-us/intune/device-management/reports/export-graph-apis)
- [View Microsoft Intune reports](https://learn.microsoft.com/en-us/intune/device-management/reports/overview)
