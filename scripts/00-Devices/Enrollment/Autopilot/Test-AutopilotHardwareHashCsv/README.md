# Validate a Windows Autopilot hardware hash CSV before Intune import

Use this PowerShell script to validate a Windows Autopilot hardware hash CSV before uploading it to Microsoft Intune. It checks the exact Windows Autopilot CSV header, row format, manual import limit, device serial numbers, duplicate serial numbers and hardware hashes, and Base64 hardware hash values.

This offline Autopilot CSV validator helps catch common formatting issues before importing devices into Windows Autopilot. The generated report includes the source row number, serial number, validation result, and findings. It never copies hardware hash values into the report.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7.
- A Windows Autopilot CSV file from your hardware provider or approved collection process.
- Read access to the CSV and write access to the report destination.

The required header is exactly `Device Serial Number,Windows Product ID,Hardware Hash,Group Tag,Assigned User` in that order and case. The manual import file supports up to 500 device rows. Windows Product ID, Group Tag, and Assigned User values can be blank when appropriate, but additional or missing columns, quotation marks, and rows with a different number of fields are rejected.

## Run the Autopilot CSV validation

    .\Test-AutopilotHardwareHashCsv.ps1 -CsvPath .\AutopilotDevices.csv

Choose a report path:

    .\Test-AutopilotHardwareHashCsv.ps1 -CsvPath .\AutopilotDevices.csv -OutputPath .\Reports\AutopilotCsvValidation.csv

By default, the report is written beside the source file with the suffix .validation.csv. The script returns exit code 0 when every row passes and exit code 1 when it finds errors or cannot validate the file. It enforces Microsoft’s 500-device manual import limit and the documented header/row format. This supports a pre-import check in a packaging or deployment workflow.

## Validation checks

- The five required headers match exactly, including spelling, case, and order; each row has five fields.
- Device Serial Number is not blank.
- The CSV contains no more than 500 device rows, and quotation marks are absent.
- Serial numbers are unique within the file, ignoring letter case.
- Hardware Hash is populated and can be decoded as Base64. Duplicate hashes are detected with a SHA-256 digest that is never written to the report.

The script does not contact Microsoft Graph, upload the CSV, modify the source file, verify the ANSI encoding required by Microsoft, check whether a serial number is already registered in your tenant, or determine whether a Group Tag matches your dynamic group rules.

## Security and handling

Windows Autopilot hardware hashes are sensitive device enrollment data. Protect the source CSV and delete it according to your organization’s data handling policy after import. The validation report intentionally omits the hash value.

## References

- [Windows Autopilot device registration overview](https://learn.microsoft.com/en-us/autopilot/registration-overview)
- [Windows Autopilot device import and CSV requirements](https://learn.microsoft.com/en-us/autopilot/add-devices)
