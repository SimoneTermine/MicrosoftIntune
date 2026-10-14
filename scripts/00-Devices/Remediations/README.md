# Intune Management Extension service health

## Purpose

This Remediations package checks the Windows service used by the Intune Management Extension (IME). If the service is stopped, the remediation starts it and waits up to 20 seconds for it to enter the `Running` state. A running service is left alone.

If the service is missing, detection reports an issue and remediation reports a failure. The scripts do not install or repair the IME. Investigate enrollment and IME installation separately.

## Files

- `Detect-IMEService.ps1`: exits `0` when the service is running and `1` otherwise.
- `Remediate-IMEService.ps1`: starts a stopped service, then verifies its state.

## Intune configuration

Create a script package under **Devices > Manage devices > Scripts and remediations** and upload the two files. Run the scripts in the 64-bit PowerShell host and as `SYSTEM` (do not run them with the signed-in user's credentials). Configure signature enforcement to match your organization's policy. Use a pilot assignment before broad deployment.

The remediation runs only when detection exits with code `1`. Remediations require an eligible Windows/Intune license and supported enrollment; check the current Microsoft documentation for tenant prerequisites.

## Scope and limitations

- The scripts only check and start the `IntuneManagementExtension` Windows service.
- They do not confirm that the device can reach Intune or that policy processing is healthy.
- Starting the service may initiate normal IME activity and policy processing.
- A failure to start the service should be investigated through IME logs and Windows service events.
- Test in a lab or pilot group before production.

## References

- [Use Remediations to detect and fix support issues](https://learn.microsoft.com/intune/device-management/tools/deploy-remediations)
- [Intune Management Extension for Windows](https://learn.microsoft.com/intune/apps/intune-management-extension)
