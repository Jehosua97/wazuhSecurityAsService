# n8n SOC Automation

n8n convierte alertas y vulnerabilidades de Wazuh en acciones operativas.

## Que hace

- Consulta `wazuh-alerts-*` para alertas P1/P2/P3.
- Crea tickets Jira con resumen, evidencia, regla, agente e indicadores.
- Agrega analisis ChatGPT si `AI_ENABLE_ANALYSIS=true`.
- Manda Telegram para P1/P2 si `TELEGRAM_ENABLE_ALERTS=true`.
- Consulta vulnerabilidades y puede priorizarlas con KEV/EPSS.

## Entrar a n8n

```powershell
terraform -chdir=terraform/wazuh-deploy output n8n_url
terraform -chdir=terraform/wazuh-deploy output n8n_basic_auth_user
terraform -chdir=terraform/wazuh-deploy output -raw n8n_credentials_command
```

## Ejecutar tickets de alertas

```powershell
terraform -chdir=terraform/wazuh-deploy output -raw n8n_run_alert_tickets_command
```

## Ejecutar triage de vulnerabilidades

```powershell
terraform -chdir=terraform/wazuh-deploy output -raw n8n_run_triage_command
```

## Editar variables reales

```powershell
gcloud compute ssh n8n-automation --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo nano /opt/wazuh-n8n/.env"
gcloud compute ssh n8n-automation --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo systemctl restart wazuh-n8n"
```

## Variables sensibles

No poner valores reales en Git.

Variables comunes:

- `JIRA_API_TOKEN`
- `OPENAI_API_KEY`
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`
- `WAZUH_INDEXER_PASSWORD`

## Documentacion detallada

- [Alertas Jira IA Telegram](../n8n-alert-jira-automation.md)
- [Vulnerabilidades](../n8n-vulnerability-automation.md)
- `integrations/n8n/README.md`
