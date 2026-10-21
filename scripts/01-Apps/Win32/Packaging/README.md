# Microsoft Intune Win32 app installer metadata and hash script

Get-Win32AppSourceMetadata.ps1 collects installer metadata for Microsoft Intune Win32 app packaging. It reports file size and SHA-256 for EXE and MSI installers, reads version resources from executable files, and extracts product properties from MSI packages without installing them.

## Run the script

    ./Get-Win32AppSourceMetadata.ps1 -InstallerPath ./ContosoApp.msi

To save the result as JSON:

    ./Get-Win32AppSourceMetadata.ps1 -InstallerPath ./ContosoSetup.exe -OutputPath ./ContosoSetup-metadata.json

For MSI files, the output can include ProductName, ProductVersion, Manufacturer, ProductCode, and UpgradeCode. For EXE files, version fields are read from the file's version resource and may be blank if the vendor did not publish them.

## Why use it before creating an Intune Win32 app

The metadata helps document an installer source, validate the file selected for packaging, record its SHA-256 checksum, and prepare MSI product-code or version-based detection rules. Keep the output with your application source and deployment notes.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7 on Windows.
- Windows Installer service components available to read MSI metadata.
- Read access to the installer file.

## Limitations

- The script does not create an .intunewin package, upload an app to Intune, or validate install commands.
- EXE metadata depends on the file version resource supplied by the publisher.
- MSI metadata may differ when an installation transform changes package properties.
- SHA-256 identifies the exact source file but does not establish that the installer is trusted or safe.

## References

- Microsoft Learn: [Add, assign, and monitor a Win32 app in Microsoft Intune](https://learn.microsoft.com/en-us/intune/app-management/deployment/add-win32)
- Microsoft Learn: [Get-FileHash](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash)
