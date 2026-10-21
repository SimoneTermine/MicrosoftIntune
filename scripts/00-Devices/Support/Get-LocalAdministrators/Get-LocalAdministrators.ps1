<#
.SYNOPSIS
    Lists members of the built-in Windows local Administrators group.
    Author: Simone Termine
    Version: 1.1
    Blog: https://www.endpointninja.com

.DESCRIPTION
    Read-only inventory script for Windows endpoint support and security reviews.
    It resolves the Administrators group by its well-known SID, so the result
    works on localized Windows installations. Optionally exports the inventory
    to CSV.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$CsvPath
)

$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'This script runs on Windows only.'
}

if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    throw 'Run the script in 64-bit PowerShell. The LocalAccounts module is unavailable in 32-bit PowerShell on 64-bit Windows.'
}

if (-not (Get-Command -Name 'Get-LocalGroupMember' -ErrorAction SilentlyContinue)) {
    throw 'Get-LocalGroupMember is unavailable. Use Windows PowerShell 5.1 or a supported 64-bit PowerShell session on Windows.'
}

$administratorsSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
$group = Get-LocalGroup -SID $administratorsSid -ErrorAction Stop
$members = @(Get-LocalGroupMember -SID $administratorsSid -ErrorAction Stop)

$rows = @(
    foreach ($member in $members) {
        [PSCustomObject]@{
            ComputerName    = $env:COMPUTERNAME
            GroupName       = $group.Name
            MemberName      = $member.Name
            ObjectClass     = [string]$member.ObjectClass
            PrincipalSource = [string]$member.PrincipalSource
            SID             = [string]$member.SID
        }
    }
)

if ($CsvPath) {
    $fullPath = [System.IO.Path]::GetFullPath($CsvPath)
    $parentPath = Split-Path -Parent $fullPath
    if ($parentPath -and -not (Test-Path -LiteralPath $parentPath)) {
        New-Item -Path $parentPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    if ($rows.Count -gt 0) {
        $rows | Export-Csv -LiteralPath $fullPath -NoTypeInformation -Encoding UTF8
    }
    else {
        'ComputerName,GroupName,MemberName,ObjectClass,PrincipalSource,SID' |
            Set-Content -LiteralPath $fullPath -Encoding UTF8
    }

    Write-Output ("Exported {0} local Administrators group member(s) to {1}" -f $rows.Count, $fullPath)
}
else {
    $rows
}
