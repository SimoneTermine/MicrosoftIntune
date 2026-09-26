<#
.SYNOPSIS
    Removes a printer deployed through Microsoft Intune.

.DESCRIPTION
    This script removes a local printer queue and optionally removes
    its associated TCP/IP printer port.

    The printer port is removed only when it is no longer used
    by other printer queues.

    The printer driver is intentionally preserved.

    Uninstallation logs are saved to:
    C:\ProgramData\EndpointNinja\PrinterDeployment

.PARAMETER PrinterName
    Exact name of the printer to remove.

.PARAMETER PortName
    Name of the TCP/IP printer port associated with the printer.

    If omitted and the printer exists, the script retrieves
    the port name from the installed printer.

.PARAMETER RemovePort
    Optional switch that removes the TCP/IP printer port
    when it is no longer used by other printers.

.NOTES
    Author: Simone Termine
    Website: https://www.endpointninja.com

    Requirements:
    - Windows 10 or Windows 11.
    - Windows PowerShell 5.1.
    - Administrative privileges or SYSTEM context.

    CUSTOMIZATION:

    No printer-specific values are hardcoded in this script.

    To remove a different printer, modify the uninstall command
    configured in Microsoft Intune.

    Update the following parameters:

    -PrinterName
    -PortName

    Include -RemovePort only when the associated TCP/IP port
    should also be removed.

    The printer driver is not removed because it may be
    shared by other printer queues.

.EXAMPLE

    .\Uninstall-Printer.ps1 `
        -PrinterName "IT Floor 1 - EPSON WF-2510" `
        -PortName "IP_192.0.2.25" `
        -RemovePort

    Replace the example values with your printer configuration.

    192.0.2.25 is a documentation-only IP address.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PrinterName,

    [string]$PortName,

    [switch]$RemovePort
)

$ErrorActionPreference = "Stop"

#Create the directory used to store uninstallation logs.
$LogRoot = Join-Path $env:ProgramData "EndpointNinja\PrinterDeployment"
New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null

#Remove invalid filename characters from the printer name.
$SafePrinterName = ($PrinterName -replace '[\\/:*?"<>|]', '_')
$LogFile = Join-Path $LogRoot "$SafePrinterName-uninstall.log"

$TranscriptStarted = $false
$ExitCode = 0

try {
    Start-Transcript -Path $LogFile -Append | Out-Null
    $TranscriptStarted = $true
    Write-Output "Starting printer removal: $PrinterName"

    #Check whether the printer queue exists.
    $Printer = Get-Printer `
        -Name $PrinterName `
        -ErrorAction SilentlyContinue

    if ($Printer) {

        #Retrieve the associated port if no port was specified.
        if ([string]::IsNullOrWhiteSpace($PortName)) {
            $PortName = $Printer.PortName
        }
        elseif ($PortName -ne $Printer.PortName) {
            throw "The specified port does not match the printer's configured port. Printer removal cancelled."
        }

        #Remove the printer queue.
        Write-Output "Removing printer: $PrinterName"
        Remove-Printer `
            -Name $PrinterName `
            -Confirm:$false
    }
    else {
        Write-Output "Printer not found: $PrinterName"
    }

    #Remove the TCP/IP port only when explicitly requested.
    if (
        $RemovePort -and
        -not [string]::IsNullOrWhiteSpace($PortName)
    ) {

        #Check whether other printers are using the same port.
        $PrintersUsingPort = Get-Printer |
            Where-Object {
                $_.PortName -eq $PortName
            }

        if (-not $PrintersUsingPort) {
            $Port = Get-PrinterPort `
                -Name $PortName `
                -ErrorAction SilentlyContinue

            if ($Port) {
                Write-Output "Removing unused printer port: $PortName"
                Remove-PrinterPort `
                    -Name $PortName `
                    -Confirm:$false
            }
            else {
                Write-Output "Printer port not found: $PortName"
            }
        }
        else {
            Write-Output "Printer port is still used by other printers: $PortName"
            Write-Output "Port removal skipped."
        }
    }

    Write-Output "Printer removal completed successfully."

}
catch {
    Write-Output "ERROR: $($_.Exception.Message)"
    $ExitCode = 1
}
finally {
    if ($TranscriptStarted) {
        Stop-Transcript | Out-Null
    }
}
exit $ExitCode
