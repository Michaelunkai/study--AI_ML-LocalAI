[CmdletBinding()]
param(
    [string]$OllamaPath = "F:\backup\LocalAI\ollama\ollama-app\ollama.exe",
    [string]$ModelsPath = "F:\backup\LocalAI\ollama\models",
    [string]$DefaultModel = "gpt-oss:20b",
    [int]$CommandTimeoutSeconds = 30,
    [switch]$RunSmokeTest
)

$ErrorActionPreference = "Stop"

$checks = @()

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
        USERPROFILE    = $userProfile
        HOME           = $userProfile
        APPDATA        = if ($userProfile) { Join-Path $userProfile "AppData\Roaming" } else { $null }
        LOCALAPPDATA   = $localAppData
        TEMP           = $tempPath
        TMP            = $tmpPath
        SystemRoot     = $systemRoot
        windir         = $systemRoot
        SystemDrive    = $systemDrive
        ProgramData    = $programData
        ALLUSERSPROFILE = $programData
        PUBLIC         = Join-Path $systemDrive "Users\Public"
        ComSpec        = $comSpec
    }
}

function Add-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Details
    )

    $script:checks += [pscustomobject]@{
        Name = $Name
        Passed = $Passed
        Details = $Details
    }
}

function Invoke-CapturedProcess {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [int]$TimeoutSeconds = $CommandTimeoutSeconds
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
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

    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        try {
            $process.Kill()
            $process.WaitForExit()
        }
        catch {
        }

        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $timeoutMessage = "Timed out after $TimeoutSeconds seconds"

        return [pscustomobject]@{
            ExitCode = -2
            StdOut = $stdout
            StdErr = (($stderr + [Environment]::NewLine + $timeoutMessage).Trim())
            Combined = ((($stdout + [Environment]::NewLine + $stderr).Trim() + [Environment]::NewLine + $timeoutMessage).Trim())
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

function Resolve-NvidiaSmiPath {
    $candidates = @()

    $command = Get-Command "nvidia-smi" -ErrorAction SilentlyContinue
    if ($command -and $command.Source) {
        $candidates += $command.Source
    }

    $candidates += @(
        "C:\Windows\System32\nvidia-smi.exe"
        "C:\Windows\SysWOW64\nvidia-smi.exe"
        "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
    )

    $installerRoot = "C:\Program Files\NVIDIA Corporation\Installer2"
    if (Test-Path $installerRoot) {
        $candidates += @(Get-ChildItem -LiteralPath $installerRoot -Directory -Filter "Display.Driver.*" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            ForEach-Object { Join-Path $_.FullName "nvidia-smi.exe" })
    }

    return ($candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1)
}

Add-Check -Name "ollama binary exists" -Passed (Test-Path $OllamaPath) -Details $OllamaPath
Add-Check -Name "models path exists" -Passed (Test-Path $ModelsPath) -Details $ModelsPath

$resolvedOllama = (Get-Command ollama -ErrorAction Stop).Source
Add-Check -Name "ollama PATH target" -Passed ($resolvedOllama -eq $OllamaPath) -Details $resolvedOllama

$version = Invoke-CapturedProcess -FilePath $OllamaPath -ArgumentList @("--version")
Add-Check -Name "ollama version" -Passed ($version.ExitCode -eq 0) -Details $version.Combined

$listOutput = Invoke-CapturedProcess -FilePath $OllamaPath -ArgumentList @("list")
Add-Check -Name "ollama list" -Passed ($listOutput.ExitCode -eq 0) -Details (($listOutput.Combined -split [Environment]::NewLine | Select-Object -First 3) -join " | ")

$nvidiaSmiPath = Resolve-NvidiaSmiPath
if ($nvidiaSmiPath) {
    $nvidiaOutput = Invoke-CapturedProcess -FilePath $nvidiaSmiPath -ArgumentList @("--query-gpu=name,driver_version,memory.total", "--format=csv,noheader")
    Add-Check -Name "nvidia-smi" -Passed ($nvidiaOutput.ExitCode -eq 0) -Details ("path=" + $nvidiaSmiPath + " | " + $nvidiaOutput.Combined)
}
else {
    Add-Check -Name "nvidia-smi" -Passed $false -Details "nvidia-smi.exe not found in PATH or known NVIDIA locations"
}

$psOutput = Invoke-CapturedProcess -FilePath $OllamaPath -ArgumentList @("ps")
Add-Check -Name "ollama ps" -Passed ($psOutput.ExitCode -eq 0) -Details (($psOutput.Combined -split [Environment]::NewLine | Select-Object -First 3) -join " | ")

if ($RunSmokeTest) {
    try {
        $smokeBody = @{
            model = $DefaultModel
            prompt = "Reply with exactly OK."
            stream = $false
            keep_alive = "2m"
            options = @{
                num_ctx = 4096
            }
        } | ConvertTo-Json -Depth 6

        $smokeResponse = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:11434/api/generate" -ContentType "application/json" -Body $smokeBody -TimeoutSec 180
        $smokeText = if ($smokeResponse.response) { ([string]$smokeResponse.response).Trim() } else { "" }
        $passed = ($smokeText -eq "OK")
        $details = "response=$smokeText | total_duration=$($smokeResponse.total_duration) | load_duration=$($smokeResponse.load_duration)"
        Add-Check -Name "smoke test" -Passed $passed -Details $details
    }
    catch {
        Add-Check -Name "smoke test" -Passed $false -Details $_.Exception.Message
    }
}

$checks | Format-Table -AutoSize

if ($checks.Passed -contains $false) {
    exit 1
}
