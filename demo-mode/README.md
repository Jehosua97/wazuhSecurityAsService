# Demo Mode

Scripts seguros para generar eventos controlados en el laboratorio Wazuh. Estan pensados para demos comerciales, capacitacion interna y generacion de evidencia sin depender de eventos reales.

No ejecutan explotacion real, malware, evasion, persistencia ni acciones contra terceros. Todos los eventos son locales, controlados y reversibles.

## Requisitos

- Wazuh en GCP corriendo.
- Endpoints Linux locales arriba con Docker Compose.
- Ejecutar desde la raiz del repositorio o usando rutas relativas.
- Tener `docker` disponible en PATH.

Levantar endpoints:

```bash
./scripts/local-docker-lab.ps1 -Scope Linux -Action up
```

En PowerShell puedes ejecutar los scripts con Git Bash, WSL o cualquier Bash disponible:

```powershell
& "C:\Program Files\Git\bin\bash.exe" demo-mode/run_all_demo_events.sh
```

En Linux, macOS, WSL o Git Bash interactivo:

```bash
bash demo-mode/run_all_demo_events.sh
```

## Estructura

```text
demo-mode/
├── README.md
├── evidence/
├── logs/
├── lib/
│   └── demo_common.sh
├── 01_fim_critical_file_change.sh
├── 02_permission_change.sh
├── 03_service_restart_event.sh
├── 04_container_lifecycle_event.sh
├── 05_anomalous_logs.sh
├── 06_generate_report_evidence.sh
├── run_all_demo_events.sh
└── reset_demo.sh
```

## Ejecucion rapida

Ejecutar todos los eventos:

```powershell
& "C:\Program Files\Git\bin\bash.exe" demo-mode/run_all_demo_events.sh
```

```bash
bash demo-mode/run_all_demo_events.sh
```

Revertir artefactos temporales:

```powershell
& "C:\Program Files\Git\bin\bash.exe" demo-mode/reset_demo.sh
```

```bash
bash demo-mode/reset_demo.sh
```

Ver evidencias locales:

```bash
ls -la demo-mode/evidence
cat demo-mode/logs/demo-mode.log
```

## Scripts

### 01_fim_critical_file_change.sh

- Objetivo: modificar un archivo controlado en `/Confidencial`.
- Contenedor: `linux-ui-workstation`.
- Evento esperado: FIM sobre carpeta sensible.
- Wazuh: buscar `agent.name: "linux-ui-workstation"` y reglas `100015` o `100010`.
- Evidencia local: `demo-mode/evidence/*_01_fim_critical_file_change.md`.
- Revertir: `bash demo-mode/reset_demo.sh`.
- Riesgo: generar demasiados cambios FIM durante una demo.
- Mitigacion: el script toca un unico archivo controlado.

Ejecucion:

```bash
bash demo-mode/01_fim_critical_file_change.sh
```

### 02_permission_change.sh

- Objetivo: cambiar permisos de un archivo de prueba.
- Contenedor: `pyme-demo-target`.
- Evento esperado: FIM en `/opt/pyme-compliance` y evento `pyme-demo`.
- Wazuh: buscar `agent.name: "pyme-demo-target"` y reglas `100130`, `100131` o `100111`.
- Evidencia local: `demo-mode/evidence/*_02_permission_change.md`.
- Revertir: `bash demo-mode/reset_demo.sh`.
- Riesgo: dejar permisos amplios si se interrumpe la demo.
- Mitigacion: el reset elimina el archivo temporal y restaura permisos del dataset demo.

Ejecucion:

```bash
bash demo-mode/02_permission_change.sh
```

### 03_service_restart_event.sh

- Objetivo: simular un servicio critico detenido y reiniciado sin apagar servicios reales.
- Contenedor: `pyme-demo-target`.
- Evento esperado: log `pyme-demo` y evidencia en `/opt/pyme-compliance/evidence`.
- Wazuh: buscar `full_log: "service_restarted"` o regla `100111`.
- Evidencia local: `demo-mode/evidence/*_03_service_restart_event.md`.
- Revertir: `bash demo-mode/reset_demo.sh`.
- Riesgo: confundir simulacion con caida real.
- Mitigacion: el campo `outcome=simulated` aparece en el log.

Ejecucion:

```bash
bash demo-mode/03_service_restart_event.sh
```

### 04_container_lifecycle_event.sh

- Objetivo: simular contenedor detenido y reiniciado.
- Contenedor: `docker-host`.
- Evento esperado: log `docker-lab` con `container_stop` y `container_restart`.
- Wazuh: buscar `agent.name: "docker-host"` y reglas `100190` o `100191`.
- Evidencia local: `demo-mode/evidence/*_04_container_lifecycle_event.md`.
- Revertir: `bash demo-mode/reset_demo.sh`.
- Riesgo: detener un contenedor real durante una presentacion.
- Mitigacion: el script solo escribe logs controlados, no detiene workloads reales.

Ejecucion:

```bash
bash demo-mode/04_container_lifecycle_event.sh
```

### 05_anomalous_logs.sh

- Objetivo: generar logs anomalos no ofensivos.
- Contenedor: `pyme-demo-target`.
- Evento esperado: errores 503 de healthcheck y evento `pyme-attack-panel`.
- Wazuh: buscar `full_log: "anomalous_log_burst"` o regla `100140`.
- Evidencia local: `demo-mode/evidence/*_05_anomalous_logs.md`.
- Revertir: no requiere rollback; los logs quedan como evidencia.
- Riesgo: que el cliente interprete los 503 como incidente real.
- Mitigacion: explicar que son healthchecks simulados para observabilidad.

Ejecucion:

```bash
bash demo-mode/05_anomalous_logs.sh
```

### 06_generate_report_evidence.sh

- Objetivo: generar un bundle de evidencia para reporte.
- Contenedor: `pyme-demo-target` y host local.
- Evento esperado: FIM sobre `/opt/pyme-compliance/evidence` y evento `pyme-demo`.
- Wazuh: buscar `full_log: "report_evidence_generated"` o reglas `100111`, `100130`, `100131`.
- Evidencia local: `demo-mode/evidence/*_06_report_evidence_bundle.md`.
- Revertir: `bash demo-mode/reset_demo.sh`.
- Riesgo: mezclar evidencia de diferentes clientes.
- Mitigacion: este laboratorio usa datos ficticios; en clientes reales separar carpetas, indices, tenants o despliegues.

Ejecucion:

```bash
bash demo-mode/06_generate_report_evidence.sh
```

## Donde verlo en Wazuh

Consultas utiles:

```text
agent.name: ("pyme-demo-target" or "linux-ui-workstation" or "docker-host")
rule.id: (100015 or 100010 or 100111 or 100130 or 100131 or 100140 or 100190 or 100191)
rule.groups: demo or rule.groups: evidence or rule.groups: soc_signal
```

Para el dashboard ejecutivo, capturar:

- Numero de endpoints activos.
- Alertas criticas generadas.
- Cambios FIM.
- Eventos de contenedores.
- Evidencia generada.
- Recomendacion SOC asociada.

## Como documentar evidencia

Cada script crea un archivo Markdown en `demo-mode/evidence/`. Durante una demo:

1. Ejecuta el script.
2. Espera de 30 a 90 segundos a que Wazuh procese el evento.
3. Captura pantalla de la alerta.
4. Guarda el query usado.
5. Relaciona la alerta con una recomendacion de negocio.
6. Ejecuta `06_generate_report_evidence.sh` para crear el bundle.

## Riesgos generales y mitigaciones

- Riesgo: ejecutar contra un ambiente incorrecto.
  Mitigacion: los scripts apuntan al compose `wazuh-local-endpoints` y validan que los servicios esten arriba.

- Riesgo: mezclar datos reales con demo.
  Mitigacion: usar solo archivos y rutas de laboratorio; no copiar datos de clientes.

- Riesgo: confundir eventos simulados con incidentes reales.
  Mitigacion: todos los logs incluyen `demo-mode`, `pyme-demo`, `simulated` o `controlled`.

- Riesgo: dejar archivos temporales.
  Mitigacion: ejecutar `bash demo-mode/reset_demo.sh` despues de la demo.
