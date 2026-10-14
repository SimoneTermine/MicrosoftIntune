<#
.SYNOPSIS
    Reports whether the operating-system volume is fully encrypted and protected by BitLocker.

.DESCRIPTION
    Detection-only script. It does not enable BitLocker, change protectors, or read recovery passwords.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    if (-not (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue)) {
        throw 'Get-BitLockerVolume is unavailable. Confirm that the BitLocker PowerShell feature is installed.'
    }

    $volume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
    if ($null -eq $volume) { throw "Could not retrieve BitLocker state for $env:SystemDrive." }

    $isProtected = $volume.ProtectionStatus -eq 'On'
    $isEncrypted = $volume.VolumeStatus -eq 'FullyEncrypted'
    $percent = [int]$volume.EncryptionPercentage

    if ($isProtected -and $isEncrypted -and $percent -ge 100) {
        Write-Output "Compliant: $env:SystemDrive is fully encrypted and BitLocker protection is on."
        exit 0
    }

    Write-Output ("Review required: drive={0}; volumeStatus={1}; protectionStatus={2}; encryptionPercentage={3}." -f $env:SystemDrive, $volume.VolumeStatus, $volume.ProtectionStatus, $percent)
    exit 1
}
catch {
    Write-Output "Detection error: $($_.Exception.Message)"
    exit 1
}
