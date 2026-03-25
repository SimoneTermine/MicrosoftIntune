$ErrorActionPreference = "Stop"

$uninstallKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$chrome = $null

foreach ($key in $uninstallKeys) {
    $chrome = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue |
        Where-Object {
            $_.DisplayName -like "*Chrome*"
        } |
        Select-Object -First 1

    if ($chrome) { break }
}

if ($chrome) {
    $version = $chrome.DisplayVersion
    Write-Output ("Google Chrome installato{0}" -f $(if ($version) { " (versione $version)" } else { "" }))
    exit 1
}

Write-Output "Chrome non installato"
exit 0