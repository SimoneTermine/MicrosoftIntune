# Windows laptop battery health custom compliance for Microsoft Intune

Use this PowerShell custom compliance script to report Windows laptop battery health in Microsoft Intune. It compares the battery's current full-charge capacity with its designed capacity and returns a JSON value that Intune can evaluate against a configurable threshold.

## What the battery health script reports

Get-BatteryHealth.ps1 reads the Windows battery WMI classes BatteryStaticData and BatteryFullChargedCapacity. It reports the calculated battery health percentage, the capacity values, and whether Windows returned usable data. The script is read-only and does not change power settings or device state.

Battery health percentage is calculated as full-charge capacity divided by designed capacity, multiplied by 100. It is a capacity estimate reported by the battery provider; it is not a runtime or battery-cycle prediction.

## Files

- Get-BatteryHealth.ps1 — Intune custom compliance discovery script.
- BatteryHealth-Compliance.json — sample Intune compliance rules with a 70% battery health threshold.

## Configure in Intune

1. In the Intune admin center, create a Windows custom compliance policy and upload Get-BatteryHealth.ps1 as the discovery script.
2. Upload BatteryHealth-Compliance.json as the compliance rules file.
3. Assign the policy to a pilot group containing battery-powered Windows devices.
4. Review the reported BatteryHealthPercent and QuerySucceeded values before using the 70% threshold for production decisions.

Do not assign this policy to desktops or devices without a supported battery. A missing battery or unavailable WMI data returns QuerySucceeded as false and is treated as noncompliant by the sample rules.

## Output properties

| Property | Meaning |
|---|---|
| BatteryHealthPercent | Current full-charge capacity as a percentage of designed capacity. |
| QuerySucceeded | True when Windows returned capacity data that could be evaluated. |
| BatteryPresent | Indicates whether the battery WMI provider returned battery data. |
| DesignedCapacityWh | Sum of designed battery capacity, converted from mWh to Wh. |
| FullChargeCapacityWh | Sum of current full-charge capacity, converted from mWh to Wh. |
| ErrorMessage | Short diagnostic detail when the query could not be completed. |

## Adjust the threshold

The sample JSON marks a device compliant when BatteryHealthPercent is at least 70. Change the Operand value in BatteryHealth-Compliance.json to match your hardware lifecycle policy, then pilot the policy before broad assignment. The JSON also requires QuerySucceeded to be true.

## Limitations

- Battery reporting depends on the device firmware and Windows battery WMI provider.
- A device with multiple batteries is evaluated using total designed and full-charge capacity.
- Capacity readings can vary by firmware and battery calibration.
- The script reports battery capacity only. It does not identify a battery fault, predict remaining service life, or trigger a repair.
- Review the output on representative device models before using the result for warranty or replacement decisions.

## References

- Microsoft Learn: [Use custom compliance settings for Windows devices in Intune](https://learn.microsoft.com/en-us/intune/protect/compliance-use-custom-settings)
- Microsoft Learn: [Windows battery full-charge capacity structure](https://learn.microsoft.com/en-us/windows/win32/api/batclass/ns-batclass-battery_wmi_full_charged_capacity)
- Microsoft Learn: [Windows battery static data structure](https://learn.microsoft.com/en-us/windows/win32/api/batclass/ns-batclass-battery_wmi_static_data)
