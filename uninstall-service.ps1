# Remove as tarefas agendadas do Podcast Processor
# Execute como Administrador

Write-Host ""
Write-Host "=== Podcast Processor - Remocao do Servico ===" -ForegroundColor Cyan
Write-Host ""

$tasks = @("PodcastProcessor-n8n", "PodcastProcessor-UI")

foreach ($task in $tasks) {
    $exists = Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
    if ($exists) {
        Stop-ScheduledTask  -TaskName $task -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $task -Confirm:$false
        Write-Host "  [OK] Tarefa $task removida" -ForegroundColor Green
    } else {
        Write-Host "  [--] Tarefa $task nao encontrada (ja removida?)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Pronto! Os servicos nao iniciarao mais automaticamente." -ForegroundColor Green
Write-Host "Para reinstalar, execute .\install-service.ps1 como Administrador." -ForegroundColor Cyan
Write-Host ""
