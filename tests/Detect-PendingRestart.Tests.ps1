Describe 'Detect-PendingRestart.ps1' {
    BeforeAll {
        $script:scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\00-Devices\Remediations\Detect-PendingRestart\Detect-PendingRestart.ps1'

        function ConvertTo-PowerShellLiteral {
            param([Parameter(Mandatory)][string]$Value)

            "'" + $Value.Replace("'", "''") + "'"
        }

        function Invoke-PendingRestartScenario {
            param(
                [bool]$CbsPending = $false,
                [bool]$WindowsUpdatePending = $false,
                [object[]]$PendingRenameOperations = @(),
                [switch]$MissingPendingRenameValue,
                [ValidateSet('None', 'TestPath', 'GetItemProperty', 'GetItemPropertyWriteError')]
                [string]$Failure = 'None'
            )

            $scenario = @{
                CbsPending             = $CbsPending
                WindowsUpdatePending  = $WindowsUpdatePending
                PendingRenameOperations = @($PendingRenameOperations)
                MissingPendingRenameValue = [bool]$MissingPendingRenameValue
                Failure                = $Failure
            }
            $scenarioJson = ConvertTo-Json -InputObject $scenario -Compress
            $command = @'
$global:PendingRestartTestScenario = ConvertFrom-Json -InputObject __SCENARIO__
function Test-Path {
    [CmdletBinding()]
    param([string]$LiteralPath)

    switch -Exact ($LiteralPath) {
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' {
            if ($global:PendingRestartTestScenario.Failure -eq 'TestPath') { throw 'Mock Test-Path failure' }
            return [bool]$global:PendingRestartTestScenario.CbsPending
        }
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' {
            if ($global:PendingRestartTestScenario.Failure -eq 'TestPath') { throw 'Mock Test-Path failure' }
            return [bool]$global:PendingRestartTestScenario.WindowsUpdatePending
        }
        default { throw "Unexpected registry path passed to Test-Path: $LiteralPath" }
    }
}
function Get-ItemProperty {
    [CmdletBinding()]
    param(
        [string]$LiteralPath
    )

    if ($LiteralPath -cne 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager') {
        throw "Unexpected registry path passed to Get-ItemProperty: $LiteralPath"
    }
    if ($global:PendingRestartTestScenario.Failure -eq 'GetItemProperty') {
        throw 'Mock Get-ItemProperty failure'
    }
    if ($global:PendingRestartTestScenario.Failure -eq 'GetItemPropertyWriteError') {
        Write-Error 'Mock Get-ItemProperty provider error'
    }
    if ($global:PendingRestartTestScenario.MissingPendingRenameValue) {
        return [PSCustomObject]@{}
    }

    [PSCustomObject]@{
        PendingFileRenameOperations = $global:PendingRestartTestScenario.PendingRenameOperations
    }
}

& __SCRIPT_PATH__
'@
            $command = $command.Replace('__SCENARIO__', (ConvertTo-PowerShellLiteral -Value $scenarioJson))
            $command = $command.Replace('__SCRIPT_PATH__', (ConvertTo-PowerShellLiteral -Value $script:scriptPath))
            $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))

            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = (Get-Process -Id $PID).Path
            $processInfo.Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encodedCommand"
            $processInfo.UseShellExecute = $false
            $processInfo.CreateNoWindow = $true
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true

            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo

            try {
                if (-not $process.Start()) {
                    throw 'Could not start the PowerShell process for the detection scenario.'
                }

                $standardOutput = $process.StandardOutput.ReadToEnd()
                $standardError = $process.StandardError.ReadToEnd()
                $process.WaitForExit()

                [PSCustomObject]@{
                    ExitCode = $process.ExitCode
                    Output   = $standardOutput.Trim()
                    Error    = $standardError.Trim()
                }
            }
            finally {
                $process.Dispose()
            }
        }
    }

    It 'returns exit code 0 when no indicator is present' {
        $result = Invoke-PendingRestartScenario

        $result.ExitCode | Should -Be 0
        $result.Output | Should -BeExactly 'No pending restart indicators were found.'
    }

    It 'detects only the Component Based Servicing indicator' {
        $result = Invoke-PendingRestartScenario -CbsPending $true

        $result.ExitCode | Should -Be 1
        $result.Output | Should -BeExactly 'Pending restart detected: Component Based Servicing reports a pending restart'
    }

    It 'detects only the Windows Update indicator' {
        $result = Invoke-PendingRestartScenario -WindowsUpdatePending $true

        $result.ExitCode | Should -Be 1
        $result.Output | Should -BeExactly 'Pending restart detected: Windows Update reports a pending restart'
    }

    It 'detects only pending file rename operations' {
        $result = Invoke-PendingRestartScenario -PendingRenameOperations @('source.tmp', 'destination.tmp')

        $result.ExitCode | Should -Be 1
        $result.Output | Should -BeExactly 'Pending restart detected: Windows has pending file rename operations'
    }

    It 'does not detect empty pending file rename operations' {
        $result = Invoke-PendingRestartScenario -PendingRenameOperations @()

        $result.ExitCode | Should -Be 0
        $result.Output | Should -BeExactly 'No pending restart indicators were found.'
    }

    It 'does not detect a missing pending file rename registry value' {
        $result = Invoke-PendingRestartScenario -MissingPendingRenameValue

        $result.ExitCode | Should -Be 0
        $result.Output | Should -BeExactly 'No pending restart indicators were found.'
    }

    It 'reports both Component Based Servicing and Windows Update indicators' {
        $result = Invoke-PendingRestartScenario -CbsPending $true -WindowsUpdatePending $true

        $result.ExitCode | Should -Be 1
        $result.Output | Should -BeExactly 'Pending restart detected: Component Based Servicing reports a pending restart; Windows Update reports a pending restart'
    }

    It 'reports Component Based Servicing and pending file rename indicators' {
        $result = Invoke-PendingRestartScenario -CbsPending $true -PendingRenameOperations @('source.tmp', 'destination.tmp')

        $result.ExitCode | Should -Be 1
        $result.Output | Should -BeExactly 'Pending restart detected: Component Based Servicing reports a pending restart; Windows has pending file rename operations'
    }

    It 'reports Windows Update and pending file rename indicators' {
        $result = Invoke-PendingRestartScenario -WindowsUpdatePending $true -PendingRenameOperations @('source.tmp', 'destination.tmp')

        $result.ExitCode | Should -Be 1
        $result.Output | Should -BeExactly 'Pending restart detected: Windows Update reports a pending restart; Windows has pending file rename operations'
    }

    It 'reports all indicators in script order when all are present' {
        $result = Invoke-PendingRestartScenario -CbsPending $true -WindowsUpdatePending $true -PendingRenameOperations @('source.tmp', 'destination.tmp')

        $result.ExitCode | Should -Be 1
        $result.Output | Should -BeExactly 'Pending restart detected: Component Based Servicing reports a pending restart; Windows Update reports a pending restart; Windows has pending file rename operations'
    }

    It 'reports registry path access errors and returns exit code 1' {
        $result = Invoke-PendingRestartScenario -Failure TestPath

        $result.ExitCode | Should -Be 1
        $result.Output | Should -BeExactly 'Detection error: Mock Test-Path failure'
    }

    It 'reports registry value access errors and returns exit code 1' {
        $result = Invoke-PendingRestartScenario -Failure GetItemProperty

        $result.ExitCode | Should -Be 1
        $result.Output | Should -BeExactly 'Detection error: Mock Get-ItemProperty failure'
    }

    It 'stops on a non-terminating registry provider error and returns exit code 1' {
        $result = Invoke-PendingRestartScenario -Failure GetItemPropertyWriteError

        $result.ExitCode | Should -Be 1
        $result.Output | Should -BeExactly 'Detection error: Mock Get-ItemProperty provider error'
    }
}
