<#
.SYNOPSIS
    Collects Windows Update logs, event records, service state, and policy details for support.
    Author: Simone Termine
    Version: 1.1
    Blog: https://www.endpointninja.com

.DESCRIPTION
    Creates a ZIP support bundle for Windows Update troubleshooting on Windows 10
    and Windows 11. The script gathers diagnostics only and does not change policy.
#>
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path (Get-Location).Path ("WindowsUpdateDiagnostics-{0}-{1}.zip" -f $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMdd-HHmmss'))),
    [ValidateRange(1, 30)]
    [int]$Days = 7,
    [ValidateRange(100, 20000)]
    [int]$MaxEventsPerLog = 2000
)
$ErrorActionPreference = 'Stop'
$work = Join-Path ([IO.Path]::GetTempPath()) ("WindowsUpdateDiagnostics-{0}" -f [guid]::NewGuid())
New-Item -Path $work -ItemType Directory -Force | Out-Null
$collectionLog = Join-Path $work 'CollectionNotes.txt'

function Add-CollectionNote {
    param([string]$Message)
    Add-Content -LiteralPath $collectionLog -Value ("[{0}] {1}" -f (Get-Date -Format s), $Message) -Encoding UTF8
}

try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    if ($os.Caption -notmatch 'Windows 10|Windows 11') { throw 'This collector is intended for Windows 10 and Windows 11.' }
    @(
        "ComputerName: $env:COMPUTERNAME"
        "CollectedAt: $(Get-Date -Format o)"
        "OSCaption: $($os.Caption)"
        "OSVersion: $($os.Version)"
        "BuildNumber: $($os.BuildNumber)"
        "LastBootUpTime: $($os.LastBootUpTime)"
        "PowerShellVersion: $($PSVersionTable.PSVersion)"
        "CollectionWindowDays: $Days"
    ) | Set-Content -LiteralPath (Join-Path $work 'SystemInformation.txt') -Encoding UTF8

    $serviceNames = @('wuauserv','bits','UsoSvc','DoSvc','WaaSMedicSvc')
    Get-CimInstance -ClassName Win32_Service |
        Where-Object Name -in $serviceNames |
        Select-Object Name, DisplayName, State, StartMode, StartName, ExitCode |
        Export-Csv -LiteralPath (Join-Path $work 'WindowsUpdateServices.csv') -NoTypeInformation -Encoding UTF8

    $registryPaths = @(
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU',
        'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update'
    )
    $registryRows = foreach ($path in $registryPaths) {
        if (Test-Path -LiteralPath $path) {
            $item = Get-ItemProperty -LiteralPath $path
            foreach ($property in $item.PSObject.Properties | Where-Object Name -notmatch '^PS') {
                [PSCustomObject]@{
                    RegistryPath = $path
                    Name = $property.Name
                    Value = ($property.Value | ConvertTo-Json -Compress -Depth 5)
                }
            }
        }
    }
    if ($registryRows) { $registryRows | Export-Csv -LiteralPath (Join-Path $work 'WindowsUpdatePolicyRegistry.csv') -NoTypeInformation -Encoding UTF8 }
    else { 'RegistryPath,Name,Value' | Set-Content -LiteralPath (Join-Path $work 'WindowsUpdatePolicyRegistry.csv') -Encoding UTF8 }

    try {
        Get-WindowsUpdateLog -LogPath (Join-Path $work 'WindowsUpdate.log') -ErrorAction Stop | Out-Null
        Add-CollectionNote 'Generated WindowsUpdate.log with Get-WindowsUpdateLog.'
    }
    catch { Add-CollectionNote ("Get-WindowsUpdateLog failed: {0}" -f $_.Exception.Message) }

    $eventLogs = @('Microsoft-Windows-WindowsUpdateClient/Operational','Microsoft-Windows-UpdateOrchestrator/Operational','Microsoft-Windows-DeliveryOptimization/Operational')
    foreach ($logName in $eventLogs) {
        $safeName = $logName -replace '[\\/:*?"<>|]', '_'
        $eventPath = Join-Path $work ($safeName + '.csv')
        try {
            $events = @(Get-WinEvent -FilterHashtable @{ LogName = $logName; StartTime = (Get-Date).AddDays(-$Days) } -MaxEvents $MaxEventsPerLog -ErrorAction Stop)
            if ($events.Count) {
                $events | Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
                    Export-Csv -LiteralPath $eventPath -NoTypeInformation -Encoding UTF8
            }
            else { 'TimeCreated,Id,LevelDisplayName,ProviderName,Message' | Set-Content -LiteralPath $eventPath -Encoding UTF8 }
            Add-CollectionNote ("Collected {0} event(s) from {1}." -f $events.Count, $logName)
        }
        catch {
            'TimeCreated,Id,LevelDisplayName,ProviderName,Message' | Set-Content -LiteralPath $eventPath -Encoding UTF8
            Add-CollectionNote ("Could not read event log {0}: {1}" -f $logName, $_.Exception.Message)
        }
    }

    $fullPath = [IO.Path]::GetFullPath($OutputPath)
    $parent = Split-Path -Parent $fullPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }
    if (Test-Path -LiteralPath $fullPath) { Remove-Item -LiteralPath $fullPath -Force }
    Compress-Archive -Path (Join-Path $work '*') -DestinationPath $fullPath -CompressionLevel Optimal
    Write-Output ("Windows Update diagnostics saved to {0}" -f $fullPath)
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
