# Intune custom compliance: check Windows system drive free space

Use this Microsoft Intune custom compliance discovery script to report the free space on a Windows device's system drive. It returns the free capacity in GiB as compact JSON, making it available to an Intune custom compliance policy and device compliance reporting.

The example compliance rule uses a **15 GiB** minimum. Set the threshold to match your Windows update, feature update, application deployment, and recovery requirements before assigning the policy. The script only reads drive capacity; it does not remove temporary files, empty folders, or otherwise free disk space.

## Files

- `Get-SystemDriveFreeSpace.ps1` — Windows PowerShell discovery script for Intune custom compliance.
- `SystemDriveFreeSpace-Compliance.json` — sample JSON rules for a minimum free-space threshold and a successful query.

## Example output

```json
{"SystemDriveFreeSpaceGiB":42.18,"SystemDrive":"C:","QuerySucceeded":true}
```

If the system drive cannot be queried, the script reports `QuerySucceeded` as `false`; the policy's second rule then marks the setting noncompliant instead of treating the failed query as sufficient free space.

## Configure in Microsoft Intune

1. In the Intune admin center, upload `Get-SystemDriveFreeSpace.ps1` as a Windows custom compliance discovery script.
2. Configure the script to run as **SYSTEM** and in the **64-bit PowerShell host**.
3. Create a Windows compliance policy and select this discovery script.
4. Upload `SystemDriveFreeSpace-Compliance.json` when prompted for the custom compliance rules.
5. Review the example 15 GiB threshold and remediation message. Pilot the policy before assigning it broadly.

Each discovery script can be selected by one custom compliance policy. If you need separate policy assignments or thresholds, create a copy of the discovery script and JSON with distinct setting names.

## Requirements and limitations

- Windows 10 or Windows 11 enrolled and reporting to Microsoft Intune.
- The device must be able to run PowerShell and query `Win32_LogicalDisk`.
- The threshold is an example, not a universal Windows servicing requirement.
- Compliance status can affect Conditional Access access decisions. Validate assignments, grace periods, and user messaging before enforcing access controls.
- The script does not clean up disk space or confirm whether a future Windows feature update will fit.

## References

- [Create discovery scripts for custom compliance in Microsoft Intune](https://learn.microsoft.com/en-us/intune/device-security/compliance/create-custom-script)
- [Create a JSON file for custom compliance settings in Microsoft Intune](https://learn.microsoft.com/en-us/intune/device-security/compliance/create-custom-json)
- [Use custom compliance settings in Microsoft Intune](https://learn.microsoft.com/en-us/intune/device-security/compliance/use-custom-compliance-settings)
