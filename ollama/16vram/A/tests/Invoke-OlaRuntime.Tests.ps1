[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Invoke-OlaCapture {
    param(
        [string[]]$ArgumentList,
        [int]$TimeoutSeconds
    )

    $stdoutPath = Join-Path $env:TEMP ("ola-test-stdout-" + [guid]::NewGuid().ToString("N") + ".log")
    $stderrPath = Join-Path $env:TEMP ("ola-test-stderr-" + [guid]::NewGuid().ToString("N") + ".log")
    $launcherPath = (Resolve-Path (Join-Path $PSScriptRoot "..\scripts\Invoke-Ola.ps1")).ProviderPath
    $workingDirectory = (Resolve-Path (Join-Path $PSScriptRoot "..")).ProviderPath

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "powershell.exe"
    $startInfo.Arguments = (
        @(
            "-NoProfile"
            "-ExecutionPolicy"
            "Bypass"
            "-File"
            $launcherPath
        ) + $ArgumentList | ForEach-Object {
            if ($_ -match '[\s"]') {
                '"' + ($_ -replace '"', '\"') + '"'
            }
            else {
                $_
            }
        }
    ) -join " "
    $startInfo.WorkingDirectory = $workingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    $startedAt = Get-Date

    try {
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        $timedOut = $false
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $timedOut = $true
            try {
                $process.Kill()
                $process.WaitForExit()
            }
            catch {
            }
        }

        [System.Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask), 5000) | Out-Null
        return [pscustomobject]@{
            TimedOut = $timedOut
            ExitCode = if ($process.HasExited) { $process.ExitCode } else { -1 }
            DurationSeconds = [math]::Round(((Get-Date) - $startedAt).TotalSeconds, 2)
            StdOut = $stdoutTask.Result
            StdErr = $stderrTask.Result
            Combined = (($stdoutTask.Result + [Environment]::NewLine + $stderrTask.Result).Trim())
        }
    }
    finally {
        $process.Dispose()
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -ErrorAction SilentlyContinue
    }
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

Write-Host "Running ola runtime regression checks..."

$workspacePath = (Resolve-Path (Join-Path $PSScriptRoot "..")).ProviderPath

$exactResult = Invoke-OlaCapture -ArgumentList @(
    "-WorkspacePath", $workspacePath,
    "-Prompt", "Reply with exactly OK."
) -TimeoutSeconds 60

Assert-True ($exactResult.Combined -match "(?m)^\s*OK\s*$") "Exact-output prompt did not return OK exactly. Output:`n$($exactResult.Combined)"
Assert-True ($exactResult.DurationSeconds -le 60) "Exact-output prompt took too long: $($exactResult.DurationSeconds)s"

$cleanupPrompt = "Inspect the real C drive cleanup candidates. Return only a flat bullet list where each bullet is 'absolute_path | size_mb MB | short reason'."
$cleanupResult = Invoke-OlaCapture -ArgumentList @(
    "-WorkspacePath", $workspacePath,
    "-Prompt", $cleanupPrompt
) -TimeoutSeconds 180

Assert-True ($cleanupResult.ExitCode -eq 0) "Cleanup prompt failed or timed out. Output:`n$($cleanupResult.Combined)"
Assert-True ($cleanupResult.DurationSeconds -le 180) "Cleanup prompt took too long: $($cleanupResult.DurationSeconds)s"
Assert-True ($cleanupResult.Combined -notmatch "\[ASSISTANT PLAN\]") "Cleanup prompt still printed an assistant plan block. Output:`n$($cleanupResult.Combined)"

$answerLines = @(
    $cleanupResult.Combined -split "\r?\n" |
        ForEach-Object { $_.TrimEnd() } |
        Where-Object { $_ -match '^\s*-\s+[A-Z]:\\.+\|\s*\d+(\.\d+)?\s*MB\s*\|\s*.+' }
)

Assert-True ($answerLines.Count -ge 3) "Cleanup prompt did not return enough verified bullet lines. Output:`n$($cleanupResult.Combined)"

Write-Host "All ola runtime regression checks passed."
