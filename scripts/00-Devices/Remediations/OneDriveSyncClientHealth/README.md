# Microsoft Intune OneDrive sync client health remediation

This Microsoft Intune Remediations package checks whether the OneDrive sync client is running for a signed-in Windows user and starts it when it has stopped. It is intended for devices where OneDrive is already configured for the current user.

## Files

- Detect-OneDriveSyncClient.ps1 — detects a configured OneDrive account whose sync client process is not running.
- Remediate-OneDriveSyncClient.ps1 — starts OneDrive.exe in the current user session when needed.

The package does not install OneDrive, configure a sync account, resume paused syncing, or repair a sync error.

## Configure the Intune remediation

1. In the Intune admin center, go to Devices > Manage devices > Scripts and remediations and create a remediation package.
2. Upload Detect-OneDriveSyncClient.ps1 as the detection script and Remediate-OneDriveSyncClient.ps1 as the remediation script.
3. Set Run this script using the logged-on credentials to Yes.
4. Select 64-bit PowerShell and assign the package to a pilot group of Windows user devices.
5. Review detection and remediation output before expanding the assignment.

The user-context setting is required because the package checks the current user's OneDrive account registry and starts the sync client in that user's session. This design is intended for interactive endpoints; validate behavior before assigning to shared or multi-session devices.

## Detection and remediation results

- No detection output and exit code 0: OneDrive is already running, or no OneDrive account is configured for the current user.
- JSON result with OneDriveNotRunning and exit code 1: a configured account was found, but the OneDrive process was not running in the current session.
- Remediation output confirms that OneDrive started: the process was launched and remained present for the brief verification interval.
- RemediationFailed: the configured client could not be started. Review the output, installation paths, and user sign-in state.
- UnsupportedContext: the package is running as SYSTEM. Change the Intune package setting to run using logged-on credentials.

## What the package checks

Detection looks for account keys under the current user's OneDrive Accounts registry key and checks for OneDrive.exe in the current Windows session. The remediation searches standard per-user and machine installation paths, then starts the client in the background.

## Limitations

- A running process does not prove that files are syncing successfully or that the client is signed in.
- A paused client, sync error, blocked file, or network issue is outside the scope of this check.
- The script does not restart OneDrive when the process is already present.
- Intune user-context remediations run in the context available to the agent. Test shared and multi-session scenarios before deployment.
- Use a pilot assignment and a reasonable schedule to avoid repeated process launches during user troubleshooting.

## References

- Microsoft Learn: [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)
- Microsoft Support: [OneDrive sync problems](https://support.microsoft.com/en-us/office/fix-onedrive-sync-problems)
