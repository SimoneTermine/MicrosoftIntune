<#
.SYNOPSIS
    Starts the Intune Management Extension service if it is stopped.

.DESCRIPTION
    Intended for an Intune Remediations package. Does not restart a running
    service and does not attempt to install or repair a missing service.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$serviceName = 'IntuneManagementExtension'

try {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        throw "Service '$serviceName' is not installed. The script will not install the Intune Management Extension."
    }

    if ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
        Write-Output "No action required: service '$serviceName' is already running."
        exit 0
    }

    Start-Service -Name $serviceName -ErrorAction Stop
    $service = Get-Service -Name $serviceName -ErrorAction Stop
    $service.WaitForStatus(
        [System.ServiceProcess.ServiceControllerStatus]::Running,
        [TimeSpan]::FromSeconds(20)
    )

    $service.Refresh()
    if ($service.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running) {
        throw "Service '$serviceName' did not reach the Running state. Current state: $($service.Status)."
    }

    Write-Output "Remediated: service '$serviceName' is running."
    exit 0
}
catch {
    Write-Output "Remediation failed: $($_.Exception.Message)"
    exit 1
}
