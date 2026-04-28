# Launch Ollama serve (with dedup check)
$proc = Get-Process ollama -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "Ollama already running (PID: $($proc.Id))" -ForegroundColor Yellow
} else {
    Write-Host "Starting Ollama..." -ForegroundColor Cyan
    Start-Process -FilePath "F:\backup\LocalAI\ollama\ollama-app\ollama.exe" -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 2
    $proc = Get-Process ollama -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "Ollama started (PID: $($proc.Id))" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Ollama failed to start" -ForegroundColor Red
    }
}
