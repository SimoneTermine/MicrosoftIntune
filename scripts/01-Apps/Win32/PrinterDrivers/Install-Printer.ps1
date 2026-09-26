<#
.SYNOPSIS
    Installs a printer driver and a local TCP/IP printer using Microsoft Intune.

.DESCRIPTION
    This script is designed to be deployed as a Microsoft Intune Win32 app
    and executed in the SYSTEM context.

    The script performs the following operations:

    1. Validates the printer driver INF file.
    2. Stages the driver package in the Windows Driver Store using PnPUtil.
    3. Registers the printer driver if it is not already installed.
    4. Creates a Standard TCP/IP printer port if it does not exist.
    5. Validates the IP address and TCP port of an existing printer port.
    6. Creates the printer queue if it does not exist.
    7. Recreates the printer queue if its driver or port does not match
       the expected configuration.

    Installation logs are saved to:
    C:\ProgramData\EndpointNinja\PrinterDeployment

.PARAMETER PrinterName
    Display name of the printer that will appear in Windows.

.PARAMETER PrinterIP
    IP address or DNS name of the network printer.

.PARAMETER DriverName
    Exact name of the printer driver as reported by Get-PrinterDriver.

.PARAMETER InfFile
    Relative path to the printer driver INF file included in the
    Win32 application package.

.PARAMETER PortName
    Name of the TCP/IP printer port.

    If omitted, the script generates a port name using:
    IP_<PrinterIP>

.PARAMETER PortNumber
    TCP port used by the printer.

    Default: 9100

.NOTES
    Author: Simone Termine
    Website: https://www.endpointninja.com

    Requirements:
    - Windows 10 or Windows 11.
    - Windows PowerShell 5.1.
    - Administrative privileges or SYSTEM context.
    - A complete and compatible printer driver package.
    - Network connectivity to the printer.

    CUSTOMIZATION:

    No printer-specific values are hardcoded in this script.

    To deploy a different printer, modify the installation command
    configured in Microsoft Intune.

    Update the following parameters:

    -PrinterName
    -PrinterIP
    -DriverName
    -InfFile
    -PortName
    -PortNumber (only if the printer does not use TCP 9100)

    The driver INF file and all required driver files must be placed
    inside the Drivers folder before creating the .intunewin package.

    WARNING:

    If a printer with the specified name already exists but uses
    a different driver or port, the script removes and recreates it.

    Test this behavior before deploying to production devices,
    especially when existing print jobs or custom queue settings
    must be preserved.

.EXAMPLE

    .\Install-Printer.ps1 `
        -PrinterName "IT Floor 1 - EPSON WF-2510" `
        -PrinterIP "192.0.2.25" `
        -DriverName "EPSON WF-2510 Series" `
        -InfFile ".\Drivers\E_WF1IXE.INF" `
        -PortName "IP_192.0.2.25"

    Replace the example values with your printer configuration.

    192.0.2.25 is a documentation-only IP address.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PrinterName,

    [Parameter(Mandatory = $true)]
    [string]$PrinterIP,

    [Parameter(Mandatory = $true)]
    [string]$DriverName,

    [Parameter(Mandatory = $true)]
    [string]$InfFile,

    [string]$PortName,

    [ValidateRange(1, 65535)]
    [int]$PortNumber = 9100
)

$ErrorActionPreference = "Stop"

#Generate the printer port name if it was not provided.
if ([string]::IsNullOrWhiteSpace($PortName)) {
    $PortName = "IP_$PrinterIP"
}

#Create the directory used to store installation logs.
$LogRoot = Join-Path $env:ProgramData "EndpointNinja\PrinterDeployment"
New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null

#Remove invalid filename characters from the printer name.
$SafePrinterName = ($PrinterName -replace '[\\/:*?"<>|]', '_')
$LogFile = Join-Path $LogRoot "$SafePrinterName-install.log"

$TranscriptStarted = $false
$ExitCode = 0

try {
    Start-Transcript -Path $LogFile -Append | Out-Null
    $TranscriptStarted = $true
    Write-Output "Starting printer installation: $PrinterName"

    #Resolve the INF file path relative to the script location.
    $InfPath = Join-Path $PSScriptRoot $InfFile

    if (-not (Test-Path -Path $InfPath -PathType Leaf)) {
        throw "Driver INF file not found: $InfPath"
    }

    #Stage the printer driver package in the Windows Driver Store.
    Write-Output "Staging printer driver: $InfPath"

    $PnPUtil = Join-Path $env:WINDIR "System32\pnputil.exe"
    $PnPProcess = Start-Process `
        -FilePath $PnPUtil `
        -ArgumentList "/add-driver `"$InfPath`"" `
        -Wait `
        -PassThru `
        -NoNewWindow

    if ($PnPProcess.ExitCode -ne 0) {
        throw "PnPUtil failed with exit code $($PnPProcess.ExitCode)"
    }

    #Register the printer driver if it is not already installed.
    $ExistingDriver = Get-PrinterDriver `
        -Name $DriverName `
        -ErrorAction SilentlyContinue

    if (-not $ExistingDriver) {
        Write-Output "Installing printer driver: $DriverName"
        Add-PrinterDriver -Name $DriverName
    }
    else {
        Write-Output "Printer driver already installed: $DriverName"
    }

    #Confirm that the printer driver is available.
    $InstalledDriver = Get-PrinterDriver `
        -Name $DriverName `
        -ErrorAction SilentlyContinue

    if (-not $InstalledDriver) {
        throw "Printer driver installation could not be verified: $DriverName"
    }

    #Check whether the TCP/IP printer port already exists.
    $ExistingPort = Get-PrinterPort `
        -Name $PortName `
        -ErrorAction SilentlyContinue

    if (-not $ExistingPort) {
        Write-Output "Creating TCP/IP printer port: $PortName"
        Add-PrinterPort `
            -Name $PortName `
            -PrinterHostAddress $PrinterIP `
            -PortNumber $PortNumber
    }
    else {
        Write-Output "Printer port already exists: $PortName"

        #Validate the existing port configuration.
        if (
            $ExistingPort.PrinterHostAddress -ne $PrinterIP -or
            $ExistingPort.PortNumber -ne $PortNumber
        ) {
            throw "Existing printer port configuration does not match the expected IP address or TCP port: $PortName"
        }

        Write-Output "Existing printer port configuration is correct."
    }

    #Check whether the printer queue already exists.

    $ExistingPrinter = Get-Printer `
        -Name $PrinterName `
        -ErrorAction SilentlyContinue

    if ($ExistingPrinter) {

        #Recreate the printer if its driver or port does not match.
        if (
            $ExistingPrinter.DriverName -ne $DriverName -or
            $ExistingPrinter.PortName -ne $PortName
        ) {

            Write-Output "Printer configuration mismatch detected."
            Write-Output "Removing existing printer: $PrinterName"

            Remove-Printer `
                -Name $PrinterName `
                -Confirm:$false

            Write-Output "Creating printer with the expected configuration."

            Add-Printer `
                -Name $PrinterName `
                -DriverName $DriverName `
                -PortName $PortName
        }
        else {
            Write-Output "Printer is already configured correctly: $PrinterName"
        }
    }
    else {

        #Create the printer queue.
        Write-Output "Creating printer: $PrinterName"

        Add-Printer `
            -Name $PrinterName `
            -DriverName $DriverName `
            -PortName $PortName
    }

    #Verify the final printer configuration.
    $InstalledPrinter = Get-Printer `
        -Name $PrinterName `
        -ErrorAction SilentlyContinue

    if (
        -not $InstalledPrinter -or
        $InstalledPrinter.DriverName -ne $DriverName -or
        $InstalledPrinter.PortName -ne $PortName
    ) {
        throw "Printer installation verification failed: $PrinterName"
    }
    Write-Output "Printer installation completed successfully."
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
