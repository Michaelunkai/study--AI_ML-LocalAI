Fix this repository so its verification command passes.

Rules:
- Inspect the files before editing.
- Keep Windows PowerShell 5 compatibility.
- Change only `PathStem.ps1` unless the task is impossible otherwise.
- Preserve the test file exactly as-is.
- Run the verification command yourself before you finish.

Verification:
- `powershell -NoProfile -File .\test.ps1`
