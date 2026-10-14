<#
.SYNOPSIS
    Detects common Windows indicators that a restart is pending.

.DESCRIPTION
    Detection-only script for Intune Remediations. It reports the indicators
    found and does not restart the device or change registry values.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$reasons = [System.Collections.Generic.List[string]]::new()

try {
    $cbsPendingPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    if (Test-Path -LiteralPath $cbsPendingPath) {
        $reasons.Add('Component Based Servicing reports a pending restart')
    }

    $wuPendingPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    if (Test-Path -LiteralPath $wuPendingPath) {
        $reasons.Add('Windows Update reports a pending restart')
    }

    $sessionManagerPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    $pendingRename = (Get-ItemProperty -LiteralPath $sessionManagerPath -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
    if ($pendingRename -and $pendingRename.Count -gt 0) {
        $reasons.Add('Windows has pending file rename operations')
    }

    if ($reasons.Count -gt 0) {
        Write-Output ("Pending restart detected: {0}" -f ($reasons -join '; '))
        exit 1
    }

    Write-Output 'No pending restart indicators were found.'
    exit 0
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    exit 1
}
