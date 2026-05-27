# Docker y Cloud Security visual

## Que se implementa

Esta demo usa el endpoint `docker-host` como host de contenedores en GCP y lo muestra en Wazuh con tres capas:

- **Docker / Container Security**: el agente Wazuh lee eventos del Docker Engine con `docker-listener`.
- **Docker nativo para la vista de Wazuh**: el lab escribe eventos JSON compatibles con las reglas Docker nativas en `/var/log/docker-native-demo.json`.
- **Cloud Security GCP**: el lab genera eventos seguros de control plane en `/var/log/cloud-gcp-demo.log` para representar cambios cloud sin guardar credenciales GCP dentro del endpoint.

Dashboard:

```text
SOC Docker y Cloud Security - Visual
```

URL:

```text
https://<WAZUH_IP>/app/dashboards#/view/soc-docker-cloud-security-dashboard
```

Mapa:

```text
https://<WAZUH_IP>/app/maps-dashboards#/view/soc-geo-threat-map
```

## Como funciona Docker Security

Wazuh no instala un agente dentro de cada contenedor. El patron del lab es monitorear el **host Docker**:

1. El agente vive en `docker-host`.
2. El modulo `docker-listener` se conecta al Docker Engine local.
3. El agente observa eventos como reinicio de contenedores, creacion, start/stop y pulls de imagenes.
4. Wazuh los procesa con reglas nativas `docker` y con reglas custom del lab:

```text
100191 container_restart
100192 image_pull
100193 config_drift
100311 container_security expected
```

La seccion nativa **Cloud Security > Docker > docker-host** usa campos Docker especificos para llenar sus paneles. Para que esa pantalla tenga datos durante la demo, tambien se genera JSON con:

```text
integration=docker
docker.status=restart|pull|start
docker.Actor.Attributes.image=nginx:alpine|alpine:latest|redis:7-alpine
```

La configuracion persistente quedo en:

```text
terraform/wazuh-deploy/scripts/docker_host_startup.sh.tftpl
```

Bloque clave:

```xml
<wodle name="docker-listener">
  <disabled>no</disabled>
  <interval>2m</interval>
  <attempts>5</attempts>
  <run_on_start>yes</run_on_start>
</wodle>
```

## Como funciona Cloud Security

En produccion, Cloud Security normalmente recolecta eventos del proveedor cloud por APIs o por logs exportados, por ejemplo GCP Audit Logs enviados a Pub/Sub y consumidos por Wazuh.

En este lab se usa una simulacion segura:

- no se guardan llaves de servicio dentro de la VM demo;
- los eventos se escriben en `/var/log/cloud-gcp-demo.log`;
- el agente los lee con `localfile`;
- las reglas `100312`, `100313` y `100314` los muestran como Cloud Security.

Eventos visuales incluidos:

```text
100313 GCP IAM policy change
100314 GCP compute instance stop
```

## Aplicar en la VM viva

```powershell
gcloud compute scp scripts/configure-docker-cloud-security-agent.sh docker-host:/tmp/configure-docker-cloud-security-agent.sh --project=wazuh-iac-on-gcp --zone=us-central1-a
gcloud compute ssh docker-host --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo bash /tmp/configure-docker-cloud-security-agent.sh"
```

## Generar eventos de demo

```powershell
gcloud compute ssh docker-host --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo /usr/local/bin/docker-cloud-security-demo.sh"
```

## Importar visualizaciones

```powershell
.\scripts\import-wazuh-dashboards.ps1
.\scripts\import-wazuh-soc-map.ps1
```

## Queries utiles

Docker y contenedores:

```text
agent.name: "docker-host" and rule.groups: (wazuh_agent_container_security or docker or docker_host or container_platform)
```

Cloud Security GCP:

```text
rule.groups: (wazuh_agent_cloud_security or cloud_security or gcp)
```

Vista combinada:

```text
rule.groups: (wazuh_agent_container_security or docker or docker_host or container_platform or wazuh_agent_cloud_security or cloud_security)
```

## Nota de seguridad

El acceso a `/var/run/docker.sock` equivale a acceso privilegiado al Docker Engine. Para demo esta bien controlado; en produccion debe limitarse al host correcto, con permisos minimos y monitoreo de cambios.
