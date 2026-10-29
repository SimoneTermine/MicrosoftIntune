Describe 'Get-LocalAdministrators.ps1' {
    BeforeAll {
        $script:scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\00-Devices\Support\Get-LocalAdministrators\Get-LocalAdministrators.ps1'
    }

    BeforeEach {
        $script:originalOs = $env:OS
        $env:OS = 'Windows_NT'
        $script:hadMockMembers = Test-Path variable:global:GetLocalAdministratorsMockMembers
        if ($script:hadMockMembers) {
            $script:originalMockMembers = $global:GetLocalAdministratorsMockMembers
        }
        $global:GetLocalAdministratorsMockMembers = @(
            [PSCustomObject]@{
                Name            = 'CONTOSO\Alice'
                ObjectClass     = 'User'
                PrincipalSource = 'ActiveDirectory'
                SID             = 'S-1-5-21-1000'
            }
            [PSCustomObject]@{
                Name            = 'BUILTIN\Administrators'
                ObjectClass     = 'Group'
                PrincipalSource = 'Local'
                SID             = 'S-1-5-32-544'
            }
        )

        Mock Get-LocalGroup {
            [PSCustomObject]@{ Name = 'Localized Administrators' }
        }

        Mock Get-LocalGroupMember {
            $global:GetLocalAdministratorsMockMembers
        }
    }

    AfterEach {
        if ($null -eq $script:originalOs) {
            Remove-Item Env:\OS -ErrorAction SilentlyContinue
        }
        else {
            $env:OS = $script:originalOs
        }

        if ($script:hadMockMembers) {
            $global:GetLocalAdministratorsMockMembers = $script:originalMockMembers
        }
        else {
            Remove-Variable -Name GetLocalAdministratorsMockMembers -Scope Global -ErrorAction SilentlyContinue
        }
    }

    It 'returns the expected properties and values for each member' {
        $result = @(& $script:scriptPath)

        $result.Count | Should -Be 2
        ($result[0].PSObject.Properties.Name -join ',') | Should -Be 'ComputerName,GroupName,MemberName,ObjectClass,PrincipalSource,SID'
        $result[0].ComputerName | Should -Be $env:COMPUTERNAME
        $result[0].GroupName | Should -Be 'Localized Administrators'
        $result[0].MemberName | Should -Be 'CONTOSO\Alice'
        $result[0].ObjectClass | Should -Be 'User'
        $result[0].PrincipalSource | Should -Be 'ActiveDirectory'
        $result[0].SID | Should -Be 'S-1-5-21-1000'
        $result[1].MemberName | Should -Be 'BUILTIN\Administrators'
        $result[1].ObjectClass | Should -Be 'Group'
        $result[1].PrincipalSource | Should -Be 'Local'
        $result[1].SID | Should -Be 'S-1-5-32-544'
    }

    It 'returns no objects when the Administrators group is empty' {
        $global:GetLocalAdministratorsMockMembers = @()

        $result = @(& $script:scriptPath)

        $result.Count | Should -Be 0
    }

    It 'exports member rows to CSV and creates a missing parent directory' {
        $csvPath = Join-Path $TestDrive 'reports\administrators.csv'

        $output = @(& $script:scriptPath -CsvPath $csvPath)

        (Test-Path -LiteralPath $csvPath) | Should -Be $true
        $output.Count | Should -Be 1
        $output[0] | Should -Be ("Exported 2 local Administrators group member(s) to {0}" -f [System.IO.Path]::GetFullPath($csvPath))

        $csvRows = @(Import-Csv -LiteralPath $csvPath)
        $csvRows.Count | Should -Be 2
        $csvRows[0].ComputerName | Should -Be $env:COMPUTERNAME
        $csvRows[0].GroupName | Should -Be 'Localized Administrators'
        $csvRows[0].MemberName | Should -Be 'CONTOSO\Alice'
        $csvRows[0].ObjectClass | Should -Be 'User'
        $csvRows[0].PrincipalSource | Should -Be 'ActiveDirectory'
        $csvRows[0].SID | Should -Be 'S-1-5-21-1000'
        $csvRows[1].MemberName | Should -Be 'BUILTIN\Administrators'
    }

    It 'writes a header-only CSV when the Administrators group is empty' {
        $global:GetLocalAdministratorsMockMembers = @()
        $csvPath = Join-Path $TestDrive 'empty-administrators.csv'

        $output = @(& $script:scriptPath -CsvPath $csvPath)

        $output[0] | Should -Be ("Exported 0 local Administrators group member(s) to {0}" -f [System.IO.Path]::GetFullPath($csvPath))
        (Get-Content -LiteralPath $csvPath -Raw).Trim() | Should -Be 'ComputerName,GroupName,MemberName,ObjectClass,PrincipalSource,SID'
        @(Import-Csv -LiteralPath $csvPath).Count | Should -Be 0
    }
}
