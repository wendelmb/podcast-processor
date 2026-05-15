# CLAUDE.md — Podcast Processor

Guia de referência rápida para o Claude Code trabalhar neste projeto.

## Instruções para o Claude Code

- Sempre que fizer uma alteração no projeto (novo nó, novo script, novo limite descoberto, problema resolvido), atualize as seções relevantes deste CLAUDE.md no mesmo commit.
- Nunca deixe o CLAUDE.md desatualizado em relação ao código que acabou de mudar.

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

---

# CLAUDE.md — Lounge Café Bot

## O que é este projeto

Bot de atendimento WhatsApp para a Lounge Café (loja física em Araras/SP, da Ednea Cristina, sogra do Wendel).
O bot apresenta o cardápio, guia o cliente por um fluxo de pedido e notifica a loja.

Fluxo: WhatsApp → Evolution API → n8n webhook → máquina de estados → resposta WhatsApp + Google Sheets + notificação loja.

Stack: **Evolution API v2** (WhatsApp), **n8n** (orquestração), **Docker** no VPS Hostinger KVM 2.

## Estrutura de arquivos

```
lounge-cafe-bot/
├── n8n-workflow/
│   └── lounge-cafe-bot.json   # workflow exportado (fonte da verdade)
└── vps/
    ├── docker-compose.yml     # 4 serviços: evolution-api, n8n, postgres, redis
    └── setup-vps.sh           # instala Docker no Ubuntu 24.04
```

## VPS e infraestrutura

| Item | Valor |
|------|-------|
| Provider | Hostinger KVM 2 |
| IP | `145.79.7.215` |
| OS | Ubuntu 24.04 |
| SSH key | `C:\Users\Admin\.ssh\lounge_cafe_vps` |
| Acesso SSH | `ssh -i C:\Users\Admin\.ssh\lounge_cafe_vps root@145.79.7.215` |
| Compose dir | `/opt/lounge-cafe/` |

## Serviços Docker no VPS

| Serviço | Porta | URL |
|---------|-------|-----|
| Evolution API | 8080 | http://145.79.7.215:8080 |
| n8n | 5678 | http://145.79.7.215:5678 |
| PostgreSQL | 5432 (interno) | banco da Evolution API |
| Redis | 6379 (interno) | cache da Evolution API |

**API Key Evolution**: `loungecafe2026secret`

## n8n no VPS

- **Workflow ID**: `lounge-cafe-bot-v1`
- **Webhook**: `POST http://145.79.7.215:5678/webhook/lounge-cafe`
- **Status**: inativo (ativar apenas quando tiver número WhatsApp dedicado)

**Nós do workflow** (em ordem):
1. `Webhook Evolution API` — recebe eventos do WhatsApp
2. `Respond 200` — resposta imediata (paralela)
3. `Ignore Own Messages` — filtra fromMe e event≠messages.upsert
4. `Process State Machine` — Code node com toda a lógica do bot (7 estados)
5. `Skip Groups` — ignora mensagens de grupos
6. `Send WhatsApp Message` — HTTP POST para Evolution API
7. `Order Complete?` — IF verifica se pedido foi confirmado
8. `Prepare Order Data` — formata dados para Sheets e notificação
9. `Save Order to Google Sheets` — registra pedido (requer credencial OAuth2)
10. `Notify Store WhatsApp` — envia alerta para `5511970957327`

## Máquina de estados (7 estados)

| Estado | Descrição |
|--------|-----------|
| 0 | Saudação + cardápio |
| 1 | Escolha do café (1-4) |
| 2 | Tipo: G=Grão / M=Moído |
| 3 | Quantidade de pacotes |
| 4 | Farofa? S/N |
| 45 | Quantidade de farofa |
| 5 | Nome do cliente + dados PIX |
| 6 | Aguarda comprovante PIX |

**Reiniciar pedido**: digitar `1` em qualquer estado ≠ 1.

**Estado persistido em**: `staticData` do n8n (in-memory por execução do workflow no VPS).

## Cardápio e preços

| Produto | Preço |
|---------|-------|
| Café Premium Suave (500g) | R$ 69,00 |
| Café Especial Equilibrado (500g) | R$ 69,00 |
| Café Gourmet Clássico (500g) | R$ 57,00 |
| Café Super Intenso (500g) | R$ 57,00 |
| Farofa | R$ 30,00/unidade |

**Chave PIX**: `(19) 998972667` — Beneficiária: Ednea Cristina

## Horário de funcionamento (BRT)

- Segunda a Sexta: 08h–18h
- Sábado: 08h–12h
- Fora do horário: bot menciona que confirmarão na abertura

## Evolution API: instância WhatsApp

- **Nome da instância**: `lounge-cafe`
- **Status**: desconectada (aguardando número dedicado)
- **Webhook configurado**: `MESSAGES_UPSERT` → `http://145.79.7.215:5678/webhook/lounge-cafe`
- **QR Code**: gerar via Manager UI em http://145.79.7.215:8080/manager ou via pairing code

Para conectar número:
```bash
# Pairing code (alternativa ao QR)
curl -X POST 'http://145.79.7.215:8080/instance/pairingCode/lounge-cafe' \
  -H 'apikey: loungecafe2026secret' \
  -H 'Content-Type: application/json' \
  -d '{"phoneNumber": "5519XXXXXXXXX"}'
```

## Google Sheets (pendente configuração)

1. Criar planilha com aba "Pedidos" e colunas: Timestamp, Nome, WhatsApp, Produtos, Total, PIX, Status, Obs
2. Compartilhar com a conta de serviço Google
3. Configurar credencial OAuth2 no n8n do VPS
4. Atualizar o ID da planilha no nó "Save Order to Google Sheets" (atualmente `COLE_O_ID_DA_PLANILHA_AQUI`)

## Importar/atualizar workflow no VPS

```powershell
# Gerar JSON base64 e importar via SSH (sem escrita em disco local)
$b64 = (python-script-que-gera-json) | python
$b64 | ssh -i C:\Users\Admin\.ssh\lounge_cafe_vps root@145.79.7.215 "tr -d '\r\n' | base64 -d > /tmp/wf.json && docker cp /tmp/wf.json n8n:/tmp/wf.json && docker exec n8n n8n import:workflow --input=/tmp/wf.json"
```

## Problemas conhecidos e soluções

**QR code não renderiza na UI do Evolution Manager** → bug do browser; usar pairing code como alternativa.

**n8n "secure cookie" error** → adicionar `N8N_SECURE_COOKIE=false` no docker-compose e recriar container: `docker compose up --force-recreate -d n8n`.

**Evolution API crashando** → verificar se PostgreSQL e Redis estão rodando; a API depende dos dois.

**`cat: command not found` no terminal Hostinger** → PATH incompleto; usar `python3` para escrever arquivos ou `nano` para editar.

**Heredoc não funciona no Bash tool do Claude Code** → usar PowerShell com `@'...'@` (heredoc single-quoted) + pipe para `python` local.
