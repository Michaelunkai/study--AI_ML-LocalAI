# Research freeze — form-20261012-1240 (yield + clarity round)

## Verified answer: "best agent harness for local LLMs" (all URLs fetched/verified 2026-10-12)
The four pasted reference titles are AI-generated paraphrases; no exact-title pages resolve.
Real equivalents + the actual 2026 field:

- OpenCode — terminal coding agent, MIT, ~212.8k stars, first-class Ollama provider config. https://opencode.ai/docs/providers/ + https://github.com/sst/opencode (stars via GitHub API)
- Codex CLI — Apache-2.0, ~128.8k stars. https://github.com/openai/codex
- Goose — ~55.2k stars. https://github.com/aaif-goose/goose (block/goose renamed)
- OpenHands — ~90.7k stars, heavier autonomous work. https://github.com/OpenHands/OpenHands (All-Hands-AI/OpenHands renamed)
- Cline — ~70.2k stars, IDE/CLI. https://github.com/cline/cline
- Aider — respected (~49.5k, https://github.com/Aider-AI/aider) but repo idle since May 2026.
- Building blocks: smolagents https://github.com/huggingface/smolagents (~29.8k), Letta https://github.com/letta-ai/letta (~25.1k), PydanticAI https://github.com/pydantic/pydantic-ai (~20.6k)
- Best 2026 tutorial for exactly this setup (Ollama + harness): Sebastian Raschka, "Using Local Coding Agents" — https://magazine.sebastianraschka.com/p/using-local-coding-agents
- Reference-title mappings: (1) "Agent Harness for Local LLMs (2026 Guide)" → Raschka article above. (2) "Best Open-Source Agent Harnesses 2026" → unverifiable as titled; real equivalents: https://en.wikipedia.org/wiki/Agent_harness + https://github.com/bradAGI/awesome-cli-coding-agents (1,342★). (3) "Context Harness Documentation" → unverifiable as titled; closest real: https://github.com/zilliztech/mfs (154★), https://github.com/parallax-labs/context-harness (42★). (4) "Awesome Harness Engineering GitHub" → https://github.com/ai-boost/awesome-harness-engineering (4,794★, pushed 2026-10-12) + sibling https://github.com/walkinglabs/learn-harness-engineering (19,736★).
- Lesson encoded into the harness: an in-harness model invented "Context Harness — a Rust-based framework" from those titles. FACTUAL INTEGRITY rule + research nudge + qa_live.py exist to make that impossible to pass silently.

## Yield-mechanism facts (verified)
- keep_alive: 0 (+ empty prompt) unloads the model immediately; /api/ps size_vram==0 proves it; expires_at reflects keep_alive. https://docs.ollama.com/faq (fetched)
- Ollama counts only VRAM free of other programs when placing layers; insufficient VRAM → automatic CPU/GPU layer split (same weights = same smartness, lower speed); num_gpu option overrides. Improved scheduler Sep 2025 cut OOMs. https://github.com/ollama/ollama/issues/10232 context
- OLLAMA_KV_CACHE_TYPE=q8_0 (~1/2 KV mem, negligible ppl loss 8.3891→8.3934) documented + stable since Dec 2024, requires flash attention (auto on RTX 5080); daemon-GLOBAL env — documented as opt-in only, never set silently. https://docs.ollama.com/faq + https://smclead.net/2024/12 K/V quantisation writeup
- Ollama releases 0.34.1→0.40.3 (Sep 14–Oct 11 2026): zero KV/CUDA VRAM changes; v0.40.2 auto model upgrades (0.40.3 paused churn); default ctx still 4096 → always pass num_ctx.
- Adapter VRAM pressure WITHOUT nvidia-smi: DXGI IDXGIAdapter3::QueryVideoMemoryInfo → DXGI_QUERY_VIDEO_MEMORY_INFO {Budget, CurrentUsage} on segment 0 (local/dedicated), ctypes COM vtable call. https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_4/nf-dxgi1_4-idxgiadapter3-queryvideomemoryinfo ; per-process GPU counters: https://stackoverflow.com/questions/51702335/
- Fallback counter: '\GPU Adapter Memory(*)\Dedicated Usage' via Get-Counter.
- nvidia-smi on this box can hang >126s (observed today) — never on the sentinel's path.

## Today's probe data (missions/logs/ctx-probe-20261012-124513)
- num_ctx 32768: 8.4 tok/s steady, /api/ps 12.77GB. 65536 idle small-prompt: 9.0–25.4 tok/s, 12.8GB (KV not yet populated).
- 60k-token prompt @65536: runner disconnected (allocation crash) → 65536 REJECTED. KEEP 32768. q8_0 64k documented as opt-in (daemon-global, needs restart discipline).
