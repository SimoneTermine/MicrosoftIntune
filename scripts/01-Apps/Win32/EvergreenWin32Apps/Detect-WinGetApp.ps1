#Detect-WinGetApp.ps1
$ErrorActionPreference = "Stop"

#========= CONFIG =========
$PackageId = "7zip.7zip" #<<---change with your desired winget packageid (eg. "Google.Chrome", or "Notepad++.Notepad++", etc.)
#==========================

$SafeId    = ($PackageId -replace '[^\w\.-]', '_')
$LogDir    = Join-Path $env:ProgramData "ICTPower\Intune\WingetApps\$SafeId"
New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
$DateStamp = (Get-Date).ToString("dd-MM-yyyy_HH.mm.ss")
$LogFile   = Join-Path $LogDir ("detect_{0}_{1}.log" -f $SafeId, $DateStamp)

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR","DEBUG")][string]$Level = "INFO"
    )
    $ts = (Get-Date).ToString("dd/MM/yyyy HH:mm:ss")
    "[$ts] - [$Level] $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

function Write-LogSeparator { Write-Log ("-" * 60) "DEBUG" }

function Write-LogWingetOutput {
    param([string]$RawOutput, [string]$Tag = "winget output")
    Write-Log "--- $Tag begin ---" "DEBUG"
    ($RawOutput -split "`r?`n") | Where-Object {
        $_ -match '\S' -and
        $_ -notmatch '^\s*[-\\|/]\s*$' -and
        $_ -match '^[\x20-\x7E\t]*$'
    } | ForEach-Object { Write-Log "  | $_" "DEBUG" }
    Write-Log "--- $Tag end ---" "DEBUG"
}

function Get-WinGetPath {
    Write-Log "Resolving winget.exe in WindowsApps (DesktopAppInstaller x64)..." "DEBUG"
    $resolved = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" `
        -ErrorAction SilentlyContinue
    if (-not $resolved) {
        throw "winget.exe not found in WindowsApps. Ensure App Installer is installed and up to date."
    }
    Write-Log "Found $($resolved.Count) winget candidate(s). Using highest version." "DEBUG"
    return $resolved[-1].Path
}

#Parses 'winget list' output by finding the data line that contains the package ID, then extracting version tokens that appear after it.
#Locale-agnostic: no dependency on header text, separator format, or column positions.
#The 'Available' column is only present when winget knows of a newer version.
#Source tokens (e.g. "winget") never start with a digit and are never mistaken for versions.
#Returns: @{ Installed = "x.y.z"; Available = "x.y.z" | $null }  or  $null if not found.
function Get-WinGetAppInfo {
    param([string]$WingetExe, [string]$Id)

    Write-Log "Executing: winget list --id $Id -e --accept-source-agreements" "DEBUG"
    $out  = & $WingetExe list --id $Id -e --accept-source-agreements 2>&1 | Out-String

    Write-LogWingetOutput -RawOutput $out -Tag "winget list output"

    $line = ($out -split "`r?`n") | Where-Object { $_ -match [regex]::Escape($Id) } | Select-Object -First 1
    if (-not $line) {
        Write-Log "No data line matched Id='$Id' in winget output." "DEBUG"
        return $null
    }
    Write-Log "Matched data line: '$($line.Trim())'" "DEBUG"

    #Split on the exact ID to isolate tokens to its right (avoids digits in app display name)
    $afterId  = ($line -split [regex]::Escape($Id), 2)[1]
    Write-Log "Tokens right of ID: '$($afterId.Trim())'" "DEBUG"

    #@() forces array - critical for PS5.1 where a single match is a bare string and [0] returns the first character
    $versions = @([regex]::Matches($afterId, '\b\d[0-9A-Za-z\.\-_]*') | ForEach-Object { $_.Value })
    Write-Log "Version tokens found: [$($versions -join ' | ')]" "DEBUG"

    if ($versions.Count -eq 0) {
        Write-Log "No version tokens found after ID - treating as not installed." "WARN"
        return $null
    }

    $result = @{
        Installed = $versions[0]
        Available = if ($versions.Count -gt 1) { $versions[1] } else { $null }
    }
    Write-Log "Parsed result -> Installed='$($result.Installed)'  Available='$(if ($result.Available) { $result.Available } else { '(none)' })'" "DEBUG"
    return $result
}


#=====================================================================
Write-LogSeparator
Write-Log "START detection"
Write-Log "PackageId  : $PackageId"
Write-Log "LogFile    : $LogFile"
Write-LogSeparator
Write-Log "Execution context" "DEBUG"
Write-Log "  User        : $(whoami)" "DEBUG"
Write-Log "  Hostname    : $env:COMPUTERNAME" "DEBUG"
Write-Log "  OS          : $([System.Environment]::OSVersion.VersionString)" "DEBUG"
Write-Log "  PS version  : $($PSVersionTable.PSVersion)" "DEBUG"
Write-Log "  64-bit proc : $([Environment]::Is64BitProcess)" "DEBUG"
Write-LogSeparator

try {
    #---- Resolve winget ----
    $winget    = Get-WinGetPath
    $wingetDir = Split-Path $winget -Parent
    Set-Location $wingetDir
    Write-Log "winget.exe  : $winget" "DEBUG"
    $wingetVer = (& $winget --version 2>&1 | Out-String).Trim()
    Write-Log "winget ver  : $wingetVer" "DEBUG"
    Write-LogSeparator

    #---- Query installed state ----
    Write-Log "Querying installed state for '$PackageId'..."
    $info = Get-WinGetAppInfo -WingetExe $winget -Id $PackageId
    Write-LogSeparator

    #---- Evaluate ----
    if (-not $info -or -not $info.Installed) {
        Write-Log "RESULT    : NOT INSTALLED - package '$PackageId' not found by winget."
        Write-Log "DECISION  : Intune will trigger the install script."
        Write-LogSeparator
        Write-Log "DETECTION END - exit=1"
        exit 1
    }

    Write-Log "Installed version  : $($info.Installed)"
    Write-Log "Available version  : $(if ($info.Available) { $info.Available } else { '(none - already at latest)' })"

    if ($info.Available) {
        Write-Log "RESULT    : NOT COMPLIANT - upgrade available ($($info.Installed) -> $($info.Available))."
        Write-Log "DECISION  : Intune will trigger the install script to upgrade."
        Write-LogSeparator
        Write-Log "DETECTION END - exit=1"
        exit 1
    }

    Write-Log "RESULT    : COMPLIANT - installed and up-to-date."
    Write-Log "DECISION  : No action required."
    Write-LogSeparator
    Write-Log "DETECTION END - exit=0"
    Write-Output "Installed"
    exit 0
}
catch {
    Write-LogSeparator
    Write-Log "UNHANDLED EXCEPTION: $($_.Exception.Message)" "ERROR"
    Write-Log "ScriptStackTrace:" "ERROR"
    $_.ScriptStackTrace -split "`r?`n" | ForEach-Object { Write-Log "  $_" "ERROR" }
    Write-LogSeparator
    Write-Log "DETECTION END - exit=1" "ERROR"
    exit 1
}
