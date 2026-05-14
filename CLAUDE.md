# CLAUDE.md — Podcast Processor

Guia de referência rápida para o Claude Code trabalhar neste projeto.

## O que é este projeto

Automação local que processa podcasts do YouTube e salva um resumo estruturado no Notion.
Fluxo: URL do YouTube → yt-dlp → ffmpeg → Groq Whisper → Claude Sonnet → Notion API.

Stack: **n8n** (orquestração), **Node.js** (interface web), **PowerShell** (scripts Windows).

## Estrutura de arquivos

```
podcast-processor/
├── n8n-workflow/
│   └── podcast-processor.json   # workflow exportado do n8n (fonte da verdade)
├── podcast-ui/
│   ├── serve.js                 # servidor Express da interface web (porta 3000)
│   └── public/index.html        # frontend da interface
├── start-n8n.ps1                # inicia o n8n com as variáveis de ambiente corretas
├── start-ui.ps1                 # inicia a interface web
├── install-service.ps1          # registra serviços no Task Scheduler (requer Admin)
├── uninstall-service.ps1        # remove os serviços do Task Scheduler
├── check-services.ps1           # exibe status dos serviços agendados
└── CLAUDE.md                    # este arquivo
```

## Ambientes

| Ambiente | Caminho | Uso |
|----------|---------|-----|
| Dev | `C:\dev\podcast-processor` | criar branches, fazer alterações |
| Produção | `C:\claude-code` | clone do GitHub, recebe `git pull` após merge |

O n8n roda no ambiente de **produção** (`C:\claude-code`). Alterações no workflow n8n precisam ser exportadas manualmente e salvas em `n8n-workflow/podcast-processor.json`.

## n8n: onde ficam as coisas

- **URL local**: http://localhost:5678
- **Workflow ID**: `Fbf0OUNIfrXOQmNP`
- **Webhook**: `POST http://localhost:5678/webhook/process-podcast` com body `{ "url": "..." }`
- **Nós do workflow** (em ordem de execução):
  1. `Webhook` — recebe a URL do YouTube
  2. `Download Audio` — yt-dlp + ffmpeg, salva em `~/.n8n-files/podcast.mp3`
  3. `Read Audio File` — lê o arquivo usando `$json.audioPath`
  4. `Groq Whisper` — transcreve (HTTP Request, modelo `whisper-large-v3`)
  5. `Store Transcription` — armazena transcrição no contexto
  6. `Claude Synthesis` — gera resumo (HTTP Request, `claude-sonnet-4-6`, max_tokens 16000)
  7. `Store Summary` — armazena resumo no contexto
  8. `Save to Notion` — cria página, envia blocos em lotes de 100
  9. `Cleanup Audio` — apaga `~/.n8n-files/podcast.mp3`

## Variáveis de ambiente do n8n (start-n8n.ps1)

```
NODE_FUNCTION_ALLOW_BUILTIN = child_process,fs,path,https,http
N8N_RUNNERS_HEARTBEAT_INTERVAL = 300
N8N_RUNNERS_TASK_TIMEOUT = 900
```

Sem essas variáveis, os Code nodes do n8n não conseguem usar `child_process` (necessário para yt-dlp e ffmpeg) e downloads longos sofrem timeout.

## Limites e comportamentos importantes

| Componente | Limite | Comportamento atual |
|------------|--------|---------------------|
| Groq Whisper | 25 MB por arquivo | ffmpeg recodifica para 32kbps (>24MB) ou 16kbps (>50MB) |
| Groq rate limit | 7.200s áudio/hora | retry automático após 8 min (3 tentativas) |
| Notion API | 100 blocos por request | envio em lotes: POST cria com 100, PATCH appenda o restante |
| Claude max_tokens | 16.000 | suficiente para resumos de até ~2h de podcast |

## Fluxo de desenvolvimento (Git + PR)

```powershell
# Em C:\dev\podcast-processor
git checkout main
git pull origin main
git checkout -b feature/nome-da-mudanca

# ... fazer alterações ...
# Se mudou o workflow n8n: exportar e salvar em n8n-workflow/podcast-processor.json

git add <arquivos>
git commit -m "descricao da mudanca"
git push origin feature/nome-da-mudanca
gh pr create --title "..." --body "..."

# Após merge no GitHub:
# Em C:\claude-code
git pull origin main
```

## Aplicar mudanças no workflow n8n via MCP

Quando o n8n está rodando, é possível atualizar nós diretamente via MCP (sem precisar exportar/importar manualmente):

```
mcp__n8n-mcp__n8n_update_partial_workflow
  workflowId: "Fbf0OUNIfrXOQmNP"
  ... (ver documentação do n8n-mcp)
```

Se o n8n não estiver rodando, editar diretamente `n8n-workflow/podcast-processor.json` e reimportar após `git pull`.

## Serviços do Windows (Task Scheduler)

Dois serviços agendados iniciam automaticamente no login:
- `PodcastProcessor-n8n` — executa `start-n8n.ps1`
- `PodcastProcessor-UI` — executa `start-ui.ps1`

Para verificar: `.\check-services.ps1`
Para reinstalar após mover o projeto: `.\install-service.ps1` (como Administrador)

## APIs e credenciais

As credenciais **não estão no repositório**. São configuradas diretamente nos nós do n8n:
- **Groq API Key** — nó "Groq Whisper"
- **Anthropic API Key** — nó "Claude Synthesis"
- **Notion Token** — nó "Save to Notion" (variável `NOTION_TOKEN`)
- **Notion Database ID** — nó "Save to Notion" (variável `NOTION_DATABASE_ID`)

O arquivo `n8n-workflow/podcast-processor.json` no repositório usa placeholders (`YOUR_GROQ_API_KEY`, etc.) — as chaves reais ficam só na instância local do n8n.

## Problemas comuns e soluções conhecidas

**"Erro no processamento"** na UI → n8n não está rodando. Iniciar com `.\start-n8n.ps1` ou verificar `.\check-services.ps1`.

**Download timeout** → vídeo muito longo ou rede lenta. `N8N_RUNNERS_TASK_TIMEOUT=900` permite até 15 min. Se persistir, tentar novamente.

**Groq 429** → rate limit atingido. O sistema espera 8 min e tenta novamente (até 3x). Processamento pode levar 20-25 min.

**Título "Podcast Processado" no Notion** → Claude não gerou a seção `FRASE DO EPISÓDIO` no formato esperado. Checar o nó "Claude Synthesis" e o prompt do sistema.

**Temas não populados no Notion** → regex `\*\*TEMAS DISCUTIDOS[^*]*\*\*` no nó "Save to Notion" não encontrou a seção. Verificar a saída do Claude.
