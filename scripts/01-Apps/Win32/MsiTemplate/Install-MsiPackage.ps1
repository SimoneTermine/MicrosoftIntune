<#
.SYNOPSIS
    Installs an MSI included in the Intune Win32 app package and writes a verbose log.

.DESCRIPTION
    Set the MSI filename and any vendor-specific public properties before packaging.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# --- Configuration ---
$MsiFileName = 'Application.msi'
$AdditionalMsiProperties = '' # Example: 'ALLUSERS=1'
# --- End configuration ---

$msiPath = Join-Path $PSScriptRoot $MsiFileName
$logDirectory = Join-Path $env:ProgramData 'Microsoft\IntuneManagementExtension\Logs\Win32Msi'
$logPath = Join-Path $logDirectory ("Install-{0}.log" -f [IO.Path]::GetFileNameWithoutExtension($MsiFileName))
$msiexec = Join-Path $env:windir 'System32\msiexec.exe'
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    $msiexec = Join-Path $env:windir 'Sysnative\msiexec.exe'
}

try {
    if (-not (Test-Path -LiteralPath $msiPath -PathType Leaf)) { throw "MSI file not found: $msiPath" }
    New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null

    $arguments = "/i `"$msiPath`" /qn /norestart /L*v `"$logPath`""
    if (-not [string]::IsNullOrWhiteSpace($AdditionalMsiProperties)) {
        $arguments += " $AdditionalMsiProperties"
    }

    $process = Start-Process -FilePath $msiexec -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
    Write-Output "msiexec completed with exit code $($process.ExitCode). Log: $logPath"

    # Preserve standard Windows Installer codes so Intune can apply its configured return-code behavior.
    exit $process.ExitCode
}
catch {
    Write-Error "MSI installation failed: $($_.Exception.Message)"
    exit 1
}
