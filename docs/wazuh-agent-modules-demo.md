# Demo de modulos del agente Wazuh en contenedores

## Objetivo

Este documento explica como quedan activados y demostrables los modulos principales del agente Wazuh dentro de los contenedores Linux locales del laboratorio.

La demo es defensiva y controlada. No crea malware, no explota sistemas, no intenta evadir controles y no ejecuta acciones contra terceros.

## Alcance

Endpoints incluidos:

- `pyme-demo-target`
- `metasploit-node`
- `edge-gateway`
- `db-server`
- `docker-host`
- `linux-ui-workstation`

Dashboard visible:

```text
SOC Modulos Wazuh - Demo tecnico
```

URL esperada:

```text
https://<WAZUH_IP>/app/dashboards#/view/soc-modulos-wazuh-dashboard
```

## Modulos configurados

| Modulo | Donde vive | Configuracion | Evidencia visible |
|---|---|---|---|
| Log collector | Todos los contenedores | `localfile` sobre `/var/log/wazuh-agent-modules-demo.log` y `/var/log/cloud-gcp-demo.log` | Reglas `100300`, `100301`, `100312` |
| Command execution | Todos los contenedores | `wodle name="command"` ejecutando scripts locales autorizados | Reglas `100302`, `100303` |
| FIM | Todos los contenedores | `syscheck` monitorea rutas del perfil y `/opt/wazuh-module-demo` | Reglas `100304`, reglas `syscheck` nativas |
| SCA | Todos los contenedores | Politica custom `/var/ossec/etc/shared/wazuh_demo_sca.yml` | Regla `100305`, reglas `sca` nativas |
| System inventory | Todos los contenedores | `wodle name="syscollector"` con OS, red, paquetes, puertos y procesos | Regla `100306`, inventario del agente |
| Malware detection | Todos los contenedores | `rootcheck` habilitado | Regla `100307`, reglas `rootcheck` nativas si aplica |
| Active Response | Todos los contenedores | Respuesta segura `module-demo-response.sh` en modo evidencia | Reglas `100309`, `100310` |
| Container security | `docker-host` | `wodle name="docker-listener"` y socket Docker montado de solo lectura | Regla `100311`, reglas `docker` nativas |
| Cloud security | Todos los contenedores | Telemetria GCP simulada por log local, sin credenciales cloud en contenedores | Reglas `100312`, `100313`, `100314` |
| Vulnerability Detection | Manager + inventario de agentes | El manager ya tiene `vulnerability-detection`; los agentes envian inventario con `syscollector` | Regla `100308`, modulo de vulnerabilidades de Wazuh |

## Archivos modificados

- `docker/linux-endpoints/entrypoint.sh`
- `docker/linux-endpoints/Dockerfile`
- `docker-compose.endpoints.yml`
- `terraform/config/wazuh-manager/etc/rules/local_rules.xml`
- `terraform/config/wazuh-manager/etc/ossec.conf`
- `terraform/config/wazuh-manager/active-response/bin/module-demo-response.sh`
- `scripts/import-wazuh-dashboards.ps1`
- `dashboards/wazuh-soc-dashboards.ndjson`

## Como activar los cambios

Aplicar configuracion del manager:

```powershell
.\scripts\apply-wazuh-config.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a"
```

Reconstruir endpoints Linux:

```powershell
.\scripts\lab-master.ps1 -Action start-linux
```

Importar dashboards:

```powershell
.\scripts\import-wazuh-dashboards.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a" -DashboardUser "admin" -DashboardPassword "SecretPassword"
```

## Generar eventos de demo

Ejecutar en todos los contenedores:

```powershell
docker compose -f docker-compose.endpoints.yml exec pyme-demo-target /usr/local/bin/wazuh-demo-generate-module-events.sh
docker compose -f docker-compose.endpoints.yml exec metasploit-node /usr/local/bin/wazuh-demo-generate-module-events.sh
docker compose -f docker-compose.endpoints.yml exec edge-gateway /usr/local/bin/wazuh-demo-generate-module-events.sh
docker compose -f docker-compose.endpoints.yml exec db-server /usr/local/bin/wazuh-demo-generate-module-events.sh
docker compose -f docker-compose.endpoints.yml exec docker-host /usr/local/bin/wazuh-demo-generate-module-events.sh
docker compose -f docker-compose.endpoints.yml exec linux-ui-workstation /usr/local/bin/wazuh-demo-generate-module-events.sh
```

El script genera:

- Eventos syslog controlados por modulo.
- Cambio FIM en `/opt/wazuh-module-demo/config/module-baseline.conf`.
- Evidencia JSON en `/opt/wazuh-module-demo/evidence`.
- Eventos cloud GCP simulados en `/var/log/cloud-gcp-demo.log`.
- Trigger de Active Response seguro.

## Consultas en Wazuh

Vista general:

```text
rule.groups: wazuh_module_visibility
```

Log collector:

```text
rule.id: 100301
```

Command execution:

```text
rule.groups: wazuh_agent_command
```

FIM:

```text
rule.groups: wazuh_agent_fim or (rule.groups: syscheck and syscheck.path: "/opt/wazuh-module-demo*")
```

SCA:

```text
rule.groups: wazuh_agent_sca or rule.groups: sca
```

System inventory / vulnerability:

```text
rule.groups: (wazuh_agent_syscollector or wazuh_agent_vulnerability_detection or vulnerability_management)
```

Malware detection / rootcheck:

```text
rule.groups: (wazuh_agent_rootcheck or rootcheck)
```

Active Response:

```text
rule.groups: wazuh_agent_active_response
```

Container security:

```text
agent.name: "docker-host" and rule.groups: (wazuh_agent_container_security or docker)
```

Cloud security demo:

```text
rule.groups: wazuh_agent_cloud_security
```

## Validacion tecnica en contenedor

Ver configuracion del agente:

```powershell
docker compose -f docker-compose.endpoints.yml exec docker-host grep -n "LOCAL_DOCKER_WAZUH" /var/ossec/etc/ossec.conf
```

Probar configuracion de modulos:

```powershell
docker compose -f docker-compose.endpoints.yml exec docker-host /var/ossec/bin/wazuh-modulesd -t
docker compose -f docker-compose.endpoints.yml exec docker-host /var/ossec/bin/wazuh-logcollector -t
docker compose -f docker-compose.endpoints.yml exec docker-host /var/ossec/bin/wazuh-syscheckd -t
```

Ver evidencias:

```powershell
docker compose -f docker-compose.endpoints.yml exec docker-host ls -la /opt/wazuh-module-demo/evidence
```

## Riesgos y mitigaciones

- `docker-host` monta `/var/run/docker.sock` para Docker listener. Esto es util para demo, pero en produccion debe tratarse como acceso privilegiado al Docker Engine.
- No se habilitan comandos remotos desde el manager hacia agentes. Los comandos configurados son locales y controlados.
- Active Response no bloquea IPs ni mata procesos en esta demo de modulos; solo escribe evidencia.
- Cloud security esta simulado en contenedores para no guardar credenciales GCP dentro del cliente demo. La integracion real debe hacerse con Pub/Sub/log sinks y cuentas de servicio dedicadas.
- Malware detection se muestra con Rootcheck y eventos seguros; no se crea malware ni binarios sospechosos reales.

## Referencias oficiales

- Local configuration `ossec.conf`: https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/index.html
- Command monitoring: https://documentation.wazuh.com/current/user-manual/capabilities/command-monitoring/configuration.html
- File integrity monitoring: https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/syscheck.html
- SCA: https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/sca.html
- System inventory: https://documentation.wazuh.com/current/user-manual/capabilities/system-inventory/configuration.html
- Docker monitoring: https://documentation.wazuh.com/current/user-manual/capabilities/container-security/monitoring-docker.html
- Active Response: https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/active-response.html
