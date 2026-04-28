param(
    [string]$Model = "gpt-oss:20b",
    [int]$Port = 11434,
    [int]$MaxAttempts = 80,
    [ValidateSet("low", "medium", "high", "xhigh")]
    [string]$ReasoningEffort = "medium",
    [int]$ContextWindow = 32768,
    [string]$ExecPrompt,
    [switch]$NoAltScreen,
    [switch]$WithPlugins,
    [switch]$WithMemories
)

# Use the real Codex binary directly to avoid PowerShell wrapper quirks.
$codexBinary = Join-Path $env:LOCALAPPDATA "npm-global\node_modules\@openai\codex\node_modules\@openai\codex-win32-x64\vendor\x86_64-pc-windows-msvc\codex\codex.exe"
if (-not (Test-Path $codexBinary)) {
    throw "Codex binary not found: $codexBinary"
}

$localInstructionsFile = Join-Path $PSScriptRoot "local-ollama-instructions.md"
if (-not (Test-Path $localInstructionsFile)) {
    throw "Local instructions file not found: $localInstructionsFile"
}

# Ensure Ollama daemon is running.
if (-not (Get-Process -Name ollama -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden | Out-Null
}

# Wait for Ollama API port to accept connections.
$attempt = 0
while ($attempt -lt $MaxAttempts -and -not (Test-NetConnection -ComputerName 127.0.0.1 -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue)) {
    Start-Sleep -Milliseconds 250
    $attempt++
}

if (-not (Test-NetConnection -ComputerName 127.0.0.1 -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue)) {
    throw "Ollama serve did not become ready on port $Port"
}

$leanFlags = @()
if (-not $WithPlugins) {
    $leanFlags += @("--disable", "plugins")
}
if (-not $WithMemories) {
    $leanFlags += @("--disable", "memories")
}

if ($ExecPrompt) {
    $codexArgs = @(
        "exec",
        "--skip-git-repo-check",
        "--profile", "ollama-launch",
        "-m", $Model,
        "-s", "danger-full-access"
    )

    foreach ($flag in $leanFlags) {
        $codexArgs += $flag
    }

    $codexArgs += @(
        "-c", "approval_policy=never",
        "-c", "model_reasoning_effort=$ReasoningEffort",
        "-c", "model_context_window=$ContextWindow",
        "-c", "model_instructions_file=`"$localInstructionsFile`"",
        $ExecPrompt
    )
} else {
    # Lean mode is the default for local models because the full plugin/memory payload
    # materially increases prompt size and slows or destabilizes local inference.
    $codexArgs = @(
        "--profile", "ollama-launch",
        "-m", $Model,
        "-a", "never",
        "-s", "danger-full-access",
        "-c", "approval_policy=never",
        "-c", "model_reasoning_effort=$ReasoningEffort",
        "-c", "model_context_window=$ContextWindow",
        "-c", "model_instructions_file=`"$localInstructionsFile`""
    )

    if ($NoAltScreen) {
        $codexArgs += "--no-alt-screen"
    }

    foreach ($flag in $leanFlags) {
        $codexArgs += $flag
    }
}

if ($args.Count -gt 0) {
    $codexArgs += $args
}

& $codexBinary @codexArgs
