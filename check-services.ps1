# Verifica o status dos servicos do Podcast Processor

Write-Host ""
Write-Host "=== Podcast Processor - Status dos Servicos ===" -ForegroundColor Cyan
Write-Host ""

$tasks = @("PodcastProcessor-n8n", "PodcastProcessor-UI")

foreach ($task in $tasks) {
    $t = Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
    if ($t) {
        $info = Get-ScheduledTaskInfo -TaskName $task
        $state = $t.State
        $color = if ($state -eq "Running") { "Green" } elseif ($state -eq "Ready") { "Yellow" } else { "Red" }
        Write-Host "  $task" -ForegroundColor Cyan
        Write-Host "    Status    : $state" -ForegroundColor $color
        Write-Host "    Ultimo Run: $($info.LastRunTime)"
        Write-Host "    Resultado : $($info.LastTaskResult)"
        Write-Host ""
    } else {
        Write-Host "  $task : NAO INSTALADO" -ForegroundColor Red
        Write-Host ""
    }
}

Write-Host "Endpoints:" -ForegroundColor Cyan
Write-Host "  n8n : http://localhost:5678"
Write-Host "  UI  : http://localhost:3000"
Write-Host ""
