<#
.SYNOPSIS
    Detects whether the configured OneDrive sync client is running for the signed-in user.
    Author: Simone Termine
    Version: 1.1
    Blog: https://www.endpointninja.com

.DESCRIPTION
    Intune Remediations detection script for Windows user sessions. It reports
    an issue when OneDrive is configured for the current user but its process
    is not running. Run this package with the logged-on user credentials.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    if ($identity.User.Value -eq 'S-1-5-18') {
        Write-Output '{"Status":"UnsupportedContext","Detail":"Run this remediation package with logged-on user credentials."}'
        exit 1
    }

    $accountPath = 'HKCU:\Software\Microsoft\OneDrive\Accounts'
    $accounts = @(Get-ChildItem -Path $accountPath -ErrorAction SilentlyContinue)
    if ($accounts.Count -eq 0) {
        exit 0
    }

    $sessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
    $process = @(Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $sessionId })
    if ($process.Count -gt 0) {
        exit 0
    }

    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    $candidatePaths = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive\OneDrive.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft OneDrive\OneDrive.exe')
    )
    if ($programFilesX86) {
        $candidatePaths += Join-Path $programFilesX86 'Microsoft OneDrive\OneDrive.exe'
    }

    $executable = $candidatePaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    [PSCustomObject]@{
        Status     = 'OneDriveNotRunning'
        User       = $identity.Name
        Executable = [string]$executable
    } | ConvertTo-Json -Compress | Write-Output
    exit 1
}
catch {
    [PSCustomObject]@{
        Status = 'DetectionError'
        Detail = $_.Exception.Message
    } | ConvertTo-Json -Compress | Write-Output
    exit 1
}
