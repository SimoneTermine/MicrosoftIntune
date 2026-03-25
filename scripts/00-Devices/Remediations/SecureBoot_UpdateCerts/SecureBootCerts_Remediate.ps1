# Remediation - Secure Boot CA 2023 rollout (AvailableUpdates=0x5944) with in-progress guardrails
# Runs as SYSTEM in Intune Proactive Remediations

$ErrorActionPreference = 'Stop'

$RegSecureBoot   = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
$RegServicing    = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing'
$ValueName       = 'AvailableUpdates'
$TargetValue     = 0x5944  # hex
$TaskPath        = '\Microsoft\Windows\PI\'
$TaskName        = 'Secure-Boot-Update'

function Get-UEFICA2023Present {
    try {
        # Look for "Windows UEFI CA 2023" in UEFI db
        $db = Get-SecureBootUEFI db
        return ([System.Text.Encoding]::ASCII.GetString($db.Bytes) -match 'Windows UEFI CA 2023')
    } catch {
        # If Secure Boot/UEFI cmdlets not available, don't hard-fail the remediation
        Write-Output "WARN: Get-SecureBootUEFI failed ($($_.Exception.Message))."
        return $false
    }
}

try {
    # 0) Read AvailableUpdates early (so we can report reboot-required clearly)
    $current = $null
    if (Test-Path $RegSecureBoot) {
        $current = (Get-ItemProperty -Path $RegSecureBoot -Name $ValueName -ErrorAction SilentlyContinue).$ValueName
    }
    if ($current -eq $null) { $current = 0 }
    Write-Output ("INFO: Current AvailableUpdates = 0x{0:X4}." -f [int]$current)

    # If reboot required, do nothing (avoid re-triggering)
    if ([int]$current -eq 0x4100) {
        Write-Output "OK: Reboot required (AvailableUpdates=0x4100). No registry changes."
        exit 0
    }

    # 1) Read servicing status/error (if present)
    $status = $null
    $err    = $null

    if (Test-Path $RegServicing) {
        $p = Get-ItemProperty -Path $RegServicing -ErrorAction SilentlyContinue
        $status = $p.UEFICA2023Status
        $err    = $p.UEFICA2023Error
    }

    if ($status) { Write-Output "INFO: UEFICA2023Status = '$status'." }
    if ($err -ne $null) { Write-Output ("INFO: UEFICA2023Error = 0x{0:X8}." -f [uint32]$err) }

    # 2) If an error is present, don't keep forcing; exit cleanly
    if (($err -ne $null) -and ([uint32]$err -ne 0)) {
        Write-Output "WARN: UEFICA2023Error is non-zero. Not forcing AvailableUpdates; investigate."
        exit 0
    }

    # 3) If update is in progress or updated, do NOT touch AvailableUpdates
    if ($status -match '^In\s*Progress$' -or $status -match '^InProgress$') {
        Write-Output "OK: Update is already in progress. Not touching AvailableUpdates."
        exit 0
    }
    if ($status -match '^Updated$' -or $status -match '^Aggiornato$') {
        Write-Output "OK: Status reports Updated. Not touching AvailableUpdates."
        exit 0
    }

    # 4) If AvailableUpdates indicates processing (bits being cleared), do NOT reset it
    # (anything non-zero and not 0x5944 means progress states like 0x4000, etc.)
    if (($current -ne 0) -and ($current -ne $TargetValue)) {
        Write-Output "OK: AvailableUpdates already shows partial/progress state. Not resetting it."
        exit 0
    }
    if ($current -eq $TargetValue) {
        Write-Output "OK: AvailableUpdates already set to 0x5944. No change."
        exit 0
    }

    # 5) Optional info: CA presence in DB (do not treat as completion)
    if (Get-UEFICA2023Present) {
        Write-Output "INFO: 'Windows UEFI CA 2023' is present in Secure Boot db."
        # We still continue, because completion may also depend on boot manager + reboots.
    }

    # 6) Ensure key exists and set AvailableUpdates = 0x5944
    if (-not (Test-Path $RegSecureBoot)) {
        New-Item -Path $RegSecureBoot -Force | Out-Null
    }

    New-ItemProperty -Path $RegSecureBoot -Name $ValueName -PropertyType DWord -Value $TargetValue -Force | Out-Null
    Write-Output "FIX: Set AvailableUpdates to 0x5944."

    # 7) Optional: trigger the scheduled task to process immediately
    try {
        $t = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($t) {
            Start-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName
            Write-Output "INFO: Triggered scheduled task '$TaskPath$TaskName'."
        } else {
            Write-Output "INFO: Scheduled task '$TaskPath$TaskName' not found. Windows will process on its normal schedule."
        }
    } catch {
        Write-Output "WARN: Could not start scheduled task ($($_.Exception.Message))."
    }

    exit 0
}
catch {
    Write-Output "ERROR: Remediation failed: $($_.Exception.Message)"
    exit 1
}