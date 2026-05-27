# n8n Alert Jira Automation

Este documento describe el workflow que crea tickets Jira automaticamente cuando Wazuh genera alertas `P1`, `P2` o `P3`.

## Que resuelve

El laboratorio ya clasifica varias reglas custom con grupos como:

- `incident_priority_p1`
- `incident_priority_p2`
- `incident_priority_p3`

El workflow `Wazuh Alert Jira Tickets - P1 P2 P3` consulta `wazuh-alerts-*`, agrupa alertas repetidas y crea un ticket por incidente agrupado. Cada ticket explica que paso, por que se disparo, que regla lo genero, que agente fue afectado, que evidencia trajo Wazuh y que acciones se recomiendan.

## Flujo

```text
Wazuh Indexer
  wazuh-alerts-*
        |
        v
n8n
  Manual / cada 15 minutos
        |
        v
Script de alertas
  integrations/n8n/scripts/wazuh-alert-jira-tickets.js
        |
        +--> filtra P1/P2/P3
        +--> agrupa duplicados por regla, agente, IP, usuario y path
        +--> genera evidencia JSON/Markdown
        +--> crea o reutiliza ticket Jira
        +--> devuelve links directos al ticket
```

## Variables principales

```env
ALERT_WAZUH_INDEX=wazuh-alerts-*
ALERT_LOOKBACK_MINUTES=60
ALERT_MAX_RESULTS=100
ALERT_TOP_FINDINGS=25
ALERT_PRIORITIES=P1,P2,P3
ALERT_INCLUDE_LEVEL_DERIVED=false
ALERT_EXCLUDE_RULE_IDS=

JIRA_CREATE_ALERT_TICKETS=true
JIRA_BASE_URL=https://your-domain.atlassian.net
JIRA_EMAIL=security@example.com
JIRA_API_TOKEN=CAMBIAR_EN_PASSWORD_MANAGER
JIRA_PROJECT_KEY=SEC
JIRA_ISSUE_TYPE=Task
JIRA_ALERT_MAX_TICKETS=15
JIRA_ALERT_DEDUPE=true
JIRA_SET_PRIORITY_FIELD=true
JIRA_DESCRIPTION_FORMAT=adf
JIRA_PRIORITY_MAP_JSON={"P1":"Highest","P2":"High","P3":"Medium","P4":"Low"}
```

`JIRA_CREATE_ALERT_TICKETS=false` deja el flujo en modo dry-run: no crea tickets, pero genera evidencia y muestra que tickets habria creado.

## Como probar sin Jira real

En `integrations/n8n/.env`:

```env
ALERT_SAMPLE_FILE=/home/node/.n8n/samples/wazuh-alerts-sample.json
JIRA_CREATE_ALERT_TICKETS=false
```

Ejecutar:

```powershell
.\scripts\n8n-security-automation.ps1 -Action run-alert-tickets
```

La evidencia queda en:

```text
integrations/n8n/output/alert-jira-triage-latest.json
integrations/n8n/output/alert-jira-triage-latest.md
```

## Como activar en GCP

Terraform copia el script, el workflow y el sample a la VM `n8n-automation`. Despues de aplicar:

```powershell
terraform -chdir=terraform/wazuh-deploy apply
terraform -chdir=terraform/wazuh-deploy output -raw n8n_run_alert_tickets_command
```

Ejecuta el comando devuelto para correr el script dentro del contenedor cloud.

Para que cree tickets reales, edita el `.env` de n8n en la VM y reinicia el servicio:

```powershell
gcloud compute ssh n8n-automation --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo nano /opt/wazuh-n8n/.env"
gcloud compute ssh n8n-automation --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo systemctl restart wazuh-n8n"
```

## Que trae el ticket

Cada issue incluye:

- prioridad `P1`, `P2` o `P3`;
- motivo exacto del ticket, por ejemplo el grupo `incident_priority_p1`;
- regla Wazuh, nivel, descripcion y grupos;
- agente afectado, IP del agente y manager;
- IPs, usuarios, ruta FIM, decoder y ubicacion del log cuando existen;
- evidencia `full_log` y eventos relacionados;
- mapeo MITRE cuando Wazuh lo incluye;
- acciones recomendadas para validar, contener y documentar.

## Deduplicacion

El script agrega labels como:

```text
wazuh-alert
alert-<hash>
priority-p1
rule-100030
agent-017
```

Con `JIRA_ALERT_DEDUPE=true`, antes de crear un issue busca tickets abiertos con el mismo `alert-<hash>`. Si existe uno, no crea duplicado y devuelve el link del ticket existente.
