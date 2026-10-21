<#
.SYNOPSIS
    Exports failed Microsoft Intune app installation statuses by device to CSV.
    Author: Simone Termine
    Version: 1.1
    Blog: https://www.endpointninja.com

.DESCRIPTION
    Uses Microsoft Graph Intune reporting and filters OrgDeviceInstallStatus
    for failed or error installation states. This is a read-only report.
#>
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path (Get-Location).Path ("Intune-App-Install-Failures-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))),
    [ValidateRange(30, 1800)]
    [int]$TimeoutSeconds = 600,
    [switch]$IncludeAllStatuses
)
$ErrorActionPreference = 'Stop'
$scope = 'DeviceManagementApps.Read.All'

function Connect-IntuneGraph {
    $context = Get-MgContext
    if (-not $context -or $context.AuthType -ne 'Delegated' -or $context.Scopes -notcontains $scope) {
        Connect-MgGraph -Scopes $scope -NoWelcome
    }
}
function Export-IntuneReport {
    param([string]$ReportName, [string[]]$Columns)
    $uri = 'https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs'
    $body = @{ reportName = $ReportName; format = 'csv'; localizationType = 'ReplaceLocalizableValues'; select = $Columns }
    $job = Invoke-MgGraphRequest -Method POST -Uri $uri -Body ($body | ConvertTo-Json -Depth 6) -ContentType 'application/json'
    if (-not $job.id) { throw 'Microsoft Graph did not return an export job identifier.' }
    $statusUri = "$uri('$([uri]::EscapeDataString([string]$job.id))')"
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        Start-Sleep -Seconds 5
        $status = Invoke-MgGraphRequest -Method GET -Uri $statusUri
        if ($status.status -in @('failed', 'error')) { throw "Intune report export failed: $($status.status)" }
        if ($timer.Elapsed.TotalSeconds -ge $TimeoutSeconds) { throw 'Timed out waiting for the Intune report export job.' }
    } while ($status.status -notin @('completed', 'complete'))
    if (-not $status.url) { throw 'The completed export did not return a download URL.' }
    $temp = Join-Path ([IO.Path]::GetTempPath()) ("IntuneAppReport-{0}" -f [guid]::NewGuid())
    New-Item -Path $temp -ItemType Directory -Force | Out-Null
    try {
        $zip = Join-Path $temp 'report.zip'
        Invoke-WebRequest -Uri $status.url -OutFile $zip -UseBasicParsing
        Expand-Archive -LiteralPath $zip -DestinationPath $temp -Force
        $csv = Get-ChildItem -LiteralPath $temp -Filter '*.csv' -File -Recurse | Select-Object -First 1
        if (-not $csv) { throw 'The downloaded report archive did not contain a CSV file.' }
        @{ CsvPath = $csv.FullName; TempRoot = $temp }
    }
    catch {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
        throw
    }
}

try {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        throw 'Install Microsoft.Graph.Authentication with: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser'
    }
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Connect-IntuneGraph
    $columns = @('ApplicationId','AppVersion','DeviceId','DeviceName','ErrorCode','InstallState','InstallStateDetail','LastModifiedDateTime','Platform','UserName','UserPrincipalName')
    $export = Export-IntuneReport -ReportName 'OrgDeviceInstallStatus' -Columns $columns
    try {
        $allRows = @(Import-Csv -LiteralPath $export.CsvPath)
        if ($IncludeAllStatuses) { $rows = $allRows }
        else { $rows = @($allRows | Where-Object { [string]$_.InstallState -match '(?i)fail|error' }) }
        $fullPath = [IO.Path]::GetFullPath($OutputPath)
        $parent = Split-Path -Parent $fullPath
        if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }
        if ($rows.Count) { $rows | Export-Csv -LiteralPath $fullPath -NoTypeInformation -Encoding UTF8 }
        else { ($columns -join ',') | Set-Content -LiteralPath $fullPath -Encoding UTF8 }
        Write-Output ("Exported {0} app installation record(s) to {1}" -f $rows.Count, $fullPath)
    }
    finally {
        if ($export.TempRoot -and (Test-Path -LiteralPath $export.TempRoot)) { Remove-Item -LiteralPath $export.TempRoot -Recurse -Force }
    }
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
