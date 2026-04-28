# LocalAI

Local AI model hosting and inference using Ollama.

## Data Location
Runtime data (models, app, keys) lives at: `F:\backup\LocalAI\ollama\`

## Ollama
- **App**: `F:\backup\LocalAI\ollama\ollama-app\ollama.exe`
- **Models**: `F:\backup\LocalAI\ollama\models\` (~6GB)
- **SSH Keys**: `F:\backup\LocalAI\ollama\id_ed25519`
- **History**: `F:\backup\LocalAI\ollama\history`

## Python Environment
- **System Python** (with pyautogui, win32gui): `C:\Users\micha\AppData\Local\Programs\Python\Python312\python.exe`
- **Ollama venv** (minimal, no GUI libs): `F:\backup\LocalAI\ollama\venv\Scripts\python.exe`
  - WARNING: This venv is first in PATH and lacks pyautogui/win32gui. Use system Python for GUI automation.

## AHK Shortcuts
- `llocalai` - Opens this study folder
- `ppppp` - Runs Paragon disk check automation (uses system Python)
