# CONTRACTS v4 — form-20261012-1240 (clarity + unlimited-memory round)

Frozen interfaces for this round. Immutable after freeze.

## C1 — Compaction summary tail (compact_history, harness.py)
After the model summary, the summary message content MUST end with exactly this block:
```
COMPACTED NOTICE: older turns were compressed above. The FULL verbatim transcript of this
session is archived on disk - ANY earlier detail (tokens, codes, file contents, exact
requirements) can be recovered with the memory_search tool. If the user asks for any
detail from before this summary, you MUST call memory_search first and answer from its
result. Answering from this summary when the archive holds the detail is a failure.
```
Summary system instruction additionally requires verbatim preservation of codes/tokens/
passwords, filenames+paths, and numbers.

## C2 — Compaction storm guard (compact_history)
`if not force and (mono - STATE["last_compaction_mono"]) < 45 and est < threshold*1.35: return False`
STATE["last_compaction_mono"] set on every successful compaction (time.monotonic()).

## C3 — Tool-evidence gate
- `parse_required_tools(mission_text) -> list[str]`: lines matching
  `TOOL EVIDENCE REQUIRED:` collect comma-separated tool names. Pure function.
- STATE tracking: `STATE["tool_log"]` = list of tool names (append in both native and
  fallback tool paths, cap 500); `STATE["compaction_at_seq"]` = len(tool_log) snapshot
  taken inside compact_history when it actually compacts.
- `evidence_missing(required, tool_log, compaction_idx) -> list[str]`: a required tool is
  missing unless it appears in tool_log[compaction_idx:] (or anywhere if compaction_idx
  is None). Pure function.
- Gate placement: in BOTH task_done acceptance paths (native + fallback), BEFORE the
  checklist gate. On missing evidence and `evidence_rejects < 3`: append the reject note
  "(tool-evidence gate: the mission requires {tools} to be called ... call it now, quote
  the archived record, then task_done again)" and continue the loop. After 3 rejects:
  task_done result becomes `ERROR: task_done rejected - ...` (never accepted).

## C4 — FACTUAL INTEGRITY system block (build_system_prompt)
Verbatim block appended to the system prompt:
```
FACTUAL INTEGRITY (critical): never invent or guess product names, project names, links,
URLs, quotes, versions, or statistics. If the question involves current facts, a
recommendation ("best", "top", "which"), or any online resource, use web_search and
fetch_url FIRST and answer ONLY from tool results. Cite only URLs that appeared in your
tool results. If a lookup fails, say exactly what you could not verify.
```

## C5 — Superlative research nudge (run_agent_turn)
Trigger: regex `\b(best|top|ultimate|which|recommend|compare)\b` (case-insensitive) on the
user input AND no web_search/fetch_url in STATE["tool_log"] this session AND not already
nudged (`STATE["research_nudged"]`). Action: append one system-note message
"(policy note: ground the answer in web_search/fetch_url results ...)" right after the
user message. Once per session.

## C6 — MEM.txt additions
End of file gains the line: `TOOL EVIDENCE REQUIRED: memory_search`
Step 4 gains byte-exact verification wording (read_file back, content === token).

## C7 — tools/qa_live.py acceptance (anti-hallucination proof)
Real-console child, prewarmed model. Prompt: user's exact scenario ("Look online and tell
me: what is the best agent harness for a local LLM in 2026? ..."). PASS requires ALL of:
(a) >= 2 web_search/fetch_url tool-call panels in the transcript before the final answer;
(b) every http(s) URL in the final answer block appears earlier in the transcript
(tool-result ground); (c) final answer >= 200 chars; (d) progress-audit max gap < 5s
during the turn; (e) clean /exit, child exit 0.

## C8 — Context probe decision rule (tools/ctx_probe.py)
3 chats at num_ctx 32768 (baseline t/s), then 3 at 65536. Adopt 65536 as the launcher
default ONLY if: no HTTP/OOM error, t/s >= 50% of baseline median on all 3, and /api/ps
VRAM size does not exceed 15.5GB during inference. Otherwise keep 32768 and record the
KV math (fp16 KV ~48KB/token: 64k = ~3.0GB vs ~2.5-3GB headroom after 12.3GB weights).

## C9 — Regression trio (unchanged, after every harness edit batch)
1. `.venv\Scripts\python.exe harness\harness.py --self-test` exit 0
2. `{ echo /exit } | cmd /c Ultimate-AI.cmd` < 1000 ms ×3
3. piped smoke `printf '/help\n/stats\n/exit\n' | .venv\Scripts\python.exe harness\harness.py --model gpt-oss:20b --num-ctx 32768` exit 0
