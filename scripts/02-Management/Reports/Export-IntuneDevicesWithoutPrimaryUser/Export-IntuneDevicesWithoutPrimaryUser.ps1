<#
.SYNOPSIS
    Exports Windows Intune managed devices without an associated primary user.

.DESCRIPTION
    Read-only Microsoft Graph report. Uses delegated authentication and exports
    devices where userId and userPrincipalName are both empty. Shared, kiosk,
    and enrollment-only devices can be expected to have no primary user.
#>

[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path -Path (Get-Location).Path -ChildPath ("Intune-Devices-Without-Primary-User-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

$ErrorActionPreference = 'Stop'
$scope = 'DeviceManagementManagedDevices.Read.All'

try {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.DeviceManagement)) {
        throw 'Microsoft.Graph.DeviceManagement is not installed. Install it with: Install-Module Microsoft.Graph.DeviceManagement -Scope CurrentUser'
    }

    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.DeviceManagement -ErrorAction Stop

    $graphContext = Get-MgContext
    if (-not $graphContext -or $graphContext.AuthType -ne 'Delegated' -or $graphContext.Scopes -notcontains $scope) {
        Connect-MgGraph -Scopes $scope -NoWelcome
    }

    $devices = Get-MgDeviceManagementManagedDevice -All -Property @(
        'id', 'deviceName', 'operatingSystem', 'osVersion', 'azureADDeviceId',
        'userId', 'userPrincipalName', 'userDisplayName', 'emailAddress',
        'managedDeviceOwnerType', 'managementAgent', 'enrollmentType',
        'complianceState', 'lastSyncDateTime', 'serialNumber', 'manufacturer', 'model'
    )

    $results = @(
        $devices |
            Where-Object {
                $_.OperatingSystem -eq 'Windows' -and
                [string]::IsNullOrWhiteSpace([string]$_.UserId) -and
                [string]::IsNullOrWhiteSpace([string]$_.UserPrincipalName)
            } |
            ForEach-Object {
                [PSCustomObject]@{
                    DeviceName           = $_.DeviceName
                    OperatingSystem      = $_.OperatingSystem
                    OSVersion            = $_.OsVersion
                    SerialNumber         = $_.SerialNumber
                    Manufacturer         = $_.Manufacturer
                    Model                = $_.Model
                    ManagedDeviceOwner   = $_.ManagedDeviceOwnerType
                    EnrollmentType       = $_.EnrollmentType
                    ManagementAgent      = $_.ManagementAgent
                    ComplianceState      = $_.ComplianceState
                    LastSyncDateTime     = $_.LastSyncDateTime
                    IntuneManagedDeviceId = $_.Id
                    EntraDeviceId        = $_.AzureADDeviceId
                }
            }
    )

    $parent = Split-Path -Path $OutputPath -Parent
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }

    if ($results.Count -gt 0) {
        $results | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8
    }
    else {
        'DeviceName,OperatingSystem,OSVersion,SerialNumber,Manufacturer,Model,ManagedDeviceOwner,EnrollmentType,ManagementAgent,ComplianceState,LastSyncDateTime,IntuneManagedDeviceId,EntraDeviceId' |
            Set-Content -LiteralPath $OutputPath -Encoding UTF8
    }
    Write-Output ("Exported {0} Windows device(s) without an associated primary user to {1}" -f $results.Count, (Resolve-Path -LiteralPath $OutputPath).Path)
}
catch {
    Write-Error -Message $_.Exception.Message
    exit 1
}
