$ErrorActionPreference = 'SilentlyContinue'

$regSB   = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
$regServ = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing'

$avail  = (Get-ItemProperty -Path $regSB   -Name AvailableUpdates -ErrorAction SilentlyContinue).AvailableUpdates
$status = (Get-ItemProperty -Path $regServ -Name UEFICA2023Status -ErrorAction SilentlyContinue).UEFICA2023Status
$err    = (Get-ItemProperty -Path $regServ -Name UEFICA2023Error  -ErrorAction SilentlyContinue).UEFICA2023Error

if ($null -eq $avail) { $avail = 0 }
$availInt = [int]$avail
$availHex = ('0x{0:X4}' -f $availInt)

# REBOOT REQUIRED => NON COMPLIANT
if ($availInt -eq 0x4100) {
    Write-Output "Non-Compliant: Reboot required (AvailableUpdates=$availHex)."
    exit 1
}

# Error => non compliant
if ($err -ne $null -and [uint32]$err -ne 0) {
    Write-Output ("Non-Compliant: UEFICA2023Error=0x{0:X8} (AvailableUpdates={1})" -f [uint32]$err, $availHex)
    exit 1
}

if ($null -eq $status) { $status = '' }
$s = (($status -replace '\s','').ToLower())

if ($s -eq 'inprogress' -or $s -eq 'updated') {
    Write-Output "Compliant: UEFICA2023Status=$status (AvailableUpdates=$availHex)"
    exit 0
}

# FALLBACK: DB Check
try {
    $match = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'
    if ($match) { Write-Output "Compliant: Windows UEFI CA 2023 found in db. (AvailableUpdates=$availHex)"; exit 0 }
} catch {}

Write-Output "Non-Compliant: Not updated or not in progress. (AvailableUpdates=$availHex)"
exit 1