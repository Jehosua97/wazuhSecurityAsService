# Puesta en marcha

Esta pagina es el camino feliz para levantar o validar el lab sin leer todo el repo.

## 1. Preparar herramientas

Necesitas:

- Google Cloud SDK autenticado.
- Terraform.
- PowerShell.
- Docker Desktop solo si vas a usar fallback local.

Valida acceso a GCP:

```powershell
gcloud auth list
gcloud config get-value project
```

## 2. Revisar variables locales

El archivo real de Terraform no se commitea:

```powershell
Copy-Item terraform\wazuh-deploy\terraform.tfvars.example terraform\wazuh-deploy\terraform.tfvars
notepad terraform\wazuh-deploy\terraform.tfvars
```

Antes de usarlo en serio, restringe `admin_source_ranges` y `n8n_source_ranges` a tu IP publica `/32`.

## 3. Crear o actualizar infraestructura

```powershell
terraform -chdir=terraform/wazuh-deploy init
terraform -chdir=terraform/wazuh-deploy plan
terraform -chdir=terraform/wazuh-deploy apply
```

## 4. Aplicar configuracion Wazuh

```powershell
.\scripts\apply-wazuh-config.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a"
```

## 5. Importar dashboards y mapa

Define la password del Dashboard fuera del repo:

```powershell
$env:WAZUH_DASHBOARD_PASSWORD = "CAMBIAR_EN_PASSWORD_MANAGER"
.\scripts\import-wazuh-dashboards.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a" -DashboardUser "admin" -DashboardPassword $env:WAZUH_DASHBOARD_PASSWORD
.\scripts\import-wazuh-soc-map.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a" -DashboardUser "admin" -DashboardPassword $env:WAZUH_DASHBOARD_PASSWORD
```

## 6. Validar URLs y comandos utiles

```powershell
terraform -chdir=terraform/wazuh-deploy output wazuh_dashboard_url
terraform -chdir=terraform/wazuh-deploy output n8n_url
terraform -chdir=terraform/wazuh-deploy output -raw n8n_credentials_command
terraform -chdir=terraform/wazuh-deploy output -raw n8n_run_alert_tickets_command
```

## Si algo falla

Empieza por [Operacion diaria](operacion-diaria.md). Ahi estan los comandos de estado y los reinicios mas comunes.
