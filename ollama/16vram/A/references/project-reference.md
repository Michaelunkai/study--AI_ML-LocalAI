# ola Project Reference

## Canonical Root

- Project root: `F:\study\AI_ML\LocalAI\ollama\16vram\A`
- Primary launcher: `scripts\Invoke-Ola.ps1`
- Primary native runtime: `scripts\Invoke-OlaNativeAgent.ps1`
- Native web helper: `scripts\ola_web_tools.py`

## Top-Level Hierarchy

- `.git`
- `artifacts`
- `benchmarks`
- `docs`
- `references`
- `scripts`
- `README.md`
- `.gitignore`

## Current Runtime Contract

- `ola` remains the launcher name.
- Default interactive path for `-Profile agentic` is the native agent, not `aider`.
- Native model catalog:
  - fast: `qwen3.5-oll90:latest`
  - coding: `qwen3-coder:latest`
  - structured: `gpt-oss:20b`
  - heavy: `qwen3:30b-a3b`
  - vision: `gemma4:latest`
- Native tool surface includes filesystem/system tools plus:
  - `web_search`
  - `web_fetch`
  - `scrape_web_page`
- Native progress output is a compact TUI-style dashboard with timestamped phase lines.
- Native long-running model and tool phases now emit heartbeat `WAIT` lines every few seconds, so the terminal does not sit silent during blocking work.
- Native status output now includes machine-wide CPU/RAM/GPU plus local-Ollama CPU/RAM/GPU snapshots and active-model hints.
- Native directive mode is available through `-DirectiveMode` and strengthens the system prompt for mission ownership and verification.
- Native session compaction now summarizes older turns back into the system prompt once the conversation grows past the configured threshold.
- Native cleanup discovery now supports a broader heuristic scan for temp/cache/log folders under AppData, ProgramData, and Windows.
- Native `read_file` now uses a bounded shared-read path instead of a raw `Get-Content -Raw` call.
- Native routing can be verified with `-RoutingProbeOnly`.

## Verification Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -PrintResolvedCommand -WorkspacePath .
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -SmokeTest -WorkspacePath .
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -CapabilityProbe -WorkspacePath .
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -DirectiveMode -WorkspacePath . -Prompt 'Reply with exactly OK.'
python .\scripts\ola_web_tools.py search '{"query":"Ollama web search","max_results":5}'
python .\scripts\ola_web_tools.py fetch '{"url":"https://docs.ollama.com/capabilities/tool-calling","max_chars":1200,"max_links":5}'
python .\scripts\ola_web_tools.py scrape '{"url":"https://docs.ollama.com/capabilities/tool-calling","selector":"h2, h3","max_items":8}'
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OlaNativeAgent.ps1 -WorkspacePath . -RoutingProbeOnly -InitialPrompt 'Inspect scripts/Invoke-OlaNativeAgent.ps1 and reply with only the function name that writes progress lines.' -SinglePrompt
```

## Supporting Docs

- `README.md`
- `docs/evidence-ledger.md`
- `docs/ola-integration-design.md`
- `references/current-status.md`
