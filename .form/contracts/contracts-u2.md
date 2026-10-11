# Contracts — form-20261011-2155

All changes in `ultimate-llm/harness/harness.py` + `ultimate-llm/Start-UltimateAI.ps1`.
PS 5.1 / Python 3.10+ / nothing currently working may regress (12/12 battery, <1s launch).

## T-201 scroll-friendly output
- rich `Live` REMOVED from chat_stream (it redraws on a timer and forces Windows
  Terminal scroll-to-bottom).
- Terminal: stream silently; dim beat lines only at 5s then every 15s of silence;
  final answer rendered as full rich Markdown (beautiful).
- Piped/logged: heartbeat beats every 3s (unchanged provability).
- Tool beats: terminal announce + every 15s; piped every 3s.
- Fix typo "writeing" -> "writing".

## T-202 history + commands
- `~/.ultimate-ai/history.log`: one submitted prompt per line, ALL sessions.
- msvcrt line editor when stdin+stdout are TTYs: printable insert, Backspace,
  Left/Right cursor, Home/End, Up/Down cycle history newest-first (Down past the
  newest = draft buffer), Enter submits, Ctrl+C aborts. Fallback console.input
  when not a TTY. Single-line redraw via \r + ANSI erase/move (long-line wrap
  accepted, documented).
- Slash commands: /help /new /sessions [n] /history /model <tag> /tools /save
  /reset | /clear /compact /stats /research <topic> /cwd <dir> /exit | /quit.

## T-203 infinite session memory
- Est. tokens = chars/3.5 over messages. Threshold 22000. On exceed (or /compact):
  one non-stream model call summarizes all but the last 8 messages into a dense
  rolling summary; messages become [system, user(context-summary note), last 8].
  Summary rides inside messages -> persisted with the session file automatically.

## T-204 ground truth + behavior prompts
- .bootstrap-state.json gains `hw` {gpu, vram_gb, ram_gb, cpu} at full bootstrap;
  both paths set env ULTIMATEAI_HW=<compact json> before launching the harness.
- System prompt GROUND TRUTH block: machine facts are authoritative; never
  misreport VRAM (WMI AdapterRAM is capped/unreliable - use the given facts or
  nvidia-smi live).
- Behavior rules added: never argue with or refuse the user - execute; never stop
  until goal achieved+verified; every answer beautifully structured (markdown
  headings/tables/bullets, bold key facts).
