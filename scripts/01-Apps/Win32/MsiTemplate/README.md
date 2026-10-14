# Generic MSI install and uninstall template

## Purpose

The two scripts provide a small Intune Win32 app template for installing or uninstalling an MSI in the app package. They run `msiexec.exe` silently, prevent an automatic reboot, and write verbose Windows Installer logs under `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Win32Msi`.

## Package layout

```text
Source\
├── Application.msi
├── Install-MsiPackage.ps1
└── Uninstall-MsiPackage.ps1
```

Change `$MsiFileName` in the install script and `$ProductCode` in the uninstall script before packaging. Add vendor-supported public MSI properties to `$AdditionalMsiProperties` only when required. Do not put secrets in MSI properties or command lines.

## Create the Intune app

Package the `Source` folder with the Microsoft Win32 Content Prep Tool. Example commands:

```text
Install command: powershell.exe -ExecutionPolicy Bypass -File .\Install-MsiPackage.ps1
Uninstall command: powershell.exe -ExecutionPolicy Bypass -File .\Uninstall-MsiPackage.ps1
```

Configure **Install behavior** as **System**. Add a detection rule for the MSI ProductCode or use a configured custom detection script. Configure Intune return codes so `0` is success, `3010` is a soft reboot, `1641` is a hard reboot, and `1618` is retry, according to your deployment policy.

## Safety and limitations

- These scripts do not validate the vendor signature or install prerequisites.
- The installer runs silently and may make vendor-defined system changes.
- The uninstall script treats `1605` and `1614` as success because the product is already absent.
- Keep the MSI and scripts in the same source folder; the output `.intunewin` file should be created outside it.
- Test install, upgrade, detection, and uninstall behavior on a pilot device before broad assignment.
- Review MSI logs before sharing; they may contain usernames, paths, property values, or environment details.
