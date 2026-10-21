<#
.SYNOPSIS
    Exports Microsoft Intune managed Windows devices with low or unavailable disk-space data.
    Author: Simone Termine
    Version: 1.1
    Blog: https://www.endpointninja.com

.DESCRIPTION
    Uses Microsoft Graph to read managed-device inventory and exports Windows
    devices below a configurable free-space threshold, plus devices for which
    storage data is unavailable. The script is read-only.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateRange(1, 1024)]
    [double]$MinimumFreeSpaceGB = 20,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = (Join-Path (Get-Location) ('Intune-LowDiskSpace-{0}.csv' -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command -Name 'Invoke-MgGraphRequest' -ErrorAction SilentlyContinue)) {
    throw 'Microsoft.Graph.Authentication is required. Install it with: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser'
}

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All'
}

$select = 'id,deviceName,userPrincipalName,operatingSystem,osVersion,complianceState,lastSyncDateTime,manufacturer,model,serialNumber,totalStorageSpaceInBytes,freeStorageSpaceInBytes'
$uri = 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$select={0}&$top=100' -f $select
$devices = [System.Collections.Generic.List[object]]::new()

while ($uri) {
    $page = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject -ErrorAction Stop
    foreach ($device in @($page.value)) {
        if ([string]$device.operatingSystem -eq 'Windows') {
            $devices.Add($device)
        }
    }
    $uri = [string]$page.'@odata.nextLink'
}

$bytesPerGiB = 1GB
$rows = @(
    foreach ($device in $devices) {
        $hasTotalStorage = ($null -ne $device.totalStorageSpaceInBytes)
        $hasFreeStorage = ($null -ne $device.freeStorageSpaceInBytes)
        $totalBytes = 0L
        $freeBytes = 0L
        if ($hasTotalStorage) {
            $totalBytes = [int64]$device.totalStorageSpaceInBytes
        }
        if ($hasFreeStorage) {
            $freeBytes = [int64]$device.freeStorageSpaceInBytes
        }

        $dataAvailable = ($hasTotalStorage -and $hasFreeStorage -and $totalBytes -gt 0)
        $freeGiB = $null
        $totalGiB = $null
        $freePercent = $null
        if ($dataAvailable) {
            $freeGiB = [math]::Round($freeBytes / $bytesPerGiB, 2)
            $totalGiB = [math]::Round($totalBytes / $bytesPerGiB, 2)
            $freePercent = [math]::Round(($freeBytes / $totalBytes) * 100, 2)
        }

        if (-not $dataAvailable -or $freeGiB -lt $MinimumFreeSpaceGB) {
            [PSCustomObject]@{
                DeviceName            = [string]$device.deviceName
                UserPrincipalName     = [string]$device.userPrincipalName
                Manufacturer          = [string]$device.manufacturer
                Model                 = [string]$device.model
                SerialNumber          = [string]$device.serialNumber
                OSVersion             = [string]$device.osVersion
                ComplianceState       = [string]$device.complianceState
                LastSyncDateTime      = [string]$device.lastSyncDateTime
                FreeStorageGiB        = $freeGiB
                TotalStorageGiB       = $totalGiB
                FreeStoragePercent    = $freePercent
                StorageDataAvailable  = $dataAvailable
            }
        }
    }
)

$fullOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$parentPath = Split-Path -Parent $fullOutputPath
if ($parentPath -and -not (Test-Path -LiteralPath $parentPath)) {
    New-Item -Path $parentPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
}

if ($rows.Count -gt 0) {
    $rows | Sort-Object StorageDataAvailable, FreeStorageGiB |
        Export-Csv -LiteralPath $fullOutputPath -NoTypeInformation -Encoding UTF8
}
else {
    'DeviceName,UserPrincipalName,Manufacturer,Model,SerialNumber,OSVersion,ComplianceState,LastSyncDateTime,FreeStorageGiB,TotalStorageGiB,FreeStoragePercent,StorageDataAvailable' |
        Set-Content -LiteralPath $fullOutputPath -Encoding UTF8
}

Write-Output ("Exported {0} device(s) below {1} GiB free or without storage data to {2}" -f $rows.Count, $MinimumFreeSpaceGB, $fullOutputPath)
