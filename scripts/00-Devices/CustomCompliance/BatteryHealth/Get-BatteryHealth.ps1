<#
.SYNOPSIS
    Reports Windows laptop battery health for Microsoft Intune custom compliance.
    Author: Simone Termine
    Version: 1.1
    Blog: https://www.endpointninja.com

.DESCRIPTION
    Reads designed and fully charged battery capacity from the Windows battery
    WMI provider and writes one compact JSON object to standard output. The
    script makes no changes to the device.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Write-ComplianceResult {
    param(
        [Parameter(Mandatory)] [double] $BatteryHealthPercent,
        [Parameter(Mandatory)] [bool] $QuerySucceeded,
        [Parameter(Mandatory)] [bool] $BatteryPresent,
        [double] $DesignedCapacityWh = 0,
        [double] $FullChargeCapacityWh = 0,
        [string] $ErrorMessage = ''
    )

    [PSCustomObject]@{
        BatteryHealthPercent = $BatteryHealthPercent
        QuerySucceeded       = $QuerySucceeded
        BatteryPresent       = $BatteryPresent
        DesignedCapacityWh   = $DesignedCapacityWh
        FullChargeCapacityWh = $FullChargeCapacityWh
        ErrorMessage         = $ErrorMessage
    } | ConvertTo-Json -Compress | Write-Output
}

try {
    $designData = @(Get-CimInstance -Namespace 'root\wmi' -ClassName 'BatteryStaticData')
    $chargeData = @(Get-CimInstance -Namespace 'root\wmi' -ClassName 'BatteryFullChargedCapacity')

    if ($designData.Count -eq 0 -or $chargeData.Count -eq 0) {
        Write-ComplianceResult -BatteryHealthPercent 0 -QuerySucceeded $false -BatteryPresent ($designData.Count -gt 0)
        exit 0
    }

    $designValues = @($designData | Where-Object { [double]$_.DesignedCapacity -gt 0 })
    $chargeValues = @($chargeData | Where-Object { [double]$_.FullChargedCapacity -gt 0 })

    if ($designValues.Count -eq 0 -or $chargeValues.Count -eq 0 -or $designValues.Count -ne $chargeValues.Count) {
        Write-ComplianceResult -BatteryHealthPercent 0 -QuerySucceeded $false -BatteryPresent $true -ErrorMessage 'Windows returned incomplete or mismatched battery capacity data.'
        exit 0
    }

    $designedCapacity = [double](($designValues | Measure-Object -Property DesignedCapacity -Sum).Sum)
    $fullChargeCapacity = [double](($chargeValues | Measure-Object -Property FullChargedCapacity -Sum).Sum)

    if ($designedCapacity -le 0) {
        Write-ComplianceResult -BatteryHealthPercent 0 -QuerySucceeded $false -BatteryPresent $true -ErrorMessage 'The reported designed battery capacity is zero.'
        exit 0
    }

    $healthPercent = [math]::Round(($fullChargeCapacity / $designedCapacity) * 100, 2)
    Write-ComplianceResult -BatteryHealthPercent $healthPercent -QuerySucceeded $true -BatteryPresent $true -DesignedCapacityWh ([math]::Round($designedCapacity / 1000, 2)) -FullChargeCapacityWh ([math]::Round($fullChargeCapacity / 1000, 2))
}
catch {
    $message = $_.Exception.Message
    if ($message.Length -gt 240) {
        $message = $message.Substring(0, 240)
    }
    Write-ComplianceResult -BatteryHealthPercent 0 -QuerySucceeded $false -BatteryPresent $false -ErrorMessage $message
}
