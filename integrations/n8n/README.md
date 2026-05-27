# n8n Security Automation

Automatizacion MVP para convertir informacion de Wazuh en prioridades accionables para el SOC y, cuando este listo, en tickets de Jira. Incluye triage de vulnerabilidades y creacion automatica de tickets para alertas `P1`, `P2` y `P3`.

## Objetivo

Este modulo hace dos flujos principales.

Vulnerabilidades:

1. Consulta vulnerabilidades activas desde Wazuh Indexer (`wazuh-states-vulnerabilities*`).
2. Enriquece CVEs con CISA KEV y FIRST EPSS.
3. Calcula prioridad de negocio (`P1` a `P4`) usando severidad, CVSS, KEV, EPSS, criticidad y exposicion del activo.
4. Genera evidencia JSON/Markdown y, si se activa, crea tickets en Jira Cloud.

Alertas:

1. Consulta alertas desde `wazuh-alerts-*`.
2. Selecciona reglas marcadas con `incident_priority_p1`, `incident_priority_p2` o `incident_priority_p3`.
3. Agrupa duplicados por regla, agente, IP, usuario y path.
4. Crea tickets Jira con una descripcion detallada de que paso y por que se disparo.

La fase de IA queda preparada para agregarse despues entre el triage y la creacion del ticket.

## Arquitectura

```text
Wazuh Indexer
  index: wazuh-states-vulnerabilities*
  index: wazuh-alerts-*
        |
        v
n8n workflow
  Manual Trigger / Schedule
        |
        v
Node scripts versionados
  integrations/n8n/scripts/wazuh-vulnerability-triage.js
  integrations/n8n/scripts/wazuh-alert-jira-tickets.js
        |
        +--> CISA KEV
        +--> FIRST EPSS
        +--> Risk scoring
        +--> Alert grouping P1/P2/P3
        +--> Markdown/JSON evidence
        +--> Jira Cloud ticket creation (opcional)
```

## Archivos

| Archivo | Uso |
| --- | --- |
| `docker-compose.n8n.yml` | Levanta n8n local con Docker, solo como fallback. |
| `integrations/n8n/.env.example` | Variables necesarias para Wazuh, KEV, EPSS y Jira. |
| `integrations/n8n/workflows/wazuh-vulnerability-triage.workflow.json` | Workflow importable en n8n. |
| `integrations/n8n/workflows/wazuh-alert-jira-tickets.workflow.json` | Workflow importable para tickets Jira de alertas P1/P2/P3. |
| `integrations/n8n/scripts/wazuh-vulnerability-triage.js` | Logica de consulta, enriquecimiento, scoring y Jira. |
| `integrations/n8n/scripts/wazuh-alert-jira-tickets.js` | Logica de consulta de alertas, deduplicacion y Jira. |
| `integrations/n8n/samples/wazuh-vulnerabilities-sample.json` | Datos ficticios para validar el workflow sin conectar a Wazuh. |
| `integrations/n8n/samples/wazuh-alerts-sample.json` | Datos ficticios para validar tickets de alertas sin conectar a Wazuh. |
| `integrations/n8n/output/` | Evidencia generada por cada ejecucion. No se commitea. |
| `scripts/n8n-security-automation.ps1` | Helper para levantar n8n, importar workflow y correr triage. |
| `scripts/start-wazuh-indexer-tunnel.ps1` | Tunel SSH local hacia el Wazuh Indexer en GCP. |

## Modo GCP persistente

Terraform ahora puede crear una VM dedicada `n8n-automation` en la misma VPC de Wazuh.

Caracteristicas:

- IP publica estatica para abrir n8n desde internet.
- Disco persistente `n8n-automation-data` para workflows, credenciales, SQLite y evidencia.
- Docker administrado por systemd, con reinicio automatico.
- Workflow y script versionados copiados al host durante el startup.
- Conexion privada al Wazuh Indexer en `https://<wazuh-private-ip>:9200`; ya no necesita tunel local.
- Agente Wazuh instalado en la propia VM n8n para monitorear la automatizacion.

Variables principales en `terraform/wazuh-deploy/terraform.tfvars`:

```hcl
enable_gcp_endpoints  = true
enable_windows_server = true
enable_n8n            = true

n8n_source_ranges = ["0.0.0.0/0"]
n8n_basic_auth_user = "admin"
n8n_basic_auth_password = ""
n8n_encryption_key = ""
n8n_wazuh_indexer_username = "admin"
n8n_wazuh_indexer_password = "SecretPassword"
```

Dejar `n8n_basic_auth_password` y `n8n_encryption_key` vacios hace que la VM genere valores una sola vez y los guarde en el disco persistente.

Desplegar:

```powershell
terraform -chdir=terraform/wazuh-deploy init
terraform -chdir=terraform/wazuh-deploy apply
terraform -chdir=terraform/wazuh-deploy output n8n_url
terraform -chdir=terraform/wazuh-deploy output n8n_credentials_command
```

Leer password generado:

```powershell
terraform -chdir=terraform/wazuh-deploy output -raw n8n_credentials_command
```

Ejecuta el comando que imprime Terraform. El usuario por defecto es:

```text
admin
```

Ejecutar triage desde la nube:

```powershell
terraform -chdir=terraform/wazuh-deploy output -raw n8n_run_triage_command
```

Ejecuta el comando devuelto para correr `wazuh-vulnerability-triage.js` dentro del contenedor cloud.

Ejecutar creacion de tickets por alertas desde la nube:

```powershell
terraform -chdir=terraform/wazuh-deploy output -raw n8n_run_alert_tickets_command
```

Ejecuta el comando devuelto para correr `wazuh-alert-jira-tickets.js` dentro del contenedor cloud.

## Puesta en marcha local fallback

### 1. Crear archivo de variables

```powershell
Copy-Item integrations\n8n\.env.example integrations\n8n\.env
notepad integrations\n8n\.env
```

Valores minimos para laboratorio:

```env
WAZUH_INDEXER_URL=https://host.docker.internal:9200
WAZUH_INDEXER_USERNAME=admin
WAZUH_INDEXER_PASSWORD=CAMBIAR_EN_PASSWORD_MANAGER
WAZUH_INDEXER_INSECURE_TLS=true
JIRA_CREATE_TICKETS=false
```

### 2. Abrir tunel al Wazuh Indexer

En una terminal separada:

```powershell
.\scripts\start-wazuh-indexer-tunnel.ps1
```

Ese tunel deja disponible:

```text
https://localhost:9200
https://host.docker.internal:9200
```

n8n usa `host.docker.internal` porque corre dentro de Docker.

### 3. Levantar n8n

```powershell
.\scripts\n8n-security-automation.ps1 -Action up
```

Abrir:

```text
http://localhost:5678
```

### 4. Importar workflow

```powershell
.\scripts\n8n-security-automation.ps1 -Action import-workflow
```

Para importar ambos workflows:

```powershell
.\scripts\n8n-security-automation.ps1 -Action import-workflows
```

En n8n, abrir alguno de estos workflows:

```text
Wazuh Vulnerability Triage - KEV EPSS Jira
Wazuh Alert Jira Tickets - P1 P2 P3
```

### 5. Ejecutar triage sin Jira

Desde PowerShell:

```powershell
.\scripts\n8n-security-automation.ps1 -Action run-triage
```

Para ejecutar el flujo de alertas P1/P2/P3:

```powershell
.\scripts\n8n-security-automation.ps1 -Action run-alert-tickets
```

O desde n8n, usar `Manual Trigger`.

La evidencia queda en:

```text
integrations/n8n/output/vulnerability-triage-latest.json
integrations/n8n/output/vulnerability-triage-latest.md
integrations/n8n/output/alert-jira-triage-latest.json
integrations/n8n/output/alert-jira-triage-latest.md
```

## Activar Jira

Primero probar con `JIRA_CREATE_TICKETS=false`. Cuando el output sea correcto, editar `integrations/n8n/.env`:

```env
JIRA_CREATE_TICKETS=true
JIRA_CREATE_ALERT_TICKETS=true
JIRA_BASE_URL=https://your-domain.atlassian.net
JIRA_EMAIL=security@example.com
JIRA_API_TOKEN=CAMBIAR_EN_PASSWORD_MANAGER
JIRA_PROJECT_KEY=SEC
JIRA_ISSUE_TYPE=Task
JIRA_MAX_TICKETS=15
JIRA_ALERT_MAX_TICKETS=15
JIRA_DEDUPE=true
JIRA_ALERT_DEDUPE=true
```

El script de vulnerabilidades crea tickets para todos los hallazgos priorizados, limitado por `JIRA_MAX_TICKETS`. El script de alertas crea tickets para `P1`, `P2` y `P3`, limitado por `JIRA_ALERT_MAX_TICKETS`. Cada ticket creado o detectado por deduplicacion devuelve `issueUrl` y el workflow lo resume en el nodo `Jira Ticket Links`.

## Modo sample sin Wazuh

Para validar n8n, scoring y evidencia sin abrir el tunel a Wazuh, configura:

```env
TRIAGE_SAMPLE_FILE=/home/node/.n8n/samples/wazuh-vulnerabilities-sample.json
ALERT_SAMPLE_FILE=/home/node/.n8n/samples/wazuh-alerts-sample.json
ENRICHMENT_OFFLINE=true
JIRA_CREATE_TICKETS=false
JIRA_CREATE_ALERT_TICKETS=false
```

Despues ejecuta:

```powershell
.\scripts\n8n-security-automation.ps1 -Action run-triage
.\scripts\n8n-security-automation.ps1 -Action run-alert-tickets
```

Cuando quieras volver a datos reales, deja `TRIAGE_SAMPLE_FILE=` y `ALERT_SAMPLE_FILE=` vacios.

## Scoring

El score final va de `0` a `100`.

| Factor | Peso maximo |
| --- | ---: |
| Severidad Wazuh | 40 |
| CVSS | 30 |
| CISA KEV | 30 |
| EPSS | 20 |
| Criticidad del activo | 15 |
| Exposicion del activo | 15 |

El score se limita a `100`.

Prioridades:

| Prioridad | Criterio | SLA sugerido |
| --- | --- | --- |
| `P1` | Score >= 85 o KEV + Critical | 24-48 horas |
| `P2` | Score >= 65 | 3-7 dias |
| `P3` | Score >= 40 | 15-30 dias |
| `P4` | Resto | Siguiente ciclo |

## Donde entra la IA despues

La IA debe entrar despues de `Parse Summary` y antes de Jira.

Uso recomendado:

1. Recibir `topFindings`.
2. Resumir impacto en lenguaje ejecutivo.
3. Proponer plan de remediacion.
4. Generar descripcion de ticket mas clara.
5. Generar texto para cliente.

No debe inventar evidencia. La fuente de verdad sigue siendo Wazuh + KEV + EPSS.

## Seguridad

- No commitear `integrations/n8n/.env`.
- No activar Jira hasta validar el output.
- Mantener `JIRA_MAX_TICKETS` bajo al inicio.
- Usar token de Jira con permisos minimos.
- Para demos rapidas, n8n puede quedar publico por `n8n_source_ranges = ["0.0.0.0/0"]`.
- Para uso real, restringir `n8n_source_ranges` a tu IP publica `/32` o poner n8n detras de VPN/HTTPS/SSO.
- No abrir el puerto `9200` del Wazuh Indexer a internet; n8n lo consulta por IP privada con firewall interno.

## Troubleshooting

### n8n no puede conectar con Wazuh Indexer

Verifica que el tunel este abierto:

```powershell
curl.exe -k -u admin:CAMBIAR https://localhost:9200
```

Dentro de n8n usa:

```text
https://host.docker.internal:9200
```

### No aparecen vulnerabilidades

Revisar:

- Wazuh Vulnerability Detection esta activo.
- Los agentes tienen inventario.
- El indice `wazuh-states-vulnerabilities*` tiene datos.
- `VULN_MIN_SEVERITY` no esta filtrando demasiado.
- `VULN_STATUS=Active` coincide con el estado de tus datos.

### Jira no crea tickets

Revisar:

- `JIRA_CREATE_TICKETS=true`.
- `JIRA_PROJECT_KEY` existe.
- `JIRA_ISSUE_TYPE` existe en el proyecto.
- El usuario/token puede crear issues.
- El proyecto permite el campo `priority`.
