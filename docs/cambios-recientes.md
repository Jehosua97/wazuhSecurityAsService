# Cambios recientes

Resumen humano de lo mas importante. Para detalle completo, usa `CHANGELOG.md` y el historial de Git.

## Mayo 2026

### Documentacion del equipo

- Se agrego sitio MkDocs para leer la documentacion como portal navegable.
- Se agregaron paginas cortas de accesos, operacion diaria, cambios recientes y puesta en marcha.
- Se agrego plantilla de Pull Request para que cada cambio deje pruebas y documentacion.

### RHEL UI para demo visual

- Se preparo `rhel-ui-workstation` en GCP.
- Sistema: Red Hat Enterprise Linux 9.6.
- UI: GNOME + XRDP.
- Usuario demo: `esquivel`.
- Runbook: [RHEL UI en GCP](runbooks/rhel-ui-gcp.md).

### n8n SOC Automation

- n8n vive en GCP como VM persistente.
- Crea tickets Jira para alertas Wazuh P1, P2 y P3.
- Puede agregar analisis de ChatGPT dentro del ticket.
- Puede mandar Telegram para P1/P2.
- Runbook: [n8n SOC Automation](runbooks/n8n-soc-automation.md).

### Docker y Cloud Security visual

- Se configuro telemetria Docker para que aparezca en dashboards.
- Se agrego demo visual de Docker/Cloud Security con eventos controlados.
- Guia: [Docker Cloud Security](docker-cloud-security-visual.md).

### FIM y Active Response

- Linux UI monitorea `/home/esquivel/Confidencial`.
- Se agregaron reglas para FIM, ransomware-like burst, fuerza bruta y escaneo de puertos.
- Active Response puede bloquear IPs por 2 minutos en endpoints conectados, segun la regla configurada.
