$env:NODE_FUNCTION_ALLOW_BUILTIN = "child_process,fs,path,https,http"
$env:N8N_RUNNERS_HEARTBEAT_INTERVAL = "300"
$env:N8N_RUNNERS_TASK_TIMEOUT = "900"
Write-Host "Iniciando n8n com permissoes de modulos nativos..." -ForegroundColor Green
n8n start
