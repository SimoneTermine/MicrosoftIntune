<#
.SYNOPSIS
    Uninstalls an MSI product by ProductCode and writes a verbose log.

.DESCRIPTION
    Set ProductCode to the exact MSI product GUID before packaging.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# --- Configuration ---
$ProductCode = '{00000000-0000-0000-0000-000000000000}'
# --- End configuration ---

$logDirectory = Join-Path $env:ProgramData 'Microsoft\IntuneManagementExtension\Logs\Win32Msi'
$logPath = Join-Path $logDirectory ("Uninstall-{0}.log" -f ($ProductCode.Trim('{}')))
$msiexec = Join-Path $env:windir 'System32\msiexec.exe'
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    $msiexec = Join-Path $env:windir 'Sysnative\msiexec.exe'
}

try {
    if ($ProductCode -notmatch '^\{[0-9A-Fa-f-]{36}\}$') { throw 'Configure ProductCode as the MSI product GUID.' }
    New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null

    $arguments = "/x $ProductCode /qn /norestart /L*v `"$logPath`""
    $process = Start-Process -FilePath $msiexec -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
    Write-Output "msiexec completed with exit code $($process.ExitCode). Log: $logPath"

    # 1605 and 1614 mean the product is not installed / already uninstalled.
    if ($process.ExitCode -in @(1605, 1614)) { exit 0 }
    exit $process.ExitCode
}
catch {
    Write-Error "MSI uninstallation failed: $($_.Exception.Message)"
    exit 1
}
