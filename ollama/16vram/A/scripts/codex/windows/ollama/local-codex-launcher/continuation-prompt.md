Until-done mode is active. I will continue until the requested outcome is achieved and verified or a real blocker requires your input.

You are resuming an unresolved Windows local Codex + Ollama repair mission. This is not a fresh task. Continue exactly from the state below. Do not restart broad discovery. Do not stop at explanation, setup, partial progress, or launcher-only success.

Primary objective:
Make local interactive Codex running through Ollama on this exact machine actually behave agentically and correctly, with the best achievable balance of speed, reliability, and tool-use quality. The launcher relocation is already done. The remaining problem is model behavior and runtime/tool behavior under Codex.

You are required to work until one of these is true:
1. You materially improve the actual local interactive behavior and verify it live.
2. You prove with command-backed evidence that no available local Ollama model can currently deliver acceptable Codex agentic behavior on this machine under the corrected runtime path.
3. A real blocker exists that cannot be bypassed safely.

Do not declare success for any weaker outcome.

Hard boundaries:
- Do not treat this as prompt-only work.
- Do not stop at "launcher works."
- Do not stop at "the model reasoned about the right command."
- Do not stop at benchmark summaries alone.
- Do not stop after one failed attempt.
- Do not ask broad open-ended questions.
- Do not redo solved wrapper or relocation work unless a verification check proves it regressed.
- Do not recommend cloud fallback unless you first prove the local path cannot be materially improved.
- Do not produce TODOs, placeholders, or soft handoffs.

Environment:
- Workspace: F:\Downloads
- Main project root relevant to this mission: F:\study\AI_ML\LocalAI\ollama\16vram\A
- Active launcher project folder:
  F:\study\AI_ML\LocalAI\ollama\16vram\A\scripts\codex\windows\ollama\local-codex-launcher
- Shell: PowerShell on Windows
- Codex home: C:\Users\micha\.codex
- Ollama is available locally

Already fixed and already verified:
1. The launcher project was moved into:
   F:\study\AI_ML\LocalAI\ollama\16vram\A\scripts\codex\windows\ollama\local-codex-launcher

2. The active launcher script is:
   F:\study\AI_ML\LocalAI\ollama\16vram\A\scripts\codex\windows\ollama\local-codex-launcher\start-codex-ollama.ps1

3. The old loose path no longer exists:
   F:\Downloads\start-codex-ollama.ps1

4. The launcher uses the real vendor Codex binary directly, not the broken PowerShell wrapper or WinGet shim:
   C:\Users\micha\AppData\Local\npm-global\node_modules\@openai\codex\node_modules\@openai\codex-win32-x64\vendor\x86_64-pc-windows-msvc\codex\codex.exe

5. The launcher uses profile:
   ollama-launch

6. The launcher now resolves its local instruction file from its own project folder:
   F:\study\AI_ML\LocalAI\ollama\16vram\A\scripts\codex\windows\ollama\local-codex-launcher\local-ollama-instructions.md

7. The active local model catalog file is:
   F:\study\AI_ML\LocalAI\ollama\16vram\A\scripts\codex\windows\ollama\local-codex-launcher\local-model-catalog.json

8. C:\Users\micha\.codex\config.toml already points model_catalog_json at that relocated catalog path.

9. Codex model registration was already re-verified:
   codex debug models contains "slug":"gpt-oss:20b"

10. The launcher defaults are currently:
   - model: gpt-oss:20b
   - reasoning effort: medium
   - context window: 32768
   - default disables: plugins and memories
   - optional re-enable flags:
     -WithPlugins
     -WithMemories

11. The relocated launcher already passed these live checks:
   - PowerShell parse check succeeded
   - a one-shot run from the new path returned OK
   - an interactive smoke launch showed codex.exe using:
     -c model_instructions_file="F:\study\AI_ML\LocalAI\ollama\16vram\A\scripts\codex\windows\ollama\local-codex-launcher\local-ollama-instructions.md"

Known hardware and runtime facts:
- CPU: AMD Ryzen 7 9800X3D
- RAM: about 93.6 GB
- Ollama previously showed gpt-oss:20b loaded on GPU with context 131072
- Prior ollama ps example:
  NAME           ID              SIZE     PROCESSOR    CONTEXT    UNTIL
  gpt-oss:20b    17052f91a42e    15 GB    100% GPU     131072     Forever

What improved before this session:
- The launcher path is now durable and project-local.
- The local model is registered in Codex's catalog.
- Prompt payload was reduced by disabling plugins and memories by default.
- Prior Codex debug prompt-input evidence showed approximate prompt size reduction:
  defaultChars: 57771
  leanChars: 27061
- A one-shot noninteractive closed-stdin check already succeeded for gpt-oss:20b through the corrected runtime path.

What is still broken:
- Interactive/local agent behavior remains unreliable.
- Real example of bad behavior:
  User asked:
  "List all the folders I have in my e Drive"
  Model produced the wrong command:
  Get-ChildItem | Where-Object { $_.PSIsContainer } | Select-Object -Expand Name
  with workdir F:\Downloads
  That was wrong because it ignored E:\ and used the current directory.
- After adding the local instruction layer, gpt-oss:20b improved in reasoning and explicitly thought about:
  Get-ChildItem -Path 'E:\' -Directory
  But it still did not reliably finish the execution path and instead drifted in Codex output.
- Therefore the remaining problem is not startup. The remaining problem is local model quality and/or Codex runtime/tool behavior and/or stdin/session behavior under Codex.

Critical benchmark evidence already known:
Benchmark runs live under:
F:\study\AI_ML\LocalAI\ollama\16vram\A\benchmarks\runs

The history is mixed. Do not assume all local Codex runs always fail.

Previously observed aggregate results:
- aider-qwen3.5_latest-20260421-073344: provider aider, model qwen3.5:latest, cases 4, passed 4, avg_seconds 42.4
- aider-qwen3-coder_latest-20260421-073802: provider aider, model qwen3-coder:latest, cases 4, passed 4, avg_seconds 48.17
- codex-qwen3-coder_latest-20260421-054204: provider codex, model qwen3-coder:latest, cases 4, passed 4, avg_seconds 20.96
- codex-gpt-oss_20b-20260421-054010: provider codex, model gpt-oss:20b, cases 4, passed 4, avg_seconds 24.87
- codex-gpt-oss_20b-20260421-030442: provider codex, model gpt-oss:20b, cases 1, passed 1, avg_seconds 18.91
- codex-gpt-oss_20b-20260421-073102: provider codex, model gpt-oss:20b, cases 4, passed 0, avg_seconds 19.76
- codex-qwen3-coder_latest-20260421-072911: provider codex, model qwen3-coder:latest, cases 4, passed 0, avg_seconds 21.74
- codex-qwen3.5_latest-20260421-072819: provider codex, model qwen3.5:latest, cases 4, passed 0, avg_seconds 5.7
- codex-qwen3_30b-a3b-20260421-070419: provider codex, model qwen3:30b-a3b, cases 4, passed 0, avg_seconds 97.21

Interpretation you must test, not merely repeat:
- This machine has shown better Codex+local-model behavior than the latest failures.
- Something may have regressed between earlier passing Codex runs and later failing Codex runs.
- Some earlier passing rows may be contaminated by an older verifier issue, so do not trust only headline pass counts.
- Some failures may be model-side, some may be Codex runtime-side, and some may be stdin/session artifacts.

Files you must inspect first:
1. F:\study\AI_ML\LocalAI\ollama\16vram\A\scripts\codex\windows\ollama\local-codex-launcher\start-codex-ollama.ps1
2. F:\study\AI_ML\LocalAI\ollama\16vram\A\scripts\codex\windows\ollama\local-codex-launcher\local-ollama-instructions.md
3. F:\study\AI_ML\LocalAI\ollama\16vram\A\scripts\codex\windows\ollama\local-codex-launcher\local-model-catalog.json
4. C:\Users\micha\.codex\config.toml

Benchmark artifacts worth comparing first:
1. F:\study\AI_ML\LocalAI\ollama\16vram\A\benchmarks\runs\codex-gpt-oss_20b-20260421-054010
2. F:\study\AI_ML\LocalAI\ollama\16vram\A\benchmarks\runs\codex-gpt-oss_20b-20260421-073102
3. F:\study\AI_ML\LocalAI\ollama\16vram\A\benchmarks\runs\codex-qwen3-coder_latest-20260421-054204
4. F:\study\AI_ML\LocalAI\ollama\16vram\A\benchmarks\runs\codex-qwen3-coder_latest-20260421-072911

Observations already gathered from prior inspection:
- Some earlier "passing" runs still contain weird off-task or drift text in agent-output artifacts.
- Some later failing runs show the model understood part of the task but failed invocation or completion.
- Closed-stdin execution helped at least one one-shot path and should be reused.
- Some prior exec hangs were at least partly stdin-related, not just model latency.

High-priority hypotheses to test:
1. There is a regression in the effective Codex runtime prompt or tool environment between earlier successful local Codex runs and later failing ones.
2. The local model may perform better when the prompt environment is lean and the instruction layer is explicit.
3. Some failures are caused by Codex exec/stdin/session behavior rather than the model alone.
4. qwen3-coder:latest may still be competitive under Codex and should not be dismissed until retested using the same corrected closed-stdin path and same lean settings.
5. Interactive behavior may differ materially from noninteractive exec behavior, so both surfaces must be tested.

Concrete commands and patterns already known to matter:
- Catalog registration check:
  codex debug models
- Prompt size inspection:
  codex debug prompt-input
- Closed-stdin noninteractive pattern:
  cmd /c '<nul "C:\Users\micha\AppData\Local\npm-global\node_modules\@openai\codex\node_modules\@openai\codex-win32-x64\vendor\x86_64-pc-windows-msvc\codex\codex.exe" exec ...'
- Active launcher path:
  powershell -NoProfile -ExecutionPolicy Bypass -File "F:\study\AI_ML\LocalAI\ollama\16vram\A\scripts\codex\windows\ollama\local-codex-launcher\start-codex-ollama.ps1"
- Ollama state:
  ollama ps
  ollama show gpt-oss:20b
  ollama show qwen3-coder:latest

Required execution plan:
1. Inspect the four core files listed above before editing anything.
2. Verify the launcher still passes the exact current lean flags and the project-local instruction file.
3. Verify Codex still recognizes gpt-oss:20b through the relocated catalog path.
4. Reuse the closed-stdin exec pattern for controlled probes.
5. Run controlled A/B comparisons for at least:
   - gpt-oss:20b
   - qwen3-coder:latest
   - qwen3.5:latest if useful
6. Use identical prompts and identical flags when comparing.
7. Test at least:
   - one trivial one-shot prompt
   - one simple Windows path/tool-use prompt
8. If one-shot passes but interactive fails, compare interactive and noninteractive behavior directly.
9. Inspect whether model_instructions_file is actually visible or effective in the model-visible prompt and whether that layer can be improved without bloating the context too much.
10. If you make a durable change, verify it live immediately.

What not to waste time on:
- Do not re-fix the broken PowerShell codex wrapper unless current evidence proves the launcher stopped using the vendor binary.
- Do not argue about clipboard handling.
- Do not stop at "launcher works."
- Do not give generic advice not grounded in this exact machine and these exact files.
- Do not jump to cloud as the answer unless you first prove the local path cannot be materially improved.
- Do not make unrelated broad config changes without evidence.

Acceptance criteria:
- You must determine whether the remaining problem is primarily:
  - model quality
  - Codex runtime/tool environment
  - stdin/session behavior
  - prompt/instruction payload
  - or a combination
- You must improve the actual local behavior if possible, not just describe it.
- Any change to launcher, config, or instruction files must be live-verified.
- If you change defaults, justify them with observed evidence from this machine.
- If a different local model is better than gpt-oss:20b under the corrected runtime path, switch the default and verify.
- If no local model can deliver acceptable agentic behavior under Codex after strong targeted attempts, prove that with command-backed evidence and state the exact blocker honestly.

Reporting requirements:
- Keep commentary short while working.
- Distinguish clearly between:
  - what was already fixed
  - what you changed this session
  - what is still broken
- If you finish successfully, include the exact final working launcher behavior and the best-supported default model choice.
- If blocked, name the blocker concretely and say exactly what remains impossible or unproven.

Finish-line rule:
The mission is not complete unless you either:
1. produce a genuinely better verified local interactive Codex setup on this machine, or
2. produce hard evidence that the remaining failure is a real local-model/runtime blocker that you could not safely bypass.

Do not end on partial progress. Do not end on a plan. Do not end on a plausible explanation. End only with verified completion or a concrete blocker.

Required final contract:
If complete, the final response must end with exactly:
until-done: complete
until-done: proof - <specific observed evidence>
until-done: verification - <tests, commands, inspections, or reviews that passed>

If blocked, the final response must end with exactly:
until-done: blocked - <specific blocker>
until-done: next - <specific missing input, approval, access, or dependency>
