<#
.SYNOPSIS
    Detects an MSI product by ProductCode and minimum installed version.

.DESCRIPTION
    Configure the values in the Configuration section before uploading this
    script as a Win32 app custom detection script. It checks both Windows
    Installer registry views and compares versions numerically.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# --- Configuration: replace these values for the application being packaged. ---
$ProductCode = '{00000000-0000-0000-0000-000000000000}'
$MinimumVersion = '1.0.0'
# $true means a version equal to or newer than MinimumVersion is detected.
$AllowNewerVersions = $true
# --- End configuration. ---

if ($ProductCode -notmatch '^\{[0-9A-Fa-f-]{36}\}$') {
    Write-Output 'Detection is not configured: set ProductCode to the MSI ProductCode GUID.'
    exit 1
}

$requiredVersion = $null
if (-not [version]::TryParse($MinimumVersion, [ref]$requiredVersion)) {
    Write-Output "Detection is not configured: '$MinimumVersion' is not a valid version."
    exit 1
}

$subKeyPath = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
$registryViews = @(
    [Microsoft.Win32.RegistryView]::Registry64,
    [Microsoft.Win32.RegistryView]::Registry32
)
$foundVersions = [System.Collections.Generic.List[version]]::new()

try {
    foreach ($view in $registryViews) {
        $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
            [Microsoft.Win32.RegistryHive]::LocalMachine,
            $view
        )

        try {
            $uninstallKey = $baseKey.OpenSubKey($subKeyPath)
            if ($null -eq $uninstallKey) { continue }

            try {
                foreach ($keyName in $uninstallKey.GetSubKeyNames()) {
                    if ($keyName -ine $ProductCode) { continue }

                    $productKey = $uninstallKey.OpenSubKey($keyName)
                    if ($null -eq $productKey) { continue }

                    try {
                        $displayVersion = [string]$productKey.GetValue('DisplayVersion')
                        $installedVersion = $null
                        if ([version]::TryParse($displayVersion, [ref]$installedVersion)) {
                            $foundVersions.Add($installedVersion)
                        }
                    }
                    finally {
                        $productKey.Dispose()
                    }
                }
            }
            finally {
                $uninstallKey.Dispose()
            }
        }
        finally {
            $baseKey.Dispose()
        }
    }

    if ($foundVersions.Count -eq 0) {
        Write-Output "Not detected: MSI ProductCode $ProductCode was not found with a parseable DisplayVersion."
        exit 1
    }

    $installedVersion = $foundVersions | Sort-Object -Descending | Select-Object -First 1
    $versionMatches = if ($AllowNewerVersions) {
        $installedVersion -ge $requiredVersion
    }
    else {
        $installedVersion -eq $requiredVersion
    }

    if ($versionMatches) {
        Write-Output "Detected: $ProductCode version $installedVersion."
        exit 0
    }

    Write-Output "Not detected: installed version $installedVersion; required version $MinimumVersion."
    exit 1
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    exit 1
}
