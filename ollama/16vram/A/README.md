# Ollama Local Daily Driver

This repo now contains the evidence-backed local daily-driver winner for this exact Windows machine.

Search-space status for `2026-04-21`: closed for today.

## Final Decision

- Benchmark winner for code-edit cases: `python -m aider`
- Benchmark winner model: `qwen3.5:latest`
- Default interactive runtime: repo-local native `ola` agent
- Native model catalog:
  - fast general: `qwen3.5-oll90:latest`
  - coding: `qwen3-coder:latest`
  - heavy reasoning: `qwen3:30b-a3b`
  - strict structured output: `gpt-oss:20b`
  - vision fallback: `gemma4:latest`
- Launcher: `ola`
- Runtime style: terminal-first, no browser, no tray app, no watcher, no tunnel, no dev server

Why this won:

- `aider + qwen3.5:latest` passed all 4 benchmark cases under the repaired PS5-safe harness.
- `aider + qwen3-coder:latest` also passed all 4 benchmark cases and remains the evidence-backed fallback.
- The native `ola` path is now the default interactive agent because it can route between fast, coding, structured, and heavy models per mission instead of pinning every turn to one stack.
- The native `ola` path now has first-class `web_search`, `web_fetch`, and `scrape_web_page` tools plus readable timestamped progress output.
- Every current `codex --oss --local-provider ollama` row tested on `2026-04-21` finished `0/4`.
- Raw `ollama run --experimental` and `--experimental-yolo` are real and working for direct prompts, but no fair repo benchmark harness exists for them in this repo today, so they did not beat the benchmarked Aider path.

## Verified Machine Baseline

- Windows: `Microsoft Windows 11 Pro` `10.0.26200`
- CPU: `AMD Ryzen 7 9800X3D 8-Core Processor`
- RAM: `93.6 GB`
- GPUs: `AMD Radeon(TM) Graphics` and `NVIDIA GeForce RTX 5080`
- NVIDIA display driver: `32.0.15.9621` via `oem11.inf`, dated `2026-04-13`
- Canonical Ollama binary: `F:\backup\LocalAI\ollama\ollama-app\ollama.exe`
- Canonical Ollama home: `F:\backup\LocalAI\ollama`
- Canonical models path: `F:\backup\LocalAI\ollama\models`
- Ollama version: `0.21.0`

## Current Truth

- GPU inference is working on this machine through Ollama.
- `nvidia-smi` is still failing with `Failed to initialize NVML: Unknown Error`.
- That NVML failure did not stop successful local inference or the winning benchmark runs.
- `ola` is designed to enforce the canonical Ollama paths and auto-start the Ollama API if needed.

## Weighted Matrix

| Stack | Model | Validity | Result | Total Time | Decision |
| --- | --- | --- | --- | --- | --- |
| Aider | `qwen3.5:latest` | valid | `4/4` pass | `169.61s` | winner |
| Aider | `qwen3-coder:latest` | valid | `4/4` pass | `192.66s` | fallback |
| Codex local | `qwen3.5:latest` | valid | `0/4` pass | `22.82s` | reject |
| Codex local | `qwen3-coder:latest` | valid | `0/4` pass | `86.94s` | reject |
| Codex local | `gpt-oss:20b` | valid | `0/4` pass | `79.04s` | reject |
| Codex local | `qwen3:30b-a3b` | invalid earlier, infra-contaminated today | not decision-grade | n/a | reject |
| Codex local | `glm-4.7-flash:latest` | invalid due no-server row | not decision-grade | n/a | reject |
| Codex local | `gemma4:latest` | invalid due no-server row | not decision-grade | n/a | reject |
| Codex local | `gemma3:27b` | invalid due no-server row | not decision-grade | n/a | reject |
| Raw Ollama experimental | `qwen3.5:latest` | direct prompt only | simple prompt works | about `20s` | not selected |
| Raw Ollama experimental-yolo | `qwen3.5:latest` | direct prompt only | simple prompt works | about `22s` | not selected |

Decision rule:

- prefer full benchmark correctness over raw prompt latency
- prefer the lighter model when correctness ties
- reject stacks that drift off-task, invoke unsupported tools, or fail every case

## Benchmark Evidence

### Winner

Run path:

- `benchmarks\runs\aider-qwen3.5_latest-20260421-073344`

Result summary:

- `python-slugify`: pass in `39.30s`
- `powershell-stem`: pass in `73.18s`
- `instruction-alerts`: pass in `31.10s`
- `context-policy`: pass in `26.03s`

### Fallback

Run path:

- `benchmarks\runs\aider-qwen3-coder_latest-20260421-073828`

Result summary:

- `python-slugify`: pass in `44.75s`
- `powershell-stem`: pass in `77.18s`
- `instruction-alerts`: pass in `24.52s`
- `context-policy`: pass in `46.21s`

### Key Losers

- `benchmarks\runs\codex-qwen3.5_latest-20260421-072819`
  - valid `0/4`
  - stayed in-bounds but mostly inspected and stopped
- `benchmarks\runs\codex-qwen3-coder_latest-20260421-072911`
  - valid `0/4`
  - transcript fell into unsupported `mcp__playwright__`
- `benchmarks\runs\codex-gpt-oss_20b-20260421-073102`
  - valid `0/4`
  - transcript drifted off-task into unrelated `pipenv` discussion

### Invalid Older Rows

These older rows remain useful as raw artifacts, but not as trusted scoreboard entries:

- `benchmarks\runs\codex-gpt-oss_20b-20260421-054010`
- `benchmarks\runs\codex-qwen3-coder_latest-20260421-054204`

Reason:

- the earlier verifier bug could record `success=true` even when `verify-output.txt` showed failing tests

## `ola` Usage

Default runtime split:

- `agentic` profile now defaults to the repo-local native Ollama tool-calling agent with auto routing.
- Native auto routing now chooses across `qwen3.5-oll90:latest`, `qwen3-coder:latest`, `gpt-oss:20b`, `gemma4:latest`, and `qwen3:30b-a3b` based on mission type.
- Native turns now emit timestamped phase-stable progress lines for routing, model calls, tool execution, formatting passes, and final rendering.
- Native agentic mode now includes first-class `web_search`, `web_fetch`, and `scrape_web_page` tools instead of forcing ad hoc shell-based browsing.
- Native routing can be verified quickly with `Invoke-OlaNativeAgent.ps1 -RoutingProbeOnly`.
- Windows temp/cache cleanup prompts prefer a targeted cleanup-candidate tool instead of a blind whole-drive crawl.
- `aider` remains available with `-Runtime aider` and is still the benchmark winner for code-edit benchmark cases.

Repo-local launcher:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -PrintResolvedCommand -WorkspacePath .
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -SmokeTest -WorkspacePath .
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -CapabilityProbe -WorkspacePath .
```

Fresh PS5 usage after profile wiring:

```powershell
ola -WorkspacePath 'F:\study\AI_ML\LocalAI\ollama\16vram\A'
ola -WorkspacePath 'F:\study\AI_ML\LocalAI\ollama\16vram\A' -Prompt 'List the top-level folders in each drive by actually inspecting them.'
ola -WorkspacePath 'F:\study\AI_ML\LocalAI\ollama\16vram\A' -Runtime aider
ola -WorkspacePath 'F:\study\AI_ML\LocalAI\ollama\16vram\A' -Model 'qwen3-coder:latest'
ola -WorkspacePath 'F:\study\AI_ML\LocalAI\ollama\16vram\A' -Model 'qwen3:30b-a3b' -ModelRouting fixed
ola -SmokeTest -WorkspacePath 'F:\study\AI_ML\LocalAI\ollama\16vram\A'
```

## Health Check

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OllamaHealthCheck.ps1
```

Current result:

- `ollama binary exists=True`
- `models path exists=True`
- `ollama PATH target=True`
- `ollama version=True`
- `ollama list=True`
- `ollama ps=True`
- `nvidia-smi=False`

Interpretation:

- the local-model daily driver is viable today
- NVML is still broken and should be revisited separately
- that NVML issue is bounded and does not reopen today’s local-model search space

## Explicit Search-Space Closure For Today

Closed for `2026-04-21` on this machine:

- Aider vs Codex local-provider comparison
- default-model choice between the two evidence-backed Aider finalists
- terminal-first launcher implementation path
- Codex-local stack viability for this machine today

Not selected today:

- OpenCode
- Open WebUI
- raw Ollama experimental modes as the default coding driver
- any browser, tunnel, tray, watcher, or sidecar-first workflow

Still true after closure:

- future model releases may change the ranking
- a future raw-experimental benchmark harness could reopen that branch later
- NVML repair is still worth doing, but it is no longer a blocker to using the chosen daily driver

## Repo Layout

- `docs/evidence-ledger.md`: commands, outcomes, decisions, and closure notes
- `docs/ola-integration-design.md`: exact wrapper design and PS5 verification path
- `benchmarks/cases/`: fixed benchmark fixtures
- `scripts/Invoke-OllamaHealthCheck.ps1`: PS5-safe health verifier
- `scripts/Invoke-Benchmarks.ps1`: PS5-safe benchmark harness
- `scripts/Invoke-Ola.ps1`: repo-local `ola` runtime
