# Wazuh IaC en GCP para PYMES en Mexico

Este repositorio despliega un MVP de Wazuh gestionado en Google Cloud Platform para demostrar una oferta de SIEM/XDR orientada a PYMES mexicanas. La solución fue adaptada con base en los PDFs de la carpeta:

- `Wazuh Analisis Estrategico Integral.pdf`
- `Wazuh Guia Comercial y Certificaciones.pdf`

El objetivo ya no es solo levantar Wazuh, sino mostrar una propuesta comercial y técnica: monitoreo 24/7, evidencia de cumplimiento, detección de amenazas, escaneo inicial y reportes ejecutivos para sectores como manufactura, retail, fintech, logística y salud.

Si quieres posicionarlo como servicio SOC para clientes, revisa también:

- `docs/soc-mvp-playbook.md`
- `docs/soc-dashboard-queries.md`
- `docs/endpoint-onboarding.md`
- `docs/endpoint-noise-playbook.md`
- `docs/wazuh-soc-dashboards.md`

## Que despliega

- Una VPC privada `vpc-wazuh` con subnet `10.0.1.0/24`.
- Un `wazuh-server` single-node con Wazuh Docker `v4.13.0`.
- Un endpoint `pyme-demo-target` con Apache, Docker, Juice Shop y agente Wazuh.
- Un endpoint `metasploit-node` con Metasploit Framework y agente Wazuh.
- Un endpoint `edge-gateway` con nftables, WireGuard y agente Wazuh.
- Un endpoint `db-server` con MariaDB y agente Wazuh.
- Un endpoint `docker-host` con Docker, portal demo y agente Wazuh.
- Un panel web en el target con botones para lanzar pruebas controladas contra Juice Shop.
- Artefactos controlados de cumplimiento en `/opt/pyme-compliance`.
- Un laboratorio vulnerable con Juice Shop en el puerto `3000`.
- Reglas locales Wazuh `100100-100194` para threat intelligence, ataques web, fuerza bruta SSH, FIM, correlación SOC, actividad del endpoint Metasploit, red/firewall/VPN, base de datos, docker host y acciones del panel.
- Integración con lista AlienVault convertida a CDB para bloqueo activo.
- Firewall más segmentado: dashboard/SSH por `admin_source_ranges`, target demo por `target_source_ranges`, y puertos de agente desde la subnet privada mas `extra_agent_source_ranges` cuando necesites enrolar endpoints externos.

## Requisitos

- Proyecto GCP con billing habilitado.
- APIs habilitadas:
  - Compute Engine API
  - Cloud Resource Manager API
  - IAM API
- Terraform instalado.
- Google Cloud CLI instalado.
- Permisos para crear Compute Engine, VPC, firewall rules y discos.

En esta máquina ya se detectaron `terraform` y `gcloud`, pero si corres desde otra máquina instala ambos primero.

## Configuracion rapida

Desde PowerShell:

```powershell

gcloud auth login
gcloud auth application-default login
gcloud config set project wazuh-iac-on-gcp
gcloud config set compute/zone us-central1-a

cd terraform\wazuh-deploy
Copy-Item terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars
```

Edita `terraform.tfvars` antes de aplicar. Para una demo segura, cambia:

```hcl
admin_source_ranges = ["TU_IP_PUBLICA/32"]
target_source_ranges = ["TU_IP_PUBLICA/32"]
extra_agent_source_ranges = ["TU_IP_PUBLICA/32"]
```

Si lo dejas en `0.0.0.0/0`, cualquiera en internet podrá intentar llegar al dashboard, SSH o laboratorio demo según la regla correspondiente.
`extra_agent_source_ranges` sirve para permitir el alta de endpoints externos como tu laptop, VMs fuera de GCP o redes conectadas por VPN.

## Comandos rapidos

### Levantar todo desde cero

Ejecuta esto desde la raiz del repo en PowerShell:

```powershell
cd "C:\Users\Jehosua Joya\Desktop\Github Repos\Wazuh-IaC-on-GCP"

gcloud auth login
gcloud auth application-default login
gcloud config set project wazuh-iac-on-gcp
gcloud config set compute/zone us-central1-a

if (-not (Test-Path "terraform\wazuh-deploy\terraform.tfvars")) {
    Copy-Item "terraform\wazuh-deploy\terraform.tfvars.example" "terraform\wazuh-deploy\terraform.tfvars"
}

notepad "terraform\wazuh-deploy\terraform.tfvars"

terraform -chdir="terraform/wazuh-deploy" init
terraform -chdir="terraform/wazuh-deploy" validate
terraform -chdir="terraform/wazuh-deploy" plan
terraform -chdir="terraform/wazuh-deploy" apply

.\scripts\apply-wazuh-config.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a"
.\scripts\import-wazuh-dashboards.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a" -DashboardUser "admin" -DashboardPassword "SecretPassword"

terraform -chdir="terraform/wazuh-deploy" output
```

Esto hace:

- autentica `gcloud`
- prepara `terraform.tfvars`
- crea toda la infraestructura en GCP
- aplica reglas y tuning de Wazuh
- importa los dashboards SOC
- imprime las URLs e IPs finales

### Borrar todo en GCP

Ejecuta esto desde la raiz del repo:

```powershell
cd "C:\Users\Jehosua Joya\Desktop\Github Repos\Wazuh-IaC-on-GCP"

gcloud auth login
gcloud auth application-default login
gcloud config set project wazuh-iac-on-gcp
gcloud config set compute/zone us-central1-a

terraform -chdir="terraform/wazuh-deploy" plan -destroy
terraform -chdir="terraform/wazuh-deploy" destroy
```

Si quieres borrarlo sin confirmacion interactiva:

```powershell
terraform -chdir="terraform/wazuh-deploy" destroy -auto-approve
```

Esto elimina todo lo administrado por este estado:

- VMs
- discos
- VPC y subnet
- reglas de firewall
- IPs y outputs asociados

Nota:
Usa siempre `terraform -chdir="terraform/wazuh-deploy"` o entra a esa carpeta antes de correr `destroy`.
Si lo ejecutas desde otra ruta con otro estado, Terraform puede decir que no hay nada por borrar aunque los recursos sigan vivos.

## Despliegue

Desde `terraform\wazuh-deploy`:

```powershell
terraform init
terraform validate
terraform plan
terraform apply
terraform output
```

Si ya tenias un despliegue anterior, revisa bien el `terraform plan`: la versión actual cambia nombres, tags, startup scripts y reglas de firewall, por lo que Terraform puede reemplazar VMs existentes.

## Aplicar reglas y tuning de Wazuh

El startup de la VM levanta Wazuh. Después aplica la configuración gestionada del manager:

```powershell
cd "C:\Users\Jehosua Joya\Desktop\Github Repos\Wazuh-IaC-on-GCP"
.\scripts\apply-wazuh-config.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a"
```

Esto copia `terraform/config/wazuh-manager` al manager y aplica:

- `ossec.conf` con FIM, SCA, vulnerability detection y active response.
- `local_rules.xml` con reglas PYME Mexico.
- Lista AlienVault para reputación IP.
- Conversión de IP set a CDB list.

## Acceso

Obtén URLs con:

```powershell
cd terraform\wazuh-deploy
terraform output
```

El dashboard queda en:

```text
https://IP_PUBLICA_WAZUH
```

Credenciales por defecto de Wazuh Docker:

```text
Usuario: admin
Password: SecretPassword
```

Cambia la contraseña al primer acceso.

## Demo comercial y tecnica

Después del despliegue, el target expone:

- Attack Control Center: `http://IP_PUBLICA_TARGET/panel/`
- Juice Shop por Apache y misma origin del panel: `http://IP_PUBLICA_TARGET/`
- Juice Shop directo al contenedor: `http://IP_PUBLICA_TARGET:3000`

El Attack Control Center carga Juice Shop en la misma pagina y muestra botones para:

- SQLi login controlado.
- XSS search probe.
- Recon de API/productos.
- Cambio de evidencia FIM.
- Ejecucion completa de todas las pruebas.

Cada boton registra un evento en `/var/log/pyme-attack-panel.log`, actualiza el historial visible en la web y manda telemetria al agente Wazuh. En el dashboard puedes buscar:

```text
rule.id: 100140 or rule.id: 100141 or rule.id: 100142 or rule.id: 100143 or rule.id: 100144 or rule.id: 100145 or rule.id: 100150 or rule.id: 100151 or rule.id: 100152 or rule.id: 100153
```

Para consultas tipo SOC y listas operativas ya preparadas, revisa `docs/soc-dashboard-queries.md`.
Para una guia de que endpoint disparar y que deberias ver, revisa `docs/endpoint-noise-playbook.md`.
Si quieres importar dashboards listos para cliente y SOC, revisa `docs/wazuh-soc-dashboards.md`.

Tambien se despliega un endpoint ofensivo monitoreado:

- Metasploit node: `metasploit-node`
- Agente esperado en Wazuh: `metasploit-node`

Para conectarte:

```powershell
gcloud compute ssh metasploit-node --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo /usr/local/bin/msf-lab-console"
```

Para generar telemetria controlada del endpoint Metasploit:

```powershell
gcloud compute ssh metasploit-node --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo /usr/local/bin/metasploit-demo-generate-events.sh"
```

Y en Wazuh puedes buscar:

```text
agent.name: "metasploit-node" and (rule.id: 100160 or rule.id: 100161 or rule.id: 100162 or rule.id: 100163 or rule.id: 100164)
```

Tambien se despliegan endpoints adicionales para ampliar el alcance del laboratorio:

- `edge-gateway`: firewall/VPN con WireGuard y nftables.
- `db-server`: base de datos MariaDB con datos demo y eventos de acceso sensible.
- `docker-host`: host de contenedores con portal web demo.

Para generar telemetria controlada:

```powershell
gcloud compute ssh edge-gateway --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo /usr/local/bin/gateway-demo-generate-events.sh"
gcloud compute ssh db-server --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo /usr/local/bin/db-demo-generate-events.sh"
gcloud compute ssh docker-host --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo /usr/local/bin/docker-demo-generate-events.sh"
```

Consultas recomendadas:

```text
agent.name: "edge-gateway" and rule.groups: edge_gateway
agent.name: "db-server" and rule.groups: database_endpoint
agent.name: "docker-host" and rule.groups: docker_host
rule.groups: infrastructure_incident
```

Para generar eventos controlados de demo:

```powershell
gcloud compute ssh pyme-demo-target --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo /usr/local/bin/pyme-demo-generate-events.sh"
```

Ese script genera:

- Intento de login SSH fallido.
- Evento web tipo inyección contra Apache.
- Cambio en evidencia de cumplimiento.
- Cambio en carpeta con permisos débiles.
- Evento `pyme-demo` para reporte ejecutivo.

En Wazuh revisa:

- Alertas de reglas `100100-100194`.
- File Integrity Monitoring sobre `/opt/pyme-compliance`.
- SCA y vulnerabilidades del endpoint.
- Telemetría web de Apache y Juice Shop.
- Inventario, vulnerabilidades y actividad del endpoint Metasploit.

## Como se alineo con la propuesta de los PDFs

- Enfoque PYME: el target simula una empresa mexicana con datos personales, web app vulnerable y evidencia de auditoria.
- Cumplimiento: reglas y grupos etiquetan LFPDPPP, PCI-DSS e ISO 27001.
- Venta consultiva: la landing page y el script demo soportan el discurso de "escaneo gratuito" y "evidencia ejecutiva".
- Monitoreo gestionado: `apply-wazuh-config.ps1` permite operar el tuning como servicio recurrente.
- Diferenciacion: se activa FIM, SCA, vulnerability detection, active response y threat intelligence sin licencias propietarias.

## Actualizar configuracion

Modifica archivos en:

```text
terraform/config/wazuh-manager
```

Luego ejecuta:

```powershell
.\scripts\apply-wazuh-config.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a"
```

Si quieres agregar endpoints nuevos al manager cloud, revisa `docs/endpoint-onboarding.md`.
Para importar los dashboards ejecutivo y operativo en tu Wazuh actual:

```powershell
.\scripts\import-wazuh-dashboards.ps1
```

También existe GitHub Actions para despliegue inicial y actualización de configuración, pero localmente el flujo anterior es más directo.

## Apagar o destruir

Para eliminar todos los recursos creados por Terraform:

```powershell
cd "C:\Users\Jehosua Joya\Desktop\Github Repos\Wazuh-IaC-on-GCP"
terraform -chdir="terraform/wazuh-deploy" plan -destroy
terraform -chdir="terraform/wazuh-deploy" destroy
```

Esto borra VMs, discos, red y reglas de firewall administradas por este estado.

## Costos y seguridad

Este laboratorio crea recursos que generan costo en GCP. No lo dejes encendido si no lo vas a usar.

Antes de mostrarlo a prospectos:

- Restringe `admin_source_ranges`.
- Cambia la contraseña default del dashboard.
- No uses datos reales en `/opt/pyme-compliance`.
- Revisa que el laboratorio Juice Shop solo esté expuesto al público deseado.
