# CONTRACTS v5 — form-20261012-1240 (resource-yield + evidence-gate amendments)

Amends CONTRACTS v4 (form-20261012-1240). Freezes the resource-yield and evidence-gate
interfaces AS ACTUALLY SHIPPED on 2026-10-12. Where an amendment contradicts v4 or the
v4-era research freeze, THE AMENDMENT WINS.

## A1 — VRAM source: NVML (nvml.dll), NOT DXGI (supersedes v4-era research freeze)
The v4-era round docs (notes-research-20261012.md) named DXGI
IDXGIAdapter3::QueryVideoMemoryInfo as the adapter-pressure source. Shipped sentinel uses
NVML (nvml.dll) instead. DXGI is a documented dead end on this stack and is banned from the
sentinel path:
- DXGI COM QueryInterface -> E_NOINTERFACE
- D3DKMT -> C0000008
- PDH wildcard counter -> C0000BBB
All three dead ends recorded 2026-10-12. nvidia-smi also banned (observed hang >126s).
Poll cadence: NVML 3 s poll (mission.json C-406 interface_spec).

## A2 — sample() "loading" flag + never-yield guard (amends yield sentinel sampling)
sample() derives a "loading" flag from /api/ps partial residency: a model is loading while
its reported size is < 50% of its full size. The sentinel NEVER yields while the loading
flag is set, and never yields mid-turn (while a model turn is in flight).

## A3 — Tool-evidence gate: FIRST-compaction semantics (amends v4 C3)
v4 C3 recorded a single `compaction_at_seq` snapshot (last compaction). Shipped semantics:
STATE["compaction_marks"] is a LIST of tool_log indexes, one appended per actual
compaction, and `first_compaction_seq()` returns the earliest mark. The evidence window for
a required tool is tool_log[first_compaction_seq:] (anywhere in tool_log if no compaction
has occurred). Rationale: the mission requirement is "after a compaction occurred" — tool
evidence from before the FIRST compaction does not satisfy it. Consequence recorded:
the earlier MEM 3/3 PASS sequence, certified under last-compaction semantics, is
invalidated; a rerun under first-compaction semantics is in flight.

## A4 — Interactive clean Q&A fast-accept (amends task_done acceptance path)
An interactive answer that is clean Q&A — no tools used, >= 40 chars, does not end with
a trailing '?', and is not a mission turn — accepts task_done IMMEDIATELY, and the
no-task_done nudge is skipped for that turn. (Fixes every clean answer being doubled by a
nudge + second task_done round.)

## A5 — ollama BelowNormal CPU priority
The daemon runs at BelowNormal CPU priority, set in BOTH ultimate-llm/Start-UltimateAI.ps1
AND ultimate-llm/lib/ensure-prereqs.ps1, so the priority holds no matter which path starts
ollama. Verified by T-Y4.

## A6 — /yield surface (new in this round)
- Interactive command: /yield.
- 5 config keys: resource_yield, yield_poll_s, yield_other_gb, yield_headroom_gb,
  yield_rewarm_s.
- doctor gains an 11th check: "sentinel".
- Yield mechanics per C-406 spec + A1/A2: keep_alive 0 (+ empty prompt) deterministic
  unload, rewarm after yield_rewarm_s, partial-residency guard (A2), BelowNormal daemon
  priority (A5). Acceptance hooks: harness self-test block 28, tools/yield_proof.py PASS,
  T-Y4 priority BelowNormal.

## Unchanged
v4 C1, C2, C4, C5, C6, C7, C8, C9 remain in force except where amended above (C3 amended
by A3).
