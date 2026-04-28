[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Prompt,

    [string]$WorkspacePath = (Get-Location).Path,
    [ValidateSet("auto", "aider", "native")]
    [string]$Runtime = "auto",
    [string]$Model = "qwen3.5:latest",
    [string]$HeavyModel = "qwen3:30b-a3b",
    [string]$CoderModel = "qwen3-coder:latest",
    [string]$StructuredModel = "gpt-oss:20b",
    [string]$VisionModel = "gemma4:latest",
    [ValidateSet("auto", "fixed")]
    [string]$ModelRouting = "auto",
    [string]$FallbackModel = "qwen3-coder:latest",
    [string]$OllamaPath = "F:\backup\LocalAI\ollama\ollama-app\ollama.exe",
    [string]$OllamaHome = "F:\backup\LocalAI\ollama",
    [string]$ModelsPath = "F:\backup\LocalAI\ollama\models",
    [string]$RunnersDir = "F:\backup\LocalAI\ollama\runners",
    [string[]]$Files = @(),
    [ValidateSet("standard", "agentic")]
    [string]$Profile = "agentic",
    [switch]$SmokeTest,
    [switch]$CapabilityProbe,
    [switch]$EnsurePlaywright,
    [string]$SmokePrompt = "Reply with exactly OK.",
    [switch]$PrintResolvedCommand,
    [switch]$DirectiveMode,
    [switch]$YesAlways
)

$ErrorActionPreference = "Stop"

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

function Set-ProcessEnvironment {
    param(
        [hashtable]$Values
    )

    foreach ($entry in $Values.GetEnumerator()) {
        if (-not [string]::IsNullOrWhiteSpace($entry.Value)) {
            [Environment]::SetEnvironmentVariable($entry.Key, [string]$entry.Value, "Process")
        }
    }
}

function Invoke-CapturedProcess {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$StdIn,
        [int]$TimeoutSeconds = 30
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = (-not [string]::IsNullOrEmpty($StdIn))
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $startInfo.WorkingDirectory = (Get-Location).Path
    $startInfo.Arguments = (($ArgumentList | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_ -replace '"', '\"') + '"'
        }
        else {
            $_
        }
    }) -join ' ')

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        if (-not [string]::IsNullOrEmpty($StdIn)) {
            $process.StandardInput.WriteLine($StdIn)
            $process.StandardInput.Close()
        }
    }
    catch {
        return [pscustomobject]@{
            ExitCode = -1
            StdOut = ""
            StdErr = $_.Exception.Message
            Combined = $_.Exception.Message
        }
    }

    try {
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            try {
                $process.Kill()
                $process.WaitForExit()
            }
            catch {
            }

            [System.Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask), 5000) | Out-Null
            $stdout = $stdoutTask.Result.TrimEnd()
            $stderr = $stderrTask.Result.TrimEnd()
            $timeoutMessage = "Timed out after $TimeoutSeconds seconds"

            return [pscustomobject]@{
                ExitCode = -2
                StdOut = $stdout
                StdErr = (($stderr + [Environment]::NewLine + $timeoutMessage).Trim())
                Combined = ((($stdout + [Environment]::NewLine + $stderr).Trim() + [Environment]::NewLine + $timeoutMessage).Trim())
            }
        }

        $process.WaitForExit()
        [System.Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask), 5000) | Out-Null
        $stdout = $stdoutTask.Result.TrimEnd()
        $stderr = $stderrTask.Result.TrimEnd()

        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOut = $stdout
            StdErr = $stderr
            Combined = (($stdout + [Environment]::NewLine + $stderr).Trim())
        }
    }
    finally {
        $process.Dispose()
    }
}

function Reset-OlaSuccessExitCode {
    $global:LASTEXITCODE = 0
}

function Complete-OlaSuccess {
    # Successful child runs can leave a stale native-process exit code behind in PS5.
    # Keep the wrapper exit clean when the visible run itself succeeded.
    Reset-OlaSuccessExitCode
}

function Set-Utf8Console {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    try {
        [Console]::InputEncoding = $utf8NoBom
        [Console]::OutputEncoding = $utf8NoBom
    }
    catch {
    }

    $global:OutputEncoding = $utf8NoBom
}

function Test-PlaywrightModuleInstalled {
    $probe = Invoke-CapturedProcess -FilePath $pythonCommand.Source -ArgumentList @(
        "-c",
        "import importlib.util; print(importlib.util.find_spec('playwright') is not None)"
    ) -TimeoutSeconds 30

    return ($probe.ExitCode -eq 0 -and $probe.Combined.Trim() -eq "True")
}

function Test-PlaywrightChromiumReady {
    if (-not (Test-PlaywrightModuleInstalled)) {
        return [pscustomobject]@{
            Ready = $false
            Details = "Python playwright module is not installed."
        }
    }

    $probeScript = @'
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()
    page.goto("https://example.com", wait_until="domcontentloaded", timeout=15000)
    print(page.title())
    browser.close()
'@

    $probe = Invoke-CapturedProcess -FilePath $pythonCommand.Source -ArgumentList @("-c", $probeScript) -TimeoutSeconds 90

    return [pscustomobject]@{
        Ready = ($probe.ExitCode -eq 0 -and $probe.Combined -match "Example Domain")
        Details = $probe.Combined
    }
}

function Ensure-PlaywrightChromium {
    $before = Test-PlaywrightChromiumReady
    if ($before.Ready) {
        return [pscustomobject]@{
            Changed = $false
            Ready = $true
            Details = $before.Details
            InstallOutput = ""
        }
    }

    if (-not (Test-PlaywrightModuleInstalled)) {
        return [pscustomobject]@{
            Changed = $false
            Ready = $false
            Details = "Python playwright module is not installed."
            InstallOutput = ""
        }
    }

    $install = Invoke-CapturedProcess -FilePath $pythonCommand.Source -ArgumentList @("-m", "playwright", "install", "chromium") -TimeoutSeconds 900
    $after = Test-PlaywrightChromiumReady

    return [pscustomobject]@{
        Changed = $true
        Ready = $after.Ready
        Details = $after.Details
        InstallOutput = $install.Combined
    }
}

function Test-GitRepository {
    param(
        [string]$Path
    )

    $gitOutput = Invoke-CapturedProcess -FilePath "git" -ArgumentList @("-C", $Path, "rev-parse", "--is-inside-work-tree")
    return ($gitOutput.ExitCode -eq 0 -and $gitOutput.Combined.Trim() -eq "true")
}

function Get-CurrentWhoAmI {
    $whoamiOutput = Invoke-CapturedProcess -FilePath "cmd.exe" -ArgumentList @("/c", "whoami") -TimeoutSeconds 15
    if ($whoamiOutput.ExitCode -ne 0) {
        return $null
    }

    return $whoamiOutput.Combined.Trim()
}

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

function Ensure-OllamaServer {
    if (Test-OllamaApi) {
        return
    }

    $serveProcess = Get-Process -Name ollama -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -eq $OllamaPath } |
        Select-Object -First 1

    if (-not $serveProcess) {
        Start-Process -FilePath $OllamaPath -ArgumentList @("serve") -WindowStyle Hidden | Out-Null
    }

    for ($attempt = 0; $attempt -lt 15; $attempt++) {
        Start-Sleep -Seconds 1
        if (Test-OllamaApi) {
            return
        }
    }

    throw "Ollama API is not reachable at http://127.0.0.1:11434/v1/models after attempting startup."
}

function Format-CommandForDisplay {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList
    )

    $parts = @($FilePath) + $ArgumentList
    return ($parts | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_ -replace '"', '\"') + '"'
        }
        else {
            $_
        }
    }) -join ' '
}

function Get-InstalledOllamaModels {
    param(
        [string]$ListOutput
    )

    return @(
        $ListOutput -split '\r?\n' |
            ForEach-Object { $_.Trim() } |
            Where-Object {
                $_ -and
                $_ -notmatch '^(NAME|ID|SIZE|MODIFIED)\b'
            } |
            ForEach-Object {
                ($_ -split '\s+')[0]
            }
    )
}

function Resolve-OlaRuntime {
    param(
        [string]$RequestedRuntime,
        [string]$SelectedProfile
    )

    if ($RequestedRuntime -ne "auto") {
        return $RequestedRuntime
    }

    if ($SelectedProfile -eq "agentic") {
        return "native"
    }

    return "aider"
}

function Resolve-OlaModelRouting {
    param(
        [string]$ChosenRuntime,
        [string]$RequestedRouting,
        [bool]$ExplicitPrimaryModel,
        [bool]$ExplicitRouting
    )

    if ($ChosenRuntime -ne "native") {
        return "fixed"
    }

    if ($ExplicitRouting) {
        return $RequestedRouting
    }

    if ($ExplicitPrimaryModel) {
        return "fixed"
    }

    return "auto"
}

function Resolve-OlaModel {
    param(
        [string]$ChosenRuntime,
        [string]$RequestedModel,
        [string[]]$InstalledModels,
        [bool]$ExplicitModel
    )

    if ($ChosenRuntime -ne "native") {
        return $RequestedModel
    }

    if ($ExplicitModel) {
        return $RequestedModel
    }

    if ($InstalledModels -contains "qwen3.5-oll90:latest") {
        return "qwen3.5-oll90:latest"
    }

    if ($InstalledModels -contains "qwen3.5:latest") {
        return "qwen3.5:latest"
    }

    return $RequestedModel
}

function Resolve-OlaHeavyModel {
    param(
        [string]$ChosenRuntime,
        [string]$RequestedHeavyModel,
        [string[]]$InstalledModels,
        [string]$PrimaryModel
    )

    if ($ChosenRuntime -ne "native") {
        return $PrimaryModel
    }

    if ($InstalledModels -contains $RequestedHeavyModel) {
        return $RequestedHeavyModel
    }

    if ($InstalledModels -contains "qwen3:30b-a3b") {
        return "qwen3:30b-a3b"
    }

    return $PrimaryModel
}

function Resolve-OlaOptionalModel {
    param(
        [string]$RequestedModel,
        [string[]]$InstalledModels,
        [string[]]$PreferredInstalledCandidates,
        [string]$FallbackModel
    )

    if ($InstalledModels -contains $RequestedModel) {
        return $RequestedModel
    }

    foreach ($candidate in $PreferredInstalledCandidates) {
        if ($InstalledModels -contains $candidate) {
            return $candidate
        }
    }

    return $FallbackModel
}

function Get-NativeAgentArguments {
    param(
        [string]$AgentScriptPath,
        [string]$SelectedModel,
        [string]$SelectedHeavyModel,
        [string]$SelectedCoderModel,
        [string]$SelectedStructuredModel,
        [string]$SelectedVisionModel,
        [string]$SelectedModelRouting,
        [string]$ResolvedWorkspace,
        [string]$InitialPrompt,
        [bool]$SinglePromptMode,
        [bool]$DirectiveEnabled
    )

    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $AgentScriptPath,
        "-WorkspacePath", $ResolvedWorkspace,
        "-Model", $SelectedModel,
        "-HeavyModel", $SelectedHeavyModel,
        "-CoderModel", $SelectedCoderModel,
        "-StructuredModel", $SelectedStructuredModel,
        "-VisionModel", $SelectedVisionModel,
        "-RoutingMode", $SelectedModelRouting
    )

    if (-not [string]::IsNullOrWhiteSpace($InitialPrompt)) {
        $args += @("-InitialPrompt", $InitialPrompt)
    }

    if ($SinglePromptMode) {
        $args += "-SinglePrompt"
    }

    if ($DirectiveEnabled) {
        $args += "-DirectiveMode"
    }

    return $args
}

function Invoke-NativeAgentCapabilityProbe {
    param(
        [string]$AgentScriptPath,
        [string]$SelectedModel,
        [string]$SelectedHeavyModel,
        [string]$SelectedCoderModel,
        [string]$SelectedStructuredModel,
        [string]$SelectedVisionModel,
        [string]$SelectedModelRouting,
        [string]$ResolvedWorkspace
    )

    $probePrompt = "Use tools to inspect the actual workspace at '$ResolvedWorkspace'. Return the absolute workspace path and the top-level directories exactly as found."
    $probeArgs = Get-NativeAgentArguments -AgentScriptPath $AgentScriptPath -SelectedModel $SelectedModel -SelectedHeavyModel $SelectedHeavyModel -SelectedCoderModel $SelectedCoderModel -SelectedStructuredModel $SelectedStructuredModel -SelectedVisionModel $SelectedVisionModel -SelectedModelRouting $SelectedModelRouting -ResolvedWorkspace $ResolvedWorkspace -InitialPrompt $probePrompt -SinglePromptMode $true -DirectiveEnabled $false
    $probeOutput = Invoke-CapturedProcess -FilePath "powershell.exe" -ArgumentList $probeArgs -TimeoutSeconds 300
    $combined = $probeOutput.Combined

    $expectedEntries = @("docs", "scripts", "benchmarks", "artifacts")
    $missingEntries = @($expectedEntries | Where-Object { $combined -notmatch ("(?i)\b" + [regex]::Escape($_) + "\b") })
    $toolCallWorked = (
        $combined -match '> run_powershell' -or
        $combined -match '> list_directory' -or
        $combined -match '(?m)^\[\d{2}:\d{2}:\d{2}\]\s+TOOL\s+START\s+run_powershell\b' -or
        $combined -match '(?m)^\[\d{2}:\d{2}:\d{2}\]\s+TOOL\s+START\s+list_directory\b'
    )
    $workspaceMentioned = ($combined -match [regex]::Escape($ResolvedWorkspace))

    return [pscustomobject]@{
        CapabilityProbePassed = (
            $probeOutput.ExitCode -eq 0 -and
            $toolCallWorked -and
            $workspaceMentioned -and
            $missingEntries.Count -eq 0
        )
        ProbeOutput = $combined
        ToolCallWorked = $toolCallWorked
        WorkspaceMentioned = $workspaceMentioned
        MissingEntries = ($missingEntries -join ", ")
    }
}

function Get-AiderArguments {
    param(
        [string]$SelectedModel,
        [bool]$GitWorkspace,
        [string]$SelectedProfile,
        [bool]$ForceYesAlways
    )

    $args = @(
        "-m", "aider",
        "--model", ("ollama_chat/" + $SelectedModel),
        "--openai-api-base", "http://127.0.0.1:11434/v1",
        "--analytics-disable",
        "--no-check-update",
        "--no-browser",
        "--encoding", "utf-8"
    )

    if (-not $GitWorkspace) {
        $args += "--no-git"
    }

    if ($SelectedProfile -eq "agentic" -or $ForceYesAlways) {
        $args += "--yes-always"
    }

    return $args
}

function Invoke-AiderCapabilityProbe {
    param(
        [string[]]$BaseAiderArgs
    )

    $probeRoot = Join-Path $env:TEMP ("ola-capability-probe-" + [guid]::NewGuid().ToString("N"))
    $null = New-Item -ItemType Directory -Path $probeRoot -Force
    $probeFile = Join-Path $probeRoot "note.txt"
    Set-Content -Path $probeFile -Value "seed" -Encoding utf8

    $runOutput = $null
    $editOutput = $null
    $settingsOutput = $null
    $webOutput = $null
    $expectedWhoAmI = Get-CurrentWhoAmI
    $probeAiderArgs = @() + $BaseAiderArgs

    if ($probeAiderArgs -notcontains "--yes-always") {
        $probeAiderArgs += "--yes-always"
    }

    if ($probeAiderArgs -notcontains "--no-git") {
        $probeAiderArgs += "--no-git"
    }

    $probeAiderArgs += @(
        "--no-pretty",
        "--no-stream",
        "--no-show-model-warnings"
    )

    Push-Location $probeRoot
    try {
        $runOutput = Invoke-CapturedProcess -FilePath $pythonCommand.Source -ArgumentList (@() + $probeAiderArgs + @(
            "--message", "/run whoami"
        )) -TimeoutSeconds 180

        $editOutput = Invoke-CapturedProcess -FilePath $pythonCommand.Source -ArgumentList (@() + $probeAiderArgs + @(
            "--message", "Change note.txt so it contains exactly OK and nothing else.",
            "note.txt"
        )) -TimeoutSeconds 300

        $settingsOutput = Invoke-CapturedProcess -FilePath $pythonCommand.Source -ArgumentList (@() + $probeAiderArgs + @(
            "--message", "/settings"
        )) -TimeoutSeconds 180

        $webOutput = Invoke-CapturedProcess -FilePath $pythonCommand.Source -ArgumentList (@() + $probeAiderArgs + @(
            "--message", "/web https://example.com"
        )) -TimeoutSeconds 240
    }
    finally {
        Pop-Location
    }

    $fileContents = (Get-Content -Raw $probeFile).Trim()
    $settingsText = $settingsOutput.Combined
    $functionCalling = $null

    if ($settingsText -match "supports_function_calling:\s+(\w+)") {
        $functionCalling = $Matches[1]
    }

    $shellCommandWorked = (
        $runOutput.ExitCode -eq 0 -and
        (
            [string]::IsNullOrWhiteSpace($expectedWhoAmI) -or
            $runOutput.Combined -match [regex]::Escape($expectedWhoAmI)
        )
    )
    $fileEditWorked = ($editOutput.ExitCode -eq 0 -and $fileContents -eq "OK")
    $webFetchWorked = (
        $webOutput.ExitCode -eq 0 -and
        $webOutput.Combined -match "added to chat" -and
        $webOutput.Combined -notmatch "Failed to retrieve content" -and
        $webOutput.Combined -notmatch "Error navigating"
    )
    $yesAlwaysEnabled = ($settingsText -match "yes_always:\s+True")
    $playwrightDisabled = ($settingsText -match "disable_playwright:\s+True")
    $fullAgenticClaimSupported = ($functionCalling -eq "True")

    return [pscustomobject]@{
        CapabilityProbePassed = (
            $shellCommandWorked -and
            $fileEditWorked -and
            $settingsOutput.ExitCode -eq 0 -and
            $yesAlwaysEnabled -and
            $settingsText -match "disable_playwright:\s+False" -and
            $webFetchWorked
        )
        ProbeWorkspace = $probeRoot
        ExpectedWhoAmI = $expectedWhoAmI
        ShellCommandWorked = $shellCommandWorked
        FileEditWorked = $fileEditWorked
        WebFetchWorked = $webFetchWorked
        YesAlwaysEnabled = $yesAlwaysEnabled
        PlaywrightDisabled = $playwrightDisabled
        NativeFunctionCallingAdvertised = $functionCalling
        FullAgenticClaimSupported = $fullAgenticClaimSupported
        FinalFileContents = $fileContents
        RunOutput = $runOutput.Combined
        EditOutput = $editOutput.Combined
        WebOutput = $webOutput.Combined
        SettingsOutput = $settingsText
    }
}

$resolvedWorkspace = if (Test-Path -LiteralPath $WorkspacePath) {
    (Resolve-Path -LiteralPath $WorkspacePath).ProviderPath
}
else {
    throw "WorkspacePath not found: $WorkspacePath"
}

if (-not (Test-Path -LiteralPath $OllamaPath)) {
    throw "Canonical Ollama binary not found: $OllamaPath"
}

if (-not (Test-Path -LiteralPath $OllamaHome)) {
    throw "Canonical Ollama home not found: $OllamaHome"
}

if (-not (Test-Path -LiteralPath $ModelsPath)) {
    throw "Canonical Ollama models path not found: $ModelsPath"
}

Set-ProcessEnvironment -Values (Get-RepairedProcessEnvironment)

$codexHome = if ($env:CODEX_HOME -and -not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
    $env:CODEX_HOME
}
else {
    "C:\Users\micha\.codex"
}

Set-ProcessEnvironment -Values ([ordered]@{
    CODEX_HOME            = $codexHome
    OLLAMA_HOME           = $OllamaHome
    OLLAMA_MODELS         = $ModelsPath
    OLLAMA_RUNNERS_DIR    = $RunnersDir
    OLLAMA_HOST           = "127.0.0.1:11434"
    OLLAMA_CONTEXT_LENGTH = "131072"
    OLLAMA_BATCH_SIZE     = "4096"
    OLLAMA_KV_CACHE_TYPE  = "q4_0"
    OLLAMA_NUM_PARALLEL   = "1"
    OLLAMA_GPU_LAYERS     = "-1"
    PYTHONUTF8            = "1"
    PYTHONIOENCODING      = "utf-8"
    PYTHONLEGACYWINDOWSSTDIO = "1"
    OLLAMA_API_BASE       = "http://127.0.0.1:11434"
})

Set-Utf8Console

Ensure-OllamaServer

$listOutput = Invoke-CapturedProcess -FilePath $OllamaPath -ArgumentList @("list") -TimeoutSeconds 30
if ($listOutput.ExitCode -ne 0) {
    throw "Ollama list failed via $OllamaPath`n$listOutput.Combined"
}

$installedModels = Get-InstalledOllamaModels -ListOutput $listOutput.Combined
$resolvedRuntime = Resolve-OlaRuntime -RequestedRuntime $Runtime -SelectedProfile $Profile
$resolvedModelRouting = Resolve-OlaModelRouting -ChosenRuntime $resolvedRuntime -RequestedRouting $ModelRouting -ExplicitPrimaryModel $PSBoundParameters.ContainsKey("Model") -ExplicitRouting $PSBoundParameters.ContainsKey("ModelRouting")
$resolvedModel = Resolve-OlaModel -ChosenRuntime $resolvedRuntime -RequestedModel $Model -InstalledModels $installedModels -ExplicitModel $PSBoundParameters.ContainsKey("Model")
$resolvedHeavyModel = Resolve-OlaHeavyModel -ChosenRuntime $resolvedRuntime -RequestedHeavyModel $HeavyModel -InstalledModels $installedModels -PrimaryModel $resolvedModel
$resolvedCoderModel = Resolve-OlaOptionalModel -RequestedModel $CoderModel -InstalledModels $installedModels -PreferredInstalledCandidates @("qwen3-coder-next:latest", "qwen3-coder:latest", "qwen3-coder-next", "qwen3-coder") -FallbackModel $resolvedModel
$resolvedStructuredModel = Resolve-OlaOptionalModel -RequestedModel $StructuredModel -InstalledModels $installedModels -PreferredInstalledCandidates @("gpt-oss:20b", "gpt-oss:latest") -FallbackModel $resolvedHeavyModel
$resolvedVisionModel = Resolve-OlaOptionalModel -RequestedModel $VisionModel -InstalledModels $installedModels -PreferredInstalledCandidates @("gemma4:latest", "gemma4") -FallbackModel $resolvedModel
$nativeAgentScript = Join-Path $PSScriptRoot "Invoke-OlaNativeAgent.ps1"

if ($installedModels -notcontains $resolvedModel) {
    throw "Model '$resolvedModel' was not found in 'ollama list'."
}

if ($resolvedRuntime -eq "native" -and $installedModels -notcontains $resolvedHeavyModel) {
    throw "Heavy model '$resolvedHeavyModel' was not found in 'ollama list'."
}

$isGitWorkspace = Test-GitRepository -Path $resolvedWorkspace
$forceYesAlways = ($YesAlways -or $SmokeTest -or $CapabilityProbe)
$pythonCommand = $null
$playwrightModuleInstalled = $false
$playwrightState = [pscustomobject]@{
    Changed = $false
    Ready = $false
    Details = ""
    InstallOutput = ""
}

if ($resolvedRuntime -eq "aider") {
    $pythonCommand = Get-Command "python" -ErrorAction Stop
    $shouldEnsurePlaywright = ($EnsurePlaywright -or $CapabilityProbe -or $Profile -eq "agentic")
    $playwrightModuleInstalled = Test-PlaywrightModuleInstalled
    $playwrightState = if ($shouldEnsurePlaywright) {
    Ensure-PlaywrightChromium
}
else {
    $probe = Test-PlaywrightChromiumReady
    [pscustomobject]@{
        Changed = $false
        Ready = $probe.Ready
        Details = $probe.Details
        InstallOutput = ""
    }
}
}

$aiderArgs = if ($resolvedRuntime -eq "aider") {
    Get-AiderArguments -SelectedModel $resolvedModel -GitWorkspace $isGitWorkspace -SelectedProfile $Profile -ForceYesAlways $forceYesAlways
}
else {
    @()
}
$nativeArgs = Get-NativeAgentArguments -AgentScriptPath $nativeAgentScript -SelectedModel $resolvedModel -SelectedHeavyModel $resolvedHeavyModel -SelectedCoderModel $resolvedCoderModel -SelectedStructuredModel $resolvedStructuredModel -SelectedVisionModel $resolvedVisionModel -SelectedModelRouting $resolvedModelRouting -ResolvedWorkspace $resolvedWorkspace -InitialPrompt $Prompt -SinglePromptMode (-not [string]::IsNullOrWhiteSpace($Prompt)) -DirectiveEnabled $DirectiveMode.IsPresent

if ($PrintResolvedCommand) {
    [pscustomobject]@{
        Mode = if ($SmokeTest) { "smoke" } elseif ($Prompt) { "one-shot" } else { "interactive" }
        Profile = $Profile
        Runtime = $resolvedRuntime
        WorkspacePath = $resolvedWorkspace
        GitWorkspace = $isGitWorkspace
        ModelRouting = $resolvedModelRouting
        Model = $resolvedModel
        HeavyModel = $resolvedHeavyModel
        CoderModel = $resolvedCoderModel
        StructuredModel = $resolvedStructuredModel
        VisionModel = $resolvedVisionModel
        FallbackModel = $FallbackModel
        DirectiveMode = $DirectiveMode.IsPresent
        PythonPath = if ($pythonCommand) { $pythonCommand.Source } else { $null }
        OllamaPath = $OllamaPath
        OLLAMA_HOME = $env:OLLAMA_HOME
        OLLAMA_MODELS = $env:OLLAMA_MODELS
        OLLAMA_RUNNERS_DIR = $env:OLLAMA_RUNNERS_DIR
        OLLAMA_HOST = $env:OLLAMA_HOST
        OLLAMA_CONTEXT_LENGTH = $env:OLLAMA_CONTEXT_LENGTH
        OLLAMA_BATCH_SIZE = $env:OLLAMA_BATCH_SIZE
        OLLAMA_KV_CACHE_TYPE = $env:OLLAMA_KV_CACHE_TYPE
        OLLAMA_NUM_PARALLEL = $env:OLLAMA_NUM_PARALLEL
        OLLAMA_GPU_LAYERS = $env:OLLAMA_GPU_LAYERS
        PlaywrightPythonInstalled = $playwrightModuleInstalled
        PlaywrightChromiumReady = $playwrightState.Ready
        PlaywrightChanged = $playwrightState.Changed
        Command = if ($resolvedRuntime -eq "aider") {
            Format-CommandForDisplay -FilePath $pythonCommand.Source -ArgumentList $aiderArgs
        }
        else {
            Format-CommandForDisplay -FilePath "powershell.exe" -ArgumentList $nativeArgs
        }
        FallbackHint = if ($resolvedRuntime -eq "aider") {
            "ola -WorkspacePath '$resolvedWorkspace' -Model '$FallbackModel'"
        }
        else {
            "ola -WorkspacePath '$resolvedWorkspace' -Model '$resolvedCoderModel' -ModelRouting auto"
        }
    } | Format-List
    return
}

Push-Location $resolvedWorkspace
try {
    if ($SmokeTest) {
        if ($resolvedRuntime -eq "aider") {
            $smokeArgs = @() + $aiderArgs + @(
                "--no-pretty",
                "--no-stream",
                "--message", $SmokePrompt
            )
            $smokeOutput = Invoke-CapturedProcess -FilePath $pythonCommand.Source -ArgumentList $smokeArgs -TimeoutSeconds 180
            $smokeLines = @($smokeOutput.Combined -split [Environment]::NewLine | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            if ($smokeOutput.ExitCode -ne 0 -or -not ($smokeLines -contains "OK")) {
                throw "ola smoke test failed`n$($smokeOutput.Combined)"
            }
        }
        else {
            $smokeArgs = Get-NativeAgentArguments -AgentScriptPath $nativeAgentScript -SelectedModel $resolvedModel -SelectedHeavyModel $resolvedHeavyModel -SelectedCoderModel $resolvedCoderModel -SelectedStructuredModel $resolvedStructuredModel -SelectedVisionModel $resolvedVisionModel -SelectedModelRouting $resolvedModelRouting -ResolvedWorkspace $resolvedWorkspace -InitialPrompt $SmokePrompt -SinglePromptMode $true -DirectiveEnabled $DirectiveMode.IsPresent
            $smokeOutput = Invoke-CapturedProcess -FilePath "powershell.exe" -ArgumentList $smokeArgs -TimeoutSeconds 180
            if ($smokeOutput.ExitCode -ne 0 -or $smokeOutput.Combined -notmatch "(?m)^\s*OK\s*$") {
                throw "ola smoke test failed`n$($smokeOutput.Combined)"
            }
        }

        [pscustomobject]@{
            SmokePassed = $true
            Runtime = $resolvedRuntime
            WorkspacePath = $resolvedWorkspace
            Model = $resolvedModel
            HeavyModel = $resolvedHeavyModel
            CoderModel = $resolvedCoderModel
            StructuredModel = $resolvedStructuredModel
            VisionModel = $resolvedVisionModel
            ModelRouting = $resolvedModelRouting
            FallbackModel = $FallbackModel
            PythonPath = if ($pythonCommand) { $pythonCommand.Source } else { $null }
            OllamaPath = $OllamaPath
            Output = "OK"
        } | Format-List
        Complete-OlaSuccess
        return
    }

    if ($CapabilityProbe) {
        if ($resolvedRuntime -eq "aider") {
            $probe = Invoke-AiderCapabilityProbe -BaseAiderArgs $aiderArgs
            [pscustomobject]@{
                CapabilityProbePassed = $probe.CapabilityProbePassed
                Runtime = $resolvedRuntime
                Profile = $Profile
                WorkspacePath = $resolvedWorkspace
                Model = $resolvedModel
                GitWorkspace = $isGitWorkspace
                PlaywrightPythonInstalled = $playwrightModuleInstalled
                PlaywrightChromiumReady = $playwrightState.Ready
                ShellCommandWorked = $probe.ShellCommandWorked
                FileEditWorked = $probe.FileEditWorked
                WebFetchWorked = $probe.WebFetchWorked
                YesAlwaysEnabled = $probe.YesAlwaysEnabled
                PlaywrightDisabled = $probe.PlaywrightDisabled
                NativeFunctionCallingAdvertised = $probe.NativeFunctionCallingAdvertised
                FullAgenticClaimSupported = $probe.FullAgenticClaimSupported
                ProbeWorkspace = $probe.ProbeWorkspace
                FinalFileContents = $probe.FinalFileContents
            } | Format-List

            if (-not $probe.CapabilityProbePassed) {
                throw "ola capability probe failed`nRunOutput:`n$($probe.RunOutput)`n`nEditOutput:`n$($probe.EditOutput)`n`nWebOutput:`n$($probe.WebOutput)`n`nSettingsOutput:`n$($probe.SettingsOutput)"
            }
        }
        else {
            $probe = Invoke-NativeAgentCapabilityProbe -AgentScriptPath $nativeAgentScript -SelectedModel $resolvedModel -SelectedHeavyModel $resolvedHeavyModel -SelectedCoderModel $resolvedCoderModel -SelectedStructuredModel $resolvedStructuredModel -SelectedVisionModel $resolvedVisionModel -SelectedModelRouting $resolvedModelRouting -ResolvedWorkspace $resolvedWorkspace
            [pscustomobject]@{
                CapabilityProbePassed = $probe.CapabilityProbePassed
                Runtime = $resolvedRuntime
                Profile = $Profile
                WorkspacePath = $resolvedWorkspace
                Model = $resolvedModel
                HeavyModel = $resolvedHeavyModel
                CoderModel = $resolvedCoderModel
                StructuredModel = $resolvedStructuredModel
                VisionModel = $resolvedVisionModel
                ModelRouting = $resolvedModelRouting
                ToolCallWorked = $probe.ToolCallWorked
                WorkspaceMentioned = $probe.WorkspaceMentioned
                MissingEntries = $probe.MissingEntries
            } | Format-List

            if (-not $probe.CapabilityProbePassed) {
                throw "ola capability probe failed`n$($probe.ProbeOutput)"
            }
        }

        Complete-OlaSuccess
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($Prompt)) {
        if ($resolvedRuntime -eq "aider") {
            & $pythonCommand.Source @($aiderArgs + @("--message", $Prompt) + $Files)
        }
        else {
            & powershell.exe @($nativeArgs)
        }
        Complete-OlaSuccess
        return
    }

    if ($resolvedRuntime -eq "aider") {
        & $pythonCommand.Source @($aiderArgs + $Files)
    }
    else {
        $interactiveArgs = Get-NativeAgentArguments -AgentScriptPath $nativeAgentScript -SelectedModel $resolvedModel -SelectedHeavyModel $resolvedHeavyModel -SelectedCoderModel $resolvedCoderModel -SelectedStructuredModel $resolvedStructuredModel -SelectedVisionModel $resolvedVisionModel -SelectedModelRouting $resolvedModelRouting -ResolvedWorkspace $resolvedWorkspace -InitialPrompt $null -SinglePromptMode $false -DirectiveEnabled $DirectiveMode.IsPresent
        & powershell.exe @($interactiveArgs)
    }
    Complete-OlaSuccess
}
finally {
    Pop-Location
}
