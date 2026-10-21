# Export Windows Autopilot deployment failures from Intune

Export failed Windows Autopilot deployment records from Microsoft Intune to a CSV report. This read-only PowerShell script uses the Microsoft Graph Intune reporting export API to collect deployment state, Autopilot profile, device name and serial number, Enrollment Status Page status, failure reason, and related deployment details.

Use the report to investigate Windows Autopilot enrollment failures and identify devices that need follow-up. By default, the script keeps records with a failure or error state, or populated failure details. Use the IncludeAllDeployments switch to export every row returned by the Autopilot V1 deployment status report.

## Requirements and permissions

- PowerShell 5.1 or PowerShell 7.
- Microsoft.Graph.Authentication PowerShell module.
- Delegated Microsoft Graph permissions DeviceManagementConfiguration.Read.All and DeviceManagementManagedDevices.Read.All. Tenant consent and Intune RBAC access may be required.
- An active Intune license and access to Microsoft Graph.

Install the authentication module:

    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser

## Run the Autopilot deployment failure report

    .\Export-AutopilotDeploymentFailures.ps1

Export all deployment rows instead of failures only:

    .\Export-AutopilotDeploymentFailures.ps1 -IncludeAllDeployments

Set an output file and report timeout:

    .\Export-AutopilotDeploymentFailures.ps1 -OutputPath C:\Reports\AutopilotFailures.csv -TimeoutSeconds 900

The script creates an Intune report export job, waits for completion, downloads the temporary report archive, and writes the selected deployment records to CSV. It removes its temporary download after saving the CSV.

## Scope and limitations

This script uses the Autopilot V1 deployment status report. It reports deployment activity available in Intune; it is not a pre-import validator and does not prove that a device without a deployment row is ready or assigned a profile. Report freshness and returned properties depend on Intune reporting data.

The CSV can contain device identifiers, serial numbers, user principal names, and deployment failure details. Store and share it according to your organization’s data handling policy. The script does not change Autopilot profiles, assignments, devices, or enrollment state.

## References

- [Intune reports and properties available using Microsoft Graph](https://learn.microsoft.com/en-us/intune/device-management/reports/ref-graph-available-reports)
- [Export Intune reports using Microsoft Graph APIs](https://learn.microsoft.com/en-us/intune/device-management/reports/export-graph-apis)
- [Windows Autopilot deployment overview](https://learn.microsoft.com/en-us/autopilot/overview)
