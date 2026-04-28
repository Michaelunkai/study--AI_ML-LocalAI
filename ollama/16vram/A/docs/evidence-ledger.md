# Evidence Ledger

## Finish Line

The task is complete only when all of the following are true:

- NVIDIA and NVML health are either repaired or explicitly bounded so they no longer block the launcher decision.
- Ollama health is verified and stable.
- One canonical Ollama runtime path is selected and documented.
- One canonical models path is selected and documented.
- Current-source research has been completed with citations.
- Credible stack alternatives have been compared.
- Credible model alternatives have been compared.
- The weighted decision matrix is complete.
- The winning stack and winning default model are justified.
- The project implementation exists in `F:\study\AI_ML\LocalAI\ollama\16vram\A`.
- A GitHub repo exists and has been pushed to.
- `ola` exists in `C:\Users\micha\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`.
- `ola` has been reloaded and tested in Windows PowerShell 5.
- `ola` launches the final local interactive experience immediately ready to work.
- Zero-startup-add-ons compliance is verified by default.
- The final report explicitly closes the serious local search space for today on this machine except waiting for future releases.

## 2026-04-21 Final Closure

### Final Outcome

- Search space closed for `2026-04-21`.
- Final winner: `aider + qwen3.5:latest`.
- Final fallback: `aider + qwen3-coder:latest`.
- Final launcher target: `scripts\Invoke-Ola.ps1`, to be called through `ola` from the real Windows PowerShell 5 profile.

### Final Valid Benchmark Rows

- Winner run: `benchmarks\runs\aider-qwen3.5_latest-20260421-073344`
  - `python-slugify`: `success=true`, `39.30s`
  - `powershell-stem`: `success=true`, `73.18s`
  - `instruction-alerts`: `success=true`, `31.10s`
  - `context-policy`: `success=true`, `26.03s`
- Fallback run: `benchmarks\runs\aider-qwen3-coder_latest-20260421-073828`
  - `python-slugify`: `success=true`, `44.75s`
  - `powershell-stem`: `success=true`, `77.18s`
  - `instruction-alerts`: `success=true`, `24.52s`
  - `context-policy`: `success=true`, `46.21s`

### Final Rejections

- `benchmarks\runs\codex-qwen3.5_latest-20260421-072819`: valid `0/4`
- `benchmarks\runs\codex-qwen3-coder_latest-20260421-072911`: valid `0/4`, unsupported `mcp__playwright__`
- `benchmarks\runs\codex-gpt-oss_20b-20260421-073102`: valid `0/4`, off-task drift into unrelated `pipenv` answer
- raw `ollama run --experimental` and `--experimental-yolo` were confirmed live via CLI help and direct prompt probes, but no fair coding benchmark harness exists in this repo today, so they are not selected over the fully benchmarked Aider path

### NVML Bound, Not Fixed

- `nvidia-smi` still fails with `Failed to initialize NVML: Unknown Error`.
- Ollama inference remains materially unaffected on this machine.
- The launcher decision is therefore allowed to close today with that NVML issue explicitly documented as separate follow-up work.

## 2026-04-21 Native Agent Upgrade

### Runtime Changes

- `scripts\Invoke-OlaNativeAgent.ps1` now emits timestamped phase-stable progress lines instead of raw `[progress]` strings.
- Native routing now chooses between fast, coding, structured, vision, and heavy synthesis roles:
  - fast: `qwen3.5-oll90:latest`
  - coding: `qwen3-coder:latest`
  - structured: `gpt-oss:20b`
  - heavy: `qwen3:30b-a3b`
  - vision: `gemma4:latest`
- Native routing now has a `-RoutingProbeOnly` mode for deterministic route verification without paying full generation cost.
- Native agent now exposes first-class `web_search`, `web_fetch`, and `scrape_web_page` tools through `scripts\ola_web_tools.py`.

### Verification Added

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -PrintResolvedCommand -WorkspacePath .`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -SmokeTest -WorkspacePath .`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -CapabilityProbe -WorkspacePath .`
- direct web helper proofs:
  - `python .\scripts\ola_web_tools.py search '{"query":"Ollama web search","max_results":5}'`
  - `python .\scripts\ola_web_tools.py fetch '{"url":"https://docs.ollama.com/capabilities/tool-calling","max_chars":1200,"max_links":5}'`
  - `python .\scripts\ola_web_tools.py scrape '{"url":"https://docs.ollama.com/capabilities/tool-calling","selector":"h2, h3","max_items":8}'`
- native routing probes:
  - coding prompt routes to `qwen3-coder:latest`
  - web-research prompt routes to `qwen3.5-oll90:latest` with heavy synthesis target `qwen3:30b-a3b`
  - explicit JSON prompt routes to `gpt-oss:20b`

## Strongest Proof Of Completion

1. Repeated Windows PowerShell 5 `ola` launches succeed.
2. `ola` starts the selected default model with the selected runtime settings.
3. Health checks show the intended binary, models path, env, and GPU residency.
4. A benchmark task run through the final path passes.
5. Git history and GitHub remote contain the implementation and documentation.

## Authoritative Paths

- Project root: `F:\study\AI_ML\LocalAI\ollama\16vram\A`
- Git remote: `https://github.com/Michaelunkai/ollama-local-daily-driver.git`
- Current pushed commit at continuation start: `7a49d97` (`Refresh resume checkpoint state`)
- Previous relevant pushed commits:
  - `ec2a4c6` (`Add PS5-safe benchmark and health-check harness`)
  - `81bdfcb` (`Initialize evidence-backed local daily-driver repo`)
- PowerShell profile: `C:\Users\micha\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`
- Current Ollama binary: `F:\backup\LocalAI\ollama\ollama-app\ollama.exe`
- Current Ollama home: `F:\backup\LocalAI\ollama`
- Current Ollama models path: `F:\backup\LocalAI\ollama\models`
- NVIDIA cached installer path: `C:\Program Files\NVIDIA Corporation\Installer2\Display.Driver.{081781D8-87D1-488C-B1C2-CB6B8518F2CF}`
- NVIDIA installer core path: `C:\Program Files\NVIDIA Corporation\Installer2\InstallerCore\SETUP.EXE`

## Non-Negotiables Captured Before Edits

- Inspect before editing.
- Use current official or primary sources for time-sensitive facts.
- Do not assume the winning stack or winning model in advance.
- Do not treat one successful run as proof.
- Do not leave TODOs, placeholders, or unverified assumptions in the final state.
- Do not claim success until `ola` is added to the PowerShell 5 profile, reloaded in Windows PowerShell 5, and tested end to end.
- Preserve unrelated existing profile behavior and preserve git history.
- Commit and push after every meaningful change once the repo exists.

## Continuation State At Resume

- Resume inspection showed `HEAD` and `origin/main` already aligned at `ec2a4c6` (`Add PS5-safe benchmark and health-check harness`).
- The later continuation handoff for this turn advanced that aligned baseline to `7a49d97` (`Refresh resume checkpoint state`).
- The harness scripts and benchmark fixtures listed in the `2026-04-21 Harness Checkpoint` section were already tracked in git at resume time.
- The only unexpected working-tree noise at resume time was an untracked `%SystemDrive%\ProgramData\Microsoft\Windows\Caches\...` tree created under the repo root by a mis-expanded Windows path. It is not part of the project and should be removed before further checkpoint commits.

## 2026-04-21 Continuation Checkpoint

### Current Driver And Health State

- Current direct runtime query from the continuation handoff recorded:
  - `DeviceName: NVIDIA GeForce RTX 5080`
  - `DriverVersion: 32.0.15.9621`
  - `DriverDate: 2026-04-13 03:00:00`
  - `InfName: oem11.inf`
  - `Manufacturer: NVIDIA`
- Re-ran `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OllamaHealthCheck.ps1`.
- Latest clean health-check result still exits `1`, but only because:
  - `nvidia-smi=False`
  - resolved path is `C:\WINDOWS\system32\nvidia-smi.exe`
  - exact failure remains `Failed to initialize NVML: Unknown Error`
- Latest smoke-test rerun still exits `1`, but the captured smoke detail is dominated by spinner/control bytes and is not yet decision-grade evidence for or against inference health.

### Harness Hardening Now Present

- `scripts\Invoke-OllamaHealthCheck.ps1` now:
  - adds `-CommandTimeoutSeconds`
  - repairs missing child-process env vars including `SystemDrive`, `ProgramData`, `TEMP`, `TMP`, `windir`, and `ComSpec`
  - catches process-start failures cleanly
  - kills timed-out child processes and returns `ExitCode = -2`
  - resolves `nvidia-smi.exe` explicitly from PATH and known NVIDIA install locations
- `scripts\Invoke-Benchmarks.ps1` now:
  - repairs the same child-process env surface for benchmark subprocesses
  - catches process-start failures cleanly
  - injects Aider-safe Windows overrides: `PYTHONUTF8`, `PYTHONIOENCODING`, `TERM=dumb`, `NO_COLOR`, `OLLAMA_API_BASE`
  - exits the verifier child PowerShell with `$LASTEXITCODE` so failed tests are now recorded honestly

### Benchmark Validity State

- Pre-fix Codex benchmark rows are invalid for decision use:
  - `benchmarks\runs\codex-gpt-oss_20b-20260421-054010`
  - `benchmarks\runs\codex-qwen3-coder_latest-20260421-054204`
- In those runs, `results.json` reports `verify_exit=0` and `success=true`, but the saved `verify-output.txt` files contain failing tests.
- Root cause: the verifier child PowerShell did not exit with `$LASTEXITCODE`, so failing `python -m unittest` and nested PowerShell verifier commands were reported as green.
- Focused proof that the fix works:
  - command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Benchmarks.ps1 -Provider codex -Model qwen3-coder:latest -Case python-slugify`
  - run dir: `benchmarks\runs\codex-qwen3-coder_latest-20260421-061018`
  - result now records `agent_exit=0`, `verify_exit=1`, `success=false`
  - saved `verify-output.txt` in that run still shows the same two failing slugify tests, and the JSON now matches it
- Current incomplete runs:
  - `benchmarks\runs\codex-qwen3_30b-a3b-20260421-054331`: scaffold-only partial
  - `benchmarks\runs\codex-qwen3_30b-a3b-20260421-060120`: scaffold-only partial
  - `benchmarks\runs\raw-experimental-gpt-oss_20b-20260421-060254`: preflight/scaffold-only
  - no `raw-experimental-yolo-*` run exists yet

### Current Search-Space Status

- Search-space status for `2026-04-21`: not closed.
- Aider is provisionally ruled out on this Windows host by reproducible console and encoding failure evidence, but no fresh repaired-harness rerun has been completed yet.
- Current Codex benchmark rows from before the verifier fix are invalid for decision use.
- Raw `ollama run --experimental`, corrected Codex reruns, NVIDIA/NVML repair or hard bounding, and end-to-end Windows PowerShell 5 `ola` proof all remain open.
- No final winner or fallback is justified yet.

## Phase 1 Truth Snapshot Before Edits

### Project State

- `F:\study\AI_ML\LocalAI\ollama\16vram\A` existed but was effectively empty.
- The directory was not a git repo at the start of this run.

### Machine Facts Verified

- Windows: `Microsoft Windows 11 Pro`
- Version: `10.0.26200`
- RAM: `93.6 GB`
- CPU: `AMD Ryzen 7 9800X3D 8-Core Processor`
- GPUs:
  - `AMD Radeon(TM) Graphics`
  - `NVIDIA GeForce RTX 5080`
- Free space:
  - `C:` about `1755.7 GB`
  - `F:` about `683.1 GB`

### Profile Facts Verified

- The live orchestration shell is PowerShell `7.6.0`.
- The target compatibility requirement remains Windows PowerShell 5.
- The user profile is large and noisy; clean PowerShell 5 subprocesses are required for trustworthy verification of `ollama` and `nvidia-smi`.

### Ollama Facts Verified

- `ollama --version` in a clean PowerShell 5 subprocess returned `0.21.0`.
- `Get-Command ollama` in a clean PowerShell 5 subprocess resolved to `F:\backup\LocalAI\ollama\ollama-app\ollama.exe`.
- `ollama list` returned these installed models:
  - `gemma4:latest`
  - `gpt-oss:20b`
  - `glm-4.7-flash:latest`
  - `qwen3-coder:latest`
  - `gemma3:27b`
  - `qwen3:30b-a3b`
  - `qwen3.5:latest`
  - `qwen3-14b-oll90:latest`
  - `qwen3:14b`
  - `qwen3.5-oll90:latest`
- User environment variables in clean PowerShell 5 confirmed:
  - `OLLAMA_HOME=F:\backup\LocalAI\ollama`
  - `OLLAMA_MODELS=F:\backup\LocalAI\ollama\models`
  - `OLLAMA_RUNNERS_DIR=F:\backup\LocalAI\ollama\runners`
  - `OLLAMA_HOST=127.0.0.1:11434`
  - `OLLAMA_CONTEXT_LENGTH=131072`
  - `OLLAMA_NUM_PARALLEL=1`
  - `OLLAMA_BATCH_SIZE=4096`
  - `OLLAMA_KV_CACHE_TYPE=q4_0`
  - `OLLAMA_GPU_LAYERS=-1`
- Verified disk contents:
  - `F:\backup\LocalAI\ollama\models\blobs`
  - `F:\backup\LocalAI\ollama\models\manifests`
  - `F:\backup\LocalAI\ollama\config.json`

### NVIDIA Facts Verified

- `nvidia-smi` resolves to `C:\WINDOWS\system32\nvidia-smi.exe`.
- Both current shell and clean PowerShell 5 return:
  - `Failed to initialize NVML: Unknown Error`
- The NVIDIA device is present and started:
  - PNP instance: `PCI\VEN_10DE&DEV_2C02&SUBSYS_41961458&REV_A1\AD03D6761A2DB04800`
  - Driver INF: `oem11.inf`
  - Driver version: `32.0.15.9597`
- Driver service state:
  - `nvlddmkm` is `RUNNING`
  - `NVDisplay.ContainerLocalSystem` is `RUNNING`
  - `NvContainerLocalSystem` is `RUNNING`
- Installed package state:
  - `NVIDIA Graphics Driver 595.97`
  - Installed on `2026-04-07`
  - Cache path: `C:\Program Files\NVIDIA Corporation\Installer2\Display.Driver.{081781D8-87D1-488C-B1C2-CB6B8518F2CF}`

### GPU Runtime Evidence

- Clean PowerShell 5 inference test:
  - Command intent: `ollama run qwen3.5:latest "Reply with exactly OK."`
  - Result text included `OK`
  - Elapsed time observed: `22963 ms`
  - Follow-up `ollama ps` showed:
    - `qwen3.5:latest`
    - `PROCESSOR 100% GPU`
    - `CONTEXT 4096`

## Failed Attempts

### Attempt 1

- Approach: restart NVIDIA userland services
- Command class:
  - `Restart-Service NVDisplay.ContainerLocalSystem,NvContainerLocalSystem -Force`
  - then `nvidia-smi`
- Result: services returned to `Running`
- Error: `Failed to initialize NVML: Unknown Error`

### Attempt 2

- Approach: stop Ollama, restart the NVIDIA display device, then retest
- Command class:
  - `Stop-Process -Name ollama -Force`
  - `pnputil /restart-device "PCI\\VEN_10DE&DEV_2C02&SUBSYS_41961458&REV_A1\\AD03D6761A2DB04800"`
  - then `nvidia-smi`
- Result: device restart reported success, `nvlddmkm` stayed `RUNNING`
- Error: `Failed to initialize NVML: Unknown Error`

### Pattern

- CUDA-backed inference through Ollama can still use the GPU.
- NVML specifically remains broken across shell types and after service and device restart.
- The next credible local fix class is driver repair or clean reinstall backed by official NVIDIA guidance.

## Current Blocker

- NVIDIA/NVML health is not yet verified.
- This does not block repo construction, documentation, benchmark design, model comparison, or launcher implementation work.
- It does block final completion under the mission gate until either:
  - a clean local repair restores `nvidia-smi`, or
  - a harder blocker is proven with exact evidence.

## 2026-04-21 Harness Checkpoint

### Repo State Before Checkpoint Commit

- `git status --short --branch` showed:
  - `M .gitignore`
  - `?? benchmarks/`
  - `?? scripts/`
- `main`, `HEAD`, and `origin/main` all pointed to `81bdfcb`.
- The remote was already set to `https://github.com/Michaelunkai/ollama-local-daily-driver.git`.

### Harness Files Added Locally

- `scripts\Invoke-OllamaHealthCheck.ps1`
- `scripts\Invoke-Benchmarks.ps1`
- `benchmarks\cases\python-slugify\*`
- `benchmarks\cases\powershell-stem\*`
- `benchmarks\cases\instruction-alerts\*`
- `benchmarks\cases\context-policy\*`
- `.gitignore` now ignores:
  - `benchmarks/runs/`
  - `.aider*`

### Health Check Evidence

Verified command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OllamaHealthCheck.ps1 -RunSmokeTest
```

Checkpoint summary:

- `ollama binary exists`: `True`
- `models path exists`: `True`
- `ollama PATH target`: `True`
- `ollama version`: `True`
- `ollama list`: `True`
- `nvidia-smi`: `False` with `Failed to initialize NVML: Unknown Error`
- `ollama ps`: `True`
- `smoke test`: `True`

Meaning:

- the harness is correctly validating the intended Ollama binary and models path
- the harness is correctly catching the still-open NVML failure instead of reporting a false green
- the smoke path proves local inference remains healthy even while NVML is broken

### Benchmark Harness Design

- Provider support currently implemented:
  - `codex`
  - `aider`
- Default case set:
  - `python-slugify`
  - `powershell-stem`
  - `instruction-alerts`
  - `context-policy`
- Each run is copied into a fresh worktree under `benchmarks\runs\<provider>-<model>-<timestamp>\...`
- Each run captures:
  - `agent-output.txt`
  - `git-status-after.txt`
  - `verify-output.txt`
  - `results.json`
- Verification commands are fixed by case:
  - Python cases: `python -m unittest -q`
  - PowerShell case: `powershell -NoProfile -File .\test.ps1`

### Benchmark Evidence Captured So Far

Valid negative evidence:

- Failed Aider run from `benchmarks\runs\aider-gpt-oss_20b-20260421-030509\python-slugify\.aider.chat.history.md`:
  - `Can't initialize prompt toolkit: No Windows console found. Are you running cmd.exe?`
  - `UnicodeEncodeError: 'charmap' codec can't encode character '\u25ba' in position 0: character maps to <undefined>`
  - the command line also warned that `OLLAMA_API_BASE` was not set for the `ollama_chat/gpt-oss:20b` model alias
  - the failed attempt left a lingering `python` process with benchmark arguments, which is negative daily-driver evidence on this Windows host

Invalid decision evidence from pre-fix Codex runs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Benchmarks.ps1 -Provider codex -Model qwen3-coder:latest -Case python-slugify
```

- `benchmarks\runs\codex-gpt-oss_20b-20260421-054010\results.json` and `benchmarks\runs\codex-qwen3-coder_latest-20260421-054204\results.json` report green rows that contradict their saved `verify-output.txt` files.
- Those rows were produced before the verifier fix and must not be used for winner selection.

Corrective proof after the verifier fix:

- `case=python-slugify`
- `provider=codex`
- `model=qwen3-coder:latest`
- `agent_exit=0`
- `verify_exit=1`
- `success=false`
- `duration_seconds=1247.01`
- run path: `benchmarks\runs\codex-qwen3-coder_latest-20260421-061018`

Incomplete attempts:

- `benchmarks\runs\codex-qwen3_30b-a3b-20260421-054331`
- `benchmarks\runs\codex-qwen3_30b-a3b-20260421-060120`
- `benchmarks\runs\raw-experimental-gpt-oss_20b-20260421-060254`

### Current-Source Research Verified

Verified on `2026-04-21`:

- Ollama Codex integration:
  - https://docs.ollama.com/integrations/codex
  - Codex with Ollama is supported.
  - Ollama recommends at least `64k` context for Codex.
  - Manual usage is `codex --oss` or `codex --oss -m <model>`.
- Ollama launch announcement:
  - https://ollama.com/blog/launch
  - Dated `2026-01-23`.
  - `ollama launch` supports `Codex`, `OpenCode`, and other coding integrations.
  - Recommended local coding models include `glm-4.7-flash`, `qwen3-coder`, and `gpt-oss:20b`.
- Aider Ollama docs:
  - https://aider.chat/docs/llms/ollama.html
  - Aider recommends `ollama_chat/<model>` over `ollama/<model>`.
  - The example raises `OLLAMA_CONTEXT_LENGTH` to `8192`.
- OpenCode Windows and web docs:
  - https://opencode.ai/docs/windows-wsl/
  - https://opencode.ai/docs/web/
  - OpenCode explicitly recommends WSL on Windows for the best experience.
  - `opencode web` starts a local server and opens a browser automatically.
- Ollama tool-calling docs:
  - https://docs.ollama.com/capabilities/tool-calling
  - Raw Ollama supports single-shot, parallel, and multi-turn tool calling.
  - That keeps raw Ollama experimental mode in scope until real local evidence rules it in or out.

### Interim Interpretation At This Checkpoint

- No benchmark stack is decision-grade yet.
- Aider is already carrying Windows console and encoding risk plus Python package maintenance drag.
- OpenCode remains a likely loser for this machine’s daily-driver goal because its own Windows docs push WSL and its web mode adds server-plus-browser baggage.
- Raw Ollama still requires direct evaluation because the tool-calling primitives exist and the repo has not yet proven whether a thin wrapper around them can beat Codex on this machine.
- Codex remains in scope, but the pre-fix benchmark rows must be rerun under the corrected verifier before it can be scored honestly.

### Remaining Work After This Checkpoint

- continue from the already-pushed continuation checkpoint `7a49d97`
- rerun the benchmark matrix under the corrected verifier before comparing finalists
- verify the next official-backed NVIDIA repair path
- test raw Ollama experimental mode
- retry or decisively disqualify Aider after a UTF-8-aware rerun
- choose the default and fallback models with a weighted matrix
- implement the project runtime and the PS5 `ola` wrapper
- reload PS5 and prove `ola` launches the final winner
- explicitly close the search space for `2026-04-21`
