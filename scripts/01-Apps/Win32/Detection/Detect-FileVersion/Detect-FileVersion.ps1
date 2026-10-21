<#
.SYNOPSIS
    Detects a Win32 application by executable file version for Microsoft Intune.

.DESCRIPTION
    Configure the values in the SETTINGS section before packaging. The script
    writes output and exits 0 only when the target executable exists and its
    numeric file version meets the selected comparison rule.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# --- SETTINGS: edit these values for the application being packaged. ---
$TargetPath = '%ProgramFiles%\Contoso\ContosoApp\ContosoApp.exe'
$RequiredVersion = '4.2.0.0'
$Comparison = 'Minimum' # Minimum or Exact
# ------------------------------------------------------------------------

try {
    $expandedPath = [Environment]::ExpandEnvironmentVariables($TargetPath)
    if (-not (Test-Path -LiteralPath $expandedPath -PathType Leaf)) {
        exit 1
    }

    $actualVersionText = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($expandedPath).FileVersion
    $actualVersion = [version]$actualVersionText
    $required = [version]$RequiredVersion

    $detected = switch ($Comparison) {
        'Exact'   { $actualVersion -eq $required }
        'Minimum' { $actualVersion -ge $required }
        default   { throw "Comparison must be 'Minimum' or 'Exact'." }
    }

    if ($detected) {
        Write-Output ("Detected file version {0} at {1}." -f $actualVersion, $expandedPath)
        exit 0
    }

    exit 1
}
catch {
    # A malformed/missing version or invalid configuration is not detected.
    exit 1
}
