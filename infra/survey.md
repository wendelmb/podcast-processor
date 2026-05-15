# Varredura de Infraestrutura — 15/05/2026

## Ambientes

| Ambiente | URL | Status | API Key |
|----------|-----|--------|---------|
| n8n local (dev) | localhost:5678 | Online (start-n8n.ps1) | ✅ Configurada no MCP (`n8n-mcp`) |
| n8n VPS (prod) | http://145.79.7.215:5678 | Online | ✅ Configurada no MCP (`n8n-vps`) e em `infra/vps-secrets.env` |
| Evolution API (VPS) | http://145.79.7.215:8080 | Online, sem WhatsApp conectado | loungecafe2026secret |

## Projetos e seus workflows

| Projeto | Repo | n8n | Workflow ID | Status |
|---------|------|-----|-------------|--------|
| Podcast Processor | wendelmb/podcast-processor | **local** | Fbf0OUNIfrXOQmNP | Ativo |
| Newsletter Agent | wendelmb/newsletter-agent | **local** (migrar para VPS) | v7cI1EUEJhcCP6Hx | Inativo, em construção |
| Lounge Café Bot | wendelmb/lounge-cafe-bot | **VPS** | lounge-cafe-bot-v1 | Inativo (aguardando nº WhatsApp) |

## Serviços externos em uso

| Serviço | Quem usa | Onde está a credencial |
|---------|----------|----------------------|
| Anthropic API | Podcast Processor, Newsletter Agent, Lounge Café Bot | Hardcoded nos Code nodes |
| Notion API | Podcast Processor, Newsletter Agent | Hardcoded nos Code nodes |
| Groq API | Podcast Processor | Hardcoded no node Groq Whisper |
| Evolution API | Lounge Café Bot | API Key no .env da VPS |
| Google Sheets | Lounge Café Bot | Credential object no n8n da VPS (google-sheets-lounge-cafe) |

## Infraestrutura VPS (145.79.7.215)

- Provider: Hostinger KVM 2
- OS: Ubuntu 24.04
- SSH key: C:\Users\Admin\.ssh\lounge_cafe_vps
- Projeto no VPS: /opt/lounge-cafe/
- Docker Compose: n8n + Evolution API + PostgreSQL + Redis

## Problemas estruturantes identificados

1. **Credenciais hardcoded**: API keys da Anthropic e Notion estão dentro do código dos workflows,
   não no sistema de credenciais do n8n. Cada novo projeto copia e cola as chaves manualmente.

2. **Sem deploy automation para newsletter**: O Lounge Café Bot tem GitHub Actions que faz deploy
   automático. O Newsletter Agent ainda não tem esse pipeline.

3. **n8n VPS sem API key configurada**: Não é possível gerenciar o n8n da VPS via MCP ou scripts
   automatizados sem uma API key. Acesso só pela UI manual.

4. **DNS api.github.com instável**: O IP resolvido (4.228.31.149) frequentemente não responde.
   Fix atual via hosts file pode ser perdido. Causa: ISP resolvendo para IP problemático.

5. **n8n local e VPS desconectados**: Não há processo formal de sincronização de workflows entre
   o ambiente local (onde são desenvolvidos) e a VPS (onde rodam em produção).
