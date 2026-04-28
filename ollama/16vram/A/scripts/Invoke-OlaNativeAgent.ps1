[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$InitialPrompt,

    [string]$WorkspacePath = (Get-Location).Path,
    [string]$Model = "qwen3.5-oll90:latest",
    [string]$HeavyModel = "qwen3:30b-a3b",
    [string]$CoderModel = "qwen3-coder:latest",
    [string]$StructuredModel = "gpt-oss:20b",
    [string]$VisionModel = "gemma4:latest",
    [ValidateSet("auto", "fixed")]
    [string]$RoutingMode = "auto",
    [string]$OllamaUrl = "http://127.0.0.1:11434",
    [int]$ChatTimeoutSeconds = 240,
    [int]$ToolTimeoutSeconds = 180,
    [int]$MaxToolIterations = 10,
    [switch]$DirectiveMode,
    [int]$SessionCompactionCharThreshold = 32000,
    [int]$SessionCompactionKeepRecentEntries = 12,
    [switch]$RoutingProbeOnly,
    [switch]$SinglePrompt
)

$ErrorActionPreference = "Stop"
$script:OlaUiState = @{
    Turn = 0
    MissionType = ""
    ActiveModel = ""
    PreferredSynthesisModel = ""
    ToolCalls = 0
    DirectiveMode = $DirectiveMode.IsPresent
    Workspace = ""
    LastPhase = ""
    LastStatusRenderedAt = $null
    StartedAt = Get-Date
}
$script:OlaTelemetryCache = @{
    Snapshot = $null
    SampledAt = [datetime]::MinValue
    ActiveModels = "idle"
    ActiveModelsSampledAt = [datetime]::MinValue
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

function ConvertTo-Hashtable {
    param(
        [object]$InputObject
    )

    if ($InputObject -is [hashtable]) {
        return $InputObject
    }

    if ($InputObject -is [string]) {
        try {
            $InputObject = $InputObject | ConvertFrom-Json
        }
        catch {
            return @{ value = $InputObject }
        }
    }

    $hash = @{}
    if ($InputObject -and $InputObject.PSObject) {
        foreach ($property in $InputObject.PSObject.Properties) {
            $hash[$property.Name] = $property.Value
        }
    }

    return $hash
}

function ConvertTo-DisplayJson {
    param(
        [object]$InputObject
    )

    return ($InputObject | ConvertTo-Json -Depth 8)
}

function ConvertFrom-JsonSafe {
    param(
        [string]$JsonText
    )

    if ([string]::IsNullOrWhiteSpace($JsonText)) {
        return $null
    }

    try {
        return ($JsonText | ConvertFrom-Json -Depth 12)
    }
    catch {
        return $null
    }
}

function Test-IsCleanupInspectionRequest {
    param(
        [string]$UserInput
    )

    if ([string]::IsNullOrWhiteSpace($UserInput)) {
        return $false
    }

    $lower = $UserInput.ToLowerInvariant()
    return (
        $lower -match '\b(cleanup|free up space|free space|temp|cache|caches|monthly-empty|empty monthly|crashdump|crash dump|log cleanup|disk cleanup)\b' -or
        (
            $lower -match '\b(path|paths|folder|folders|directory|directories)\b' -and
            $lower -match '\b(add to\b.*\bfunction|cleanup function|safe to delete|safely delete|ccsizes)\b'
        )
    )
}

function Limit-OlaPreview {
    param(
        [string]$Text,
        [int]$MaxLength = 120
    )

    $collapsed = (($Text -replace "\s+", " ").Trim())
    if ([string]::IsNullOrWhiteSpace($collapsed)) {
        return ""
    }

    if ($collapsed.Length -le $MaxLength) {
        return $collapsed
    }

    return ($collapsed.Substring(0, $MaxLength - 3) + "...")
}

function Get-OlaConsoleWidth {
    $width = 96
    try {
        if ($Host.UI.RawUI.WindowSize.Width -gt 20) {
            $width = [Math]::Min([Math]::Max($Host.UI.RawUI.WindowSize.Width - 1, 20), 140)
        }
    }
    catch {
    }

    return $width
}

function Format-OlaBytes {
    param(
        [double]$Bytes
    )

    if ($Bytes -lt 0) {
        return "0B"
    }

    if ($Bytes -ge 1GB) {
        return ("{0}G" -f ([math]::Round(($Bytes / 1GB), 1)))
    }

    if ($Bytes -ge 1MB) {
        return ("{0}M" -f ([math]::Round(($Bytes / 1MB), 1)))
    }

    if ($Bytes -ge 1KB) {
        return ("{0}K" -f ([math]::Round(($Bytes / 1KB), 1)))
    }

    return ([math]::Round($Bytes, 0).ToString() + "B")
}

function Format-OlaPercent {
    param(
        [Nullable[Double]]$Value
    )

    if ($null -eq $Value) {
        return "n/a"
    }

    return (([math]::Round([double]$Value, 1)).ToString("0.#") + "%")
}

function Get-OlaActiveModelsSummary {
    $sampleAgeSeconds = ((Get-Date) - $script:OlaTelemetryCache.ActiveModelsSampledAt).TotalSeconds
    if ($sampleAgeSeconds -lt 3 -and -not [string]::IsNullOrWhiteSpace([string]$script:OlaTelemetryCache.ActiveModels)) {
        return [string]$script:OlaTelemetryCache.ActiveModels
    }

    $summary = "idle"
    try {
        $ollamaCommand = Get-Command "ollama" -ErrorAction SilentlyContinue
        if ($ollamaCommand) {
            $lines = @(
                & $ollamaCommand.Source ps 2>$null |
                    ForEach-Object { $_.TrimEnd() } |
                    Where-Object { $_ }
            )

            if ($lines.Count -gt 1) {
                $models = @()
                foreach ($line in ($lines | Select-Object -Skip 1)) {
                    $parts = ($line -split '\s{2,}').Trim() | Where-Object { $_ }
                    if ($parts.Count -ge 4) {
                        $models += (($parts[0] + " " + $parts[3]))
                    }
                    elseif ($parts.Count -ge 1) {
                        $models += $parts[0]
                    }
                }

                if ($models.Count -gt 0) {
                    $summary = Limit-OlaPreview -Text ($models -join ", ") -MaxLength 64
                }
            }
        }
    }
    catch {
        $summary = "ps unavailable"
    }

    $script:OlaTelemetryCache.ActiveModels = $summary
    $script:OlaTelemetryCache.ActiveModelsSampledAt = Get-Date
    return $summary
}

function Get-OlaTelemetrySnapshot {
    $sampleAgeMilliseconds = ((Get-Date) - $script:OlaTelemetryCache.SampledAt).TotalMilliseconds
    if ($script:OlaTelemetryCache.Snapshot -and $sampleAgeMilliseconds -lt 900) {
        return $script:OlaTelemetryCache.Snapshot
    }

    $machineCpu = $null
    $machineRamUsedBytes = $null
    $machineRamTotalBytes = $null
    $machineGpu = $null
    $localCpu = $null
    $localRamBytes = [double]0
    $localGpu = $null

    try {
        $counterSample = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop).CounterSamples | Select-Object -First 1
        if ($counterSample) {
            $machineCpu = [math]::Round([double]$counterSample.CookedValue, 1)
        }
    }
    catch {
    }

    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $machineRamTotalBytes = [double]$osInfo.TotalVisibleMemorySize * 1KB
        $machineRamUsedBytes = ([double]$osInfo.TotalVisibleMemorySize - [double]$osInfo.FreePhysicalMemory) * 1KB
    }
    catch {
    }

    try {
        $gpuSamples = @((Get-Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction Stop).CounterSamples)
        if ($gpuSamples.Count -gt 0) {
            $machineGpu = [math]::Min(([math]::Round((($gpuSamples | Measure-Object -Property CookedValue -Sum).Sum), 1)), 100)

            $ollamaProcesses = @(Get-Process ollama -ErrorAction SilentlyContinue)
            if ($ollamaProcesses.Count -gt 0) {
                $ollamaIds = @($ollamaProcesses | ForEach-Object { [int]$_.Id })
                $localGpuSum = 0.0
                foreach ($sample in $gpuSamples) {
                    if ($sample.InstanceName -match 'pid_(\d+)_') {
                        $samplePid = [int]$matches[1]
                        if ($ollamaIds -contains $samplePid) {
                            $localGpuSum += [double]$sample.CookedValue
                        }
                    }
                }

                $localGpu = [math]::Min(([math]::Round($localGpuSum, 1)), 100)
            }
        }
    }
    catch {
    }

    try {
        $ollamaProcesses = @(Get-Process ollama -ErrorAction SilentlyContinue)
        if ($ollamaProcesses.Count -gt 0) {
            $ollamaIds = @($ollamaProcesses | ForEach-Object { [int]$_.Id })
            $perfProcesses = @(
                Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction Stop |
                    Where-Object { $ollamaIds -contains [int]$_.IDProcess }
            )

            if ($perfProcesses.Count -gt 0) {
                $rawCpu = ($perfProcesses | Measure-Object -Property PercentProcessorTime -Sum).Sum
                if ($null -ne $rawCpu) {
                    $cpuCount = [Math]::Max([Environment]::ProcessorCount, 1)
                    $localCpu = [math]::Round(([double]$rawCpu / $cpuCount), 1)
                }

                $privateBytes = ($perfProcesses | Measure-Object -Property PrivateBytes -Sum).Sum
                if ($privateBytes) {
                    $localRamBytes = [double]$privateBytes
                }
            }

            if ($localRamBytes -le 0) {
                $fallbackPrivateBytes = ($ollamaProcesses | Measure-Object -Property PrivateMemorySize64 -Sum).Sum
                if ($fallbackPrivateBytes) {
                    $localRamBytes = [double]$fallbackPrivateBytes
                }
            }
        }
    }
    catch {
    }

    $snapshot = [ordered]@{
        MachineCpu = $machineCpu
        MachineRamUsedBytes = $machineRamUsedBytes
        MachineRamTotalBytes = $machineRamTotalBytes
        MachineGpu = $machineGpu
        LocalCpu = $localCpu
        LocalRamBytes = $localRamBytes
        LocalGpu = $localGpu
        ActiveModels = Get-OlaActiveModelsSummary
    }

    $script:OlaTelemetryCache.Snapshot = $snapshot
    $script:OlaTelemetryCache.SampledAt = Get-Date
    return $snapshot
}

function Get-OlaStatusLineText {
    $snapshot = Get-OlaTelemetrySnapshot
    $machineRamText = if ($snapshot.MachineRamTotalBytes) {
        (Format-OlaBytes -Bytes $snapshot.MachineRamUsedBytes) + "/" + (Format-OlaBytes -Bytes $snapshot.MachineRamTotalBytes)
    }
    else {
        "n/a"
    }

    $phaseText = if ([string]::IsNullOrWhiteSpace([string]$script:OlaUiState.LastPhase)) {
        "idle"
    }
    else {
        [string]$script:OlaUiState.LastPhase
    }

    return (
        "sys cpu {0} | ram {1} | gpu {2} || local cpu {3} | ram {4} | gpu {5} || models {6} || phase {7}" -f
        (Format-OlaPercent -Value $snapshot.MachineCpu),
        $machineRamText,
        (Format-OlaPercent -Value $snapshot.MachineGpu),
        (Format-OlaPercent -Value $snapshot.LocalCpu),
        (Format-OlaBytes -Bytes $snapshot.LocalRamBytes),
        (Format-OlaPercent -Value $snapshot.LocalGpu),
        (Limit-OlaPreview -Text ([string]$snapshot.ActiveModels) -MaxLength 44),
        (Limit-OlaPreview -Text $phaseText -MaxLength 28)
    )
}

function Update-OlaConsoleTitle {
    $title = "ola | " + (Get-OlaStatusLineText)
    try {
        [Console]::Title = (Limit-OlaPreview -Text $title -MaxLength 180)
    }
    catch {
    }
}

function Get-OlaStageColor {
    param(
        [string]$Stage,
        [string]$State
    )

    $stateUpper = if ($State) { $State.ToUpperInvariant() } else { "" }
    if ($stateUpper -eq "FAIL" -or $stateUpper -eq "ERROR") {
        return "Red"
    }

    switch ($Stage.ToLowerInvariant()) {
        "turn" { return "Magenta" }
        "route" { return "Cyan" }
        "model" { return "Yellow" }
        "tool" { return "DarkCyan" }
        "answer" { return "Green" }
        "memory" { return "DarkYellow" }
        default { return "Gray" }
    }
}

function Write-OlaDivider {
    param(
        [string]$Character = "-"
    )

    $width = Get-OlaConsoleWidth
    Write-Host ($Character * $width) -ForegroundColor DarkGray
}

function Write-OlaFramedLine {
    param(
        [string]$Text,
        [string]$Color = "White"
    )

    $width = Get-OlaConsoleWidth
    $innerWidth = [Math]::Max(($width - 4), 16)
    $trimmed = Limit-OlaPreview -Text $Text -MaxLength $innerWidth
    Write-Host ("| " + $trimmed.PadRight($innerWidth) + " |") -ForegroundColor $Color
}

function Write-OlaStatusLine {
    param(
        [switch]$Force
    )

    $now = Get-Date
    $shouldRender = $Force.IsPresent
    if (-not $shouldRender) {
        $lastRendered = $script:OlaUiState.LastStatusRenderedAt
        if ($null -eq $lastRendered) {
            $shouldRender = $true
        }
        else {
            $shouldRender = ((New-TimeSpan -Start $lastRendered -End $now).TotalSeconds -ge 2)
        }
    }

    if (-not $shouldRender) {
        return
    }

    Write-Host ("status  " + (Get-OlaStatusLineText)) -ForegroundColor DarkGray
    $script:OlaUiState.LastStatusRenderedAt = $now
    Update-OlaConsoleTitle
}

function Write-OlaProgress {
    param(
        [string]$Stage,
        [string]$Message,
        [string]$State = "info"
    )

    $script:OlaUiState.LastPhase = ($Stage + ":" + $State)
    Write-OlaStatusLine
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    $stageLabel = $Stage.ToUpperInvariant().PadRight(7)
    $stateLabel = $State.ToUpperInvariant().PadRight(7)
    $line = "[{0}] {1} {2} {3}" -f $timestamp, $stageLabel, $stateLabel, $Message
    Write-Host $line -ForegroundColor (Get-OlaStageColor -Stage $Stage -State $State)
}

function Start-OlaHeartbeat {
    param(
        [string]$Phase,
        [string]$Detail,
        [int]$IntervalSeconds = 8
    )

    $phaseLabel = if ([string]::IsNullOrWhiteSpace($Phase)) {
        "TASK"
    }
    else {
        $Phase.Trim().ToUpperInvariant()
    }

    $detailText = if ([string]::IsNullOrWhiteSpace($Detail)) {
        "waiting"
    }
    else {
        $Detail
    }

    $heartbeatScript = @'
param($HeartbeatPhase, $HeartbeatDetail, $HeartbeatIntervalSeconds)
$startedAt = Get-Date
while ($true) {
    Start-Sleep -Seconds $HeartbeatIntervalSeconds
    $line = ('[{0}] {1} WAIT    still working | {2} | elapsed={3:mm\:ss}' -f (Get-Date).ToString('HH:mm:ss'), $HeartbeatPhase.PadRight(7), $HeartbeatDetail, ((Get-Date) - $startedAt))
    $previousColor = [Console]::ForegroundColor
    try {
        [Console]::ForegroundColor = [ConsoleColor]::DarkGray
        [Console]::WriteLine($line)
    }
    finally {
        [Console]::ForegroundColor = $previousColor
    }
}
'@

    $heartbeatPs = [powershell]::Create()
    $null = $heartbeatPs.AddScript($heartbeatScript).AddArgument($phaseLabel).AddArgument($detailText).AddArgument([Math]::Max($IntervalSeconds, 1))
    $heartbeatHandle = $heartbeatPs.BeginInvoke()

    return [pscustomobject]@{
        PowerShell = $heartbeatPs
        AsyncHandle = $heartbeatHandle
    }
}

function Stop-OlaHeartbeat {
    param(
        [object]$Heartbeat
    )

    if (-not $Heartbeat) {
        return
    }

    try {
        if ($Heartbeat.PowerShell) {
            $Heartbeat.PowerShell.Stop()
        }
    }
    catch {
    }
    finally {
        if ($Heartbeat.PowerShell) {
            $Heartbeat.PowerShell.Dispose()
        }
    }
}

function Invoke-WithOlaHeartbeat {
    param(
        [string]$Phase,
        [string]$Detail,
        [int]$IntervalSeconds = 8,
        [scriptblock]$Action
    )

    $heartbeat = $null
    try {
        $heartbeat = Start-OlaHeartbeat -Phase $Phase -Detail $Detail -IntervalSeconds $IntervalSeconds
        return (& $Action)
    }
    finally {
        Stop-OlaHeartbeat -Heartbeat $heartbeat
    }
}

function Write-OlaTextBlock {
    param(
        [string]$Label,
        [string]$Text,
        [int]$MaxLines = 8
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return
    }

    $lines = @(
        $Text -split '\r?\n' |
            ForEach-Object { $_.TrimEnd() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    if ($lines.Count -eq 0) {
        return
    }

    Write-Host ("[{0}]" -f $Label.ToUpperInvariant()) -ForegroundColor DarkGray
    $displayLines = if ($MaxLines -le 0) { $lines } else { $lines | Select-Object -First $MaxLines }
    foreach ($line in $displayLines) {
        Write-Host ("  " + $line) -ForegroundColor White
    }

    if ($MaxLines -gt 0 -and $lines.Count -gt $MaxLines) {
        Write-Host ("  ... ({0} more lines)" -f ($lines.Count - $MaxLines)) -ForegroundColor DarkGray
    }
}

function Write-OlaTurnHeader {
    param(
        [int]$TurnNumber,
        [string]$UserInput,
        [string]$InitialModel,
        [string]$PreferredSynthesisModel,
        [string]$MissionType
    )

    $script:OlaUiState.Turn = $TurnNumber
    $script:OlaUiState.MissionType = $MissionType
    $script:OlaUiState.ActiveModel = $InitialModel
    $script:OlaUiState.PreferredSynthesisModel = $PreferredSynthesisModel

    $width = Get-OlaConsoleWidth
    Write-Host ("+" + ("=" * ($width - 2)) + "+") -ForegroundColor DarkGray
    Write-OlaFramedLine -Text ("OLA NATIVE | directive=" + ($(if ($script:OlaUiState.DirectiveMode) { "ON" } else { "OFF" })) + " | workspace=" + $script:OlaUiState.Workspace) -Color Cyan
    Write-OlaFramedLine -Text ("turn #" + $TurnNumber + " | mission=" + $MissionType + " | initial=" + $InitialModel + " | synthesis=" + $PreferredSynthesisModel) -Color Yellow
    Write-OlaFramedLine -Text (Get-OlaStatusLineText) -Color DarkGray
    Write-Host ("+" + ("=" * ($width - 2)) + "+") -ForegroundColor DarkGray
    $script:OlaUiState.LastStatusRenderedAt = Get-Date
    Update-OlaConsoleTitle
    Write-OlaProgress -Stage "turn" -State "start" -Message ("#" + $TurnNumber + " | mission=" + $MissionType + " | initial=" + $InitialModel + " | synthesis=" + $PreferredSynthesisModel)
    Write-OlaProgress -Stage "turn" -State "prompt" -Message (Limit-OlaPreview -Text $UserInput -MaxLength 180)
}

function Get-ToolResultProgressSummary {
    param(
        [string]$ToolName,
        [string]$ToolResult
    )

    $parsed = ConvertFrom-JsonSafe -JsonText $ToolResult
    if (-not $parsed) {
        return ""
    }

    switch ($ToolName) {
        "run_powershell" {
            $status = "exit=" + $parsed.exit_code
            if ($parsed.timed_out) {
                return ($status + " timed_out")
            }

            if ($parsed.exit_code -eq 0) {
                $stdoutPreview = Limit-OlaPreview -Text ([string]$parsed.stdout) -MaxLength 100
                return if ($stdoutPreview) { $status + " | " + $stdoutPreview } else { $status }
            }

            $stderrPreview = Limit-OlaPreview -Text ([string]$parsed.stderr) -MaxLength 100
            return if ($stderrPreview) { $status + " | " + $stderrPreview } else { $status }
        }

        "search_files" {
            if ($parsed.matches) {
                return ("matches=" + @($parsed.matches).Count)
            }

            if ($parsed.stdout) {
                $count = @(([string]$parsed.stdout -split '\r?\n') | Where-Object { $_ }).Count
                return ("lines=" + $count)
            }

            return "no matches"
        }

        "read_file" {
            $charCount = 0
            if ($null -ne $parsed.char_count) {
                $charCount = [int]$parsed.char_count
            }

            $parts = @()
            if ($charCount -gt 0) {
                $parts += ("chars=" + $charCount)
            }
            if ($parsed.truncated) {
                $parts += "truncated"
            }

            return ($parts -join " | ")
        }

        "web_search" {
            return ("provider=" + $parsed.provider + " | results=" + @($parsed.results).Count)
        }

        "web_fetch" {
            $title = Limit-OlaPreview -Text ([string]$parsed.title) -MaxLength 80
            if ($title) {
                return ("provider=" + $parsed.provider + " | title=" + $title)
            }

            return ("provider=" + $parsed.provider)
        }

        "scrape_web_page" {
            return ("items=" + $parsed.item_count + " | selector=" + $parsed.selector)
        }

        "find_cleanup_candidates" {
            return ("candidates=" + @($parsed.candidates).Count + " | broad=" + $parsed.heuristic_scan_enabled)
        }

        default {
            if ($parsed.error) {
                return (Limit-OlaPreview -Text ([string]$parsed.error) -MaxLength 100)
            }

            return ""
        }
    }
}

function Get-ToolProgressSummary {
    param(
        [string]$Name,
        [hashtable]$Arguments,
        [string]$ResolvedWorkspace
    )

    switch ($Name) {
        "run_powershell" {
            $command = [string]$Arguments["command"]
            if ([string]::IsNullOrWhiteSpace($command)) {
                return "(missing command)"
            }

            $collapsed = (($command -replace "\s+", " ").Trim())
            if ($collapsed.Length -gt 120) {
                $collapsed = $collapsed.Substring(0, 117) + "..."
            }

            return $collapsed
        }

        "list_directory" {
            $path = [string]$Arguments["path"]
            if ([string]::IsNullOrWhiteSpace($path)) {
                $path = $ResolvedWorkspace
            }

            $parts = New-Object System.Collections.Generic.List[string]
            $parts.Add($path)
            if ($Arguments.ContainsKey("recursive") -and [bool]$Arguments["recursive"]) {
                $parts.Add("recursive")
            }

            $pattern = [string]$Arguments["pattern"]
            if (-not [string]::IsNullOrWhiteSpace($pattern)) {
                $parts.Add("pattern=" + $pattern)
            }

            return ($parts -join " | ")
        }

        "read_file" { return [string]$Arguments["path"] }
        "write_file" { return [string]$Arguments["path"] }
        "edit_file" { return [string]$Arguments["path"] }

        "search_files" {
            $path = [string]$Arguments["path"]
            $pattern = [string]$Arguments["pattern"]
            $fileGlob = [string]$Arguments["file_glob"]
            $parts = @($path)
            if (-not [string]::IsNullOrWhiteSpace($fileGlob)) {
                $parts += ("glob=" + $fileGlob)
            }

            if (-not [string]::IsNullOrWhiteSpace($pattern)) {
                $parts += ("pattern=" + $pattern)
            }

            return ($parts -join " | ")
        }

        "web_search" {
            $query = [string]$Arguments["query"]
            $site = [string]$Arguments["site"]
            $parts = @()
            if (-not [string]::IsNullOrWhiteSpace($site)) {
                $parts += ("site=" + $site)
            }
            if (-not [string]::IsNullOrWhiteSpace($query)) {
                $parts += (Limit-OlaPreview -Text $query -MaxLength 90)
            }

            return ($parts -join " | ")
        }

        "web_fetch" {
            return (Limit-OlaPreview -Text ([string]$Arguments["url"]) -MaxLength 110)
        }

        "scrape_web_page" {
            $parts = @(
                (Limit-OlaPreview -Text ([string]$Arguments["url"]) -MaxLength 70),
                ("selector=" + [string]$Arguments["selector"])
            )
            return ($parts -join " | ")
        }

        "list_drives" {
            return "filesystem drives"
        }

        "find_cleanup_candidates" {
            $driveRoot = [string]$Arguments["drive_root"]
            if ([string]::IsNullOrWhiteSpace($driveRoot)) {
                $driveRoot = [Environment]::GetEnvironmentVariable("SystemDrive", "Process")
            }

            if ([string]::IsNullOrWhiteSpace($driveRoot)) {
                $driveRoot = "C:"
            }

            $parts = @(($driveRoot.TrimEnd('\') + "\"))
            if ($Arguments.ContainsKey("broad_scan") -and [bool]$Arguments["broad_scan"]) {
                $parts += "broad"
            }

            if ($Arguments.ContainsKey("max_results") -and $Arguments["max_results"]) {
                $parts += ("top=" + [int]$Arguments["max_results"])
            }

            return ($parts -join " | ")
        }

        default {
            return ""
        }
    }
}

function Get-TurnRoutingPlan {
    param(
        [string]$UserInput,
        [string]$FastModel,
        [string]$HeavyModelName,
        [string]$CoderModelName,
        [string]$StructuredModelName,
        [string]$VisionModelName,
        [string]$SelectedRoutingMode
    )

    if (
        $SelectedRoutingMode -ne "auto" -or
        [string]::IsNullOrWhiteSpace($HeavyModelName)
    ) {
        return [pscustomobject]@{
            InitialModel = $FastModel
            PreferredSynthesisModel = $FastModel
            PreferSynthesisUpgrade = $false
            ComplexityScore = 0
            MissionType = "fixed"
            Reason = "fixed model routing"
        }
    }

    $text = if ($UserInput) { $UserInput.Trim() } else { "" }
    $lower = $text.ToLowerInvariant()
    $score = 0
    $reasons = New-Object System.Collections.Generic.List[string]

    if ($lower -match '^(hi|hello|hey|thanks|thank you|ok|ola)[!. ]*$') {
        return [pscustomobject]@{
            InitialModel = $FastModel
            PreferredSynthesisModel = $FastModel
            PreferSynthesisUpgrade = $false
            ComplexityScore = 0
            MissionType = "chat"
            Reason = "simple conversational turn"
        }
    }

    if ($lower -match '^(reply|answer)\s+with\s+exactly\b') {
        return [pscustomobject]@{
            InitialModel = $FastModel
            PreferredSynthesisModel = $FastModel
            PreferSynthesisUpgrade = $false
            ComplexityScore = 0
            MissionType = "exact"
            Reason = "exact-output prompt"
        }
    }

    if ($text.Length -ge 140) {
        $score += 2
        $reasons.Add("long prompt")
    }

    if (
        $lower -match '\b(scan|search|inspect|analyze|investigate|compare|comparison|table|report|rank|ranking|every|entire|all over|recursive|recursively|system-wide|across|cleanup|monthly|complex|benchmark|fix|update|change|refactor|root cause|optimize|strategy|full path|paths|exactly|format|syntax|safer|safest|categorize)\b'
    ) {
        $score += 2
        $reasons.Add("broad or structured task")
    }

    if (
        $lower -match '\b(make|output|show|put|split|group|separate)\b' -and
        $lower -match '\b(table|list|lists|sections|columns|next the other|one after another)\b'
    ) {
        $score += 1
        $reasons.Add("strict output shape")
    }

    $driveMatches = (
        [regex]::Matches($lower, '\b[a-z]:').Count +
        [regex]::Matches($lower, '\b[a-z]\s+drive\b').Count
    )
    if ($driveMatches -ge 2) {
        $score += 2
        $reasons.Add("multi-drive scope")
    }

    if ($lower -match '\b(write|edit|modify|delete|remove|create)\b') {
        $score += 1
        $reasons.Add("change request")
    }

    $reasoningHeavyTask = $lower -match '\b(why|strategy|design|architecture|root cause|diagnose|debug|explain|refactor|plan|tradeoff|benchmark|audit|evaluate)\b'
    $codeTask = $lower -match '\b(code|repo|repository|file|files|function|class|method|script|powershell|python|javascript|typescript|test|tests|bug|stack trace|exception|compile|implementation|implement)\b'
    $webTask = $lower -match '\b(web|website|url|urls|online|internet|browse|browsing|search|latest|today|recent|official docs|documentation|docs|scrape|scraping|crawl)\b'
    $structuredTask = (
        $lower -match '\b(json|yaml|schema|csv|tsv|xml|fields|extract)\b' -or
        (
            $lower -match '\b(return|output|format|respond)\b' -and
            $lower -match '\b(json|yaml|csv|tsv|xml)\b'
        )
    )
    $visionTask = $lower -match '\b(image|images|screenshot|screenshots|photo|ocr|pdf|diagram)\b'
    $cleanupTask = Test-IsCleanupInspectionRequest -UserInput $text
    $missionType = "general"
    $preferredSynthesisModel = $FastModel
    $preferSynthesisUpgrade = $false

    $initialModel = $FastModel

    if ($cleanupTask) {
        $initialModel = $FastModel
        $preferredSynthesisModel = $FastModel
        $missionType = "cleanup"
        $reasons.Add("cleanup inspection task")
    }
    elseif (
        $visionTask -and
        -not [string]::IsNullOrWhiteSpace($VisionModelName) -and
        $VisionModelName -ne $FastModel
    ) {
        $initialModel = $VisionModelName
        $preferredSynthesisModel = $VisionModelName
        $missionType = "vision"
        $reasons.Add("vision task")
    }
    elseif (
        $codeTask -and
        -not [string]::IsNullOrWhiteSpace($CoderModelName) -and
        $CoderModelName -ne $FastModel
    ) {
        $initialModel = $CoderModelName
        $missionType = "coding"
        $reasons.Add("coding task")
        if ($reasoningHeavyTask -or $score -ge 5) {
            $preferredSynthesisModel = $HeavyModelName
            $preferSynthesisUpgrade = ($HeavyModelName -ne $CoderModelName)
            $reasons.Add("heavy synthesis after coding")
        }
        else {
            $preferredSynthesisModel = $CoderModelName
        }
    }
    elseif (
        $structuredTask -and
        -not [string]::IsNullOrWhiteSpace($StructuredModelName) -and
        $StructuredModelName -ne $FastModel
    ) {
        $initialModel = $StructuredModelName
        $preferredSynthesisModel = $StructuredModelName
        $missionType = "structured"
        $reasons.Add("structured-output task")
    }
    elseif ($reasoningHeavyTask -and -not $webTask -and $score -ge 2) {
        $initialModel = $HeavyModelName
        $preferredSynthesisModel = $HeavyModelName
        $missionType = "reasoning"
        $reasons.Add("heavy-first reasoning task")
    }
    elseif ($webTask) {
        $missionType = "research"
        $reasons.Add("web research task")
        if ($reasoningHeavyTask -or $score -ge 4) {
            $preferredSynthesisModel = $HeavyModelName
            $preferSynthesisUpgrade = ($HeavyModelName -ne $FastModel)
        }
        elseif (
            $structuredTask -and
            -not [string]::IsNullOrWhiteSpace($StructuredModelName) -and
            $StructuredModelName -ne $FastModel
        ) {
            $preferredSynthesisModel = $StructuredModelName
            $preferSynthesisUpgrade = $true
        }
        else {
            $preferredSynthesisModel = $HeavyModelName
            $preferSynthesisUpgrade = ($HeavyModelName -ne $FastModel)
        }
    }
    elseif ($score -ge 4) {
        $initialModel = $HeavyModelName
        $preferredSynthesisModel = $HeavyModelName
        $missionType = "complex"
        $reasons.Add("very high complexity")
    }
    elseif ($reasoningHeavyTask -and $score -ge 2) {
        $preferredSynthesisModel = $HeavyModelName
        $preferSynthesisUpgrade = ($HeavyModelName -ne $FastModel)
        $missionType = "analysis"
    }

    $reason = if ($reasons.Count -gt 0) {
        ($reasons -join ", ")
    }
    else {
        "fast default for a straightforward turn"
    }

    return [pscustomobject]@{
        InitialModel = $initialModel
        PreferredSynthesisModel = $preferredSynthesisModel
        PreferSynthesisUpgrade = $preferSynthesisUpgrade
        ComplexityScore = $score
        MissionType = $missionType
        Reason = $reason
    }
}

function Test-ShouldEscalateForSynthesis {
    param(
        [string]$UserInput,
        [int]$TurnToolCalls,
        [int]$Iteration,
        [bool]$PreferSynthesisUpgrade,
        [string]$CurrentModel,
        [string]$FastModel,
        [string]$PreferredSynthesisModel,
        [string]$SelectedRoutingMode
    )

    if (Test-IsCleanupInspectionRequest -UserInput $UserInput) {
        return $false
    }

    if (
        $SelectedRoutingMode -ne "auto" -or
        -not $PreferSynthesisUpgrade -or
        [string]::IsNullOrWhiteSpace($PreferredSynthesisModel) -or
        $PreferredSynthesisModel -eq $CurrentModel
    ) {
        return $false
    }

    if ($TurnToolCalls -ge 3 -and $CurrentModel -eq $FastModel) {
        return $true
    }

    $lower = if ($UserInput) { $UserInput.ToLowerInvariant() } else { "" }
    if (
        $TurnToolCalls -ge 2 -and
        $lower -match '\b(compare|comparison|report|rank|ranking|root cause|diagnose|debug|explain|tradeoff|strategy|benchmark|web|search|scrape|latest|current)\b'
    ) {
        return $true
    }

    if ($Iteration -ge 3 -and $TurnToolCalls -ge 2) {
        return $true
    }

    return $false
}

function Get-FormattingInstruction {
    param(
        [string]$UserInput
    )

    $lower = if ($UserInput) { $UserInput.ToLowerInvariant() } else { "" }
    $instructions = New-Object System.Collections.Generic.List[string]

    if ($lower -match '\btable\b') {
        $instructions.Add("Return a markdown table with clear column headers.")
    }

    if (
        $lower -match '\b(list|lists)\b' -and
        $lower -match '\b(separate|one after another|next the other|one for each|label each|label clearly)\b'
    ) {
        $instructions.Add("Return clearly labeled sections, each followed by a bullet list. Do not compress a list into a single sentence.")
    }

    if ($lower -match '\bfull path\b|\bfull paths\b|\babsolute path\b|\babsolute paths\b') {
        $instructions.Add("Use absolute Windows paths for every path you mention.")
    }

    if ($lower -match '\bexactly\b') {
        $instructions.Add("Follow the user's requested structure exactly.")
    }

    if ($instructions.Count -eq 0) {
        return $null
    }

    return ($instructions -join " ")
}

function Invoke-CapturedProcess {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$WorkingDirectory,
        [int]$TimeoutSeconds = 30
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = (($ArgumentList | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_ -replace '"', '\"') + '"'
        }
        else {
            $_
        }
    }) -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $startInfo.WorkingDirectory = $WorkingDirectory

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

    try {
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
    }
    catch {
        return [pscustomobject]@{
            ExitCode = -1
            StdOut = ""
            StdErr = $_.Exception.Message
            TimedOut = $false
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
            return [pscustomobject]@{
                ExitCode = -2
                StdOut = $stdoutTask.Result.TrimEnd()
                StdErr = $stderrTask.Result.TrimEnd()
                TimedOut = $true
            }
        }

        [System.Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask), 5000) | Out-Null
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOut = $stdoutTask.Result.TrimEnd()
            StdErr = $stderrTask.Result.TrimEnd()
            TimedOut = $false
        }
    }
    finally {
        $process.Dispose()
    }
}

function New-ToolSpec {
    param(
        [string]$Name,
        [string]$Description,
        [hashtable]$Properties,
        [string[]]$Required = @()
    )

    return @{
        type = "function"
        function = @{
            name = $Name
            description = $Description
            parameters = @{
                type = "object"
                properties = $Properties
                required = $Required
            }
        }
    }
}

function Get-OlaWebToolScriptPath {
    return (Join-Path $PSScriptRoot "ola_web_tools.py")
}

function Invoke-OlaWebTool {
    param(
        [string]$Mode,
        [hashtable]$Arguments,
        [string]$ResolvedWorkspace,
        [int]$TimeoutSeconds
    )

    $pythonCommand = Get-Command "python" -ErrorAction SilentlyContinue
    if (-not $pythonCommand) {
        return (ConvertTo-DisplayJson @{
            tool = $Mode
            error = "python is not available on PATH."
        })
    }

    $scriptPath = Get-OlaWebToolScriptPath
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        return (ConvertTo-DisplayJson @{
            tool = $Mode
            error = "Web tool script not found."
            path = $scriptPath
        })
    }

    $payload = ($Arguments | ConvertTo-Json -Depth 10 -Compress)
    $result = Invoke-CapturedProcess -FilePath $pythonCommand.Source -ArgumentList @(
        $scriptPath,
        $Mode,
        $payload
    ) -WorkingDirectory $ResolvedWorkspace -TimeoutSeconds $TimeoutSeconds

    if ($result.TimedOut) {
        return (ConvertTo-DisplayJson @{
            tool = $Mode
            error = "Timed out."
            stdout = $result.StdOut
            stderr = $result.StdErr
        })
    }

    if ($result.ExitCode -ne 0) {
        $parsedError = ConvertFrom-JsonSafe -JsonText $result.StdOut
        return (ConvertTo-DisplayJson @{
            tool = $Mode
            error = if ($parsedError -and $parsedError.error) { $parsedError.error } else { $result.StdErr }
            stdout = $result.StdOut
            stderr = $result.StdErr
            exit_code = $result.ExitCode
        })
    }

    return $result.StdOut
}

function Invoke-AgentTool {
    param(
        [string]$Name,
        [hashtable]$Arguments,
        [string]$ResolvedWorkspace,
        [int]$TimeoutSeconds
    )

    switch ($Name) {
        "run_powershell" {
            $command = [string]$Arguments["command"]
            if ([string]::IsNullOrWhiteSpace($command)) {
                return '{"error":"Missing command."}'
            }

            $tempScript = Join-Path $env:TEMP ("ola-native-" + [guid]::NewGuid().ToString("N") + ".ps1")
            try {
                Set-Content -Path $tempScript -Value $command -Encoding utf8
                $result = Invoke-CapturedProcess -FilePath "powershell.exe" -ArgumentList @(
                    "-NoProfile",
                    "-NonInteractive",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    $tempScript
                ) -WorkingDirectory $ResolvedWorkspace -TimeoutSeconds $TimeoutSeconds

                return (ConvertTo-DisplayJson @{
                    tool = "run_powershell"
                    exit_code = $result.ExitCode
                    timed_out = $result.TimedOut
                    stdout = $result.StdOut
                    stderr = $result.StdErr
                })
            }
            finally {
                Remove-Item -LiteralPath $tempScript -ErrorAction SilentlyContinue
            }
        }

        "list_directory" {
            $targetPath = [string]$Arguments["path"]
            if ([string]::IsNullOrWhiteSpace($targetPath)) {
                $targetPath = $ResolvedWorkspace
            }

            if (-not (Test-Path -LiteralPath $targetPath)) {
                return (ConvertTo-DisplayJson @{
                    tool = "list_directory"
                    error = "Path not found."
                    path = $targetPath
                })
            }

            $recursive = [bool]$Arguments["recursive"]
            $pattern = if ([string]::IsNullOrWhiteSpace([string]$Arguments["pattern"])) { "*" } else { [string]$Arguments["pattern"] }
            $items = Get-ChildItem -LiteralPath $targetPath -Force -Filter $pattern -ErrorAction Stop -Recurse:$recursive |
                Select-Object -First 200

            $dirs = @(
                $items |
                    Where-Object { $_.PSIsContainer } |
                    Select-Object -First 200 @{ Name = "name"; Expression = { $_.Name } }, @{ Name = "full_path"; Expression = { $_.FullName } }
            )
            $files = @(
                $items |
                    Where-Object { -not $_.PSIsContainer } |
                    Select-Object -First 50 @{ Name = "name"; Expression = { $_.Name } }, @{ Name = "full_path"; Expression = { $_.FullName } }, @{ Name = "size_bytes"; Expression = { $_.Length } }
            )

            return (ConvertTo-DisplayJson @{
                tool = "list_directory"
                path = $targetPath
                recursive = $recursive
                pattern = $pattern
                total_items = @($items).Count
                directories = $dirs
                files = $files
            })
        }

        "read_file" {
            $targetPath = [string]$Arguments["path"]
            if ([string]::IsNullOrWhiteSpace($targetPath)) {
                return '{"error":"Missing path."}'
            }

            if (-not (Test-Path -LiteralPath $targetPath)) {
                return (ConvertTo-DisplayJson @{
                    tool = "read_file"
                    error = "Path not found."
                    path = $targetPath
                })
            }

            $readResult = Read-OlaTextFile -Path $targetPath -MaxChars 200000
            return (ConvertTo-DisplayJson @{
                tool = "read_file"
                path = $targetPath
                char_count = $readResult.CharCount
                size_bytes = $readResult.SizeBytes
                truncated = $readResult.Truncated
                content = $readResult.Content
            })
        }

        "write_file" {
            $targetPath = [string]$Arguments["path"]
            $content = [string]$Arguments["content"]
            if ([string]::IsNullOrWhiteSpace($targetPath)) {
                return '{"error":"Missing path."}'
            }

            $parent = Split-Path -Parent $targetPath
            if ($parent -and -not (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }

            Set-Content -LiteralPath $targetPath -Value $content -Encoding utf8
            return (ConvertTo-DisplayJson @{
                tool = "write_file"
                path = $targetPath
                written = $true
            })
        }

        "edit_file" {
            $targetPath = [string]$Arguments["path"]
            $oldText = [string]$Arguments["old_text"]
            $newText = [string]$Arguments["new_text"]

            if ([string]::IsNullOrWhiteSpace($targetPath)) {
                return '{"error":"Missing path."}'
            }

            if (-not (Test-Path -LiteralPath $targetPath)) {
                return (ConvertTo-DisplayJson @{
                    tool = "edit_file"
                    error = "Path not found."
                    path = $targetPath
                })
            }

            $content = Get-Content -LiteralPath $targetPath -Raw -ErrorAction Stop
            $matches = ([regex]::Matches($content, [regex]::Escape($oldText))).Count
            if ($matches -ne 1) {
                return (ConvertTo-DisplayJson @{
                    tool = "edit_file"
                    path = $targetPath
                    replaced = $false
                    match_count = $matches
                })
            }

            $updated = $content.Replace($oldText, $newText)
            Set-Content -LiteralPath $targetPath -Value $updated -Encoding utf8
            return (ConvertTo-DisplayJson @{
                tool = "edit_file"
                path = $targetPath
                replaced = $true
            })
        }

        "list_drives" {
            $drives = Get-PSDrive -PSProvider FileSystem |
                Sort-Object Name |
                ForEach-Object {
                    $used = if ($_.Used -is [double] -or $_.Used -is [int64]) { [math]::Round(($_.Used / 1GB), 2) } else { $null }
                    $free = if ($_.Free -is [double] -or $_.Free -is [int64]) { [math]::Round(($_.Free / 1GB), 2) } else { $null }
                    $total = if ($null -ne $used -and $null -ne $free) { [math]::Round(($used + $free), 2) } else { $null }

                    [pscustomobject]@{
                        name = $_.Name
                        root = $_.Root
                        current_location = $_.CurrentLocation
                        used_gb = $used
                        free_gb = $free
                        total_gb = $total
                    }
                }

            return (ConvertTo-DisplayJson @{
                tool = "list_drives"
                drives = $drives
            })
        }

        "find_cleanup_candidates" {
            $driveRoot = [string]$Arguments["drive_root"]
            if ([string]::IsNullOrWhiteSpace($driveRoot)) {
                $driveRoot = [Environment]::GetEnvironmentVariable("SystemDrive", "Process")
            }

            if ([string]::IsNullOrWhiteSpace($driveRoot)) {
                $driveRoot = "C:"
            }

            $driveRoot = $driveRoot.TrimEnd('\')
            $userProfile = [Environment]::GetFolderPath("UserProfile")
            $localAppData = if ([string]::IsNullOrWhiteSpace($userProfile)) { $null } else { Join-Path $userProfile "AppData\Local" }
            $roamingAppData = if ([string]::IsNullOrWhiteSpace($userProfile)) { $null } else { Join-Path $userProfile "AppData\Roaming" }
            $windowsTemp = Join-Path $driveRoot "Windows\Temp"
            $broadScan = $true
            if ($Arguments.ContainsKey("broad_scan")) {
                $broadScan = [bool]$Arguments["broad_scan"]
            }

            $maxResults = 80
            if ($Arguments.ContainsKey("max_results") -and $Arguments["max_results"]) {
                $maxResults = [Math]::Min([Math]::Max([int]$Arguments["max_results"], 10), 250)
            }

            $minSizeMb = 5
            if ($Arguments.ContainsKey("min_size_mb") -and $Arguments["min_size_mb"]) {
                $minSizeMb = [Math]::Min([Math]::Max([double]$Arguments["min_size_mb"], 0), 1024)
            }

            $candidateSpecs = @(
                @{ path = if ($localAppData) { Join-Path $localAppData "Temp" } else { $null }; reason = "Per-user temporary files."; caution = "Skip locked files from active apps." },
                @{ path = if ($localAppData) { Join-Path $localAppData "CrashDumps" } else { $null }; reason = "Crash dump files from application failures."; caution = "Keep recent dumps if you still need troubleshooting evidence." },
                @{ path = if ($localAppData) { Join-Path $localAppData "D3DSCache" } else { $null }; reason = "Direct3D shader cache that Windows rebuilds."; caution = "First launch of some apps or games may be slower afterward." },
                @{ path = if ($localAppData) { Join-Path $localAppData "NVIDIA\DXCache" } else { $null }; reason = "NVIDIA DirectX shader cache."; caution = "Games may rebuild cache files on next run." },
                @{ path = if ($localAppData) { Join-Path $localAppData "NVIDIA\GLCache" } else { $null }; reason = "NVIDIA OpenGL shader cache."; caution = "Games may rebuild cache files on next run." },
                @{ path = if ($localAppData) { Join-Path $localAppData "Google\Chrome\User Data\Default\Cache" } else { $null }; reason = "Chrome web cache."; caution = "Close Chrome first for best cleanup coverage." },
                @{ path = if ($localAppData) { Join-Path $localAppData "Google\Chrome\User Data\Default\Code Cache" } else { $null }; reason = "Chrome script code cache."; caution = "Close Chrome first for best cleanup coverage." },
                @{ path = if ($localAppData) { Join-Path $localAppData "Microsoft\Edge\User Data\Default\Cache" } else { $null }; reason = "Edge web cache."; caution = "Close Edge first for best cleanup coverage." },
                @{ path = if ($localAppData) { Join-Path $localAppData "Microsoft\Edge\User Data\Default\Code Cache" } else { $null }; reason = "Edge script code cache."; caution = "Close Edge first for best cleanup coverage." },
                @{ path = if ($localAppData) { Join-Path $localAppData "Microsoft\Windows\INetCache" } else { $null }; reason = "Legacy Windows and WebView cache data."; caution = "Some items may be in use by open apps." },
                @{ path = $windowsTemp; reason = "Windows temporary working files."; caution = "Skip files currently in use or needed by an active update." },
                @{ path = Join-Path $driveRoot "Windows\SoftwareDistribution\Download"; reason = "Windows Update download cache."; caution = "Avoid clearing it while updates are actively downloading or installing." }
            )

            $candidateMap = @{}

            function Get-CleanupCandidateStats {
                param(
                    [string]$CandidatePath
                )

                $itemCount = 0
                $sizeBytes = [int64]0
                try {
                    $stats = Get-ChildItem -LiteralPath $CandidatePath -Force -Recurse -ErrorAction SilentlyContinue |
                        Measure-Object -Property Length -Sum
                    $itemCount = [int]$stats.Count
                    if ($stats.Sum) {
                        $sizeBytes = [int64]$stats.Sum
                    }
                }
                catch {
                }

                return [pscustomobject]@{
                    ItemCount = $itemCount
                    SizeBytes = $sizeBytes
                    SizeMb = [math]::Round(($sizeBytes / 1MB), 2)
                }
            }

            function Add-CleanupCandidate {
                param(
                    [string]$CandidatePath,
                    [string]$Reason,
                    [string]$Caution,
                    [string]$Source
                )

                if ([string]::IsNullOrWhiteSpace($CandidatePath) -or -not (Test-Path -LiteralPath $CandidatePath)) {
                    return
                }

                try {
                    $resolvedPath = (Resolve-Path -LiteralPath $CandidatePath -ErrorAction Stop).ProviderPath
                }
                catch {
                    $resolvedPath = $CandidatePath
                }

                if ($candidateMap.ContainsKey($resolvedPath)) {
                    return
                }

                $stats = Get-CleanupCandidateStats -CandidatePath $resolvedPath
                if ($Source -eq "heuristic_scan" -and $stats.SizeMb -lt $minSizeMb) {
                    return
                }

                $candidateMap[$resolvedPath] = [pscustomobject]@{
                    path = $resolvedPath
                    reason = $Reason
                    caution = $Caution
                    item_count = $stats.ItemCount
                    size_mb = $stats.SizeMb
                    source = $Source
                }
            }

            foreach ($spec in $candidateSpecs) {
                Add-CleanupCandidate -CandidatePath ([string]$spec.path) -Reason ([string]$spec.reason) -Caution ([string]$spec.caution) -Source "seeded"
            }

            $heuristicCandidateCount = 0
            if ($broadScan) {
                $searchRoots = @(
                    $localAppData,
                    $roamingAppData,
                    (Join-Path $driveRoot "ProgramData"),
                    (Join-Path $driveRoot "Windows\Logs"),
                    (Join-Path $driveRoot "Windows\SoftwareDistribution")
                ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -LiteralPath $_) }

                $namePattern = '^(temp|tmp|cache|caches|code cache|gpucache|shadercache|shader cache|dxcache|glcache|d3dscache|crashdumps?|logs?|downloads?)$'
                $excludedPathPattern = '\\(winsxs|servicing|driverstore|installer|systemapps|winevt|microsoft\\windows\\containers\\layers)(\\|$)'

                foreach ($root in $searchRoots) {
                    $dirs = @(
                        Get-ChildItem -LiteralPath $root -Directory -Force -Recurse -ErrorAction SilentlyContinue |
                            Where-Object {
                                $_.Name -match $namePattern -and
                                $_.FullName -notmatch $excludedPathPattern
                            } |
                            Select-Object -First 500
                    )

                    foreach ($dir in $dirs) {
                        $reason = switch -Regex ($dir.Name) {
                            '^downloads?$' { "Downloaded package or update cache discovered during the broader scan." ; break }
                            '^logs?$' { "Log directory discovered during the broader scan." ; break }
                            '^crashdumps?$' { "Crash dump directory discovered during the broader scan." ; break }
                            default { "Temp or cache directory discovered during the broader scan." ; break }
                        }

                        Add-CleanupCandidate -CandidatePath $dir.FullName -Reason $reason -Caution "Inspect the folder contents before deleting; some apps rebuild caches, but recent logs or dumps may still matter." -Source "heuristic_scan"
                    }
                }

                $heuristicCandidateCount = @(
                    $candidateMap.Values |
                        Where-Object { $_.source -eq "heuristic_scan" }
                ).Count
            }

            $candidates = @(
                $candidateMap.Values |
                    Sort-Object -Property @{ Expression = "size_mb"; Descending = $true }, @{ Expression = "path"; Descending = $false } |
                    Select-Object -First $maxResults
            )

            return (ConvertTo-DisplayJson @{
                tool = "find_cleanup_candidates"
                drive_root = ($driveRoot + "\")
                heuristic_scan_enabled = $broadScan
                min_size_mb = $minSizeMb
                max_results = $maxResults
                seeded_candidate_count = @($candidateMap.Values | Where-Object { $_.source -eq "seeded" }).Count
                heuristic_candidate_count = $heuristicCandidateCount
                candidates = @($candidates)
            })
        }

        "search_files" {
            $targetPath = [string]$Arguments["path"]
            $pattern = [string]$Arguments["pattern"]
            $fileGlob = if ([string]::IsNullOrWhiteSpace([string]$Arguments["file_glob"])) { "*" } else { [string]$Arguments["file_glob"] }

            if ([string]::IsNullOrWhiteSpace($targetPath) -or [string]::IsNullOrWhiteSpace($pattern)) {
                return '{"error":"Missing path or pattern."}'
            }

            $rgCommand = Get-Command rg -ErrorAction SilentlyContinue
            if ($rgCommand) {
                $result = Invoke-CapturedProcess -FilePath $rgCommand.Source -ArgumentList @(
                    "-n",
                    "--glob",
                    $fileGlob,
                    $pattern,
                    $targetPath
                ) -WorkingDirectory $ResolvedWorkspace -TimeoutSeconds ([Math]::Min($TimeoutSeconds, 30))

                return (ConvertTo-DisplayJson @{
                    tool = "search_files"
                    path = $targetPath
                    pattern = $pattern
                    file_glob = $fileGlob
                    exit_code = $result.ExitCode
                    stdout = $result.StdOut
                    stderr = $result.StdErr
                })
            }

            $matches = Get-ChildItem -LiteralPath $targetPath -Recurse -File -Filter $fileGlob -ErrorAction SilentlyContinue |
                Select-String -Pattern $pattern -ErrorAction SilentlyContinue |
                Select-Object -First 200 Path, LineNumber, Line

            return (ConvertTo-DisplayJson @{
                tool = "search_files"
                path = $targetPath
                pattern = $pattern
                matches = $matches
            })
        }

        "web_search" {
            return (Invoke-OlaWebTool -Mode "search" -Arguments $Arguments -ResolvedWorkspace $ResolvedWorkspace -TimeoutSeconds $TimeoutSeconds)
        }

        "web_fetch" {
            return (Invoke-OlaWebTool -Mode "fetch" -Arguments $Arguments -ResolvedWorkspace $ResolvedWorkspace -TimeoutSeconds $TimeoutSeconds)
        }

        "scrape_web_page" {
            return (Invoke-OlaWebTool -Mode "scrape" -Arguments $Arguments -ResolvedWorkspace $ResolvedWorkspace -TimeoutSeconds $TimeoutSeconds)
        }

        default {
            return (ConvertTo-DisplayJson @{
                error = "Unsupported tool."
                tool = $Name
            })
        }
    }
}

function Invoke-OllamaChat {
    param(
        [System.Collections.ArrayList]$Messages,
        [object[]]$Tools,
        [string]$ChatModel,
        [string]$Url,
        [int]$TimeoutSeconds
    )

    $body = @{
        model = $ChatModel
        messages = @($Messages)
        tools = $Tools
        stream = $false
        options = @{
            temperature = 0.2
        }
    } | ConvertTo-Json -Depth 20

    return Invoke-RestMethod -Uri ($Url.TrimEnd('/') + "/api/chat") -Method Post -ContentType "application/json" -Body $body -TimeoutSec $TimeoutSeconds
}

function Read-OlaTextFile {
    param(
        [string]$Path,
        [int]$MaxChars = 200000
    )

    $fileInfo = Get-Item -LiteralPath $Path -ErrorAction Stop
    $bufferSize = 4096
    $encoding = New-Object System.Text.UTF8Encoding($false, $false)
    $fileStream = $null
    $reader = $null

    try {
        $fileStream = New-Object System.IO.FileStream(
            $fileInfo.FullName,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )
        $reader = New-Object System.IO.StreamReader($fileStream, $encoding, $true, $bufferSize)
        $content = $reader.ReadToEnd()
    }
    finally {
        if ($reader) {
            $reader.Dispose()
        }
        elseif ($fileStream) {
            $fileStream.Dispose()
        }
    }

    $charCount = $content.Length
    $truncated = $false
    if ($charCount -gt $MaxChars) {
        $content = $content.Substring(0, $MaxChars)
        $truncated = $true
    }

    return [pscustomobject]@{
        Content = $content
        CharCount = $charCount
        Truncated = $truncated
        SizeBytes = [int64]$fileInfo.Length
    }
}

function Get-OlaSystemPrompt {
    param(
        [string]$ResolvedWorkspace,
        [bool]$DirectiveEnabled,
        [string]$SessionSummary
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("You are Ola, a local Windows agent running through Ollama with real tool access.")
    $lines.Add("Current workspace: " + $ResolvedWorkspace)
    $lines.Add("Use tools to inspect the real machine and workspace. Do not claim you are sandboxed or lack filesystem access.")
    $lines.Add("For filesystem, drive, process, environment, service, registry, or network questions, call a tool instead of guessing.")
    $lines.Add("You have real local-machine authority through the provided tools; only say a permission is missing if a tool or command actually proves it.")
    $lines.Add("For current or online facts, use web_search or web_fetch instead of claiming you cannot browse.")
    $lines.Add("Use scrape_web_page when the user wants structured extraction from a site instead of brittle ad hoc shell commands.")
    $lines.Add("Prefer read-only inspection first. Do not perform destructive actions unless the user explicitly asks for them.")
    $lines.Add("For drive, disk, or system-wide requests, inspect the actual drive roots or call list_drives first instead of staying in the current folder.")
    $lines.Add("For temp, cache, cleanup, or monthly-empty requests on Windows, prefer find_cleanup_candidates with a broad scan before attempting a blind whole-drive crawl.")
    $lines.Add("If the user mentions an existing function or script and asks what to add or change, inspect that function or script before answering.")
    $lines.Add("If the user asks for formatting only, reuse already observed results unless new inspection is required.")
    $lines.Add("Match the requested output shape exactly: tables when asked for tables, separate lists when asked for separate lists, exact counts when asked for exact counts, and full paths when asked for full paths.")
    $lines.Add("If a tool result already contains the verified facts needed for the requested table, list, or report, answer directly from that result instead of calling more tools or forcing an extra synthesis loop.")
    $lines.Add("Prefer one sufficient read-only PowerShell command over multiple exploratory tool passes when the user asked for a broad filesystem table and that command can safely inspect the requested scope.")
    $lines.Add("When web tools return results, cite the URLs used in the answer.")
    $lines.Add("Do not describe a listing as exhaustive unless you actually inspected that exact scope.")
    $lines.Add("For broad or multi-step missions, start the necessary tool work promptly. Do not print a PLAN block or narrate obvious next steps.")
    $lines.Add("For cleanup recommendations, label them as candidates and include the reason before suggesting removal.")
    $lines.Add("Use a plain technical tone. Avoid emojis, hype, and filler.")
    if ($DirectiveEnabled) {
        $lines.Add("Directive mode is active: own the mission, keep going until the user's outcome is achieved or a real blocker is proven, maintain a compact ledger mentally, and verify important claims with tools before answering.")
    }

    if (-not [string]::IsNullOrWhiteSpace($SessionSummary)) {
        $lines.Add("Session memory summary:")
        $lines.Add($SessionSummary.Trim())
    }

    $lines.Add("When you finish, answer plainly, concisely, and with the real results you observed.")
    return ($lines -join "`n")
}

function New-OlaMessageBuffer {
    param(
        [string]$SystemPrompt
    )

    $buffer = New-Object System.Collections.ArrayList
    [void]$buffer.Add(@{
        role = "system"
        content = $SystemPrompt
    })
    return ,$buffer
}

function Get-VerifiedCleanupAnswer {
    param(
        [string]$UserInput,
        [System.Collections.ArrayList]$ToolEvents
    )

    if (-not (Test-IsCleanupInspectionRequest -UserInput $UserInput)) {
        return $null
    }

    $cleanupEvent = @(
        $ToolEvents |
            Where-Object {
                $_.Name -eq "find_cleanup_candidates" -and
                $_.ResultObject -and
                -not $_.ResultObject.error -and
                $_.ResultObject.candidates
            }
    ) | Select-Object -Last 1

    if (-not $cleanupEvent) {
        return $null
    }

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($candidate in @($cleanupEvent.ResultObject.candidates)) {
        if (-not $candidate -or [string]::IsNullOrWhiteSpace([string]$candidate.path)) {
            continue
        }

        $path = [string]$candidate.path
        if ($path -match '%[^%]+%') {
            continue
        }

        $sizeMb = 0
        if ($null -ne $candidate.size_mb) {
            $sizeMb = [math]::Round([double]$candidate.size_mb, 2)
        }

        $reason = if ([string]::IsNullOrWhiteSpace([string]$candidate.reason)) {
            "Cleanup candidate discovered on the real machine."
        }
        else {
            ([string]$candidate.reason).Trim()
        }

        $lines.Add(("- {0} | {1} MB | {2}" -f $path, $sizeMb.ToString("0.##"), $reason))
    }

    if ($lines.Count -eq 0) {
        return $null
    }

    return ($lines -join "`n")
}

function Get-RequestedDriveRoot {
    param(
        [string]$UserInput
    )

    if ([string]::IsNullOrWhiteSpace($UserInput)) {
        return "C:"
    }

    $lower = $UserInput.ToLowerInvariant()
    $match = [regex]::Match($lower, '\b([a-z]):')
    if ($match.Success) {
        return ($match.Groups[1].Value.ToUpperInvariant() + ":")
    }

    $driveWordMatch = [regex]::Match($lower, '\b([a-z])\s+drive\b')
    if ($driveWordMatch.Success) {
        return ($driveWordMatch.Groups[1].Value.ToUpperInvariant() + ":")
    }

    return "C:"
}

function Get-OlaMessageCharCount {
    param(
        [System.Collections.ArrayList]$Messages
    )

    $charCount = 0
    foreach ($entry in $Messages) {
        if ($entry -and $entry.content) {
            $charCount += ([string]$entry.content).Length
        }
    }

    return $charCount
}

function Invoke-OlaSessionCompaction {
    param(
        [System.Collections.ArrayList]$Messages,
        [string]$ResolvedWorkspace,
        [bool]$DirectiveEnabled,
        [string]$SessionSummary,
        [string]$SummaryModel,
        [string]$Url,
        [int]$TimeoutSeconds,
        [int]$CharThreshold,
        [int]$KeepRecentEntries
    )

    $conversationEntries = @($Messages | Select-Object -Skip 1)
    if ($conversationEntries.Count -le ($KeepRecentEntries + 2)) {
        return [pscustomobject]@{
            Compacted = $false
            SessionSummary = $SessionSummary
            Messages = $Messages
            RemovedEntries = 0
        }
    }

    $charCount = Get-OlaMessageCharCount -Messages $Messages
    if ($charCount -lt $CharThreshold) {
        return [pscustomobject]@{
            Compacted = $false
            SessionSummary = $SessionSummary
            Messages = $Messages
            RemovedEntries = 0
        }
    }

    $recentEntries = @($conversationEntries | Select-Object -Last $KeepRecentEntries)
    $olderEntries = @($conversationEntries | Select-Object -First ([Math]::Max($conversationEntries.Count - $KeepRecentEntries, 0)))
    if ($olderEntries.Count -eq 0) {
        return [pscustomobject]@{
            Compacted = $false
            SessionSummary = $SessionSummary
            Messages = $Messages
            RemovedEntries = 0
        }
    }

    $transcriptLines = New-Object System.Collections.Generic.List[string]
    foreach ($entry in $olderEntries) {
        if (-not $entry -or -not $entry.role) {
            continue
        }

        $content = if ($entry.content) { [string]$entry.content } else { "" }
        if ([string]::IsNullOrWhiteSpace($content)) {
            continue
        }

        $transcriptLines.Add(("[" + [string]$entry.role + "] " + (Limit-OlaPreview -Text $content -MaxLength 1600)))
    }

    if ($transcriptLines.Count -eq 0) {
        return [pscustomobject]@{
            Compacted = $false
            SessionSummary = $SessionSummary
            Messages = $Messages
            RemovedEntries = 0
        }
    }

    $summaryPrompt = @"
Summarize the prior session context for a long-running local agent.
Keep only durable facts, user requirements, verified results, exact paths, important decisions, unresolved work, and current mission state.
Use compact markdown with these headings:
- Durable facts
- User requirements
- Verified results
- Open work
Do not add guesses, TODOs, or filler.
"@

    $summaryMessages = New-Object System.Collections.ArrayList
    [void]$summaryMessages.Add(@{
        role = "system"
        content = $summaryPrompt.Trim()
    })
    if (-not [string]::IsNullOrWhiteSpace($SessionSummary)) {
        [void]$summaryMessages.Add(@{
            role = "user"
            content = "Existing summary:`n" + $SessionSummary.Trim()
        })
    }
    [void]$summaryMessages.Add(@{
        role = "user"
        content = "Compress this older conversation context so it can be carried forward safely:`n`n" + (($transcriptLines -join "`n`n").Trim())
    })

    $summaryResponse = Invoke-OllamaChat -Messages $summaryMessages -Tools @() -ChatModel $SummaryModel -Url $Url -TimeoutSeconds $TimeoutSeconds
    if (-not $summaryResponse.message -or [string]::IsNullOrWhiteSpace([string]$summaryResponse.message.content)) {
        return [pscustomobject]@{
            Compacted = $false
            SessionSummary = $SessionSummary
            Messages = $Messages
            RemovedEntries = 0
        }
    }

    $updatedSummary = [string]$summaryResponse.message.content
    $newMessages = New-OlaMessageBuffer -SystemPrompt (Get-OlaSystemPrompt -ResolvedWorkspace $ResolvedWorkspace -DirectiveEnabled $DirectiveEnabled -SessionSummary $updatedSummary)
    foreach ($entry in $recentEntries) {
        [void]$newMessages.Add($entry)
    }

    return [pscustomobject]@{
        Compacted = $true
        SessionSummary = $updatedSummary
        Messages = $newMessages
        RemovedEntries = $olderEntries.Count
    }
}

Set-Utf8Console

$resolvedWorkspace = if (Test-Path -LiteralPath $WorkspacePath) {
    (Resolve-Path -LiteralPath $WorkspacePath).ProviderPath
}
else {
    throw "WorkspacePath not found: $WorkspacePath"
}

$tools = @(
    (New-ToolSpec -Name "run_powershell" -Description "Run a PowerShell command in the current workspace. Use this for filesystem, drive, process, network, service, and system inspection or control. Prefer read-only commands unless the user explicitly asked for changes." -Properties @{
        command = @{
            type = "string"
            description = "PowerShell command to execute."
        }
    } -Required @("command")),
    (New-ToolSpec -Name "list_drives" -Description "List actual filesystem drives on this Windows machine." -Properties @{}),
    (New-ToolSpec -Name "find_cleanup_candidates" -Description "Inspect seeded and heuristic Windows temp/cache/update/log folders that are often worth emptying. Use this instead of guessing about C-drive cleanup candidates." -Properties @{
        drive_root = @{
            type = "string"
            description = "Optional drive root such as C: or C:\\."
        }
        broad_scan = @{
            type = "boolean"
            description = "Whether to expand the scan beyond the seeded folders into AppData, Windows, and ProgramData heuristics."
        }
        max_results = @{
            type = "integer"
            description = "Maximum number of candidates to return."
        }
        min_size_mb = @{
            type = "number"
            description = "Ignore heuristic candidates smaller than this many megabytes."
        }
    }),
    (New-ToolSpec -Name "list_directory" -Description "List files and folders in a directory." -Properties @{
        path = @{
            type = "string"
            description = "Absolute Windows path to inspect."
        }
        recursive = @{
            type = "boolean"
            description = "Whether to recurse into subdirectories."
        }
        pattern = @{
            type = "string"
            description = "Optional wildcard filter, for example *.ps1."
        }
    }),
    (New-ToolSpec -Name "read_file" -Description "Read a text file from disk." -Properties @{
        path = @{
            type = "string"
            description = "Absolute Windows path to the file."
        }
    } -Required @("path")),
    (New-ToolSpec -Name "write_file" -Description "Write a text file to disk." -Properties @{
        path = @{
            type = "string"
            description = "Absolute Windows path to the file."
        }
        content = @{
            type = "string"
            description = "The full file content to write."
        }
    } -Required @("path", "content")),
    (New-ToolSpec -Name "edit_file" -Description "Replace one exact text block inside a file." -Properties @{
        path = @{
            type = "string"
            description = "Absolute Windows path to the file."
        }
        old_text = @{
            type = "string"
            description = "Exact text to replace. It must appear exactly once."
        }
        new_text = @{
            type = "string"
            description = "Replacement text."
        }
    } -Required @("path", "old_text", "new_text")),
    (New-ToolSpec -Name "search_files" -Description "Search file contents under a directory." -Properties @{
        path = @{
            type = "string"
            description = "Absolute Windows directory path."
        }
        pattern = @{
            type = "string"
            description = "Regex pattern to search for."
        }
        file_glob = @{
            type = "string"
            description = "Optional file glob, for example *.ps1."
        }
    } -Required @("path", "pattern")),
    (New-ToolSpec -Name "web_search" -Description "Search the web for current information. Prefer this instead of guessing about online facts." -Properties @{
        query = @{
            type = "string"
            description = "Search query."
        }
        max_results = @{
            type = "integer"
            description = "Maximum number of results to return."
        }
        site = @{
            type = "string"
            description = "Optional domain filter such as docs.ollama.com."
        }
    } -Required @("query")),
    (New-ToolSpec -Name "web_fetch" -Description "Fetch a web page by URL and return its main content, headings, and links." -Properties @{
        url = @{
            type = "string"
            description = "Absolute URL."
        }
        max_chars = @{
            type = "integer"
            description = "Maximum number of content characters to return."
        }
        max_links = @{
            type = "integer"
            description = "Maximum number of links to return."
        }
    } -Required @("url")),
    (New-ToolSpec -Name "scrape_web_page" -Description "Fetch a web page and extract items matching a CSS selector." -Properties @{
        url = @{
            type = "string"
            description = "Absolute URL."
        }
        selector = @{
            type = "string"
            description = "CSS selector to extract."
        }
        max_items = @{
            type = "integer"
            description = "Maximum number of matched items to return."
        }
    } -Required @("url", "selector"))
)

$script:OlaUiState.Workspace = $resolvedWorkspace
$sessionSummary = $null
$systemPrompt = Get-OlaSystemPrompt -ResolvedWorkspace $resolvedWorkspace -DirectiveEnabled $script:OlaUiState.DirectiveMode -SessionSummary $sessionSummary
$messages = New-OlaMessageBuffer -SystemPrompt $systemPrompt

$firstPrompt = $InitialPrompt
$turnNumber = 0
$inputIsRedirected = $false
try {
    $inputIsRedirected = [Console]::IsInputRedirected
}
catch {
}

while ($true) {
    if ($firstPrompt) {
        $userInput = $firstPrompt
        $firstPrompt = $null
        Write-Host ("ola> " + $userInput)
    }
    else {
        Write-Host -NoNewline "ola> "
        $userInput = Read-Host
        if ($inputIsRedirected -and [string]::IsNullOrWhiteSpace($userInput)) {
            break
        }
    }

    if ([string]::IsNullOrWhiteSpace($userInput)) {
        continue
    }

    $trimmed = $userInput.Trim().ToLowerInvariant()
    if ($trimmed -eq "/exit" -or $trimmed -eq "/quit") {
        break
    }

    if ($trimmed -eq "/clear") {
        $sessionSummary = $null
        $systemPrompt = Get-OlaSystemPrompt -ResolvedWorkspace $resolvedWorkspace -DirectiveEnabled $script:OlaUiState.DirectiveMode -SessionSummary $sessionSummary
        $messages = New-OlaMessageBuffer -SystemPrompt $systemPrompt
        Write-Host "[cleared]"
        continue
    }

    if ($trimmed -eq "/directive" -or $trimmed -eq "/directive on") {
        $script:OlaUiState.DirectiveMode = $true
        $systemPrompt = Get-OlaSystemPrompt -ResolvedWorkspace $resolvedWorkspace -DirectiveEnabled $script:OlaUiState.DirectiveMode -SessionSummary $sessionSummary
        $messages[0] = @{
            role = "system"
            content = $systemPrompt
        }
        Write-OlaProgress -Stage "turn" -State "info" -Message "Directive mode enabled."
        continue
    }

    if ($trimmed -eq "/directive off") {
        $script:OlaUiState.DirectiveMode = $false
        $systemPrompt = Get-OlaSystemPrompt -ResolvedWorkspace $resolvedWorkspace -DirectiveEnabled $script:OlaUiState.DirectiveMode -SessionSummary $sessionSummary
        $messages[0] = @{
            role = "system"
            content = $systemPrompt
        }
        Write-OlaProgress -Stage "turn" -State "info" -Message "Directive mode disabled."
        continue
    }

    if ($trimmed -eq "/status") {
        Write-OlaStatusLine -Force
        continue
    }

    if ($trimmed -eq "/summary") {
        if ([string]::IsNullOrWhiteSpace($sessionSummary)) {
            Write-Host "[summary] no compacted session summary yet." -ForegroundColor DarkGray
        }
        else {
            Write-OlaTextBlock -Label "session summary" -Text $sessionSummary -MaxLines 24
        }

        continue
    }

    [void]$messages.Add(@{
        role = "user"
        content = $userInput
    })

    $turnNumber++
    $turnPlan = Get-TurnRoutingPlan -UserInput $userInput -FastModel $Model -HeavyModelName $HeavyModel -CoderModelName $CoderModel -StructuredModelName $StructuredModel -VisionModelName $VisionModel -SelectedRoutingMode $RoutingMode
    $currentModel = $turnPlan.InitialModel
    $formattingInstruction = Get-FormattingInstruction -UserInput $userInput
    $turnToolCalls = 0
    $completed = $false
    $script:OlaUiState.ToolCalls = 0

    Write-OlaTurnHeader -TurnNumber $turnNumber -UserInput $userInput -InitialModel $currentModel -PreferredSynthesisModel $turnPlan.PreferredSynthesisModel -MissionType $turnPlan.MissionType
    Write-OlaProgress -Stage "route" -State "decide" -Message ("reason=" + $turnPlan.Reason)

    if ($RoutingProbeOnly) {
        Write-OlaProgress -Stage "turn" -State "probe" -Message ("initial=" + $turnPlan.InitialModel + " | synthesis=" + $turnPlan.PreferredSynthesisModel + " | mission=" + $turnPlan.MissionType)
        Write-OlaDivider "-"
        if ($SinglePrompt) {
            break
        }

        continue
    }

    $turnToolEvents = New-Object System.Collections.ArrayList
    if ($turnPlan.MissionType -eq "cleanup") {
        $cleanupDriveRoot = Get-RequestedDriveRoot -UserInput $userInput
        $cleanupSummary = $cleanupDriveRoot + "\ | broad"
        Write-OlaProgress -Stage "tool" -State "start" -Message ("find_cleanup_candidates | " + $cleanupSummary)
        $cleanupToolStart = Get-Date
        try {
            $cleanupToolResult = Invoke-WithOlaHeartbeat -Phase "tool" -Detail ("find_cleanup_candidates | " + $cleanupSummary) -IntervalSeconds 8 -Action {
                Invoke-AgentTool -Name "find_cleanup_candidates" -Arguments @{
                    drive_root = $cleanupDriveRoot
                    broad_scan = $true
                    max_results = 50
                    min_size_mb = 5
                } -ResolvedWorkspace $resolvedWorkspace -TimeoutSeconds $ToolTimeoutSeconds
            }
            $cleanupToolSeconds = [math]::Round(((Get-Date) - $cleanupToolStart).TotalSeconds, 2)
            $cleanupToolObject = ConvertFrom-JsonSafe -JsonText $cleanupToolResult
            $cleanupToolState = if (-not [string]::IsNullOrWhiteSpace($cleanupToolResult)) { "done" } else { "fail" }
            $cleanupToolResultSummary = Get-ToolResultProgressSummary -ToolName "find_cleanup_candidates" -ToolResult $cleanupToolResult
            $cleanupToolMessage = ("find_cleanup_candidates | duration={0}s" -f $cleanupToolSeconds)
            if (-not [string]::IsNullOrWhiteSpace($cleanupToolResultSummary)) {
                $cleanupToolMessage += " | " + $cleanupToolResultSummary
            }

            Write-OlaProgress -Stage "tool" -State $cleanupToolState -Message $cleanupToolMessage
            [void]$messages.Add(@{
                role = "tool"
                content = $cleanupToolResult
            })
            [void]$turnToolEvents.Add([pscustomobject]@{
                Name = "find_cleanup_candidates"
                Arguments = @{
                    drive_root = $cleanupDriveRoot
                    broad_scan = $true
                    max_results = 50
                    min_size_mb = 5
                }
                ResultObject = $cleanupToolObject
                ResultRaw = $cleanupToolResult
            })
            $turnToolCalls = 1
            $script:OlaUiState.ToolCalls = $turnToolCalls

            $verifiedCleanupAnswer = Get-VerifiedCleanupAnswer -UserInput $userInput -ToolEvents $turnToolEvents
            if (-not [string]::IsNullOrWhiteSpace($verifiedCleanupAnswer)) {
                [void]$messages.Add(@{
                    role = "assistant"
                    content = $verifiedCleanupAnswer
                })
                Write-OlaProgress -Stage "answer" -State "done" -Message ("rendering verified tool-backed response | tools=" + $turnToolCalls)
                Write-OlaTextBlock -Label "answer" -Text $verifiedCleanupAnswer -MaxLines 0
                Write-OlaProgress -Stage "turn" -State "done" -Message ("#" + $turnNumber + " | tools=" + $turnToolCalls)
                Write-OlaDivider "-"
                $completed = $true
            }
        }
        catch {
            Write-OlaProgress -Stage "route" -State "fail" -Message ("cleanup fast path failed | fallback=model | error=" + (Limit-OlaPreview -Text $_.Exception.Message -MaxLength 120))
        }
    }

    if ($completed) {
        if ($SinglePrompt) {
            break
        }

        continue
    }

    for ($iteration = 1; $iteration -le $MaxToolIterations; $iteration++) {
        $script:OlaUiState.ActiveModel = $currentModel
        Write-OlaProgress -Stage "model" -State "start" -Message ("model=" + $currentModel + " | iteration=" + $iteration + "/" + $MaxToolIterations)
        $modelStart = Get-Date
        try {
            $modelHeartbeatDetail = "waiting for " + $currentModel + " to respond"
            if ($turnToolCalls -gt 0) {
                $modelHeartbeatDetail += " after " + $turnToolCalls + " tool call(s)"
            }
            $response = Invoke-WithOlaHeartbeat -Phase "model" -Detail $modelHeartbeatDetail -IntervalSeconds 8 -Action {
                Invoke-OllamaChat -Messages $messages -Tools $tools -ChatModel $currentModel -Url $OllamaUrl -TimeoutSeconds $ChatTimeoutSeconds
            }
        }
        catch {
            $errorText = $_.Exception.Message
            if (
                $RoutingMode -eq "auto" -and
                $currentModel -ne $Model
            ) {
                Write-OlaProgress -Stage "route" -State "fail" -Message ("model=" + $currentModel + " failed | fallback=" + $Model + " | error=" + (Limit-OlaPreview -Text $errorText -MaxLength 120))
                $currentModel = $Model
                continue
            }

            throw
        }

        $modelSeconds = [math]::Round(((Get-Date) - $modelStart).TotalSeconds, 2)
        Write-OlaProgress -Stage "model" -State "done" -Message ("model=" + $currentModel + " | duration=" + $modelSeconds + "s")
        if (-not $response.message) {
            throw "Unexpected Ollama response format."
        }

        $message = $response.message
        $toolCalls = @()
        if ($message.tool_calls) {
            $toolCalls = @($message.tool_calls)
        }

        if ($toolCalls.Count -gt 0) {
            [void]$messages.Add(@{
                role = "assistant"
                content = if ($message.content) { [string]$message.content } else { "" }
                tool_calls = $toolCalls
            })

            foreach ($toolCall in $toolCalls) {
                $toolName = [string]$toolCall.function.name
                $toolArguments = ConvertTo-Hashtable -InputObject $toolCall.function.arguments
                $toolSummary = Get-ToolProgressSummary -Name $toolName -Arguments $toolArguments -ResolvedWorkspace $resolvedWorkspace
                if ([string]::IsNullOrWhiteSpace($toolSummary)) {
                    Write-OlaProgress -Stage "tool" -State "start" -Message $toolName
                }
                else {
                    Write-OlaProgress -Stage "tool" -State "start" -Message ($toolName + " | " + $toolSummary)
                }

                $toolStart = Get-Date
                $toolHeartbeatDetail = if ([string]::IsNullOrWhiteSpace($toolSummary)) {
                    $toolName
                }
                else {
                    $toolName + " | " + $toolSummary
                }
                $toolResult = Invoke-WithOlaHeartbeat -Phase "tool" -Detail $toolHeartbeatDetail -IntervalSeconds 8 -Action {
                    Invoke-AgentTool -Name $toolName -Arguments $toolArguments -ResolvedWorkspace $resolvedWorkspace -TimeoutSeconds $ToolTimeoutSeconds
                }
                $toolSeconds = [math]::Round(((Get-Date) - $toolStart).TotalSeconds, 2)
                $toolResultSummary = Get-ToolResultProgressSummary -ToolName $toolName -ToolResult $toolResult
                $toolResultObject = ConvertFrom-JsonSafe -JsonText $toolResult
                $toolState = "done"
                if (
                    ($toolResultObject -and $toolResultObject.error) -or
                    ($toolResultObject -and $toolResultObject.exit_code -and [int]$toolResultObject.exit_code -ne 0)
                ) {
                    $toolState = "fail"
                }

                $toolMessage = ("{0} | duration={1}s" -f $toolName, $toolSeconds)
                if (-not [string]::IsNullOrWhiteSpace($toolResultSummary)) {
                    $toolMessage += " | " + $toolResultSummary
                }

                Write-OlaProgress -Stage "tool" -State $toolState -Message $toolMessage
                [void]$messages.Add(@{
                    role = "tool"
                    content = $toolResult
                })
                [void]$turnToolEvents.Add([pscustomobject]@{
                    Name = $toolName
                    Arguments = $toolArguments
                    ResultObject = $toolResultObject
                    ResultRaw = $toolResult
                })
                $turnToolCalls++
                $script:OlaUiState.ToolCalls = $turnToolCalls
            }

            $verifiedToolAnswer = Get-VerifiedCleanupAnswer -UserInput $userInput -ToolEvents $turnToolEvents
            if (-not [string]::IsNullOrWhiteSpace($verifiedToolAnswer)) {
                [void]$messages.Add(@{
                    role = "assistant"
                    content = $verifiedToolAnswer
                })
                Write-OlaProgress -Stage "answer" -State "done" -Message ("rendering verified tool-backed response | tools=" + $turnToolCalls)
                Write-OlaTextBlock -Label "answer" -Text $verifiedToolAnswer -MaxLines 0
                Write-OlaProgress -Stage "turn" -State "done" -Message ("#" + $turnNumber + " | tools=" + $turnToolCalls)
                Write-OlaDivider "-"
                $completed = $true
                break
            }

            if (
                Test-ShouldEscalateForSynthesis `
                    -UserInput $userInput `
                    -TurnToolCalls $turnToolCalls `
                    -Iteration $iteration `
                    -PreferSynthesisUpgrade $turnPlan.PreferSynthesisUpgrade `
                    -CurrentModel $currentModel `
                    -FastModel $Model `
                    -PreferredSynthesisModel $turnPlan.PreferredSynthesisModel `
                    -SelectedRoutingMode $RoutingMode
            ) {
                $currentModel = $turnPlan.PreferredSynthesisModel
                Write-OlaProgress -Stage "route" -State "shift" -Message ("synthesis=" + $currentModel + " | after_tools=" + $turnToolCalls)
            }

            continue
        }

        $finalContent = if ($message.content) { [string]$message.content } else { "" }
        [void]$messages.Add(@{
            role = "assistant"
            content = $finalContent
        })
        $renderedContent = $finalContent

        if (
            -not [string]::IsNullOrWhiteSpace($formattingInstruction) -and
            -not [string]::IsNullOrWhiteSpace($finalContent) -and
            $userInput.ToLowerInvariant() -notmatch '^(reply|answer)\s+with\s+exactly\b' -and
            $finalContent.Trim() -notmatch '^[A-Za-z0-9 _.-]{1,20}$'
        ) {
            $formatModel = if (
                -not [string]::IsNullOrWhiteSpace($turnPlan.PreferredSynthesisModel) -and
                $turnPlan.PreferredSynthesisModel -ne $currentModel
            ) {
                $turnPlan.PreferredSynthesisModel
            }
            else {
                $currentModel
            }

            Write-OlaProgress -Stage "answer" -State "shape" -Message ("formatting with " + $formatModel)
            $formatMessages = New-Object System.Collections.ArrayList
            foreach ($entry in $messages) {
                [void]$formatMessages.Add($entry)
            }

            [void]$formatMessages.Add(@{
                role = "user"
                content = "Reformat the latest answer to match the user's requested output shape exactly. Do not call tools. Keep only verified facts. " + $formattingInstruction
            })

            try {
                $formatResponse = Invoke-WithOlaHeartbeat -Phase "answer" -Detail ("formatting final answer with " + $formatModel) -IntervalSeconds 8 -Action {
                    Invoke-OllamaChat -Messages $formatMessages -Tools @() -ChatModel $formatModel -Url $OllamaUrl -TimeoutSeconds $ChatTimeoutSeconds
                }
                if ($formatResponse.message -and $formatResponse.message.content) {
                    $renderedContent = [string]$formatResponse.message.content
                }
            }
            catch {
                Write-OlaProgress -Stage "answer" -State "fail" -Message "formatting pass failed; keeping original answer"
            }
        }

        Write-OlaProgress -Stage "answer" -State "done" -Message ("rendering final response from " + $currentModel + " | tools=" + $turnToolCalls)
        if ($renderedContent.Trim()) {
            Write-OlaTextBlock -Label "answer" -Text $renderedContent.Trim() -MaxLines 0
        }
        Write-OlaProgress -Stage "turn" -State "done" -Message ("#" + $turnNumber + " | tools=" + $turnToolCalls)
        Write-OlaDivider "-"
        $completed = $true
        break
    }

    if (-not $completed) {
        Write-OlaProgress -Stage "turn" -State "fail" -Message "Reached max tool iterations without a final answer."
        Write-OlaDivider "-"
    }

    try {
        $summaryModel = if (-not [string]::IsNullOrWhiteSpace($StructuredModel)) { $StructuredModel } elseif (-not [string]::IsNullOrWhiteSpace($HeavyModel)) { $HeavyModel } else { $Model }
        $compaction = Invoke-OlaSessionCompaction -Messages $messages -ResolvedWorkspace $resolvedWorkspace -DirectiveEnabled $script:OlaUiState.DirectiveMode -SessionSummary $sessionSummary -SummaryModel $summaryModel -Url $OllamaUrl -TimeoutSeconds $ChatTimeoutSeconds -CharThreshold $SessionCompactionCharThreshold -KeepRecentEntries $SessionCompactionKeepRecentEntries
        if ($compaction.Compacted) {
            $messages = $compaction.Messages
            $sessionSummary = $compaction.SessionSummary
            $systemPrompt = Get-OlaSystemPrompt -ResolvedWorkspace $resolvedWorkspace -DirectiveEnabled $script:OlaUiState.DirectiveMode -SessionSummary $sessionSummary
            $messages[0] = @{
                role = "system"
                content = $systemPrompt
            }
            Write-OlaProgress -Stage "memory" -State "done" -Message ("compacted session context | removed_entries=" + $compaction.RemovedEntries)
        }
    }
    catch {
        Write-OlaProgress -Stage "memory" -State "fail" -Message ("session compaction failed | " + (Limit-OlaPreview -Text $_.Exception.Message -MaxLength 120))
    }

    if ($SinglePrompt) {
        break
    }
}
