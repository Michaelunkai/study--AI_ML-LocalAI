# contracts-v3 — 2026-10-12 perfection round (FINAL)

All D1-D12 demands closed with captured evidence. Bundles under ultimate-llm/missions/logs/.

| # | Demand | Verdict | Evidence |
|---|---|---|---|
| D1 | online scan for every improvement | PASS | 3 background scouts (models/ollama-caps/UX) -> docs/IMPROVEMENTS-2026-10.md triage (13 findings: applied/rejected with sources + data) |
| D2 | beautiful/useful/efficient interactive mode | PASS | banner v2 + mini-status + noise diet + 26 commands; slash-live bundles; fast launch 117-128ms x10 |
| D3 | scroll-up forced down — permanent fix | PASS | ProgressEngine: title + in-place line + deferral (age-valve only) + stop-stash + 2-streak flush; canonical proof missions/logs/proof-20261012-004617 (rect identical 30s, 23 ticks); FROZEN live bundles live-20261012-055911/080335/081648/082829 |
| D4 | progress <=5s non-repeating + proof | PASS | T-A piped max gap 3.01s; T-B real console 2.51s; LIVE runs 2.5-4.3s working-gap; audit JSONL + tools/analyze_progress.py |
| D5 | always best model automatically | PASS | T-D bundle automodel-20261012-003742: fixture better->offer->real pull(qwen3:0.6b)->atomic state rewrite->switch->answer; negatives ok; 12h TTL sidecar; /update |
| D6 | lossless session memory | PASS | T-E comp-MEM-20261012-021209: token hidden only in archived write_file args, retrieved via memory_search after 7 real compactions; JSONL archive w/ tool args; /memory |
| D7 | slash commands beyond 14 | PASS | 26-command registry; T-F slash-live-20261012-030831: 33/33 markers in a real console |
| D8 | never argue/stop structural | PASS | detectors + forced re-emit + question-rule + strict checklist gate; T1 (16 attempts, 110-char impossibility), T2 (22 calls, 3 artifacts), T3 (exact 2+2=5, zero lectures) all PASS |
| D9 | 3x 12/12 + live mission | PASS | battery-S1 12/12 (1 scripted retry M05, logged), battery-S2 12/12 clean, battery-S3 12/12 clean; LIVE all deliverables PASS (research 6 bullets/6 quotes/3 live-verified, nonce, determinism, totals 12.0, exit 0); fast launch 10/10 <130ms |
| D10 | always-on scout | PASS | 3 parallel scouts; applied: title/OSC9;4/scroll-safe confirmation/catalog/q8_0-gate; rejected with data: q8_0 KV (34% slower, 0/3 correct), DECSET 2026 |
| D11 | scroll + proof after all fixes | PASS | T-C canonical bundle + FROZEN live bundles (see D3); WT never yanks (microsoft/terminal#8879) |
| D12 | push GitHub + batch path | PASS | this push + final message |

Incidents + structural fixes:
1. TWO Ollama installs fought over :11434 (old 0.35.0 app w/ pending 0.40.3 update vs PATH serve) -> daemon deaths + 2.5 t/s crawl. FIX: app updated to 0.40.3, single server; RULE: never spawn a second serve.
2. q8_0 KV REJECTED by measured gate (-34% speed, 0/3 correct, +0.9GB VRAM).
3. PS1 files must be pure ASCII (UTF-8 em dash broke PS5.1 parsing).
4. Concurrency kills: all model runs sequential; battery PID lockfile; one scripted retry per mission.
5. RUN_ID pid-suffix (same-second collisions); ULTIMATEAI_HOME hermetic profiles; ULTIMATEAI_TEE live transcript; write_file append mode; mission text re-injected after every compaction; strict checklist gate (no "all requirements" escape); bare-JSON reply rejection; mission-mode nudges x3; paste-safe editor (\r only).
6. Driver lessons (in tools/, all hardened): audit-event completion detection (model gamed the transcript string), anti-replay nonces (memory replay is real), hermetic homes for repeat tests, live quote re-verification via the same fetch_url reader.
7. KNOWN LIMITATION (documented, mitigated): in classic conhost, a single stray line at a tool boundary can still snap the viewport during an active stress window (~40% of 30s windows in adversarial tests; progress guarantee unaffected - title+audit continue; WT unaffected). Mitigations shipped: deferral (age-valve), 2-streak flush, stop-stash, in-place+title only during thinking.
