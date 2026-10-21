<#
.SYNOPSIS
    Checks Windows Update certificate-rotation readiness for the 2027 deadlines.
    Author: Simone Termine
    Version: 1.1
    Blog: https://www.endpointninja.com

.DESCRIPTION
    Read-only Intune Remediations detection script. It compares the installed
    Windows build with the minimum cumulative-update build identified by
    Microsoft's October 2026 guidance. It does not inspect certificate
    thumbprints, install updates, change update policy, or modify certificates.

    Intune Remediations supports detection-only script packages. A non-zero
    exit code reports a detected condition; exit code 0 with no output means
    no action is indicated by this check.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Write-DetectionResult {
    param(
        [Parameter(Mandatory)] [string] $Status,
        [Parameter(Mandatory)] [string] $Reason,
        [Parameter(Mandatory)] [string] $OperatingSystem,
        [string] $DisplayVersion,
        [string] $InstalledBuild,
        [string] $RequiredBuild,
        [string] $Deadline
    )

    [PSCustomObject]@{
        Status          = $Status
        Reason          = $Reason
        OperatingSystem = $OperatingSystem
        DisplayVersion  = $DisplayVersion
        InstalledBuild  = $InstalledBuild
        RequiredBuild   = $RequiredBuild
        Deadline        = $Deadline
    } | ConvertTo-Json -Compress | Write-Output
    exit 1
}

try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $cv = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

    $caption = [string]$os.Caption
    $productName = [string]$cv.ProductName
    $displayVersion = [string]$cv.DisplayVersion
    $buildNumber = [int]$cv.CurrentBuildNumber
    $ubr = [int]$cv.UBR
    $installedBuild = '{0}.{1}' -f $buildNumber, $ubr

    # Microsoft states that the 2027 Windows Update certificate rotation
    # does not apply to devices receiving updates through WSUS.
    $wuPolicy = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -ErrorAction SilentlyContinue
    if ($null -ne $wuPolicy -and [int]$wuPolicy.UseWUServer -eq 1) {
        exit 0
    }

    $isServer = $caption -match 'Windows Server'
    $isWindows11 = $caption -match 'Windows 11' -or $productName -match '^Windows 11'
    $isWindows10 = ($caption -match 'Windows 10' -or $productName -match '^Windows 10') -and -not $isServer

    # Windows 11 25H2 and later: Microsoft says no additional action is required.
    if ($isWindows11 -and $displayVersion -match '^(\d{2})H([12])$') {
        $releaseYear = [int]$Matches[1]
        $releaseHalf = [int]$Matches[2]
        if (($releaseYear -gt 25) -or ($releaseYear -eq 25 -and $releaseHalf -ge 2)) {
            exit 0
        }
    }

    $minimumBuild = $null
    $deadline = '2027-06-19'
    $baseline = $null

    if ($isServer -and $caption -match 'Windows Server 2025') {
        $minimumBuild = [version]'26100.6584'
        $baseline = '2025-09 security update (KB5065426)'
    }
    elseif ($isWindows11 -and $displayVersion -eq '24H2') {
        $minimumBuild = [version]'26100.6584'
        $baseline = '2025-09 security update (KB5065426)'
    }
    elseif ($isWindows11 -and $displayVersion -eq '23H2') {
        $minimumBuild = [version]'22631.7376'
        $baseline = '2026-07 security update (KB5099414)'
    }
    elseif ($isServer -and $caption -match 'Windows Server 2022') {
        $minimumBuild = [version]'20348.5386'
        $baseline = '2026-07 security update (KB5099540)'
    }
    elseif ($isWindows10 -and $buildNumber -eq 19045) {
        $minimumBuild = [version]'19045.7548'
        $baseline = '2026-07 security update (KB5099539); Windows 10 22H2 support entitlement must be verified separately'
    }
    elseif ($isWindows10 -and $buildNumber -eq 19044) {
        $minimumBuild = [version]'19044.7548'
        $baseline = '2026-07 security update (KB5099539); applies to supported Windows 10 21H2/LTSC servicing'
    }
    elseif (($isServer -and $caption -match 'Windows Server 2019') -or ($isWindows10 -and $buildNumber -eq 17763)) {
        $minimumBuild = [version]'17763.9020'
        $baseline = '2026-07 security update (KB5099538)'
        $deadline = '2027-05-17'
    }
    elseif ($isServer -and $caption -match 'Windows Server 2016') {
        $minimumBuild = [version]'14393.9339'
        $baseline = '2026-07 security update (KB5099535)'
        $deadline = '2027-05-17'
    }

    if ($null -eq $minimumBuild) {
        Write-DetectionResult -Status 'ManualReview' `
            -Reason 'The operating-system release is not covered by this script baseline. Confirm support status and the applicable Windows Update source.' `
            -OperatingSystem $caption -DisplayVersion $displayVersion -InstalledBuild $installedBuild `
            -RequiredBuild 'Unknown' -Deadline 'See Microsoft guidance for this OS release'
    }

    $currentBuild = [version]$installedBuild
    if ($currentBuild -lt $minimumBuild) {
        Write-DetectionResult -Status 'UpdateRequired' `
            -Reason ("Installed build is below the minimum build for the {0}. Deploy the relevant cumulative security update through the configured update service." -f $baseline) `
            -OperatingSystem $caption -DisplayVersion $displayVersion -InstalledBuild $installedBuild `
            -RequiredBuild $minimumBuild.ToString() -Deadline $deadline
    }

    #Compliant by the build-based readiness check. Keep stdout empty so that
    #Intune reports no detected issue for a detection-only package.
    exit 0
}
catch {
    Write-DetectionResult -Status 'DetectionError' `
        -Reason $_.Exception.Message -OperatingSystem 'Unknown' -DisplayVersion 'Unknown' `
        -InstalledBuild 'Unknown' -RequiredBuild 'Unknown' -Deadline 'Unknown'
}
