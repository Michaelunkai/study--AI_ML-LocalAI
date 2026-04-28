function ccsize {
    param(
        [string]$Path,
        [switch]$Recurse,
        [switch]$SizeOnly
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Host "Error: Path is required." -ForegroundColor Red
        return
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "Error: Path not found: $Path" -ForegroundColor Red
        return
    }

    $totalSize = 0
    $itemCount = 0

    try {
        if ($Recurse) {
            $items = Get-ChildItem -LiteralPath $Path -Force -Recurse -ErrorAction SilentlyContinue
        }
        else {
            $items = Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        }

        foreach ($item in $items) {
            $size = $item.Length
            $totalSize += $size
            $itemCount++
        }
    }
    catch {
        Write-Host "Error processing $Path: $_" -ForegroundColor Yellow
    }

    if ($SizeOnly) {
        Write-Host "Size: $($totalSize / 1MB) MB"
    }
    else {
        Write-Host "Path: $Path"
        Write-Host "Items: $itemCount"
        Write-Host "Size: $($totalSize / 1MB) MB"
        Write-Host ""
    }
}

# Cleanup paths discovered on C drive
$cleanupPaths = @(
    "C:\Users\micha\AppData\Local\Temp",
    "C:\Users\micha\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\Codex\Logs",
    "C:\Users\micha\AppData\Local\Yarn\Berry\cache",
    "C:\Users\micha\AppData\Local\electron\Cache",
    "C:\Users\micha\AppData\Local\uv\cache",
    "C:\Users\micha\AppData\Local\CrashDumps",
    "C:\Users\micha\AppData\Local\NVIDIA\DXCache",
    "C:\Users\micha\AppData\Local\D3DSCache",
    "C:\Windows\Temp",
    "C:\Users\micha\AppData\Local\Google\Chrome\User Data\Default\Cache",
    "C:\Users\micha\AppData\Local\Google\Chrome\User Data\Default\Code Cache",
    "C:\Users\micha\AppData\Local\Microsoft\Edge\User Data\Default\Cache",
    "C:\Users\micha\AppData\Local\Microsoft\Edge\User Data\Default\Code Cache",
    "C:\Users\micha\AppData\Local\Microsoft\Windows\INetCache",
    "C:\Users\micha\AppData\Local\NVIDIA\GLCache",
    "C:\Windows\SoftwareDistribution\Download"
)

# Function to safely clean up a path
function Clean-Path {
    param(
        [string]$Path,
        [string]$Reason,
        [string]$Caution
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "Path does not exist: $Path" -ForegroundColor Gray
        return
    }

    Write-Host "Cleaning: $Path" -ForegroundColor Cyan
    Write-Host "  Reason: $Reason" -ForegroundColor Gray
    Write-Host "  Caution: $Caution" -ForegroundColor Yellow

    try {
        # Skip locked files from active apps
        $locked = Get-ChildItem -LiteralPath $Path -Force -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Attributes -match 'ReadOnly' -or $_.Attributes -match 'Hidden' } |
            Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-1) }

        if ($locked.Count -gt 0) {
            Write-Host "  Found $($locked.Count) potentially locked files, skipping." -ForegroundColor Yellow
            return
        }

        # Delete all items in the path
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Cleaned successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "  Error: $_" -ForegroundColor Red
    }
}

# Function to get all cleanup candidates with sizes
function Get-CleanupCandidates {
    param(
        [string]$DriveRoot = "C:\",
        [int]$MinSizeMb = 100,
        [int]$MaxResults = 100
    )

    $candidates = @()

    foreach ($path in $cleanupPaths) {
        try {
            if (Test-Path -LiteralPath $path) {
                $stats = Get-ChildItem -LiteralPath $path -Force -Recurse -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum

                $itemCount = [int]$stats.Count
                $sizeBytes = [int64]$stats.Sum
                $sizeMb = [math]::Round(($sizeBytes / 1MB), 2)

                $reason = switch -Regex ($path) {
                    '.*Temp$' { "Per-user temporary files." }
                    '.*Logs$' { "Log directory discovered during the broader scan." }
                    '.*cache$' { "Temp or cache directory discovered during the broader scan." }
                    '.*CrashDumps$' { "Crash dump files from application failures." }
                    '.*DXCache$' { "NVIDIA DirectX shader cache." }
                    '.*D3DSCache$' { "Direct3D shader cache that Windows rebuilds." }
                    '.*INetCache$' { "Legacy Windows and WebView cache data." }
                    '.*GLCache$' { "NVIDIA OpenGL shader cache." }
                    '.*Download$' { "Windows Update download cache." }
                    default { "Cleanup candidate discovered on the real machine." }
                }

                $caution = "Inspect the folder contents before deleting; some apps rebuild caches, but recent logs or dumps may still matter."

                $candidates += [pscustomobject]@{
                    Path = $path
                    Reason = $reason
                    Caution = $caution
                    ItemCount = $itemCount
                    SizeMb = $sizeMb
                    SizeBytes = $sizeBytes
                }
            }
        }
        catch {
            Write-Host "Error processing $path: $_" -ForegroundColor Yellow
        }
    }

    # Sort by size descending and return top results
    $candidates = $candidates | Sort-Object -Property SizeMb -Descending | Select-Object -First $MaxResults

    return $candidates
}

# Main execution
if ($args.Count -eq 0) {
    Write-Host "ccsizes - Cleanup size checker for C drive" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  ccsize <Path> [-Recurse] [-SizeOnly]" -ForegroundColor Yellow
    Write-Host "  ccsize -List              - List all cleanup candidates" -ForegroundColor Yellow
    Write-Host "  ccsize -Clean <Path>      - Clean a specific path" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "All cleanup candidates on C drive:" -ForegroundColor Cyan
    Write-Host ""
    $candidates = Get-CleanupCandidates
    $candidates | Format-Table Path, SizeMb, ItemCount, Reason -AutoSize
}
elseif ($args[0] -eq "-List") {
    $candidates = Get-CleanupCandidates
    $candidates | Format-Table Path, SizeMb, ItemCount, Reason -AutoSize
}
elseif ($args[0] -eq "-Clean") {
    if ($args.Count -lt 2) {
        Write-Host "Error: Please specify a path to clean." -ForegroundColor Red
        return
    }
    Clean-Path -Path $args[1] -Reason "User requested cleanup" -Caution "Review contents before deletion"
}
elseif (Test-Path -LiteralPath $args[0]) {
    ccsize -Path $args[0] -Recurse:$Recurse -SizeOnly:$SizeOnly
}
else {
    Write-Host "Error: Invalid argument." -ForegroundColor Red
}

