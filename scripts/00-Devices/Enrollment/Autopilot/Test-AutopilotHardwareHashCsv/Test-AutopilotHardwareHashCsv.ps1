<#
.SYNOPSIS
    Validates a Windows Autopilot hardware hash CSV before importing it into Microsoft Intune.
    Author: Simone Termine
    Version: 1.1
    Blog: https://www.endpointninja.com

.DESCRIPTION
    Checks required headers, blank and duplicate serial numbers, and Base64
    hardware hash values. The validation report never includes the hash.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$CsvPath,
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
try {
    $inputPath = (Resolve-Path -LiteralPath $CsvPath).Path
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path (Split-Path -Parent $inputPath) (([IO.Path]::GetFileNameWithoutExtension($inputPath)) + '.validation.csv')
    }
    $resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
    if ($resolvedOutput -eq [IO.Path]::GetFullPath($inputPath)) { throw 'The report cannot overwrite the source CSV.' }

    $rows = @(Import-Csv -LiteralPath $inputPath)
    if ($rows.Count -eq 0) { throw 'The CSV contains no device rows.' }
    $headers = @($rows[0].PSObject.Properties.Name)
    foreach ($requiredHeader in @('Device Serial Number', 'Hardware Hash')) {
        if ($headers -notcontains $requiredHeader) { throw "Required CSV column is missing: $requiredHeader" }
    }

    $serialCounts = @{}
    foreach ($row in $rows) {
        $serial = ([string]$row.'Device Serial Number').Trim()
        if ($serial) {
            $key = $serial.ToUpperInvariant()
            if (-not $serialCounts.ContainsKey($key)) { $serialCounts[$key] = 0 }
            $serialCounts[$key]++
        }
    }

    $results = for ($index = 0; $index -lt $rows.Count; $index++) {
        $row = $rows[$index]
        $serial = ([string]$row.'Device Serial Number').Trim()
        $hash = ([string]$row.'Hardware Hash').Trim()
        $issues = [System.Collections.Generic.List[string]]::new()
        if (-not $serial) { $issues.Add('Device Serial Number is blank.') }
        elseif ($serialCounts[$serial.ToUpperInvariant()] -gt 1) { $issues.Add('Duplicate Device Serial Number.') }

        if (-not $hash) { $issues.Add('Hardware Hash is blank.') }
        else {
            try {
                $decoded = [Convert]::FromBase64String($hash)
                if ($decoded.Length -eq 0) { $issues.Add('Hardware Hash decodes to an empty value.') }
            }
            catch { $issues.Add('Hardware Hash is not valid Base64.') }
        }
        [PSCustomObject]@{
            CsvRow = $index + 2
            DeviceSerialNumber = $serial
            ValidationStatus = if ($issues.Count) { 'Error' } else { 'Pass' }
            Findings = $issues -join ' '
        }
    }

    $parent = Split-Path -Parent $resolvedOutput
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }
    $results | Export-Csv -LiteralPath $resolvedOutput -NoTypeInformation -Encoding UTF8
    $errorCount = @($results | Where-Object ValidationStatus -eq 'Error').Count
    Write-Output ("Rows checked: {0}; passed: {1}; rows to fix: {2}" -f $rows.Count, ($rows.Count - $errorCount), $errorCount)
    Write-Output ("Validation report: {0}" -f $resolvedOutput)
    if ($errorCount) { exit 1 }
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
