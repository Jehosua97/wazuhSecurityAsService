# Endpoint Noise Playbook

## Objetivo

Esta guia resume los endpoints monitoreados del MVP y deja un comando concreto para generar telemetria util en Wazuh sin improvisar durante la demo.

## Endpoints del MVP

### 1. `pyme-demo-target`

Rol:

- sitio publico con Apache
- Juice Shop
- panel de ataques controlados
- evidencia FIM y cumplimiento

Ruido recomendado:

```powershell
gcloud compute ssh pyme-demo-target --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo /usr/local/bin/pyme-demo-generate-events.sh"
```

Alternativa visual:

- abre `http://IP_PUBLICA_TARGET/panel/`
- usa `SQLi login`, `API probe`, `FIM change` o `Run all`

Alertas esperadas:

- `100140-100145`
- `100150-100153`

### 2. `metasploit-node`

Rol:

- workstation ofensiva monitoreada
- trazabilidad de uso de herramientas red team dentro del SOC

Ruido recomendado:

```powershell
gcloud compute ssh metasploit-node --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo /usr/local/bin/metasploit-demo-generate-events.sh"
```

Alertas esperadas:

- `100160-100164`

### 3. `edge-gateway`

Rol:

- firewall/VPN del laboratorio
- control de borde para mostrar telemetria de red y cambios de configuracion

Ruido recomendado:

```powershell
gcloud compute ssh edge-gateway --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo /usr/local/bin/gateway-demo-generate-events.sh"
```

Que genera:

- conexion de peer VPN simulada
- bloqueo de firewall
- cambio en configuracion de gateway

Alertas esperadas:

- `100170-100173`
- `100194`

### 4. `db-server`

Rol:

- base de datos monitoreada
- acceso sensible y cambios estructurales para narrativa de cumplimiento y datos personales

Ruido recomendado:

```powershell
gcloud compute ssh db-server --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo /usr/local/bin/db-demo-generate-events.sh"
```

Que genera:

- login fallido
- cambio de esquema
- consulta de datos sensibles

Alertas esperadas:

- `100180-100183`
- `100194`

### 5. `docker-host`

Rol:

- host de contenedores con portal web demo
- visibilidad sobre runtime, cambios y supply chain

Ruido recomendado:

```powershell
gcloud compute ssh docker-host --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo /usr/local/bin/docker-demo-generate-events.sh"
```

Que genera:

- reinicio de contenedor
- pull de imagen
- drift en contenido de la app

Alertas esperadas:

- `100190-100193`
- `100194`

### 6. `windows-server`

Rol:

- Windows Server 2022 monitoreado
- eventos de Application Log para mostrar cobertura Windows
- telemetria de login fallido, proceso privilegiado y cambio de configuracion

Ruido recomendado:

1. Reinicia u obten la contrasena de Administrator:

```powershell
gcloud compute reset-windows-password windows-server --project=wazuh-iac-on-gcp --zone=us-central1-a --user=Administrator
```

2. Entra por RDP y ejecuta:

```powershell
powershell.exe -ExecutionPolicy Bypass -File C:\ProgramData\WazuhDemo\Generate-WindowsDemoEvents.ps1
```

Alertas esperadas:

- `100200-100204`

## Consultas rapidas en Wazuh

Todo el SOC:

```text
rule.groups: (soc_signal or soc_incident)
```

Infraestructura nueva:

```text
agent.name: ("edge-gateway" or "db-server" or "docker-host" or "windows-server")
```

Solo incidentes correlacionados:

```text
rule.groups: soc_incident
```

## Secuencia de demo recomendada

1. Ejecuta ruido en `edge-gateway` para abrir la narrativa de perimetro.
2. Ejecuta ruido en `db-server` para mover la historia hacia datos sensibles.
3. Ejecuta ruido en `docker-host` para hablar de workloads modernos.
4. Muestra `windows-server` para validar cobertura Windows.
5. Cierra con `pyme-demo-target` o `metasploit-node` para mostrar ataque y trazabilidad.

## Nota operativa

Si quieres mostrar cada endpoint por separado en Wazuh, usa:

```text
agent.name: "NOMBRE_DEL_ENDPOINT"
```
