# Instala o Podcast Processor como servico automatico do Windows via Task Scheduler
# Execute como Administrador

Write-Host ""
Write-Host "=== Podcast Processor - Instalacao do Servico ===" -ForegroundColor Cyan
Write-Host ""

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$trigger  = New-ScheduledTaskTrigger -AtLogon
$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit 0 `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 2) `
    -MultipleInstances IgnoreNew

# --- n8n ---
$actionN8n = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$projectDir\start-n8n.ps1`""

Register-ScheduledTask `
    -TaskName    "PodcastProcessor-n8n" `
    -Action      $actionN8n `
    -Trigger     $trigger `
    -Settings    $settings `
    -Description "Inicia o n8n para o Podcast Processor" `
    -RunLevel    Highest `
    -Force | Out-Null

Write-Host "  [OK] Tarefa PodcastProcessor-n8n registrada" -ForegroundColor Green

# --- Interface Web ---
$actionUI = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$projectDir\start-ui.ps1`""

Register-ScheduledTask `
    -TaskName    "PodcastProcessor-UI" `
    -Action      $actionUI `
    -Trigger     $trigger `
    -Settings    $settings `
    -Description "Inicia a interface web do Podcast Processor" `
    -RunLevel    Highest `
    -Force | Out-Null

Write-Host "  [OK] Tarefa PodcastProcessor-UI registrada" -ForegroundColor Green

# --- Iniciar agora sem precisar reiniciar ---
Write-Host ""
Write-Host "Iniciando servicos agora..." -ForegroundColor Yellow

Start-ScheduledTask -TaskName "PodcastProcessor-n8n"
Write-Host "  [OK] n8n iniciado (aguarde ~10s para ficar disponivel em localhost:5678)"

Start-Sleep -Seconds 5
Start-ScheduledTask -TaskName "PodcastProcessor-UI"
Write-Host "  [OK] Interface iniciada (localhost:3000)"

Write-Host ""
Write-Host "Pronto! Os servicos iniciarao automaticamente a cada login." -ForegroundColor Green
Write-Host ""
Write-Host "Gerenciamento:" -ForegroundColor Cyan
Write-Host "  .\check-services.ps1   ver status dos servicos"
Write-Host "  .\uninstall-service.ps1   remover inicio automatico"
