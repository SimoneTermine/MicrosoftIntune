<#
.SYNOPSIS
    Detects a printer installed through Microsoft Intune.

.DESCRIPTION
    This script is intended to be used as a custom detection rule
    for a Microsoft Intune Win32 app.

    The script verifies:

    - Printer name.
    - Printer driver name.
    - Printer port name.
    - Printer IP address.
    - Printer TCP port number.

    Detection succeeds only when all expected values match.

    Exit code 0 with STDOUT:
    Printer detected.

    Exit code 1:
    Printer not detected or configuration mismatch.

.NOTES
    Author: Simone Termine
    Website: https://www.endpointninja.com

    CUSTOMIZATION:

    Update the variables in the CUSTOMIZE THIS SECTION block
    before uploading the script to Microsoft Intune.

    The values must match the configuration used by
    Install-Printer.ps1.

    192.168.0.126 is a documentation-only IP address.
#>


# ============================================================
# CUSTOMIZE THIS SECTION
# ============================================================

#Enter the exact printer name.
$PrinterName = "IT Floor 1 - EPSON WF-2510"

#Enter the exact printer driver name.
$ExpectedDriverName = "EPSON WF-2510 Series"

#Enter the expected TCP/IP printer port name.
$ExpectedPortName = "IP_192.168.0.126"

#Enter the printer IP address or DNS name.
$ExpectedPrinterIP = "192.168.0.126"

#Enter the TCP port number used by the printer.
$ExpectedPortNumber = 9100


# ============================================================
# DO NOT MODIFY BELOW THIS LINE
# ============================================================


#Check whether the printer exists.
$Printer = Get-Printer `
    -Name $PrinterName `
    -ErrorAction SilentlyContinue

if ($null -eq $Printer) {
    exit 1
}

#Verify the printer driver and port name.
if (
    $Printer.DriverName -ne $ExpectedDriverName -or
    $Printer.PortName -ne $ExpectedPortName
) {
    exit 1
}

#Check whether the printer port exists.
$PrinterPort = Get-PrinterPort `
    -Name $ExpectedPortName `
    -ErrorAction SilentlyContinue

if ($null -eq $PrinterPort) {
    exit 1
}

#Verify the printer IP address and TCP port number.
if (
    $PrinterPort.PrinterHostAddress -ne $ExpectedPrinterIP -or
    $PrinterPort.PortNumber -ne $ExpectedPortNumber
) {
    exit 1
}

#Printer detected with the expected configuration.
Write-Output "Detected"
exit 0
