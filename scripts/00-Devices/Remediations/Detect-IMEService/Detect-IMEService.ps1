<#
.SYNOPSIS
    Detects whether the Intune Management Extension service is installed and running.

.DESCRIPTION
    Intended for an Intune Remediations package. Returns exit code 0 when the
    service is running and exit code 1 when it is missing or stopped.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$serviceName = 'IntuneManagementExtension'

try {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if ($null -eq $service) {
        Write-Output "Issue detected: service '$serviceName' is not installed."
        exit 1
    }

    if ($service.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running) {
        Write-Output "Issue detected: service '$serviceName' is '$($service.Status)'."
        exit 1
    }

    Write-Output "Healthy: service '$serviceName' is running."
    exit 0
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    exit 1
}
