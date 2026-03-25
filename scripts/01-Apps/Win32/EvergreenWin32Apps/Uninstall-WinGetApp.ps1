#Uninstall-WinGetApp.ps1
$ErrorActionPreference = "Stop"

#========= CONFIG =========
$PackageId = "7zip.7zip" #<<---change with your desired winget packageid (eg. "Google.Chrome", or "Notepad++.Notepad++", etc.)
#==========================

$SafeId    = ($PackageId -replace '[^\w\.-]', '_')
$LogDir    = Join-Path $env:ProgramData "ICTPower\Intune\WingetApps\$SafeId"
New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
$DateStamp = (Get-Date).ToString("dd-MM-yyyy_HH.mm.ss")
$LogFile   = Join-Path $LogDir ("uninstall_{0}_{1}.log" -f $SafeId, $DateStamp)

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

function Get-InstalledVersion {
    param([string]$WingetExe, [string]$Id)

    Write-Log "Executing: winget list --id $Id -e --accept-source-agreements" "DEBUG"
    $out  = & $WingetExe list --id $Id -e --accept-source-agreements 2>&1 | Out-String

    Write-LogWingetOutput -RawOutput $out -Tag "winget list output"

    $line = ($out -split "`r?`n") | Where-Object { $_ -match [regex]::Escape($Id) } | Select-Object -First 1
    if (-not $line) {
        Write-Log "No data line matched Id='$Id' - package appears not installed." "DEBUG"
        return $null
    }
    Write-Log "Matched data line: '$($line.Trim())'" "DEBUG"

    $afterId  = ($line -split [regex]::Escape($Id), 2)[1]
    #@() forces array - critical for PS5.1 where a single match is a bare string and [0] returns the first character
    $versions = @([regex]::Matches($afterId, '\b\d[0-9A-Za-z\.\-_]*') | ForEach-Object { $_.Value })
    Write-Log "Version tokens found: [$($versions -join ' | ')]" "DEBUG"

    if ($versions.Count -eq 0) { return $null }
    return $versions[0]
}


#=====================================================================
Write-LogSeparator
Write-Log "START uninstallation"
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

    #---- Pre-check ----
    Write-Log "PRE-CHECK: verifying current installed state..."
    $currentVersion = Get-InstalledVersion -WingetExe $winget -Id $PackageId
    Write-LogSeparator

    if (-not $currentVersion) {
        Write-Log "PRE-CHECK RESULT: package '$PackageId' is not installed. Nothing to uninstall."
        Write-LogSeparator
        Write-Log "UNINSTALL END - exit=0"
        exit 0
    }

    Write-Log "PRE-CHECK RESULT: found installed version $currentVersion. Proceeding with uninstall."

    #---- Run winget uninstall ----
    $wingetArgs = @(
        "uninstall", "--id", $PackageId, "-e",
        "--silent",
        "--accept-source-agreements", "--disable-interactivity"
    )

    Write-LogSeparator
    Write-Log "Executing: winget $($wingetArgs -join ' ')" "DEBUG"
    $result     = & $winget @wingetArgs 2>&1
    $wingetExit = $LASTEXITCODE

    Write-LogWingetOutput -RawOutput ($result | Out-String) -Tag "winget uninstall output"
    Write-Log "winget exit code: $wingetExit"
    Write-LogSeparator

    #---- Post-check ----
    Write-Log "POST-CHECK: verifying package has been removed..."
    $stillInstalled = Get-InstalledVersion -WingetExe $winget -Id $PackageId
    Write-LogSeparator

    if ($stillInstalled) {
        Write-Log "POST-CHECK RESULT: package still present (v$stillInstalled) after uninstall attempt." "ERROR"
        Write-Log "Reporting FAILURE to Intune." "ERROR"
        Write-LogSeparator
        Write-Log "UNINSTALL END - exit=1" "ERROR"
        exit 1
    }

    Write-Log "POST-CHECK RESULT: package successfully removed."
    Write-LogSeparator
    Write-Log "UNINSTALL END - exit=0"
    exit 0
}
catch {
    Write-LogSeparator
    Write-Log "UNHANDLED EXCEPTION: $($_.Exception.Message)" "ERROR"
    Write-Log "ScriptStackTrace:" "ERROR"
    $_.ScriptStackTrace -split "`r?`n" | ForEach-Object { Write-Log "  $_" "ERROR" }
    Write-LogSeparator
    Write-Log "UNINSTALL END - exit=1" "ERROR"
    exit 1
}
