[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("codex", "aider")]
    [string]$Provider,

    [Parameter(Mandatory = $true)]
    [string]$Model,

    [string[]]$Case = @("python-slugify", "powershell-stem", "instruction-alerts", "context-policy")
)

$ErrorActionPreference = "Stop"

function Test-OllamaApi {
    param(
        [string]$Uri = "http://127.0.0.1:11434/v1/models"
    )

    try {
        $null = Invoke-RestMethod -Method Get -Uri $Uri -TimeoutSec 5
        return $true
    }
    catch {
        return $false
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$casesRoot = Join-Path $repoRoot "benchmarks\cases"
$runsRoot = Join-Path $repoRoot "benchmarks\runs"
$timeStamp = Get-Date -Format "yyyyMMdd-HHmmss"
$safeProvider = $Provider -replace '[^A-Za-z0-9_.-]', '_'
$safeModel = $Model -replace '[^A-Za-z0-9_.-]', '_'
$runRoot = Join-Path $runsRoot ($safeProvider + "-" + $safeModel + "-" + $timeStamp)

New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

$results = @()

if (-not (Test-OllamaApi)) {
    throw "Ollama API is not reachable at http://127.0.0.1:11434/v1/models. Start the canonical server before benchmarking."
}

function Get-RepairedProcessEnvironment {
    $userProfile = [Environment]::GetFolderPath("UserProfile")
    $systemRoot = [Environment]::ExpandEnvironmentVariables([Environment]::GetEnvironmentVariable("SystemRoot", "Machine"))
    if ([string]::IsNullOrWhiteSpace($systemRoot)) {
        $systemRoot = if ([Environment]::SystemDirectory) {
            Split-Path -Parent ([Environment]::SystemDirectory)
        }
        else {
            "C:\Windows"
        }
    }

    $systemDrive = [Environment]::GetEnvironmentVariable("SystemDrive", "Process")
    if ([string]::IsNullOrWhiteSpace($systemDrive) -or $systemDrive -like '%*%') {
        $root = [System.IO.Path]::GetPathRoot($systemRoot)
        $systemDrive = if ([string]::IsNullOrWhiteSpace($root)) { "C:" } else { $root.TrimEnd('\') }
    }

    $programData = [Environment]::ExpandEnvironmentVariables([Environment]::GetEnvironmentVariable("ProgramData", "Machine"))
    if ([string]::IsNullOrWhiteSpace($programData) -or $programData -like '%*%') {
        $programData = Join-Path $systemDrive "ProgramData"
    }

    $localAppData = if ($userProfile) { Join-Path $userProfile "AppData\Local" } else { $null }
    $tempPath = [Environment]::GetEnvironmentVariable("TEMP", "Process")
    if ([string]::IsNullOrWhiteSpace($tempPath) -and $localAppData) {
        $tempPath = Join-Path $localAppData "Temp"
    }

    $tmpPath = [Environment]::GetEnvironmentVariable("TMP", "Process")
    if ([string]::IsNullOrWhiteSpace($tmpPath)) {
        $tmpPath = $tempPath
    }

    $comSpec = [Environment]::ExpandEnvironmentVariables([Environment]::GetEnvironmentVariable("ComSpec", "Machine"))
    if ([string]::IsNullOrWhiteSpace($comSpec)) {
        $comSpec = Join-Path $systemRoot "System32\cmd.exe"
    }

    return [ordered]@{
        USERPROFILE     = $userProfile
        HOME            = $userProfile
        APPDATA         = if ($userProfile) { Join-Path $userProfile "AppData\Roaming" } else { $null }
        LOCALAPPDATA    = $localAppData
        TEMP            = $tempPath
        TMP             = $tmpPath
        SystemRoot      = $systemRoot
        windir          = $systemRoot
        SystemDrive     = $systemDrive
        ProgramData     = $programData
        ALLUSERSPROFILE = $programData
        PUBLIC          = Join-Path $systemDrive "Users\Public"
        ComSpec         = $comSpec
    }
}

function Invoke-CapturedProcess {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$WorkingDirectory,
        [hashtable]$EnvironmentOverrides
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $startInfo.Arguments = (($ArgumentList | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_ -replace '"', '\"') + '"'
        }
        else {
            $_
        }
    }) -join ' ')
    foreach ($entry in (Get-RepairedProcessEnvironment).GetEnumerator()) {
        if (-not [string]::IsNullOrWhiteSpace($entry.Value)) {
            $startInfo.EnvironmentVariables[$entry.Key] = $entry.Value
        }
    }
    if ($EnvironmentOverrides) {
        foreach ($entry in $EnvironmentOverrides.GetEnumerator()) {
            if (-not [string]::IsNullOrWhiteSpace($entry.Value)) {
                $startInfo.EnvironmentVariables[$entry.Key] = [string]$entry.Value
            }
        }
    }

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        [void]$process.Start()
    }
    catch {
        return [pscustomobject]@{
            ExitCode = -1
            StdOut = ""
            StdErr = $_.Exception.Message
            Combined = $_.Exception.Message
        }
    }
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        StdOut = $stdout
        StdErr = $stderr
        Combined = (($stdout + [Environment]::NewLine + $stderr).Trim())
    }
}

foreach ($caseName in $Case) {
    $templatePath = Join-Path $casesRoot $caseName
    if (-not (Test-Path $templatePath)) {
        throw "Unknown benchmark case: $caseName"
    }

    $workPath = Join-Path $runRoot $caseName
    Copy-Item -Recurse -Force $templatePath $workPath

    git -C $workPath init | Out-Null
    git -C $workPath config user.name "Codex Benchmark"
    git -C $workPath config user.email "codex-benchmark@example.com"
    git -C $workPath add .
    git -C $workPath commit -m "Baseline" | Out-Null

    $taskPath = Join-Path $workPath "TASK.md"
    $transcriptPath = Join-Path $workPath "agent-output.txt"
    $verifyCommand = switch ($caseName) {
        "python-slugify" { "python -m unittest -q" }
        "powershell-stem" { "powershell -NoProfile -File .\test.ps1" }
        "instruction-alerts" { "python -m unittest -q" }
        "context-policy" { "python -m unittest -q" }
        default { throw "Missing verify command for $caseName" }
    }

    $start = Get-Date
    $agentExit = 0

    if ($Provider -eq "codex") {
        $message = Get-Content -Raw $taskPath
        $codexOutput = Invoke-CapturedProcess -FilePath "codex" -WorkingDirectory $workPath -ArgumentList @(
            "exec",
            "--oss",
            "--local-provider", "ollama",
            "-m", $Model,
            "--sandbox", "workspace-write",
            "--color", "never",
            "--json",
            "-C", $workPath,
            $message
        )
        $agentExit = $codexOutput.ExitCode
        Set-Content -Path $transcriptPath -Value $codexOutput.Combined
    }
    elseif ($Provider -eq "aider") {
        $aiderOutput = Invoke-CapturedProcess -FilePath "python" -WorkingDirectory $workPath -ArgumentList @(
            "-m", "aider",
            "--model", ("ollama_chat/" + $Model),
            "--openai-api-base", "http://127.0.0.1:11434/v1",
            "--no-pretty",
            "--no-stream",
            "--yes-always",
            "--analytics-disable",
            "--no-check-update",
            "--no-browser",
            "--disable-playwright",
            "--message-file", $taskPath,
            "--test-cmd", $verifyCommand,
            "--auto-test"
        ) -EnvironmentOverrides @{
            PYTHONUTF8 = "1"
            PYTHONIOENCODING = "utf-8"
            TERM = "dumb"
            NO_COLOR = "1"
            OLLAMA_API_BASE = "http://127.0.0.1:11434"
        }
        $agentExit = $aiderOutput.ExitCode
        Set-Content -Path $transcriptPath -Value $aiderOutput.Combined
    }

    & git -C $workPath status --short | Set-Content -Path (Join-Path $workPath "git-status-after.txt")

    $escapedWorkPath = $workPath.Replace("'", "''")
    $verifyScript = @"
Set-Location '$escapedWorkPath'
$verifyCommand
if (`$LASTEXITCODE -ne `$null) {
    exit `$LASTEXITCODE
}
if (-not `$?) {
    exit 1
}
exit 0
"@
    $verifyOutput = Invoke-CapturedProcess -FilePath "powershell" -WorkingDirectory $workPath -ArgumentList @(
        "-NoProfile",
        "-Command",
        $verifyScript
    )
    $verifyExit = $verifyOutput.ExitCode
    Set-Content -Path (Join-Path $workPath "verify-output.txt") -Value $verifyOutput.Combined

    $end = Get-Date
    $durationSeconds = [Math]::Round(($end - $start).TotalSeconds, 2)

    $results += [pscustomobject]@{
        case = $caseName
        provider = $Provider
        model = $Model
        agent_exit = $agentExit
        verify_exit = $verifyExit
        success = ($agentExit -eq 0 -and $verifyExit -eq 0)
        duration_seconds = $durationSeconds
        work_path = $workPath
    }
}

$resultsPath = Join-Path $runRoot "results.json"
$results | ConvertTo-Json -Depth 4 | Set-Content -Path $resultsPath
$results | Format-Table -AutoSize
