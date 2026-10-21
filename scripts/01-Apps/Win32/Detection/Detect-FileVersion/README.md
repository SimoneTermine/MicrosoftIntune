# Intune Win32 app detection script for executable file version

`Detect-FileVersion.ps1` is a reusable Microsoft Intune Win32 app detection rule for applications that expose a stable numeric version in an executable's file properties. It can detect an exact version or confirm that the installed version is at least the required version, which is useful for application upgrades and supersedence scenarios.

## Configure the detection rule

Edit the settings at the top of `Detect-FileVersion.ps1` before uploading it as the custom detection script for a Win32 app:

```powershell
$TargetPath = '%ProgramFiles%\Contoso\ContosoApp\ContosoApp.exe'
$RequiredVersion = '4.2.0.0'
$Comparison = 'Minimum' # Minimum or Exact
```

- `TargetPath`: full path to the executable, using environment variables where useful.
- `RequiredVersion`: numeric file version such as `4.2.0.0`.
- `Comparison`: `Minimum` detects the configured version or a newer one; `Exact` requires an exact match.

In the Intune Win32 app, select **Use a custom detection script**, upload the edited `.ps1`, and configure **Run script as 32-bit process on 64-bit clients** according to the application's install location. For applications under `Program Files`, use the 64-bit process on 64-bit Windows.

## Detection behavior

- The file is missing: exits `1`, app not detected.
- File version is below the minimum or does not match exact: exits `1`, app not detected.
- File exists and meets the configured comparison: writes a short message and exits `0`, app detected.
- Invalid version metadata or configuration: exits `1`, app not detected.

Intune's custom detection rule uses the script exit code and standard output. Keep output limited to the detected case, as this script does.

## Limitations

- The executable must expose a numeric `FileVersion` that PowerShell can parse as a .NET `System.Version`.
- Some vendors use product versions that differ from file versions, or ship multiple executables with different version numbers. Verify the selected file and property during packaging tests.
- This script checks one path and does not validate signatures, installation context, architecture, services, or related components.
- Run the Win32 app detection test on a clean VM and an upgraded install before broad deployment.

## References

- [Add and assign Microsoft Intune Win32 apps](https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-add)
- [Troubleshoot Win32 app installations in Microsoft Intune](https://learn.microsoft.com/en-us/intune/app-management/deployment/troubleshoot-win32)
- [System.Diagnostics.FileVersionInfo](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.fileversioninfo)
