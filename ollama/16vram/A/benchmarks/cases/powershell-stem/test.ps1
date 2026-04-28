$ErrorActionPreference = "Stop"
. "$PSScriptRoot\PathStem.ps1"

function Assert-Eq {
    param(
        [string]$Actual,
        [string]$Expected,
        [string]$Label
    )

    if ($Actual -ne $Expected) {
        Write-Error "$Label failed. Expected '$Expected' but got '$Actual'."
    }
}

Assert-Eq (Get-SafeStem "C:\logs\archive.tar.gz") "archive.tar" "multi-dot file"
Assert-Eq (Get-SafeStem "report.txt") "report" "simple file"
Assert-Eq (Get-SafeStem ".env") ".env" "dotfile"
Assert-Eq (Get-SafeStem "C:\temp\folder\") "folder" "directory path"
Assert-Eq (Get-SafeStem "") "" "empty string"

Write-Host "PASS"
