<#
.SYNOPSIS
    Starts the configured OneDrive sync client for the signed-in user.
    Author: Simone Termine
    Version: 1.1
    Blog: https://www.endpointninja.com

.DESCRIPTION
    Intune Remediations remediation script. If a OneDrive account is configured
    for the current user and OneDrive.exe is not running in the current session,
    the script starts it in the background. Run with logged-on user credentials.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    if ($identity.User.Value -eq 'S-1-5-18') {
        throw 'Run this remediation package with logged-on user credentials, not as SYSTEM.'
    }

    $accountPath = 'HKCU:\Software\Microsoft\OneDrive\Accounts'
    $accounts = @(Get-ChildItem -Path $accountPath -ErrorAction SilentlyContinue)
    if ($accounts.Count -eq 0) {
        Write-Output 'No OneDrive account is configured for the current user; no action was taken.'
        exit 0
    }

    $sessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
    $process = @(Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $sessionId })
    if ($process.Count -gt 0) {
        Write-Output 'OneDrive is already running in the current session.'
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
    if (-not $executable) {
        throw 'OneDrive.exe was not found in the standard per-user or machine installation paths.'
    }

    Start-Process -FilePath $executable -ArgumentList '/background' -ErrorAction Stop
    Start-Sleep -Seconds 3
    $startedProcess = @(Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $sessionId })
    if ($startedProcess.Count -eq 0) {
        throw 'The OneDrive process did not remain running after launch.'
    }

    Write-Output ("OneDrive was started for {0} in session {1}." -f $identity.Name, $sessionId)
    exit 0
}
catch {
    Write-Output ("RemediationFailed: {0}" -f $_.Exception.Message)
    exit 1
}
