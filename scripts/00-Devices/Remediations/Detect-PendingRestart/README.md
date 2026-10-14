# Detect a pending Windows restart

## Purpose

This detection-only script checks three common Windows indicators: Component Based Servicing, Windows Update, and pending file rename operations. It prints the indicators it finds so the result can help explain why Windows or an application is asking for a restart.

The script does not restart the device, remove registry values, or claim that a restart is always required. These registry indicators can remain after a restart or be set by software that has its own restart behavior.

## Files

- `Detect-PendingRestart.ps1`: detection-only Intune Remediations script.

## Intune configuration

Create a Remediations package and upload the detection script. A remediation script is not required for a detection-only package. Run it as `SYSTEM` in 64-bit PowerShell. The script exits `1` when it finds an indicator and `0` when none are found; Intune uses the detection exit code to determine whether the issue was found.

## Validation and limitations

- Test on Windows 10 and Windows 11 devices before assigning broadly.
- This is a diagnostic signal, not an authoritative Windows Update status API.
- The script does not tell you which specific application set a pending operation.
- An error reading the indicators is reported as an issue so it is visible for investigation.
- Do not add automatic restart logic without a separate user-impact and maintenance-window design.

## References

- [Use Remediations to detect and fix support issues](https://learn.microsoft.com/intune/device-management/tools/deploy-remediations)
