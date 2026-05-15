# Projeto Estruturante — Plano de Execução

Data: 15/05/2026
Objetivo: eliminar o atrito estrutural que causa perda de tempo em cada novo projeto.

## O que será feito (em ordem)

---

### 1. Gerar API Key do n8n na VPS

**Por que:** sem API key, não é possível gerenciar o n8n da VPS via script ou MCP —
toda mudança exige acesso manual pela UI.

**Como:** SSH no VPS → acessar painel n8n → Settings → API → criar chave.

**Resultado:** API key salva localmente para uso em scripts e futuro MCP apontando para VPS.

---

### 2. Configurar credenciais como objetos reutilizáveis no n8n da VPS

**Por que:** hoje cada workflow hardcoda as API keys dentro dos Code nodes.
Quando uma chave muda, é necessário editar todos os workflows manualmente.
Com credential objects, basta atualizar em um lugar.

**Credenciais a configurar:**

| Nome no n8n | Tipo | Serviço |
|-------------|------|---------|
| anthropic-api | HTTP Header Auth (x-api-key) | Anthropic Claude |
| notion-api | HTTP Header Auth (Authorization: Bearer) | Notion |
| groq-api | HTTP Header Auth (Authorization: Bearer) | Groq Whisper |

**Nota:** o Lounge Café Bot usa `$helpers.httpRequest` em Code nodes — não usa o sistema
de credenciais do n8n. Essa mudança não o afeta.

---

### 3. Criar pipeline de deploy para o Newsletter Agent (GitHub Actions)

**Por que:** o Lounge Café Bot já tem deploy automático (push → GitHub Actions → VPS).
O Newsletter Agent ainda precisa de deploy manual.

**Como:** criar `.github/workflows/deploy.yml` no repo newsletter-agent com:
1. SSH no VPS
2. `sed` substitui placeholders pelas API keys reais (secrets do GitHub)
3. `docker exec n8n n8n import:workflow` importa o JSON atualizado

**Secrets necessários no GitHub:**
- `VPS_SSH_KEY` (mesma do Lounge Café Bot)
- `ANTHROPIC_API_KEY`
- `NOTION_TOKEN`
- `NOTION_PARENT_PAGE_ID`

---

### 4. Fix permanente do DNS para api.github.com

**Por que:** o IP resolvido pelo ISP para api.github.com (4.228.31.149) frequentemente
não responde, quebrando o gh CLI e bloqueando deploys.

**Como:** manter a entrada no hosts file com IP estável do GitHub (140.82.121.6),
com script para atualizar automaticamente se mudar.

---

### 5. Importar e ativar o Newsletter Agent na VPS

**Por que:** o workflow foi desenvolvido no n8n local mas precisa rodar na VPS
para garantir execução automática às 7h independente do computador estar ligado.

**Como:** usar o GitHub Actions criado no passo 3, ou importar manualmente via SSH.
Após importar: configurar credenciais e ativar o Cron.

---

## O que NÃO será feito agora

- Templates genéricos de workflows (mudam muito, valem pouco)
- Configurar Evolution API / WhatsApp (aguardando número dedicado)
- Múltiplos ambientes (staging/prod) — overhead desnecessário para este volume

---

## Ordem de execução

```
1. SSH VPS → gerar n8n API key
2. Criar credential objects no n8n VPS (Anthropic, Notion, Groq)
3. Criar GitHub Actions para newsletter-agent
4. Fixar hosts file (DNS)
5. Importar Newsletter Agent na VPS e ativar
```

Tempo estimado: 1-2h.
