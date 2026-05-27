# Wazuh Security MVP

MVP de servicio de seguridad gestionada para PYMES usando Wazuh como plataforma principal de SIEM/XDR, monitoreo de endpoints, contenedores, File Integrity Monitoring, vulnerability management, alerting, reporting y respuesta operativa.

Este repositorio convierte un laboratorio técnico en una demo comercial presentable para clientes. La arquitectura actual mantiene Wazuh en Google Cloud Platform y ejecuta los endpoints de cliente como contenedores locales en Docker, simulando un ambiente real de una PYME sin usar datos sensibles reales.

## Resumen ejecutivo

El objetivo del proyecto es demostrar, vender y operar una oferta inicial de Managed Security / MSSP para PYMES con un equipo pequeño. La demo debe responder preguntas de negocio:

- Qué activos tengo monitoreados.
- Qué vulnerabilidades y configuraciones inseguras existen.
- Qué cambios críticos fueron detectados.
- Qué alertas requieren atención.
- Qué evidencia se puede entregar en un reporte.
- Qué acciones recomienda el SOC.
- Qué valor recibe el cliente cada mes.

La solución está diseñada para defensa, monitoreo, educación y demostración controlada. No debe usarse para explotación real, pruebas contra terceros, evasión, persistencia, malware ni actividades sin autorización explícita.

## Objetivo del MVP

Construir una plataforma mínima viable que permita:

- Aprender y operar Wazuh de forma práctica.
- Mostrar una demo profesional de seguridad gestionada.
- Simular un ambiente tipo cliente con servicios Linux en contenedores.
- Generar eventos seguros y repetibles para demostrar detección.
- Crear dashboards técnicos y ejecutivos.
- Preparar reportes mensuales o de assessment.
- Documentar playbooks, onboarding, hardening y operación.
- Evolucionar hacia un servicio mensual para clientes reales.

## Arquitectura general

Estado actual objetivo: Wazuh, endpoints Linux, Windows Server y n8n pueden vivir completos en GCP. El modo Docker local queda como fallback para demos rapidas o ahorro de costo, pero el `terraform.tfvars` local de este repo ya queda preparado con `enable_gcp_endpoints = true`, `enable_windows_server = true` y `enable_n8n = true`.

```text
                         Equipo SOC / Demo
             PowerShell + Terraform + Docker + Git Bash/WSL
                                |
                                | aplica config, importa dashboards,
                                | arranca/detiene laboratorio
                                v
+------------------------------------------------------------------+
|                       Google Cloud Platform                       |
|                                                                  |
|  +----------------------------+      +-------------------------+  |
|  | wazuh-server               |      | Controles GCP           |  |
|  | - Wazuh Manager            |<-----| - VPC y firewall        |  |
|  | - Wazuh Indexer            |      | - IP publica estatica   |  |
|  | - Wazuh Dashboard          |      | - Terraform state GCS   |  |
|  | - Reglas custom            |      | - IAM / acceso admin    |  |
|  | - Decoders/listas          |      +-------------------------+  |
|  | - Active Response demo     |                                 |
|  +----------------------------+                                 |
|       ^        ^        ^                                       |
|       |        |        |                                       |
|       |        |        +-- HTTPS 443 / Dashboard               |
|       |        +----------- API 55000 / gestion                 |
|       +-------------------- 1514/1515 / agentes Wazuh           |
+-------|----------------------------------------------------------+
        |
        v
+------------------------------------------------------------------+
|                  Laptop / Ambiente Demo Local                    |
|                                                                  |
|  Docker Compose: docker-compose.endpoints.yml                    |
|                                                                  |
|  +----------------------+     +--------------------------------+  |
|  | Contenedores cliente |     | Demo mode / Evidencia          |  |
|  | - linux-ui-workstation|<---| - FIM controlado               |  |
|  | - pyme-demo-target   |     | - permisos                     |  |
|  | - edge-gateway       |     | - logs anomalos seguros        |  |
|  | - db-server          |     | - servicio reiniciado simulado |
|  | - docker-host        |     | - contenedor reiniciado sim.   |
|  | - metasploit-node    |     | - bundle de evidencia          |
|  | - juice-shop         |     +--------------------------------+  |
|  +----------------------+                                         |
|                                                                  |
|  Modulos Wazuh en agentes Linux:                                 |
|  - Log collector                                                 |
|  - Command execution                                             |
|  - FIM                                                           |
|  - SCA                                                           |
|  - System inventory                                              |
|  - Rootcheck / malware detection seguro                          |
|  - Active Response demo seguro                                   |
|  - Docker monitoring en docker-host                              |
|  - Cloud monitoring demo por logs GCP simulados                  |
+------------------------------------------------------------------+
        |
        v
+------------------------------------------------------------------+
|                    Fallbacks locales opcionales                    |
|  - docker-compose.windows.yml: Windows container demo             |
|  - ansible/windows-ad-lab: Windows Server 2016 + AD en VirtualBox |
|  - Docker local si enable_gcp_endpoints=false                     |
+------------------------------------------------------------------+
        |
        v
+------------------------------------------------------------------+
|              Automatizacion MSSP / n8n SOC Automation             |
|  - n8n-automation en GCP con IP publica estatica                  |
|  - Disco persistente para workflows, credenciales y evidencia     |
|  - Wazuh Indexer query: wazuh-states-vulnerabilities*             |
|  - Wazuh Indexer query: wazuh-alerts-*                            |
|  - CISA KEV + FIRST EPSS enrichment                               |
|  - Vulnerability triage P1-P4                                     |
|  - Alertas P1/P2/P3 -> Jira Cloud                                 |
|  - ChatGPT SOC Analysis opcional                                  |
|  - Telegram P1/P2 Alert opcional                                  |
|  - Evidencia Markdown/JSON persistente                            |
+------------------------------------------------------------------+
```

## Componentes actuales

- `terraform/wazuh-deploy`: infraestructura GCP con Terraform para Wazuh single-node, endpoints Linux, Windows Server, n8n persistente, red, firewall, IPs publicas estaticas y outputs operativos.
- `terraform/config/wazuh-manager`: configuracion administrada del manager Wazuh: reglas, decoders, listas, `ossec.conf`, herramientas y Active Response seguro de demo.
- `docker-compose.endpoints.yml`: fallback local con endpoints Linux y `juice-shop`.
- `docker-compose.windows.yml`: fallback local Windows; requiere Docker Desktop en modo Windows containers.
- `docker/linux-endpoints`: imagen base de endpoints Linux con agente Wazuh, perfiles por servicio, scripts de eventos y modulos del agente.
- `docker/windows-endpoint`: imagen base de Windows Server demo para pruebas controladas.
- `dashboards/wazuh-soc-dashboards.ndjson`: dashboards importables a Wazuh/OpenSearch Dashboards, incluyendo vista SOC y vista de modulos Wazuh.
- `demo-mode/`: scripts seguros para generar eventos controlados y evidencia local de demo.
- `ansible/windows-ad-lab`: laboratorio Windows Server 2016 con Active Directory, usuarios demo y agente Wazuh para correr en otra PC con VirtualBox/Vagrant.
- `docs/wazuh-agent-modules-demo.md`: documentacion de modulos del agente Wazuh dentro de los contenedores Linux.
- `scripts/lab-master.ps1`: consola maestra para operar GCP, Wazuh y contenedores.
- `scripts/local-docker-lab.ps1`: operacion directa de endpoints Docker.
- `scripts/apply-wazuh-config.ps1`: aplica reglas, listas, decoders, Active Response y configuracion Wazuh al manager.
- `scripts/import-wazuh-dashboards.ps1`: importa dashboards SOC al dashboard.
- `scripts/setup-linux-ui-sensitive-agent.sh`: configura el escenario Linux UI con carpeta sensible `/Confidencial`.
- `scripts/simulate-confidential-ransomware-burst.sh`: genera rafaga FIM segura para el escenario de ransomware heuristico.
- `docker-compose.n8n.yml`: fallback local para automatizacion n8n.
- `integrations/n8n`: workflows, scripts, variables de ejemplo, samples y evidencia para vulnerabilidades, Jira, ChatGPT y Telegram.
- `docs/n8n-vulnerability-automation.md`: guia rapida de triage de vulnerabilidades Wazuh + n8n + KEV/EPSS + Jira.
- `docs/n8n-alert-jira-automation.md`: guia de tickets Jira por alertas P1/P2/P3, analisis ChatGPT y notificaciones Telegram P1/P2.
- `docs/`: documentacion tecnica, playbooks, runbooks y guias actuales.

## Componentes a desarrollar

Estos entregables convertirán el laboratorio en un producto más comercial y repetible:

- `ARCHITECTURE.md`: arquitectura objetivo, flujo de datos, riesgos y diseño multi-cliente futuro.
- `DEPLOYMENT_GUIDE.md`: despliegue paso a paso en GCP y Docker local.
- `DEMO_GUIDE.md`: guion técnico de demostración con evidencias esperadas.
- `CLIENT_PRESENTATION_SCRIPT.md`: guion comercial de 10 y 30 minutos.
- `SECURITY_HARDENING.md`: hardening de Wazuh en GCP.
- `ONBOARDING_RUNBOOK.md`: proceso para assessments y servicio mensual.
- `INCIDENT_RESPONSE_PLAYBOOKS.md`: playbooks SOC por tipo de alerta.
- `REPORTING_GUIDE.md`: diseño de reportes PDF ejecutivos y técnicos.
- `API_INTEGRATION_GUIDE.md`: webhooks, tickets y notificaciones.
- `ROADMAP.md`: fases, entregables y criterios de aceptación.
- `CHANGELOG.md`: historial de cambios técnicos y comerciales.
- `reports/`: plantillas y ejemplos de reportes sin datos reales.
- `client-material/`: one-pagers, propuestas, pricing y material comercial.

## Casos de uso de demo

La demo comercial debe cubrir al menos estos escenarios:

1. Inventario de activos y visibilidad inicial.
2. Detección de vulnerabilidades y priorización de riesgo.
3. Cambio sospechoso en archivo crítico usando FIM.
4. Evento anómalo en contenedores o servicio web.
5. Respuesta activa controlada o ticket automatizado ante alerta crítica.

Escenarios adicionales recomendados:

- Endpoint desconectado o agente caído.
- Configuración insegura detectada por SCA.
- Múltiples intentos fallidos de autenticación simulados.
- Cambios en carpeta sensible `/Confidencial`.
- Evidencia para reporte mensual ejecutivo.

## Alcance

Incluido en este MVP:

- Wazuh single-node en GCP para demo y laboratorio.
- Endpoints Linux locales conectados al manager cloud.
- Monitoreo con Wazuh agents.
- Recolección de logs de sistema, servicios y aplicaciones demo.
- FIM en rutas controladas.
- Vulnerability Detection.
- Security Configuration Assessment.
- Dashboards SOC y base para dashboard ejecutivo.
- Scripts seguros de simulación local.
- Documentación operativa y comercial.
- Preparación para assessments de 7 a 14 días.

## Fuera de alcance

No incluido en esta fase:

- Explotación real contra terceros.
- Pruebas sin autorización escrita del cliente.
- Malware, evasión, persistencia o técnicas ofensivas reales.
- Multi-tenant productivo con clientes reales mezclados.
- SLA 24/7 formal sin procesos, cobertura y contratos definidos.
- Almacenamiento de datos reales de clientes en el laboratorio demo.
- Exposición pública del dashboard sin controles de acceso fuertes.

## Requisitos técnicos

Herramientas locales:

- PowerShell 5.1 o superior.
- Terraform.
- Google Cloud CLI.
- Docker Desktop.
- Git.

Requisitos GCP:

- Proyecto con billing habilitado.
- Compute Engine API habilitada.
- Cloud Resource Manager API habilitada.
- IAM API habilitada.
- Permisos para crear VMs, discos, VPC, reglas de firewall e IPs.
- Bucket GCS para Terraform state remoto.

Requisitos Docker:

- Docker Desktop en modo Linux containers para los endpoints Linux.
- Docker Desktop en modo Windows containers solo si se usa `windows-server`.

## Requisitos de seguridad

Antes de mostrar la demo a clientes:

- Restringir `admin_source_ranges` a IPs autorizadas.
- Restringir `extra_agent_source_ranges` a IPs o VPN autorizadas.
- Cambiar contraseñas por defecto y guardarlas en password manager.
- No commitear `.env`, `terraform.tfvars`, credenciales, tokens ni reportes con datos reales.
- Usar HTTPS con certificado válido para presentaciones externas.
- Activar MFA donde aplique.
- Separar ambiente demo, piloto y producción.
- Revisar reglas de firewall antes de cada presentación.
- Evitar mezclar datos de diferentes clientes en el mismo índice o tenant sin diseño formal.
- Usar únicamente datos ficticios o sanitizados.

## Estructura del repositorio

Estructura actual y recomendada:

```text
wazuh-security-mvp/
├── README.md
├── .github/
│   └── workflows/
├── dashboards/
│   └── wazuh-soc-dashboards.ndjson
├── docker/
│   ├── linux-endpoints/
│   └── windows-endpoint/
├── docs/
├── demo-mode/
├── ansible/
│   └── windows-ad-lab/
├── scripts/
├── terraform/
│   ├── config/
│   └── wazuh-deploy/
├── docker-compose.endpoints.yml
├── docker-compose.windows.yml
└── .env.example
```

Estructura objetivo por crear:

```text
wazuh-security-mvp/
├── docs/
├── diagrams/
├── scripts/
├── demo-mode/
├── reports/
├── dashboards/
├── playbooks/
├── onboarding/
├── integrations/
├── infrastructure/
├── client-material/
├── templates/
└── changelog/
```

Guía de uso por carpeta:

- `docs`: documentación técnica principal.
- `diagrams`: diagramas lógicos, red, flujo de datos y arquitectura comercial.
- `scripts`: automatización operativa para GCP, Wazuh y Docker.
- `demo-mode`: scripts seguros que generan eventos controlados.
- `reports`: plantillas y reportes PDF de ejemplo.
- `dashboards`: exports NDJSON y documentación de KPIs.
- `playbooks`: respuesta SOC por tipo de incidente.
- `onboarding`: checklists, autorización y offboarding.
- `integrations`: webhooks, ticketing, Slack, Teams, n8n y API.
- `infrastructure`: Terraform, hardening y módulos futuros.
- `client-material`: guiones, one-pagers, paquetes y objeciones.
- `templates`: plantillas de tickets, reportes y emails.
- `changelog`: cambios por versión y entregable.

## Roadmap

### Fase 1: Demo técnica funcional

Objetivo: validar que Wazuh en GCP recibe telemetría de endpoints locales.

Entregables:

- Wazuh en GCP operativo.
- Endpoints Linux locales activos.
- Reglas custom aplicadas.
- Scripts de demo básicos.
- Dashboards SOC importados.

### Fase 2: Demo comercial

Objetivo: convertir la demo técnica en una historia entendible para clientes.

Entregables:

- Guion de 10 minutos.
- Guion de 30 minutos.
- Cinco escenarios de demo.
- Material de presentación.
- Mensajes de valor por tipo de cliente.

### Fase 3: Reportes y dashboards

Objetivo: demostrar valor ejecutivo y evidencia mensual.

Entregables:

- Dashboard ejecutivo.
- Plantilla PDF ejecutiva.
- Plantilla PDF técnica.
- KPIs y Security Score.
- Export automático o semiautomático.

### Fase 4: Onboarding de cliente piloto

Objetivo: probar el servicio con un cliente controlado o ambiente propio realista.

Entregables:

- Runbook de onboarding.
- Plantilla de autorización.
- Checklist técnico.
- Baseline inicial.
- Reporte de assessment de 7 a 14 días.

### Fase 5: Servicio mensual

Objetivo: operar una oferta recurrente.

Entregables:

- Playbooks SOC.
- Flujo de tickets.
- Notificaciones.
- Reporte mensual.
- Métricas MTTD y MTTR.

### Fase 6: Escalamiento multi-cliente

Objetivo: separar clientes, datos, accesos y reportes.

Entregables:

- Diseño multi-cliente.
- Separación por grupos, índices o despliegues.
- Roles por cliente.
- Retención y backup.
- Procedimientos de privacidad.

### Fase 7: Wazuh Partner

Objetivo: formalizar operación, marca y capacidad comercial.

Entregables:

- Casos de éxito.
- Paquetes comerciales.
- Procesos documentados.
- Controles internos.
- Evidencia de operación.

## Mapa rapido de scripts

Esta es la seccion operativa principal para el equipo. Si alguien nuevo entra al repositorio, debe empezar por `scripts/lab-master.ps1`.

### Comandos mas usados

| Necesidad | Comando |
| --- | --- |
| Ver estado completo del lab | `.\scripts\lab-master.ps1 -Action status` |
| Abrir menu interactivo | `.\scripts\lab-master.ps1 -Action menu` |
| Encender lab completo en GCP | `.\scripts\lab-master.ps1 -Action full-start` |
| Modo ahorro sin perder IP | `.\scripts\lab-master.ps1 -Action cost-saver` |
| Encender solo Wazuh en GCP | `.\scripts\lab-master.ps1 -Action start-wazuh` |
| Apagar solo Wazuh en GCP | `.\scripts\lab-master.ps1 -Action stop-wazuh` |
| Encender todas las VMs GCP del lab | `.\scripts\lab-master.ps1 -Action start-cloud` |
| Apagar todas las VMs GCP del lab | `.\scripts\lab-master.ps1 -Action stop-cloud` |
| Encender endpoints Linux locales | `.\scripts\lab-master.ps1 -Action start-linux` |
| Detener endpoints Linux locales | `.\scripts\lab-master.ps1 -Action stop-linux` |
| Aplicar reglas/configuracion Wazuh | `.\scripts\lab-master.ps1 -Action configure-wazuh` |
| Crear o actualizar infraestructura GCP | `.\scripts\lab-master.ps1 -Action apply-gcp` |
| Destruir infraestructura GCP | `.\scripts\lab-master.ps1 -Action destroy-gcp` |
| Borrar contenedores/volumenes Linux | `.\scripts\lab-master.ps1 -Action destroy-linux` |
| Ver URL n8n cloud | `terraform -chdir=terraform/wazuh-deploy output n8n_url` |
| Ver password n8n cloud | `terraform -chdir=terraform/wazuh-deploy output -raw n8n_credentials_command` |
| Ejecutar triage n8n cloud | `terraform -chdir=terraform/wazuh-deploy output -raw n8n_run_triage_command` |
| Ejecutar tickets de alertas n8n cloud | `terraform -chdir=terraform/wazuh-deploy output -raw n8n_run_alert_tickets_command` |
| Levantar n8n local fallback | `.\scripts\n8n-security-automation.ps1 -Action up` |

Notas:

- `cost-saver` apaga las VMs GCP del lab y detiene contenedores locales visibles, pero mantiene discos e IPs estaticas reservadas por Terraform. Es el comando recomendado para bajar costos sin destruir el ambiente.
- `destroy-gcp` es destructivo: elimina infraestructura de GCP y puede romper la continuidad de la demo.
- `destroy-linux` es destructivo para volumenes locales de Docker; usarlo solo si se quiere reconstruir el lab desde cero.

### Scripts PowerShell de operacion

| Script | Para que sirve | Ejemplos |
| --- | --- | --- |
| `scripts/lab-master.ps1` | Consola maestra de GCP, Wazuh y Docker. | `-Action status`, `-Action full-start`, `-Action cost-saver` |
| `scripts/local-docker-lab.ps1` | Operacion directa de Docker Compose para endpoints locales. | `-Scope Linux -Action up`, `-Scope Linux -Action logs -Follow` |
| `scripts/apply-wazuh-config.ps1` | Copia reglas, decoders, listas, Active Response y `ossec.conf` al manager. | `.\scripts\apply-wazuh-config.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a"` |
| `scripts/import-wazuh-dashboards.ps1` | Importa dashboards SOC y de modulos Wazuh. | `.\scripts\import-wazuh-dashboards.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a" -DashboardUser "admin" -DashboardPassword $env:WAZUH_DASHBOARD_PASSWORD` |
| `scripts/n8n-security-automation.ps1` | Opera n8n local fallback, importa workflows y corre triage de vulnerabilidades o tickets de alertas. | `-Action up`, `-Action import-workflows`, `-Action run-triage`, `-Action run-alert-tickets` |
| `scripts/start-wazuh-indexer-tunnel.ps1` | Abre tunel SSH local hacia Wazuh Indexer solo para n8n local fallback. | `.\scripts\start-wazuh-indexer-tunnel.ps1` |

Acciones disponibles en `local-docker-lab.ps1`:

```powershell
.\scripts\local-docker-lab.ps1 -Scope Linux -Action up
.\scripts\local-docker-lab.ps1 -Scope Linux -Action status
.\scripts\local-docker-lab.ps1 -Scope Linux -Action logs -Follow
.\scripts\local-docker-lab.ps1 -Scope Linux -Action restart -Service pyme-demo-target
.\scripts\local-docker-lab.ps1 -Scope Linux -Action down
.\scripts\local-docker-lab.ps1 -Scope Linux -Action destroy
```

Para Windows containers:

```powershell
.\scripts\local-docker-lab.ps1 -Scope Windows -Action up
.\scripts\local-docker-lab.ps1 -Scope Windows -Action down
```

Requiere cambiar Docker Desktop a Windows containers.

### Scripts de demo en el host

Estos scripts viven en `demo-mode/` y se ejecutan desde Git Bash, WSL o Bash.

| Script | Evento que genera | Contenedor principal |
| --- | --- | --- |
| `demo-mode/run_all_demo_events.sh` | Ejecuta todos los eventos demo en secuencia. | Varios |
| `demo-mode/reset_demo.sh` | Limpia artefactos temporales de la demo. | Varios |
| `demo-mode/01_fim_critical_file_change.sh` | Cambio en archivo critico monitoreado por FIM. | `linux-ui-workstation` |
| `demo-mode/02_permission_change.sh` | Cambio de permisos en archivo de prueba. | `pyme-demo-target` |
| `demo-mode/03_service_restart_event.sh` | Servicio detenido/reiniciado de forma simulada. | `pyme-demo-target` |
| `demo-mode/04_container_lifecycle_event.sh` | Contenedor detenido/reiniciado de forma simulada. | `docker-host` |
| `demo-mode/05_anomalous_logs.sh` | Logs anomalos no ofensivos. | `pyme-demo-target` |
| `demo-mode/06_generate_report_evidence.sh` | Bundle de evidencia para reporte. | `pyme-demo-target` |

Ejecucion rapida en Windows:

```powershell
& "C:\Program Files\Git\bin\bash.exe" demo-mode/run_all_demo_events.sh
& "C:\Program Files\Git\bin\bash.exe" demo-mode/reset_demo.sh
```

### Scripts instalados dentro de contenedores Linux

Estos comandos corren dentro de los endpoints con `docker compose exec`.

| Contenedor | Script interno | Para que sirve |
| --- | --- | --- |
| `pyme-demo-target` | `/usr/local/bin/pyme-demo-generate-events.sh` | Eventos del servicio web/cliente PYME. |
| `pyme-demo-target` | `/usr/local/bin/wazuh-demo-generate-module-events.sh` | Eventos de modulos Wazuh: logcollector, command, FIM, SCA, inventory, rootcheck, AR, cloud demo. |
| `edge-gateway` | `/usr/local/bin/gateway-demo-generate-events.sh` | Eventos de gateway/firewall/VPN simulado. |
| `db-server` | `/usr/local/bin/db-demo-generate-events.sh` | Eventos de base de datos. |
| `docker-host` | `/usr/local/bin/docker-demo-generate-events.sh` | Eventos de seguridad de contenedores. |
| `metasploit-node` | `/usr/local/bin/metasploit-demo-generate-events.sh` | Eventos controlados del endpoint de laboratorio. |
| `metasploit-node` | `/usr/local/bin/msf-lab-console` | Consola controlada del laboratorio Metasploit. |
| `linux-ui-workstation` | `/usr/local/bin/simulate-confidential-ransomware-burst.sh` | Rafaga FIM segura sobre `/Confidencial`. |
| `linux-ui-workstation` | `/usr/local/bin/linux-ui-demo-auth-failure.sh` | Intentos fallidos simulados contra usuario `esquivel`. |
| `linux-ui-workstation` | `/usr/local/bin/linux-ui-demo-portscan-log.sh` | Log defensivo simulado para escenario de escaneo. |

Ejemplos:

```powershell
$env:WAZUH_MANAGER_IP="34.135.112.15"
docker compose -f docker-compose.endpoints.yml exec pyme-demo-target /usr/local/bin/wazuh-demo-generate-module-events.sh
docker compose -f docker-compose.endpoints.yml exec linux-ui-workstation /usr/local/bin/simulate-confidential-ransomware-burst.sh
docker compose -f docker-compose.endpoints.yml exec docker-host /usr/local/bin/docker-demo-generate-events.sh
```

### Scripts Linux auxiliares

| Script | Uso |
| --- | --- |
| `scripts/setup-linux-ui-sensitive-agent.sh` | Prepara `/Confidencial` y configuracion local para el escenario Linux UI. |
| `scripts/simulate-confidential-ransomware-burst.sh` | Version standalone del simulador de rafaga FIM/ransomware heuristico. |
| `terraform/config/wazuh-manager/deploy.sh` | Script remoto que aplica configuracion dentro del manager Wazuh en GCP. Normalmente se invoca desde `apply-wazuh-config.ps1`. |
| `terraform/config/wazuh-manager/active-response/bin/module-demo-response.sh` | Active Response seguro de demo para generar evidencia. |

### Ansible Windows AD Lab

El laboratorio Windows AD esta listo para otra PC con VirtualBox/Vagrant. No se ejecuta en esta maquina si no tienes VirtualBox.

```powershell
cd ansible\windows-ad-lab
vagrant up
ansible-playbook -i inventories\vagrant.yml playbooks\site.yml
ansible-playbook -i inventories\vagrant.yml playbooks\04-run-demo-events.yml
```

Archivo principal: `ansible/windows-ad-lab/README.md`.

### Automatizacion n8n SOC

El modulo n8n convierte datos de Wazuh en acciones operativas para el SOC. Vive en una VM persistente `n8n-automation` dentro de GCP y tambien puede correr localmente como fallback con Docker Compose.

Flujos implementados:

1. `Wazuh Vulnerability Triage - KEV EPSS Jira`: consulta `wazuh-states-vulnerabilities*`, enriquece CVEs con CISA KEV y FIRST EPSS, calcula prioridad `P1` a `P4`, genera evidencia Markdown/JSON y puede crear tickets Jira.
2. `Wazuh Alert Jira Tickets - P1 P2 P3`: consulta `wazuh-alerts-*`, toma alertas etiquetadas con `incident_priority_p1`, `incident_priority_p2` o `incident_priority_p3`, agrupa duplicados y crea tickets Jira con contexto SOC.
3. `ChatGPT SOC Analysis`: etapa visible dentro del workflow de alertas. Envia a OpenAI la evidencia estructurada de Wazuh y agrega la respuesta al ticket Jira bajo `Analisis IA (ChatGPT)`.
4. `Telegram P1/P2 Alert`: etapa visible dentro del workflow de alertas. Envia notificaciones Telegram para prioridades `P1` y `P2`, con deduplicacion para evitar spam.

Flujo visual del workflow de alertas:

```text
Manual Trigger / Every 15 Minutes
  -> Collect Wazuh Alerts
  -> Parse Wazuh Alerts
  -> ChatGPT SOC Analysis
  -> Parse AI Summary
  -> Create Jira Tickets
  -> Parse Jira Summary
  -> Telegram P1/P2 Alert
  -> Parse Telegram Summary
  -> Jira Ticket Links
```

Archivos principales:

| Archivo | Uso |
| --- | --- |
| `integrations/n8n/workflows/wazuh-vulnerability-triage.workflow.json` | Workflow de vulnerabilidades. |
| `integrations/n8n/workflows/wazuh-alert-jira-tickets.workflow.json` | Workflow de alertas P1/P2/P3, ChatGPT, Jira y Telegram. |
| `integrations/n8n/scripts/wazuh-vulnerability-triage.js` | Consulta vulnerabilidades, calcula prioridad, genera evidencia y tickets Jira. |
| `integrations/n8n/scripts/wazuh-alert-jira-tickets.js` | Consulta alertas, ejecuta ChatGPT, crea tickets Jira y envia Telegram. |
| `integrations/n8n/.env.example` | Plantilla de variables. No poner secretos reales aqui. |
| `integrations/n8n/samples/` | Samples para probar sin consultar Wazuh. |
| `integrations/n8n/output/` | Evidencia generada por ejecuciones locales. No se commitea. |
| `terraform/wazuh-deploy/scripts/n8n_startup.sh.tftpl` | Startup cloud que instala Docker, n8n, workflows, scripts, samples y agente Wazuh. |

Modo GCP persistente:

```powershell
terraform -chdir=terraform/wazuh-deploy output n8n_url
terraform -chdir=terraform/wazuh-deploy output -raw n8n_credentials_command
terraform -chdir=terraform/wazuh-deploy output -raw n8n_run_triage_command
terraform -chdir=terraform/wazuh-deploy output -raw n8n_run_alert_tickets_command
```

En este modo n8n vive en `n8n-automation`, usa disco persistente `n8n-automation-data`, reinicia con systemd, consulta el Wazuh Indexer por IP privada y queda monitoreado por su propio agente Wazuh. El `.env` real de produccion vive en:

```text
/opt/wazuh-n8n/.env
```

Editar secretos en GCP:

```powershell
gcloud compute ssh n8n-automation --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo nano /opt/wazuh-n8n/.env"
gcloud compute ssh n8n-automation --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo systemctl restart wazuh-n8n"
```

Variables importantes para Jira:

```env
JIRA_CREATE_TICKETS=false
JIRA_CREATE_ALERT_TICKETS=true
JIRA_BASE_URL=https://wazuhaservice.atlassian.net
JIRA_EMAIL=tu-correo-atlassian
JIRA_API_TOKEN=tu-token-jira
JIRA_PROJECT_KEY=KAN
JIRA_ISSUE_TYPE=Task
JIRA_ALERT_MAX_TICKETS=15
JIRA_ALERT_DEDUPE=true
```

Variables importantes para ChatGPT/OpenAI:

```env
AI_ENABLE_ANALYSIS=true
OPENAI_API_KEY=tu-openai-api-key
OPENAI_MODEL=gpt-4o-mini
OPENAI_BASE_URL=https://api.openai.com/v1
AI_MAX_OUTPUT_TOKENS=1200
AI_MAX_CHARS=8000
AI_MAX_ANALYSES=1
AI_TIMEOUT_MS=90000
```

`AI_MAX_ANALYSES=1` es recomendado para demo si aparece `HTTP 429` por limites de OpenAI. Aumentarlo gradualmente cuando billing, cuota y rate limits esten estables.

Variables importantes para Telegram:

```env
TELEGRAM_ENABLE_ALERTS=true
TELEGRAM_BOT_TOKEN=tu-token-de-bot
TELEGRAM_CHAT_ID=tu-chat-id
TELEGRAM_ALERT_PRIORITIES=P1,P2
TELEGRAM_MAX_ALERTS=10
TELEGRAM_DEDUPE=true
TELEGRAM_DEDUPE_TTL_HOURS=24
```

Para Telegram: crea el bot con `@BotFather`, manda un mensaje al bot, consulta `https://api.telegram.org/botTU_TOKEN/getUpdates` y copia `chat.id`.

Fallback local:

```powershell
Copy-Item integrations\n8n\.env.example integrations\n8n\.env
.\scripts\start-wazuh-indexer-tunnel.ps1
.\scripts\n8n-security-automation.ps1 -Action up
.\scripts\n8n-security-automation.ps1 -Action import-workflows
.\scripts\n8n-security-automation.ps1 -Action run-triage
.\scripts\n8n-security-automation.ps1 -Action run-alert-tickets
```

Para probar sin Wazuh real:

```env
TRIAGE_SAMPLE_FILE=/home/node/.n8n/samples/wazuh-vulnerabilities-sample.json
ALERT_SAMPLE_FILE=/home/node/.n8n/samples/wazuh-alerts-sample.json
JIRA_CREATE_TICKETS=false
JIRA_CREATE_ALERT_TICKETS=false
AI_ENABLE_ANALYSIS=false
TELEGRAM_ENABLE_ALERTS=false
```

Salida esperada:

```text
integrations/n8n/output/vulnerability-triage-latest.json
integrations/n8n/output/vulnerability-triage-latest.md
integrations/n8n/output/alert-jira-triage-latest.json
integrations/n8n/output/alert-jira-triage-latest.md
integrations/n8n/output/telegram-alerts-state.json
```

Seguridad:

- No pegar `OPENAI_API_KEY`, `JIRA_API_TOKEN` ni `TELEGRAM_BOT_TOKEN` en `.env.example`, scripts, docs ni Terraform templates.
- Para GCP, los secretos van solo en `/opt/wazuh-n8n/.env`.
- Para local, los secretos van solo en `integrations/n8n/.env`, que no debe commitearse.
- Mantener `n8n_source_ranges = ["TU_IP_PUBLICA/32"]` para uso real; `0.0.0.0/0` solo para demo rapida.
- No abrir el puerto `9200` del Wazuh Indexer a internet; n8n cloud lo consulta por red privada.

Troubleshooting rapido:

| Sintoma | Revision |
| --- | --- |
| Jira no crea tickets | `JIRA_CREATE_ALERT_TICKETS=true`, `JIRA_PROJECT_KEY=KAN`, issue type `Task`, token con permisos de crear issues. |
| ChatGPT muestra `HTTP 429` | Revisar billing/cuota/rate limits de OpenAI y bajar `AI_MAX_ANALYSES=1`. |
| Telegram no envia | Verificar `TELEGRAM_ENABLE_ALERTS=true`, token, `chat_id`, que el usuario haya escrito al bot y que no este deduplicado. |
| No hay alertas | Aumentar `ALERT_LOOKBACK_MINUTES`, generar ruido reciente o revisar grupos `incident_priority_p1/p2/p3`. |
| n8n local no conecta al indexer | Abrir `.\scripts\start-wazuh-indexer-tunnel.ps1` y usar `https://host.docker.internal:9200`. |

Documentacion extendida: `integrations/n8n/README.md`, `docs/n8n-vulnerability-automation.md` y `docs/n8n-alert-jira-automation.md`.

## Cómo ejecutar la demo

Para operacion diaria usa el camino corto:

```powershell
.\scripts\lab-master.ps1 -Action full-start
.\scripts\lab-master.ps1 -Action status
& "C:\Program Files\Git\bin\bash.exe" demo-mode/run_all_demo_events.sh
.\scripts\lab-master.ps1 -Action cost-saver
```

El resto de esta seccion deja el proceso detallado para reconstruir o preparar el ambiente desde cero.

### 1. Preparar credenciales locales

```powershell
gcloud auth login
gcloud auth application-default login
gcloud config set project wazuh-iac-on-gcp
gcloud config set compute/zone us-central1-a
```

### 2. Configurar Terraform

```powershell
Copy-Item terraform\wazuh-deploy\terraform.tfvars.example terraform\wazuh-deploy\terraform.tfvars
notepad terraform\wazuh-deploy\terraform.tfvars
```

Valores mínimos recomendados para demo segura:

```hcl
admin_source_ranges = ["TU_IP_PUBLICA/32"]
target_source_ranges = ["TU_IP_PUBLICA/32"]
extra_agent_source_ranges = ["TU_IP_PUBLICA/32"]
n8n_source_ranges = ["TU_IP_PUBLICA/32"]
enable_gcp_endpoints = true
enable_windows_server = true
enable_n8n = true
```

Si GCP devuelve `windowsVmNotAllowedInFreeTrialProject`, el proyecto aun no permite Windows Server VMs. En ese caso deja `enable_windows_server = false` hasta habilitar billing compatible con Windows; el resto del lab cloud queda operativo.

### 3. Levantar Wazuh en GCP

```powershell
terraform -chdir="terraform/wazuh-deploy" init
terraform -chdir="terraform/wazuh-deploy" validate
terraform -chdir="terraform/wazuh-deploy" plan
terraform -chdir="terraform/wazuh-deploy" apply
```

### 4. Aplicar configuración Wazuh

```powershell
.\scripts\apply-wazuh-config.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a"
```

### 5. Importar dashboards

Define la contraseña del dashboard como variable de entorno antes de importar:

```powershell
$env:WAZUH_DASHBOARD_PASSWORD = "CAMBIAR_EN_PASSWORD_MANAGER"
.\scripts\import-wazuh-dashboards.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a" -DashboardUser "admin" -DashboardPassword $env:WAZUH_DASHBOARD_PASSWORD
```

### 6. Levantar endpoints Linux locales

```powershell
.\scripts\local-docker-lab.ps1 -Scope Linux -Action up
```

### 7. Revisar estado del laboratorio

```powershell
.\scripts\lab-master.ps1 -Action status
.\scripts\local-docker-lab.ps1 -Scope Linux -Action status
```

### 8. Generar eventos seguros de demo

Opcion recomendada para una demo completa:

```powershell
& "C:\Program Files\Git\bin\bash.exe" demo-mode/run_all_demo_events.sh
```

Eventos especificos dentro de contenedores:

```powershell
$env:WAZUH_MANAGER_IP="34.135.112.15"
docker compose -f docker-compose.endpoints.yml exec pyme-demo-target /usr/local/bin/pyme-demo-generate-events.sh
docker compose -f docker-compose.endpoints.yml exec pyme-demo-target /usr/local/bin/wazuh-demo-generate-module-events.sh
docker compose -f docker-compose.endpoints.yml exec edge-gateway /usr/local/bin/gateway-demo-generate-events.sh
docker compose -f docker-compose.endpoints.yml exec db-server /usr/local/bin/db-demo-generate-events.sh
docker compose -f docker-compose.endpoints.yml exec docker-host /usr/local/bin/docker-demo-generate-events.sh
docker compose -f docker-compose.endpoints.yml exec linux-ui-workstation /usr/local/bin/simulate-confidential-ransomware-burst.sh
docker compose -f docker-compose.endpoints.yml exec linux-ui-workstation /usr/local/bin/linux-ui-demo-auth-failure.sh
```

### 9. Validar en Wazuh

Buscar en Security Events:

```text
agent.name: "linux-ui-workstation" and rule.id: (100010 or 100015 or 100020 or 100030)
agent.name: "edge-gateway" and rule.groups: edge_gateway
agent.name: "db-server" and rule.groups: database_endpoint
agent.name: "docker-host" and rule.groups: docker_host
agent.name: "pyme-demo-target"
rule.groups: wazuh_module_visibility
rule.id >= 100300 and rule.id <= 100315
```

## Operación con script maestro

El script `scripts/lab-master.ps1` centraliza operación del laboratorio:

```powershell
.\scripts\lab-master.ps1 -Action menu
.\scripts\lab-master.ps1 -Action status
.\scripts\lab-master.ps1 -Action full-start
.\scripts\lab-master.ps1 -Action cost-saver
.\scripts\lab-master.ps1 -Action stop-linux
.\scripts\lab-master.ps1 -Action start-linux
```

`cost-saver` detiene los contenedores locales y apaga la VM de Wazuh, pero no destruye la infraestructura. La IP pública del manager debe mantenerse porque Terraform reserva y asigna `wazuh-server-public-ip` como IP estática. Al ejecutar `full-start`, el script vuelve a resolver la IP real desde GCP antes de levantar los agentes locales.

Acciones destructivas como `destroy-gcp` o `destroy-linux` deben ejecutarse solo cuando se quiera eliminar infraestructura o volúmenes del laboratorio.

## Cómo documentar cambios

Cada cambio relevante debe quedar documentado:

1. Actualizar el archivo técnico afectado en `docs/`.
2. Registrar cambios visibles para clientes en `CHANGELOG.md` cuando exista.
3. Agregar comandos de prueba usados.
4. Indicar impacto en seguridad, costos o demo.
5. No incluir secretos, IPs privadas de clientes, datos personales ni evidencia real.
6. Si se agrega una regla Wazuh, documentar:
   - ID de regla.
   - Severidad.
   - Grupo.
   - Fuente de logs.
   - Escenario de demo asociado.
   - Consulta recomendada en dashboard.

Formato sugerido para cambios:

```text
Fecha:
Cambio:
Motivo:
Archivos modificados:
Validación:
Riesgo:
Rollback:
```

## Criterios de aceptación del MVP

El MVP está listo para mostrarse a un cliente cuando:

- Wazuh sea accesible de forma segura.
- Los agentes estén conectados y activos.
- Los contenedores locales estén monitoreados.
- FIM genere alertas esperadas.
- Vulnerability Detection esté funcionando.
- SCA esté generando baseline.
- Existan al menos cinco escenarios de demo repetibles.
- El dashboard técnico esté preparado.
- El dashboard ejecutivo tenga KPIs definidos.
- Exista un reporte PDF demo.
- Las notificaciones o tickets estén integrados al menos en versión básica.
- Los playbooks SOC estén documentados.
- El onboarding esté documentado.
- El hardening mínimo de GCP esté aplicado.
- La demo de 10 y 30 minutos esté ensayada.
- El material comercial esté listo.

## Documentación relacionada

Documentos existentes:

- `ansible/windows-ad-lab/README.md`
- `docs/local-docker-endpoints.md`
- `docs/lab-master.md`
- `docs/linux-ui-sensitive-lab.md`
- `docs/endpoint-noise-playbook.md`
- `docs/endpoint-onboarding.md`
- `docs/soc-dashboard-queries.md`
- `docs/soc-mvp-playbook.md`
- `docs/wazuh-soc-dashboards.md`
- `docs/wazuh-agent-modules-demo.md`
- `docs/n8n-vulnerability-automation.md`
- `docs/n8n-alert-jira-automation.md`
- `integrations/n8n/README.md`

Documentos por crear:

- `ARCHITECTURE.md`
- `DEPLOYMENT_GUIDE.md`
- `DEMO_GUIDE.md`
- `CLIENT_PRESENTATION_SCRIPT.md`
- `SECURITY_HARDENING.md`
- `ONBOARDING_RUNBOOK.md`
- `INCIDENT_RESPONSE_PLAYBOOKS.md`
- `REPORTING_GUIDE.md`
- `API_INTEGRATION_GUIDE.md`
- `ROADMAP.md`
- `CHANGELOG.md`

## Próximos pasos

1. Crear `ARCHITECTURE.md` con arquitectura objetivo, flujo de datos, riesgos y separación futura por cliente.
2. Crear `DEMO_GUIDE.md` con los cinco escenarios comerciales.
3. Crear `SECURITY_HARDENING.md` y aplicar controles mínimos antes de demos externas.
4. Crear `REPORTING_GUIDE.md` con plantilla de reporte ejecutivo y técnico.
5. Crear `INCIDENT_RESPONSE_PLAYBOOKS.md` con playbooks SOC.
6. Crear `ONBOARDING_RUNBOOK.md` para assessments de 7 a 14 días.
7. Implementar dashboard ejecutivo y Security Score.
8. Implementar integración inicial con notificaciones y tickets.

## Principio rector

Este proyecto debe ayudar a vender confianza, no miedo. La demo debe mostrar visibilidad, priorización, evidencia y respuesta clara. El cliente debe salir entendiendo qué riesgo tiene, qué se está monitoreando, qué acciones se recomiendan y qué valor recibe al contratar el servicio.
