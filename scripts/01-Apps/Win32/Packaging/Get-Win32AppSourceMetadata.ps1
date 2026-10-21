<#
.SYNOPSIS
    Collects installer metadata and SHA-256 information for Microsoft Intune Win32 app packaging.
    Author: Simone Termine
    Version: 1.1
    Blog: https://www.endpointninja.com

.DESCRIPTION
    Reads version information from EXE files and Windows Installer properties
    from MSI files without installing the application. The output includes
    file size and SHA-256, and can be saved as JSON for packaging records.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$InstallerPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$resolvedPath = (Resolve-Path -LiteralPath $InstallerPath).Path
$file = Get-Item -LiteralPath $resolvedPath
$versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($resolvedPath)
$hash = Get-FileHash -LiteralPath $resolvedPath -Algorithm SHA256

$metadata = [ordered]@{
    FileName       = $file.Name
    FullPath       = $resolvedPath
    Extension      = $file.Extension
    FileSizeBytes  = [int64]$file.Length
    FileSizeMiB    = [math]::Round($file.Length / 1MB, 2)
    SHA256         = $hash.Hash
    ProductName    = [string]$versionInfo.ProductName
    ProductVersion = [string]$versionInfo.ProductVersion
    FileVersion    = [string]$versionInfo.FileVersion
    Publisher      = [string]$versionInfo.CompanyName
    ProductCode    = ''
    UpgradeCode    = ''
}

if ($file.Extension -ieq '.msi') {
    $installer = $null
    $database = $null
    $view = $null
    $record = $null
    try {
        $installer = New-Object -ComObject WindowsInstaller.Installer
        $database = $installer.OpenDatabase($resolvedPath, 0)
        $quote = [string][char]96
        $query = 'SELECT ' + $quote + 'Property' + $quote + ', ' + $quote + 'Value' + $quote +
            ' FROM ' + $quote + 'Property' + $quote
        $view = $database.OpenView($query)
        $view.Execute()

        while ($null -ne ($record = $view.Fetch())) {
            $propertyName = [string]$record.StringData(1)
            $propertyValue = [string]$record.StringData(2)
            switch ($propertyName) {
                'ProductName'    { $metadata.ProductName = $propertyValue }
                'ProductVersion' { $metadata.ProductVersion = $propertyValue }
                'Manufacturer'   { $metadata.Publisher = $propertyValue }
                'ProductCode'    { $metadata.ProductCode = $propertyValue }
                'UpgradeCode'    { $metadata.UpgradeCode = $propertyValue }
            }
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($record)
            $record = $null
        }
    }
    catch {
        throw ("Could not read Windows Installer properties from {0}: {1}" -f $file.Name, $_.Exception.Message)
    }
    finally {
        foreach ($comObject in @($record, $view, $database, $installer)) {
            if ($null -ne $comObject -and [System.Runtime.InteropServices.Marshal]::IsComObject($comObject)) {
                [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($comObject)
            }
        }
    }
}

$result = [PSCustomObject]$metadata
$json = $result | ConvertTo-Json -Depth 4
if ($OutputPath) {
    $destination = [System.IO.Path]::GetFullPath($OutputPath)
    $destinationParent = Split-Path -Parent $destination
    if ($destinationParent -and -not (Test-Path -LiteralPath $destinationParent)) {
        New-Item -Path $destinationParent -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    Set-Content -LiteralPath $destination -Value $json -Encoding UTF8
    Write-Output ("Metadata saved to {0}" -f $destination)
}
else {
    Write-Output $json
}
