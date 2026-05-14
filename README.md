# Podcast Processor

Automação local que transcreve podcasts do YouTube e gera um resumo estruturado e rico no Notion, usando IA.

## O que faz

1. Você cola um link do YouTube na interface web
2. O áudio é baixado e comprimido automaticamente
3. O Groq Whisper transcreve o áudio
4. O Claude gera um resumo detalhado com citações, temas, insights, FAQ e pauta de debate
5. O resumo é salvo formatado no Notion e você recebe o link direto

## Arquitetura

```
Interface Web (localhost:3000)
    │
    └──► n8n Webhook (localhost:5678)
              │
              ├── Download Audio  (yt-dlp + ffmpeg)
              ├── Groq Whisper    (transcrição)
              ├── Claude Sonnet   (síntese)
              └── Notion API      (salva resultado)
```

## Pré-requisitos

| Ferramenta | Instalação |
|------------|------------|
| [Node.js](https://nodejs.org) | v18+ |
| [n8n](https://n8n.io) | `npm install -g n8n` |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | `winget install yt-dlp.yt-dlp` |
| [ffmpeg](https://ffmpeg.org) | `winget install ffmpeg` |

## API Keys necessárias

Configure dentro do n8n nos nós correspondentes:

| Serviço | Onde usar | Como obter |
|---------|-----------|------------|
| [Groq](https://console.groq.com) | Nó "Groq Whisper" | console.groq.com → API Keys |
| [Anthropic](https://console.anthropic.com) | Nó "Claude Synthesis" | console.anthropic.com → API Keys |
| [Notion](https://www.notion.so/my-integrations) | Nó "Save to Notion" | Criar integração + compartilhar database |

## Como rodar

### 1. Iniciar o n8n

```powershell
.\start-n8n.ps1
```

> Sempre use este script — ele define variáveis de ambiente necessárias para o n8n funcionar corretamente com módulos nativos e timeouts longos.

### 2. Importar o workflow no n8n

1. Acesse http://localhost:5678
2. Menu → Workflows → Import
3. Selecione o arquivo `n8n-workflow/podcast-processor.json`
4. Configure suas API keys nos nós indicados
5. Ative o workflow

### 3. Iniciar a interface web

```powershell
.\start-ui.ps1
```

Acesse http://localhost:3000

## Variáveis de ambiente (start-n8n.ps1)

| Variável | Valor | Por quê |
|----------|-------|---------|
| `NODE_FUNCTION_ALLOW_BUILTIN` | `child_process,fs,path,https,http` | Permite que Code nodes usem módulos nativos do Node |
| `N8N_RUNNERS_HEARTBEAT_INTERVAL` | `300` | Evita timeout do task runner em downloads longos |
| `N8N_RUNNERS_TASK_TIMEOUT` | `900` | Permite até 15 min por node (downloads de podcasts longos) |

## Estrutura do Workflow n8n

```
Webhook → Download Audio → Read Audio File → Groq Whisper
       → Store Transcription → Claude Synthesis → Store Summary
       → Save to Notion → Cleanup Audio
```

### Nós principais

**Download Audio** (Code node)
- Baixa o áudio com yt-dlp
- Se o arquivo > 24 MB, recodifica com ffmpeg para 32kbps mono (limite do Groq: 25 MB)
- Arquivos > 50 MB usam 16kbps

**Groq Whisper** (HTTP Request)
- Modelo: `whisper-large-v3`
- Retry: 3 tentativas com 8 minutos de espera (para rate limit 429)
- Limite do plano gratuito: 7.200 segundos de áudio por hora

**Claude Synthesis** (HTTP Request)
- Modelo: `claude-sonnet-4-6`
- `max_tokens`: 16.000
- Gera: contexto, citações, temas, insights, FAQ, frase do episódio e pauta de debate

**Save to Notion** (Code node)
- Cria a página com propriedades (título, data, temas, status, URL)
- Envia o conteúdo em lotes de 100 blocos (limite da API do Notion)
- Formata markdown em blocos Notion: headings, bullets, quotes, dividers, bold, italic

## Serviço do Windows (início automático)

Para que o n8n e a interface iniciem automaticamente a cada login, use os scripts de serviço:

```powershell
# Instalar (execute como Administrador)
.\install-service.ps1

# Verificar status
.\check-services.ps1

# Remover início automático
.\uninstall-service.ps1
```

O `install-service.ps1` registra duas tarefas no Task Scheduler do Windows:
- **PodcastProcessor-n8n** — inicia o n8n em segundo plano
- **PodcastProcessor-UI** — inicia a interface web em segundo plano

Ambas as tarefas reiniciam automaticamente até 3 vezes (intervalo de 2 min) em caso de falha.

## Troubleshooting

### Groq rate limit (429)
O plano gratuito tem 7.200 segundos de áudio por hora (~2h de podcast). Se atingir o limite:
- O sistema automaticamente tenta de novo após 8 minutos
- O processamento pode levar até 20-25 minutos no total
- Para aumentar o limite, upgrade para o plano pago no console.groq.com

### Download timeout
Vídeos muito longos podem exceder o timeout. O `start-n8n.ps1` já configura 15 minutos.
Se ainda ocorrer, verifique se o vídeo é público e tente novamente.

### Conteúdo truncado no Notion
O workflow envia os blocos em múltiplos lotes. Se ainda houver truncamento, pode ser que
o Claude atingiu `max_tokens`. Verifique o nó Claude Synthesis.

### Título "Podcast Processado" no Notion
O título é extraído da seção **FRASE DO EPISÓDIO** do resumo. Se o Claude não gerar essa
seção corretamente, o fallback é o título padrão.

## Fluxo de desenvolvimento (Git + PR)

```bash
# 1. Criar branch para a mudança
git checkout -b feature/nome-da-mudanca

# 2. Fazer as alterações nos arquivos
# 3. Exportar o workflow do n8n e atualizar n8n-workflow/podcast-processor.json

# 4. Commitar
git add .
git commit -m "descricao da mudanca"

# 5. Subir para o GitHub
git push origin feature/nome-da-mudanca

# 6. Abrir PR no GitHub
gh pr create --title "Título da mudança" --body "O que foi alterado e por quê"

# 7. Revisar e fazer merge no GitHub
gh pr merge --squash
```
