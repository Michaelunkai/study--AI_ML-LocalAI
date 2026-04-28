# Ola Current Status

## Snapshot

- Updated: `2026-04-21 16:05:50`
- Project root: `F:\study\AI_ML\LocalAI\ollama\16vram\A`
- Status: `in-progress`

## Mission

Keep the ola project anchored to the real Windows PowerShell 5 launcher/runtime state and make future sessions resume from verified facts instead of rediscovery.

## Latest Completed Work

- `scripts\Invoke-OlaNativeAgent.ps1` now renders a compact dashboard header, periodic status lines, and fuller answer blocks instead of the old raw-only phase log feel.
- The native agent now samples machine CPU/RAM/GPU and local-Ollama CPU/RAM/GPU state, plus active-model hints from `ollama ps`, and exposes that in the live UI and console title.
- The native runtime now supports `-DirectiveMode`, `/directive on`, `/directive off`, `/status`, and `/summary`.
- Long sessions now compact older turns back into the system prompt via an in-band summary pass once the configured character threshold is exceeded.
- `find_cleanup_candidates` now performs a broader heuristic cleanup scan across AppData, ProgramData, and Windows, not only the original small seeded folder list.
- `scripts\Invoke-Ola.ps1` now passes `-DirectiveMode` through to the native runtime and exposes that in `-PrintResolvedCommand`.
- A live directive-mode mission was run against the C-drive cleanup ask from the screenshot, and the upgraded agent returned a real candidate list from the machine instead of stalling at planning.
- Blocking model calls and blocking tool calls now emit heartbeat `WAIT` lines every 8 seconds, so the terminal no longer goes silent during long work.
- `read_file` now uses a shared-read bounded file loader, which removed the screenshot-style risk surface where a simple file read could appear to freeze the turn.
- Final answer blocks are now printed without the old hard line cap, so long structured outputs remain visible in-terminal.
- The first heartbeat implementation used `Add-Type` and failed in the user's real PS5 `ola` session when the inherited environment block exceeded Windows limits; that compile dependency has now been removed.
- Heartbeats now run through an in-process PowerShell background runspace instead of `Add-Type`, so `ola` can start even in the bloated real profile environment.

## Verification

- Parsed `scripts\Invoke-OlaNativeAgent.ps1` and `scripts\Invoke-Ola.ps1` successfully through the PowerShell parser after the UI/telemetry/session-state changes.
- Verified launcher resolution with `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -PrintResolvedCommand -DirectiveMode -WorkspacePath .`.
- Verified the native smoke path with `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -SmokeTest -DirectiveMode -WorkspacePath .`.
- Verified the native tool surface with `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -CapabilityProbe -DirectiveMode -WorkspacePath .`.
- Verified the upgraded one-shot runtime directly with `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OlaNativeAgent.ps1 -WorkspacePath . -DirectiveMode -InitialPrompt 'Reply with exactly OK.' -SinglePrompt`.
- Verified the directive-mode cleanup mission by running `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -DirectiveMode -WorkspacePath . -Prompt "scan all over c drive and output every single folder I should add to the cleanup function so it can safely free up space from C drive. inspect the real machine, use cleanup candidates only, and return a flat bullet list of absolute Windows paths with one short reason and size in MB."`
- Verified the no-silence fix by running a longer directive-mode mission that compared against `F:\study\Shells\powershell\scripts\misc\ccsizes\ccsizes-cleanup-patterns-v2.ps1`; the run showed repeated `MODEL WAIT` and `TOOL WAIT` heartbeat lines throughout the long blocking phases.
- Verified untruncated final-answer rendering by running `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-Ola.ps1 -DirectiveMode -WorkspacePath . -Prompt "Reply with exactly 25 lines, each line just 'line N' from 1 to 25."`
- Verified the real profile-wired launcher path from `F:\Downloads` with `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -Command "Set-Location 'F:\Downloads'; ola -SmokeTest -WorkspacePath 'F:\study\AI_ML\LocalAI\ollama\16vram\A'"`.
- Verified the real profile-wired one-shot path from `F:\Downloads` with `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -Command "Set-Location 'F:\Downloads'; ola -WorkspacePath 'F:\study\AI_ML\LocalAI\ollama\16vram\A' -Prompt 'Reply with exactly OK.'"`.

## Current Worktree Note

```text
## main...origin/main
 M README.md
 M docs/evidence-ledger.md
 M docs/ola-integration-design.md
 M scripts/Invoke-Ola.ps1
?? note.txt
?? references/
?? scripts/Invoke-OlaNativeAgent.ps1
?? scripts/ola_web_tools.py
```

## Next Session Start

1. Start in `F:\study\AI_ML\LocalAI\ollama\16vram\A` and read `references/project-reference.md`, then `references/current-status.md`, then `docs/ola-integration-design.md`.
2. Treat `scripts\Invoke-Ola.ps1` and `scripts\Invoke-OlaNativeAgent.ps1` as the runtime source of truth; the native agent now includes directive mode, telemetry, and session compaction.
3. Reconcile the doc contradiction: decide whether `docs/evidence-ledger.md` should be downgraded from a final closure to historical benchmark evidence, or whether the launcher/docs should be changed back toward the benchmark-winning `aider` path.
4. Clean up the worktree intentionally before any new checkpoint commit, especially `note.txt` and the untracked `references\` / native-runtime files if they are meant to be committed.
5. Re-run the bounded launcher proofs from the repo root whenever the runtime changes again: `Invoke-Ola.ps1 -PrintResolvedCommand`, `Invoke-Ola.ps1 -SmokeTest`, and `Invoke-Ola.ps1 -CapabilityProbe`.
6. The remaining obvious UX upgrade is a truly in-place refreshing footer during blocking waits; the current build already satisfies the no-silence requirement with recurring heartbeat lines, but it still appends lines rather than redrawing a single live footer row.
