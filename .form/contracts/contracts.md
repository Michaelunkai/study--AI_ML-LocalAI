# Frozen Interface Contracts — form-20261011-1746

Deliverable root: `F:\study\AI_ML\LocalAI\ultimate-llm\`
Target runtime: Windows 10/11, **PowerShell 5.1 compatible only** (no ternary, no `??`,
no `Learn more` operators; set `[Net.ServicePointManager]::SecurityProtocol` for TLS 1.2;
`ConvertTo-Json -Depth` explicit). `wmic` is NOT available — use CIM cmdlets.
Python 3.14 available on host. All probes must be try/catch-wrapped: never throw, degrade to null.

## File map (frozen)

```
ultimate-llm/
├── Ultimate-AI.cmd            # double-click entry → runs Start-UltimateAI.ps1
├── Start-UltimateAI.ps1       # master orchestrator
├── lib/hardware-scan.ps1      # TASK-001
├── lib/discover-model.ps1     # TASK-002
├── lib/fixtures/profiles.json # TASK-002 test fixtures (3 profiles)
├── lib/ensure-prereqs.ps1     # TASK-003
├── harness/harness.py         # TASK-004
├── harness/requirements.txt   # TASK-004
└── README.md                  # TASK-006
```

## TASK-001 — lib/hardware-scan.ps1

Dot-source only; no side effects at import.

```powershell
function Get-HardwareProfile { }
# Returns PSCustomObject. CLI mode:  powershell -File lib/hardware-scan.ps1  → prints JSON to stdout, exit 0.
```

JSON schema (all keys REQUIRED, values may be null when probe fails):

```json
{
  "generated_at": "ISO-8601",
  "os": "string",
  "powershell_version": "string",
  "cpu": { "name": "string", "cores": 0, "threads": 0 },
  "ram_gb": 0,
  "gpus": [ { "name": "string", "vram_gb": 0, "source": "nvidia-smi|cim|registry|none" } ],
  "vram_total_gb": 0,
  "disk_free_gb": 0,
  "ollama_path": "string|null",
  "python_version": "string|null",
  "winget_ok": false
}
```

Rules: GPU via `nvidia-smi --query-gpu=name,memory.total --format=csv,noheader` first;
fallback CIM `Win32_VideoController` + registry `HardwareInformation.qwMemorySize`
(handles >4 GB); RAM via `Win32_ComputerSystem.TotalPhysicalMemory`; disk = free GB of
the script's own drive. `vram_total_gb` = sum of gpu vram_gb.

Acceptance:
```
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { . 'F:\study\AI_ML\LocalAI\ultimate-llm\lib\hardware-scan.ps1'; $p = Get-HardwareProfile; if (-not $p.ram_gb) { exit 1 }; if (-not $p.gpus -or $p.gpus.Count -lt 1) { exit 1 }; if (-not $p.cpu.name) { exit 1 }; if (-not $p.os) { exit 1 }; if ($p.vram_total_gb -lt 1) { exit 1 }; $j = $p | ConvertTo-Json -Depth 6; if (-not $j) { exit 1 }; exit 0 }"
```

## TASK-002 — lib/discover-model.ps1

Dot-source only. Deterministic in `-Offline` mode (embedded catalog, no network).

```powershell
function Select-UltimateModel { [object]$HardwareProfile, [switch]$Offline, [string]$PreferSize }
# CLI: powershell -File lib/discover-model.ps1 -HardwareProfileJson <path-to-profile-json> [-Offline]
# → prints model-choice JSON to stdout, exit 0. Exit 2 on no-fit-model.
```

Output schema (all keys REQUIRED):

```json
{
  "model": "ollama-tag",
  "display_name": "string",
  "family": "string",
  "params_b": null,
  "quant": "Q4_K_M or similar",
  "size_gb": 0,
  "moe": false,
  "tool_call": true,
  "coder": false,
  "score": 0,
  "reason": "string",
  "sources": ["embedded-catalog"],
  "fit": { "mode": "vram|vram+ram", "est_vram_gb": 0 },
  "runner": { "num_ctx": 0 },
  "discovered_at": "ISO-8601",
  "online_used": false
}
```

Online pipeline (best-effort, each source try/catch + 15 s timeout, `online_used=true` when ANY succeeds):
1. `https://models.dev/api.json` — parse entries usable with Ollama (provider ollama or
   ids shaped like ollama tags), keep `tool_call:true` entries, capture size/params/recency.
2. `https://ollama.com/library` + `https://ollama.com/search?v=updated` HTML — regex-extract
   model name + downloaded-size strings ("21GB", "9.1GB") as freshness/size signals.
3. NEVER fail hard: on all-network-fail → embedded catalog, `online_used=false`.

Embedded fallback catalog MUST include at least (tag, size_gb Q4 est, moe, tool_call, coder,
recency_rank 1=newest): `qwen3.5` family (e.g. `qwen3.5:9b`), `gpt-oss:20b` (13.5, moe, tools),
`qwen3-coder:30b` (19, moe, tools, coder), `qwen3:30b-a3b` (19, moe, tools),
`glm-4.5-air` / GLM family entry, `deepseek-r1:14b/32b`, `devstral:24b`, `mistral-small3.2:24b`,
`llama4:scout`, `phi-4:14b`, `gemma3:12b/27b`. Catalog extensible via
`lib/fixtures/catalog-override.json` if present.

Fit rules (frozen): `usable_vram = vram_total_gb * 0.93 - 0.8`. Dense models: `size_gb <= usable_vram`.
MoE models: allowed `vram+ram` spill if `size_gb <= usable_vram * 1.6` AND host `ram_gb >= 32`
(and penalize score by 12). CPU-only host: require `size_gb <= ram_gb * 0.5`, huge penalty.
`num_ctx`: 32768 if est fits vram, else 16384.
Score = family_weight(0-10) + tool_call*4 + coder*2 + recency_bonus(≤3) + moe_speed_bonus(2) − penalties. Ties → alphabetical.

Acceptance (fixtures in `lib/fixtures/profiles.json`, three profiles keyed
`rtx5080-16gb`, `no-gpu-8gb`, `weak-gpu-4gb`; each run prints choice JSON, exit 0, ALL
schema keys present, chosen model must exist in embedded catalog, fit rule holds):
```
powershell -NoProfile -ExecutionPolicy Bypass -File "F:\study\AI_ML\LocalAI\ultimate-llm\lib\discover-model.ps1" -HardwareProfileJson "F:\study\AI_ML\LocalAI\ultimate-llm\lib\fixtures\profiles.json" -FixtureKey rtx5080-16gb -Offline
powershell -NoProfile -ExecutionPolicy Bypass -File "F:\study\AI_ML\LocalAI\ultimate-llm\lib\discover-model.ps1" -HardwareProfileJson "F:\study\AI_ML\LocalAI\ultimate-llm\lib\fixtures\profiles.json" -FixtureKey no-gpu-8gb -Offline
powershell -NoProfile -ExecutionPolicy Bypass -File "F:\study\AI_ML\LocalAI\ultimate-llm\lib\discover-model.ps1" -HardwareProfileJson "F:\study\AI_ML\LocalAI\ultimate-llm\lib\fixtures\profiles.json" -FixtureKey weak-gpu-4gb -Offline
```

## TASK-003 — lib/ensure-prereqs.ps1

Dot-source only.

```powershell
function Test-Prerequisites { }   # report-only, installs NOTHING
function Ensure-Prerequisites { [switch]$AcceptInstalls }  # may install; idempotent
```

Both return PSCustomObject serializable to JSON with REQUIRED keys:
`ollama{installed,path,version,daemon_up}`, `python{found,version}`, `venv{exists,path}`,
`winget{ok}`, `disk{free_gb}`. CLI: `powershell -File lib/ensure-prereqs.ps1 -Report`
→ prints JSON, exit 0.

Install order (only with -AcceptInstalls): ollama missing → `winget install -e --id Ollama.Ollama`
→ fallback `https://ollama.com/download/OllamaSetup.exe` silent; daemon down → try
`ollama list`, else start `ollama.exe serve` hidden (path probe:
PATH, `%LOCALAPPDATA%\Programs\Ollama\ollama.exe`); python missing → `winget install -e --id Python.Python.3.12`.

Acceptance:
```
powershell -NoProfile -ExecutionPolicy Bypass -File "F:\study\AI_ML\LocalAI\ultimate-llm\lib\ensure-prereqs.ps1" -Report
```
exit 0 + JSON has ollama.version (non-empty on this host), python.found=true, winget.ok=true.

## TASK-004 — harness/harness.py + harness/requirements.txt

Single-file agentic REPL. Python ≥3.10 (host runs 3.14). Core deps only:
`rich>=13`, `httpx>=0.28`, `psutil>=5.9`, `pyperclip>=1.9` (requirements.txt, pinned `>=`).
Optional (`import` guarded, degrade with UI notice): `playwright`, `ddgs`, `bs4`.

CLI:
```
python harness.py --model TAG [--host http://127.0.0.1:11434] [--max-iters 80] [--yes] [--self-test]
```
`--self-test`: pure-offline asserts — tool registry size ≥ 24, every tool has name+description+
json-schema args, JSON-fallback tool-call parser round-trips a sample, native tool-call
chunk assembler works, prompt builder includes all tool names. Prints `SELF-TEST PASS`, exit 0.

Required tool names (EXACT): `run_powershell, run_cmd, run_python, read_file, write_file,
edit_file, list_dir, find_files, search_files, web_search, fetch_url, open_in_browser,
start_process, list_processes, stop_process, screenshot, clipboard_get, clipboard_set,
notify_user, git_run, scaffold_project, memory_read, memory_write, task_done`.

Agent loop: stream `POST {host}/api/chat` (`stream:true`, Ollama native `tools` format);
assemble streamed `tool_calls`; if model emits none but message content contains a JSON
object `{"tool": ..., "args": {...}}` → execute via fallback path (models without native
tool support). Auto-approve every tool (`--yes` default ON). Loop until `task_done` called
or `--max-iters` reached; render every token (rich Markdown stream) and every tool call
(panel with args + result, truncated) LIVE. Persist `~/.ultimate-ai/notes.md` +
`~/.ultimate-ai/sessions/<ts>.json`. Never crash on single tool error — return error text
to model as tool result.

Acceptance:
```
python -m py_compile "F:\study\AI_ML\LocalAI\ultimate-llm\harness\harness.py"
python "F:\study\AI_ML\LocalAI\ultimate-llm\harness\harness.py" --self-test
```
both exit 0, second prints `SELF-TEST PASS`.

## TASK-005 — Start-UltimateAI.ps1 + Ultimate-AI.cmd

```
param( [switch]$SelfTest, [switch]$SkipPull, [string]$Model, [switch]$Offline,
       [switch]$LaunchOnly, [switch]$NoAlias )
```
Flow: banner → dot-source the 3 libs → `-SelfTest`: parse-check ALL .ps1 (PSL Parser, zero
ParseError), `Get-HardwareProfile`, `Select-UltimateModel -Offline` on real profile,
`Test-Prerequisites` JSON keys, `python harness.py --self-test` → print one line
`[SELFTEST] <name> PASS|FAIL` per check, exit 0 iff ALL PASS.
Normal flow: Ensure-Prerequisites -AcceptInstalls → Select-UltimateModel (online, auto-fallback
offline; `-Model` overrides; chosen model printed big) → pull if `ollama show` fails
(`-SkipPull` skips) → venv `.venv` + `pip install -r harness/requirements.txt` (per-package
try, core rich+httpx mandatory-fail) → unless `-NoAlias`: write `%LOCALAPPDATA%\UltimateAI\bin\ultimate-ai.cmd`
shim + append user PATH once → launch `python harness\harness.py --model <tag> --yes`
(interactive). `-LaunchOnly` skips straight to launch.
`Ultimate-AI.cmd`: `@powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-UltimateAI.ps1" %*`
with `if errorlevel 1 pause`.

Acceptance:
```
powershell -NoProfile -ExecutionPolicy Bypass -File "F:\study\AI_ML\LocalAI\ultimate-llm\Start-UltimateAI.ps1" -SelfTest
```
exit 0, every `[SELFTEST]` line PASS, no ParseError.

## TASK-006 — README.md

≥60 lines: what it does, run instructions (double-click Ultimate-AI.cmd / CLI), all flags,
how model discovery works (sources, fallback), harness tool list, troubleshooting
(ollama not found, no GPU, pull interrupted), uninstall. Acceptance: file exists,
`Select-String 'Ultimate-AI.cmd'` matches.

## Integration criteria (Module 7)

`Start-UltimateAI.ps1 -SelfTest` exit 0 + all acceptance commands of T1–T4 re-run exit 0
+ README check. Live pull/chat is USER-run-time behavior, NOT a form acceptance gate.
