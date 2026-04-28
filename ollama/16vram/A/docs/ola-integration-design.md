# ola Integration Design

## Current Runtime Split

- Benchmark winner for code-edit cases: `python -m aider`
- Benchmark winner model: `qwen3.5:latest`
- Default interactive runtime: repo-local native `ola` agent
- Native fast model: `qwen3.5-oll90:latest`
- Native coding model: `qwen3-coder:latest`
- Native structured-output model: `gpt-oss:20b`
- Native heavy synthesis model: `qwen3:30b-a3b`
- Native vision fallback: `gemma4:latest`

Why this split exists:

- `aider + qwen3.5:latest` passed all 4 benchmark cases on `2026-04-21`
- `aider + qwen3-coder:latest` also passed all 4 benchmark cases and is the evidence-backed fallback
- every current `codex --oss --local-provider ollama` candidate tested today finished `0/4`
- raw `ollama run --experimental` and `--experimental-yolo` are live, but no fair repo benchmark harness exists for them here today, so they are not selected over the fully benchmarked Aider path
- the native agent now has the best interactive tool surface for this repo: readable progress, routing probes, current-web tools, and per-mission model selection

## Repo-Local Runtime

- Runtime entrypoint: `scripts\Invoke-Ola.ps1`
- Default workspace: current terminal directory
- Default interactive runtime: `native` when `-Profile agentic`
- Default fast model: `qwen3.5-oll90:latest`
- Fallback invocation: `-Model qwen3-coder:latest`
- Runtime policy:
  - stay terminal-first
  - repair broken Windows env vars in-process
  - enforce canonical Ollama paths and runtime env
  - verify the selected model exists before launch
  - start `ollama serve` if the API is not already reachable
  - keep smoke verification non-interactive and bounded
  - prefer first-class web tools over ad hoc shell browsing
  - keep `aider` available as an explicit runtime, not the default interactive path
  - keep output readable enough to monitor live without parsing raw tool noise

Useful repo-local calls before profile wiring:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -PrintResolvedCommand -WorkspacePath .
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -SmokeTest -WorkspacePath .
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -CapabilityProbe -WorkspacePath .
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OlaNativeAgent.ps1 -WorkspacePath . -RoutingProbeOnly -InitialPrompt 'Search the web for current Ollama web search docs.' -SinglePrompt
```

## Exact Profile Wiring

Add one thin wrapper near the other standalone wrapper functions (`claur`, `clauc`, `codr`, `codc`) and leave unrelated profile behavior untouched:

```powershell
# Ollama local daily-driver launcher
function ola { . 'F:\study\AI_ML\LocalAI\ollama\16vram\A\scripts\Invoke-Ola.ps1' @args }
```

Why this splice:

- it matches the existing wrapper pattern already used in the profile
- it keeps the implementation repo-local
- it avoids copying launcher logic into the profile
- it preserves unrelated profile behavior

## Exact Windows PowerShell 5 Reload And Resolution Check

Authoritative PS5 executable path:

```text
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
```

Fresh-session resolution check after adding `ola` to the profile:

```powershell
& 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ExecutionPolicy Bypass -Command "Get-Command ola -ErrorAction Stop | Select-Object Name,CommandType,Definition | Format-List"
```

That is the canonical verification path because it loads the real PS5 profile in a fresh session and proves `ola` resolves without depending on the current shell.

## Exact End-To-End ola Verification Path

1. Resolved-command check in fresh PS5:

```powershell
& 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ExecutionPolicy Bypass -Command "ola -PrintResolvedCommand -WorkspacePath 'F:\study\AI_ML\LocalAI\ollama\16vram\A'"
```

2. Non-interactive smoke proof through the same wrapper path:

```powershell
& 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ExecutionPolicy Bypass -Command "ola -SmokeTest -WorkspacePath 'F:\study\AI_ML\LocalAI\ollama\16vram\A'"
```

3. Real interactive launch in fresh PS5:

```powershell
& 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ExecutionPolicy Bypass -Command "ola -WorkspacePath 'F:\study\AI_ML\LocalAI\ollama\16vram\A'"
```

4. Fallback-model launch if the default model regresses:

```powershell
& 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ExecutionPolicy Bypass -Command "ola -WorkspacePath 'F:\study\AI_ML\LocalAI\ollama\16vram\A' -Model 'qwen3-coder:latest'"
```

## Regression-Oriented Follow-Up Check

Run two fresh PS5 startups back to back and capture both stdout and stderr so profile-startup noise or command-resolution drift becomes obvious:

```powershell
$ps5 = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
$log = Join-Path $env:TEMP 'ola-ps5-startup-check.log'
Remove-Item $log -ErrorAction SilentlyContinue
1..2 | ForEach-Object {
    & $ps5 -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; Get-Command ola,python,ollama -ErrorAction Stop | Select-Object Name,Source,CommandType | ConvertTo-Json -Compress" 2>&1 |
        Tee-Object -FilePath $log -Append
}
Get-Content $log
```

Pass conditions:

- both fresh launches resolve `ola`, `python`, and `ollama`
- `ola` still points at `F:\study\AI_ML\LocalAI\ollama\16vram\A\scripts\Invoke-Ola.ps1`
- `ola -SmokeTest` returns `SmokePassed = True`
- the profile may still emit unrelated startup noise, but it must not prevent `ola` from resolving and running
