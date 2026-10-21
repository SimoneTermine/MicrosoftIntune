<#
.SYNOPSIS
    Reports free space on the Windows system drive for Intune custom compliance.

.DESCRIPTION
    Read-only custom compliance discovery script. Returns compact JSON with the
    system drive letter, free space in GiB, and query success state. It does not
    delete files or change disk configuration.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$systemDrive = $env:SystemDrive

try {
    $drive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $systemDrive)
    if ($null -eq $drive -or $null -eq $drive.FreeSpace) {
        throw "Unable to read free space for $systemDrive."
    }

    $result = [ordered]@{
        SystemDriveFreeSpaceGiB = [math]::Round(([double]$drive.FreeSpace / 1GB), 2)
        SystemDrive             = [string]$drive.DeviceID
        QuerySucceeded          = $true
    }

    ConvertTo-Json -InputObject $result -Compress
    exit 0
}
catch {
    $result = [ordered]@{
        SystemDriveFreeSpaceGiB = 0
        SystemDrive             = [string]$systemDrive
        QuerySucceeded          = $false
    }

    ConvertTo-Json -InputObject $result -Compress
    exit 0
}
