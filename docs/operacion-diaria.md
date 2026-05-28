# Operacion diaria

Esta es la chuleta corta para trabajar sin perderse.

## Antes de cambiar algo

```powershell
git status
git pull
```

Lee:

- [Cambios recientes](cambios-recientes.md)
- `CHANGELOG.md`
- el runbook del componente que vas a tocar

## Ver estado de GCP

```powershell
gcloud compute instances list --project=wazuh-iac-on-gcp
terraform -chdir=terraform/wazuh-deploy output
```

## Aplicar configuracion Wazuh

```powershell
.\scripts\apply-wazuh-config.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a"
```

## Reiniciar solo Wazuh

```powershell
gcloud compute ssh wazuh-server --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo docker restart wazuh.manager"
```

## Revisar n8n

```powershell
terraform -chdir=terraform/wazuh-deploy output n8n_url
terraform -chdir=terraform/wazuh-deploy output -raw n8n_logs_command
terraform -chdir=terraform/wazuh-deploy output -raw n8n_run_alert_tickets_command
```

## Documentar al terminar

Agrega una linea breve en `CHANGELOG.md`.

Si cambiaste una forma de operar, actualiza el runbook. Si no existe, crea uno corto en `docs/runbooks/`.

Usa la plantilla de PR para no olvidar pruebas, accesos o secretos.
