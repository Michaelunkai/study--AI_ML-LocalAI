# Contracts — form-20261011-1834 (harness prove-out battery)

Goal: prove `Ultimate-AI.cmd` stack end-to-end by driving the interactive harness through
12 complex missions with ZERO outside help, with human-readable real-time progress
(timestamped from start to finish), iterating fixes until every mission is achieved.

## T-101 — harness.py upgrade (single file, surgical)

1. `_ts()` helper → `[HH:MM:SS.mmm]` wall clock + `(+MM:SS)` elapsed since session start.
2. Before EACH model call in run_agent_turn: visible rule + line
   `── STEP <n> • <ts> • elapsed <MM:SS> • thinking + streaming…` (console.rule or prints).
3. TOOL CALL panel title: `TOOL CALL #<k> • <name> • <ts>`; RESULT panel title adds
   execution seconds: `<name> RESULT • <x.x>s • OK|ERROR`.
4. TASK DONE panel gains footer: `started <ts> • finished <ts> • total <MM:SS> • steps <n> • tool calls <k> (<e> errors)`.
5. In the streaming Live preview, top line shows `STEP <n> • <chars> chars streamed • <ts>` above the markdown preview (same transient Live).
6. New CLI: `--mission TEXT` (or `--mission @C:/path/file.txt`): print banner, run ONE
   mission through the SAME run_agent_turn engine, then exit. Exit codes: 0 = task_done
   fired; 3 = MAX ITERATIONS without task_done; 1 = connect/chat error. All real-time
   console output identical to interactive mode.
7. System prompt addition (verification protocol): before calling task_done the agent MUST
   re-verify every artifact it produced (open files, re-run scripts, check outputs match
   the mission requirements) and fix any gap; task_done summary must state what was verified.
8. `python harness.py --self-test` must still print SELF-TEST PASS; py_compile clean.

## T-102 — battery fixtures (written by main session, not the agent)

- `missions/M01..M12.txt` — exact mission prompts (complex, self-contained, artifact-verifiable).
- `missions/verify.py` — independent checker: `python verify.py M01` → prints PASS/FAIL
  evidence lines, exit 0/1. Uses its own logic, never trusts agent output text.
- Sandbox per mission: `ultimate-llm/missions/M<nn>/` (checker may create ONLY this dir when absent).

## T-103 — execution protocol (zero-help rule)

For each mission: fresh run `python harness.py --model gpt-oss:20b --num-ctx 32768 --yes
--mission @missions/M<nn>.txt` (exact engine the master script launches), full console
log captured to `missions/logs/M<nn>.log`. THEN run verify.py. No file creation/repair by
main session inside mission sandboxes — only reading/verifying. On any FAIL: diagnose,
update harness/system-prompt/mission-text clarity, delete that mission sandbox, rerun.
Requirement: 12/12 verified PASS.

## T-104 — script end-to-end + docs

One run of `Ultimate-AI.cmd -SkipPull` with a mission piped via stdin (interactive path),
plus README/ledger updates.
