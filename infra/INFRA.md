# Infraestrutura n8n — Documentação Global

**Última atualização:** 15/05/2026
**Dono:** Wendel Bitencourt (wendelbitencourt@gmail.com)

Este documento é a referência central para qualquer IA ou desenvolvedor trabalhando em projetos que usam a infraestrutura n8n do Wendel. Leia antes de criar, modificar ou depurar qualquer workflow.

---

## Princípio fundamental: DEV → PROD

```
n8n local (localhost:5678)  →  git commit + push main  →  GitHub Actions  →  n8n VPS (145.79.7.215:5678)
       DEV                                                                           PROD
```

- **Todo desenvolvimento começa no n8n local.** Nunca edite workflows diretamente na VPS pela UI.
- O **JSON do workflow no repositório é a fonte da verdade**, com placeholders para credenciais.
- O **GitHub Actions** injeta as credenciais reais (via `sed`) e importa automaticamente na VPS.
- O n8n local **não precisa** ter os mesmos workflows que a VPS — apenas os que estão em desenvolvimento ativo.

---

## Ambientes

| Ambiente | URL | Papel | MCP disponível |
|----------|-----|-------|----------------|
| n8n local (dev) | http://localhost:5678 | Desenvolvimento e teste | `mcp__n8n-mcp__*` |
| n8n VPS (prod) | http://145.79.7.215:5678 | Execução automática 24/7 | `mcp__n8n-vps__*` |
| Evolution API (VPS) | http://145.79.7.215:8080 | WhatsApp (Evolution API v2) | — |

**VPS:** Hostinger KVM 2 · Ubuntu 24.04 · IP `145.79.7.215`
**SSH:** `ssh -i C:\Users\Admin\.ssh\lounge_cafe_vps root@145.79.7.215`
**Docker Compose:** `/opt/lounge-cafe/docker-compose.yml` (n8n + Evolution API + PostgreSQL + Redis + whatsapp-bridge)

---

## Projetos e seus workflows

### 1. Podcast Processor
| Item | Valor |
|------|-------|
| Repo | `wendelmb/podcast-processor` (privado) |
| Dev local | `C:\dev\podcast-processor\` |
| Prod (clone) | `C:\claude-code\` |
| n8n ambiente | **Local only** (usa yt-dlp e ffmpeg locais) |
| Workflow ID local | `Fbf0OUNIfrXOQmNP` |
| Workflow ID VPS | _não existe_ — roda apenas local |
| Status | Ativo |
| Deploy | Manual (git pull em C:\claude-code após merge) |

**Fluxo:** URL YouTube → yt-dlp → ffmpeg → Groq Whisper → Claude Sonnet → Notion (database)
**Nota:** Não tem GitHub Actions porque depende de ferramentas locais (yt-dlp, ffmpeg). Nunca migrar para VPS sem adaptar a arquitetura.

---

### 2. Newsletter Agent
| Item | Valor |
|------|-------|
| Repo | `wendelmb/newsletter-agent` (privado) |
| Dev local | `C:\dev\newsletter-agent\` |
| n8n ambiente | **Local (dev) + VPS (prod)** |
| Workflow ID local | `v7cI1EUEJhcCP6Hx` |
| Workflow ID VPS | `newsletter-agent-vps` |
| Status | Ativo em ambos |
| Deploy | **Automático** — push para `main` dispara GitHub Actions |

**Fluxo:** Cron 7h → Fetch RSS (15 feeds) → Filtro 24h → Preparar Prompt → Claude Synthesis → Salvar no Notion (página)
**Destino Notion:** Página "Newsletter do Dia" (ID: `3614f073-2f28-80b1-974a-eddb345456fa`)
**Secrets GitHub:** `VPS_SSH_KEY`, `ANTHROPIC_API_KEY`, `NOTION_TOKEN`, `N8N_VPS_API_KEY`

---

### 3. Lounge Café Bot
| Item | Valor |
|------|-------|
| Repo | `wendelmb/lounge-cafe-bot` (privado) |
| Dev local | `C:\dev\lounge-cafe-bot\` |
| n8n ambiente | **VPS only** (depende de Evolution API na VPS) |
| Workflow ID VPS | `lounge-cafe-bot-v1` |
| Workflow ID local | `2iehrQ75JLqAiJ1X` (cópia dev — **sempre inativo** no local) |
| Status | Inativo (aguardando número WhatsApp dedicado) |
| Deploy | **Automático** — push para `main` dispara GitHub Actions |

**Fluxo:** WhatsApp (Evolution API) → n8n Webhook → Claude Haiku (AI Processor) → WhatsApp + Google Sheets
**Secrets GitHub:** `VPS_SSH_KEY`, `ANTHROPIC_API_KEY`, `N8N_VPS_API_KEY`
**Atenção:** O Lounge Café Bot usa `$helpers.httpRequest` em Code nodes — **não usa** o sistema de credenciais do n8n.

---

## Padrão de deploy (GitHub Actions)

Todos os projetos com deploy automático seguem este padrão:

```yaml
# 1. Substituir placeholders pelas chaves reais (localmente no runner)
sed -e "s|YOUR_ANTHROPIC_API_KEY|${{ secrets.ANTHROPIC_API_KEY }}|g" \
    -e "s|YOUR_NOTION_TOKEN|${{ secrets.NOTION_TOKEN }}|g" \
    workflow.json | jq '.id = "id-na-vps"' > wf_deploy.json

# 2. Copiar para VPS via SCP
appleboy/scp-action → /tmp/wf_deploy.json

# 3. Importar no n8n e ativar
docker cp /tmp/wf_deploy.json n8n:/tmp/wf_deploy.json
docker exec n8n n8n import:workflow --input=/tmp/wf_deploy.json
docker exec n8n n8n publish:workflow --id=<id-na-vps>
docker compose restart n8n  # ativa crons
```

**O JSON no repositório sempre usa placeholders:**
- `YOUR_ANTHROPIC_API_KEY`
- `YOUR_NOTION_TOKEN`
- `YOUR_NOTION_PARENT_PAGE_ID`
- `YOUR_GROQ_API_KEY`

---

## Credenciais

### Objetos de credencial no n8n da VPS
Criados via `n8n import:credentials` — disponíveis para workflows que usam HTTP Request nodes:

| ID no n8n | Nome | Tipo | Serviço |
|-----------|------|------|---------|
| `anthropic-api` | Anthropic API | HTTP Header Auth (x-api-key) | Anthropic Claude |
| `notion-api` | Notion API | HTTP Header Auth (Authorization: Bearer) | Notion |
| `groq-api` | Groq API | HTTP Header Auth (Authorization: Bearer) | Groq Whisper |
| `anthropic-lounge-cafe` | Anthropic - Lounge Cafe | HTTP Header Auth (x-api-key) | Claude (legado Lounge Café) |
| `google-sheets-lounge-cafe` | Google Sheets - Lounge Cafe | Google Service Account | Google Sheets pedidos |

### Onde ficam os valores reais
- **Arquivo local** (nunca commitar): `C:\claude-code\infra\vps-secrets.env`
- **GitHub Secrets** por repo: gerenciar em `github.com/wendelmb/<repo>/settings/secrets/actions`
- **VPS .env**: `/opt/lounge-cafe/.env` (apenas variáveis do Docker Compose)

### Serviços externos
| Serviço | Quem usa |
|---------|----------|
| Anthropic Claude | Podcast Processor, Newsletter Agent, Lounge Café Bot |
| Notion API | Podcast Processor (database), Newsletter Agent (páginas) |
| Groq Whisper | Podcast Processor |
| Evolution API | Lounge Café Bot |
| Google Sheets | Lounge Café Bot |

---

## MCP — Gerenciamento via Claude Code

Configurado em `C:\claude-code\.mcp.json`. Dois servidores n8n disponíveis:

| Servidor MCP | Aponta para | Usar quando |
|-------------|-------------|-------------|
| `mcp__n8n-mcp__*` | localhost:5678 | Desenvolver e testar workflows localmente |
| `mcp__n8n-vps__*` | 145.79.7.215:5678 | Inspecionar, atualizar ou depurar workflows em produção |

**Exemplos de uso:**
```
mcp__n8n-mcp__n8n_list_workflows          → lista workflows do dev local
mcp__n8n-vps__n8n_list_workflows          → lista workflows da VPS/prod
mcp__n8n-vps__n8n_get_workflow(id=...)    → inspeciona workflow em prod
mcp__n8n-vps__n8n_executions(id=...)      → histórico de execuções em prod
```

---

## Estado atual dos workflows

### n8n local (dev) — localhost:5678
| Workflow | ID | Nós | Status |
|----------|----|-----|--------|
| Podcast Processor | `Fbf0OUNIfrXOQmNP` | 9 | ✅ Ativo |
| Podcast Processor - Error Handler | `sQQEN2wPGYUXE3PO` | 2 | ⏸ Inativo |
| Newsletter Agent | `v7cI1EUEJhcCP6Hx` | 6 | ✅ Ativo (dev) |
| Lounge Café Bot | `2iehrQ75JLqAiJ1X` | 10 | ⏸ **Sempre inativo no local** |

### n8n VPS (prod) — 145.79.7.215:5678
| Workflow | ID | Status |
|----------|----|--------|
| Lounge Cafe Bot v2 | `lounge-cafe-bot-v1` | ✅ Ativo (aguardando WhatsApp) |
| Newsletter Agent | `newsletter-agent-vps` | ✅ Ativo — Cron 7h diário |
| QR Capture | `qr-capture-tmp` | ⏸ Inativo (temporário, sem repo) |

---

## Como adicionar um novo projeto

1. **Criar repo** `wendelmb/<nome-projeto>` com estrutura:
   ```
   <projeto>/
   ├── .github/workflows/deploy.yml   # GitHub Actions (copiar padrão acima)
   ├── n8n-workflow/<projeto>.json    # workflow com placeholders
   ├── .gitignore
   └── CLAUDE.md
   ```

2. **Desenvolver no n8n local** — exportar JSON e salvar em `n8n-workflow/`.

3. **Substituir credenciais reais por placeholders** no JSON antes de commitar.

4. **Configurar GitHub Secrets** (mínimo: `VPS_SSH_KEY`, `ANTHROPIC_API_KEY`).

5. **Definir ID único para VPS** no `deploy.yml` (ex: `meu-projeto-vps`) via `jq '.id = "..."'`.

6. **Push para `main`** → deploy automático → workflow ativo na VPS.

---

## Problemas conhecidos e soluções

| Problema | Causa | Solução |
|----------|-------|---------|
| `n8n import:workflow` não ativa o Cron | Workflow importado fica inativo | Chamar `publish:workflow` + `docker compose restart n8n` após import |
| Credenciais hardcoded nos Code nodes | Code nodes não acessam o sistema de credenciais do n8n | Usar placeholder + sed no deploy; os credential objects do n8n ficam para HTTP Request nodes |
| `staticData` perdido após restart | In-memory no n8n — não persiste | Comportamento esperado; para persistência usar Redis/Postgres |
| n8n local offline | Task Scheduler não iniciou | Rodar `C:\claude-code\start-n8n.ps1` manualmente |
| DNS api.github.com falha | ISP resolve para IP instável | `140.82.121.6 api.github.com` no hosts file do Windows |

---

## Referências rápidas

```bash
# SSH na VPS
ssh -i C:\Users\Admin\.ssh\lounge_cafe_vps root@145.79.7.215

# Status dos containers
docker compose -f /opt/lounge-cafe/docker-compose.yml ps

# Listar workflows na VPS
docker exec n8n n8n list:workflow

# Importar workflow manualmente na VPS
docker cp workflow.json n8n:/tmp/wf.json
docker exec n8n n8n import:workflow --input=/tmp/wf.json
docker exec n8n n8n publish:workflow --id=<id>

# Reiniciar n8n na VPS (ativa crons)
cd /opt/lounge-cafe && docker compose restart n8n

# Iniciar n8n local
C:\claude-code\start-n8n.ps1
```
