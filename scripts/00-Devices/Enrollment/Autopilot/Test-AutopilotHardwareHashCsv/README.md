# Validate a Windows Autopilot hardware hash CSV before Intune import

Use this PowerShell script to validate a Windows Autopilot hardware hash CSV before uploading it to Microsoft Intune. It checks required columns, device serial numbers, duplicate entries, and Base64 hardware hash values.

This offline Autopilot CSV validator helps catch common formatting issues before importing devices into Windows Autopilot. The generated report includes the source row number, serial number, validation result, and findings. It never copies hardware hash values into the report.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7.
- A Windows Autopilot CSV file from your hardware provider or approved collection process.
- Read access to the CSV and write access to the report destination.

Required CSV headers are Device Serial Number and Hardware Hash. Additional columns, such as Windows Product ID, Group Tag, and Assigned User, are allowed.

## Run the Autopilot CSV validation

    .\Test-AutopilotHardwareHashCsv.ps1 -CsvPath .\AutopilotDevices.csv

Choose a report path:

    .\Test-AutopilotHardwareHashCsv.ps1 -CsvPath .\AutopilotDevices.csv -OutputPath .\Reports\AutopilotCsvValidation.csv

By default, the report is written beside the source file with the suffix .validation.csv. The script returns exit code 0 when every row passes and exit code 1 when it finds errors or cannot validate the file. This supports a pre-import check in a packaging or deployment workflow.

## Validation checks

- Required CSV columns are present.
- Device Serial Number is not blank.
- Serial numbers are unique within the file, ignoring letter case.
- Hardware Hash is populated and can be decoded as Base64.

The script does not contact Microsoft Graph, upload the CSV, modify the source file, check whether a serial number is already registered in your tenant, or determine whether a Group Tag matches your dynamic group rules.

## Security and handling

Windows Autopilot hardware hashes are sensitive device enrollment data. Protect the source CSV and delete it according to your organization’s data handling policy after import. The validation report intentionally omits the hash value.

## References

- [Windows Autopilot device registration overview](https://learn.microsoft.com/en-us/autopilot/registration-overview)
- [Windows Autopilot device import and CSV requirements](https://learn.microsoft.com/en-us/autopilot/add-devices)
