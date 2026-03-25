#Install-WinGetApp.ps1
$ErrorActionPreference = "Stop"

#========= CONFIG =========
$PackageId    = "7zip.7zip" #<<---change with your desired winget packageid (eg. "Google.Chrome", or "Notepad++.Notepad++", etc.)
$Scope        = "machine"
#Optional: override process name for app-in-use detection.
#Leave empty to use automatic detection (recommended).
#Use only if all 5 auto-detection strategies fail for this specific app.
#Example: $ProcessNameOverride = "chrome"
$ProcessNameOverride = "7zG"
#==========================

$SafeId    = ($PackageId -replace '[^\w\.-]', '_')
$LogDir    = Join-Path $env:ProgramData "ICTPower\Intune\WingetApps\$SafeId"
New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
$DateStamp = (Get-Date).ToString("dd-MM-yyyy_HH.mm.ss")

$LogFile       = Join-Path $LogDir ("install_{0}_{1}.log" -f $SafeId, $DateStamp)
$WinGetLogFile = Join-Path $LogDir ("winget_{0}_{1}.log"  -f $SafeId, $DateStamp)

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR","DEBUG")][string]$Level = "INFO"
    )
    $ts = (Get-Date).ToString("dd/MM/yyyy HH:mm:ss")
    "[$ts] - [$Level] $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

function Write-LogSeparator { Write-Log ("-" * 60) "DEBUG" }

#Logs winget output lines, stripping progress-bar noise:
#   - Spinner lines:   "   - "  "   \ "  "   | "  "   / "
#   - Progress bars:   lines containing non-printable / non-ASCII characters (box-drawing glyphs)
#Only lines composed entirely of printable ASCII (0x20-0x7E) plus tab are written.
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
#NOTE: result wrapped in @() to force array - prevents PS5.1 string-index bug where a single-element pipeline result is a string and [0] returns the first character.
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

    $afterId  = ($line -split [regex]::Escape($Id), 2)[1]
    Write-Log "Tokens right of ID: '$($afterId.Trim())'" "DEBUG"

    #@() forces array - critical for PS5.1 where a single match is a bare string
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

#Returns $true if the package is installed AND winget reports no available upgrade.
function Test-AppCompliant {
    param([string]$WingetExe)
    Write-Log "Running compliance check for '$PackageId'..." "DEBUG"
    $info = Get-WinGetAppInfo -WingetExe $WingetExe -Id $PackageId
    if (-not $info -or -not $info.Installed) {
        Write-Log "Compliance check: NOT INSTALLED." "DEBUG"
        return $false
    }
    if ($info.Available) {
        Write-Log "Compliance check: INSTALLED but upgrade available ($($info.Installed) -> $($info.Available))." "DEBUG"
        return $false
    }
    Write-Log "Compliance check: COMPLIANT (installed=$($info.Installed), no upgrade pending)." "DEBUG"
    return $true
}

#Detects running processes belonging to the package being upgraded.
#Uses a 5-strategy fallback chain so it works regardless of installer type
#(MSI, NSIS, Inno, MSIX, portable) and regardless of whether InstallLocation is set.
#
#Strategy 1: InstallLocation registry key  --> scan processes by path
#Strategy 2: DisplayIcon registry key      --> scan processes by path
#Strategy 3: UninstallString (non-MSI exe) --> scan processes by path
#Strategy 4: winget show                   --> scan processes by path
#Strategy 5: process name hint             --> fuzzy match on ProcessName (last segment of PackageId)
#
#Returns a list of matching [System.Diagnostics.Process] objects (may be empty).
#Never throws - all errors are caught and logged.
function Get-AppRunningProcesses {
    param([string]$WingetExe, [string]$Id, [string]$NameOverride = "")

    $appNameHint = ($Id -split '\.')[-1].ToLower()
    Write-Log "Detecting running processes for '$Id' (hint: '$appNameHint')..." "DEBUG"

    # Helper: given a folder path, return all processes running from under it
    function Find-ProcessesUnderPath([string]$FolderPath) {
        if (-not $FolderPath -or -not (Test-Path $FolderPath)) { return @() }
        $base = $FolderPath.ToLower().TrimEnd('\')
        return @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
            try { $exe = $_.MainModule.FileName; $exe -and $exe.ToLower().StartsWith($base) }
            catch { $false }
        })
    }

    #Collect registry entries matching the app name hint (all hives, 32+64 bit)
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $regEntry = $(foreach ($rp in $regPaths) {
        Get-ItemProperty $rp -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match $appNameHint }
    }) | Select-Object -First 1

    #--- Strategy 1: InstallLocation ---
    if ($regEntry -and $regEntry.InstallLocation) {
        $loc = $regEntry.InstallLocation.TrimEnd('\')
        Write-Log "Strategy 1 (InstallLocation): testing path '$loc'..." "DEBUG"
        if (Test-Path $loc) {
            $procs = Find-ProcessesUnderPath $loc
            Write-Log "Strategy 1: path valid, found $($procs.Count) process(es)." "DEBUG"
            return $procs
        }
        Write-Log "Strategy 1: path does not exist - trying next." "DEBUG"
    } else { Write-Log "Strategy 1: InstallLocation not set - trying next." "DEBUG" }

    #--- Strategy 2: parent folder of DisplayIcon ---
    if ($regEntry -and $regEntry.DisplayIcon) {
        $iconExe = ($regEntry.DisplayIcon -split ',')[0].Trim('"').Trim("'")
        Write-Log "Strategy 2 (DisplayIcon): testing '$iconExe'..." "DEBUG"
        if ($iconExe -match '\.(exe|dll)$' -and (Test-Path $iconExe)) {
            $loc = Split-Path $iconExe -Parent
            $procs = Find-ProcessesUnderPath $loc
            Write-Log "Strategy 2: path valid ('$loc'), found $($procs.Count) process(es)." "DEBUG"
            return $procs
        }
        Write-Log "Strategy 2: DisplayIcon path not usable - trying next." "DEBUG"
    } else { Write-Log "Strategy 2: DisplayIcon not set - trying next." "DEBUG" }

    #--- Strategy 3: parent folder of exe in UninstallString (non-MSI only) ---
    if ($regEntry -and $regEntry.UninstallString) {
        $uninstExe = (($regEntry.UninstallString -split '\s+/')[0]).Trim('"').Trim("'")
        Write-Log "Strategy 3 (UninstallString): testing '$uninstExe'..." "DEBUG"
        if ($uninstExe -match '\.exe$' -and $uninstExe -notmatch '(?i)msiexec' -and (Test-Path $uninstExe)) {
            $loc = Split-Path $uninstExe -Parent
            $procs = Find-ProcessesUnderPath $loc
            Write-Log "Strategy 3: path valid ('$loc'), found $($procs.Count) process(es)." "DEBUG"
            return $procs
        }
        Write-Log "Strategy 3: UninstallString not usable ('$($regEntry.UninstallString)') - trying next." "DEBUG"
    } else { Write-Log "Strategy 3: UninstallString not set - trying next." "DEBUG" }

    #--- Strategy 4: winget show (parses install path from package metadata) ---
    Write-Log "Strategy 4 (winget show): querying metadata for '$Id'..." "DEBUG"
    try {
        $showOut  = & $WingetExe show --id $Id -e --accept-source-agreements 2>&1 | Out-String
        $showLine = ($showOut -split "`r?`n") |
                    Where-Object { $_ -match '(?i)(install\s*location|install\s*path|location)\s*:' } |
                    Select-Object -First 1
        if ($showLine) {
            $loc = ($showLine -split ':', 2)[1].Trim().TrimEnd('\')
            if ($loc -and (Test-Path $loc)) {
                $procs = Find-ProcessesUnderPath $loc
                Write-Log "Strategy 4: path valid ('$loc'), found $($procs.Count) process(es)." "DEBUG"
                return $procs
            }
            Write-Log "Strategy 4: path from winget show does not exist ('$loc') - trying next." "DEBUG"
        } else { Write-Log "Strategy 4: no install location in winget show output - trying next." "DEBUG" }
    } catch { Write-Log "Strategy 4: exception querying winget show - trying next." "DEBUG" }

    #--- Strategy 5: process name fuzzy match on PackageId hint (or manual override) ---
    #This is the universal fallback: matches any running process whose name contains
    #the app name hint (e.g. "chrome" from "Google.Chrome").
    #A manual $ProcessNameOverride in CONFIG bypasses all previous strategies entirely.
    $matchName = if ($NameOverride -ne "") { $NameOverride.ToLower() } else { $appNameHint }
    Write-Log "Strategy 5 (process name hint): searching for processes matching '$matchName'..." "DEBUG"
    $procs = @(Get-Process -ErrorAction SilentlyContinue |
               Where-Object { $_.ProcessName.ToLower() -match [regex]::Escape($matchName) })
    Write-Log "Strategy 5: found $($procs.Count) process(es) matching '$matchName'." "DEBUG"
    return $procs
}


#=====================================================================
Write-LogSeparator
Write-Log "START installation"
Write-Log "PackageId      : $PackageId"
Write-Log "Scope          : $Scope"
Write-Log "ProcessOverride: $(if ($ProcessNameOverride) { $ProcessNameOverride } else { '(auto)' })"
Write-Log "LogFile        : $LogFile"
Write-Log "WinGet LogFile : $WinGetLogFile"
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

    #---- Pre-check: already compliant? ----
    Write-Log "PRE-CHECK: verifying current installed state..."
    if (Test-AppCompliant -WingetExe $winget) {
        $info = Get-WinGetAppInfo -WingetExe $winget -Id $PackageId
        Write-Log "PRE-CHECK RESULT: already at latest version ($($info.Installed)). Nothing to do."
        Write-LogSeparator
        Write-Log "INSTALL END - exit=0"
        exit 0
    }
    Write-LogSeparator

    #---- Decide install vs upgrade ----
    $info = Get-WinGetAppInfo -WingetExe $winget -Id $PackageId

    $commonArgs = @(
        "--id", $PackageId, "-e",
        "--silent",
        "--accept-package-agreements", "--accept-source-agreements", "--disable-interactivity",
        "--scope", $Scope,
        "--log", $WinGetLogFile
    )

    if ($info -and $info.Installed) {
        Write-Log "DECISION: package installed (v$($info.Installed)) but not at latest (available: $($info.Available)). Running UPGRADE."
        $wingetArgs = @("upgrade") + $commonArgs

        #---- App-in-use guard (upgrade only) ----
        #If the app is currently running we defer: exit 0 so Intune does not count a failure,
        #but detection will still return 1 at the next cycle and trigger a retry automatically.
        Write-LogSeparator
        Write-Log "APP-IN-USE CHECK: verifying whether '$PackageId' processes are running..."
        $runningProcs = Get-AppRunningProcesses -WingetExe $winget -Id $PackageId -NameOverride $ProcessNameOverride

        if ($runningProcs.Count -gt 0) {
            Write-Log "APP-IN-USE: $($runningProcs.Count) process(es) detected:" "WARN"
            $runningProcs | ForEach-Object {
                $path = try { $_.MainModule.FileName } catch { "(path unavailable)" }
                Write-Log "  PID=$($_.Id)  Name=$($_.ProcessName)  Path=$path" "WARN"
            }
            Write-Log "DECISION: deferring upgrade - app is in use. Intune will retry at next detection cycle." "WARN"
            Write-LogSeparator
            Write-Log "INSTALL END - exit=0 (deferred)"
            exit 0
        }

        Write-Log "APP-IN-USE CHECK: no running processes detected. Proceeding with upgrade." "DEBUG"
        Write-LogSeparator
    }
    else {
        Write-Log "DECISION: package not installed. Running INSTALL."
        $wingetArgs = @("install") + $commonArgs
    }

    #---- Run winget ----
    Write-LogSeparator
    Write-Log "Executing: winget $($wingetArgs -join ' ')" "DEBUG"
    $result     = & $winget @wingetArgs 2>&1
    $wingetExit = $LASTEXITCODE

    Write-LogWingetOutput -RawOutput ($result | Out-String) -Tag "winget $($wingetArgs[0]) output"
    Write-Log "winget exit code: $wingetExit"
    Write-LogSeparator

    #Brief pause to let installer finalise on disk
    Write-Log "Waiting 5 seconds for installer to finalise..." "DEBUG"
    Start-Sleep -Seconds 5

    #---- Post-check ----
    Write-Log "POST-CHECK: verifying compliance after winget run..."
    if (Test-AppCompliant -WingetExe $winget) {
        $info = Get-WinGetAppInfo -WingetExe $winget -Id $PackageId
        Write-Log "POST-CHECK RESULT: COMPLIANT - installed version is now $($info.Installed) (latest)."
        Write-Log "Reporting SUCCESS to Intune regardless of winget exit code ($wingetExit)."
        Write-LogSeparator
        Write-Log "INSTALL END - exit=0"
        exit 0
    }

    #---- Real failure ----
    $postInfo = Get-WinGetAppInfo -WingetExe $winget -Id $PackageId
    if ($postInfo -and $postInfo.Installed) {
        Write-Log "POST-CHECK RESULT: INSTALLED (v$($postInfo.Installed)) but upgrade still pending (available: $($postInfo.Available))." "ERROR"
    } else {
        Write-Log "POST-CHECK RESULT: package still NOT INSTALLED after winget run." "ERROR"
    }

    $exitCode = if ($wingetExit -is [int] -and $wingetExit -ne 0) { $wingetExit } else { 1 }
    Write-Log "Reporting FAILURE to Intune with exit code $exitCode." "ERROR"
    Write-LogSeparator
    Write-Log "INSTALL END - exit=$exitCode" "ERROR"
    exit $exitCode
}
catch {
    Write-LogSeparator
    Write-Log "UNHANDLED EXCEPTION: $($_.Exception.Message)" "ERROR"
    Write-Log "ScriptStackTrace:" "ERROR"
    $_.ScriptStackTrace -split "`r?`n" | ForEach-Object { Write-Log "  $_" "ERROR" }
    Write-LogSeparator
    Write-Log "INSTALL END - exit=1" "ERROR"
    exit 1
}
