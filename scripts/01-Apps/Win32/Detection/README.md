# MSI ProductCode and version detection

## Purpose

Reusable Intune Win32 custom detection script for MSI-based applications. It checks the 32-bit and 64-bit machine uninstall registry views, matches the MSI ProductCode, and compares `DisplayVersion` as a numeric version.

## Configure

Edit the three values near the top of `Detect-MsiProductVersion.ps1` before packaging:

```powershell
$ProductCode = '{YOUR-MSI-PRODUCT-CODE-GUID}'
$MinimumVersion = '2.4.0'
$AllowNewerVersions = $true
```

With `$AllowNewerVersions = $true`, versions equal to or greater than the minimum are detected. Set it to `$false` to require an exact version. Confirm the ProductCode and version format from the vendor's MSI/package documentation.

## Intune configuration

In the Win32 app's **Detection rules**, select **Use a custom detection script** and upload the configured script. Run it as a 64-bit process and configure signature enforcement according to your policy. Intune treats exit code `0` plus non-empty standard output as detected; exit code `1` means not detected.

## Limitations

- This is for machine-wide MSI installations registered under `HKLM`.
- Per-user installs under `HKCU`, MSIX packages, and EXE installers without an MSI ProductCode are outside its scope.
- Some vendors write a non-numeric `DisplayVersion`; those products need a vendor-specific detection rule.
- The placeholder ProductCode intentionally returns not detected until configured.
- Test both installed and absent states on a representative device before assigning the app broadly.
