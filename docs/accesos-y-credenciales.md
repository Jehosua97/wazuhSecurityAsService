# Accesos y credenciales

Esta pagina dice donde entrar y como recuperar credenciales. No guardamos secretos reales en el repo.

## Servicios principales

| Servicio | Como entrar | Usuario | Password |
|---|---|---|---|
| Wazuh Dashboard | `terraform -chdir=terraform/wazuh-deploy output wazuh_dashboard_url` | `admin` | password manager o variable local |
| n8n cloud | `terraform -chdir=terraform/wazuh-deploy output n8n_url` | `terraform -chdir=terraform/wazuh-deploy output n8n_basic_auth_user` | comando `n8n_credentials_command` |
| Linux UI Ubuntu | RDP a `linux_ui_public_ip` | `esquivel` | comando `linux_ui_rdp_credentials_command` |
| RHEL UI | RDP a `34.75.69.7:3389` | `esquivel` | archivo `/root/rhel-ui-rdp-credentials.txt` |
| Windows Server | RDP a `windows_server_public_ip` | `Administrator` | `windows_rdp_password_command` |
| Kali | SSH con `kali_shell_command` | usuario GCP | SSH/IAM |

## Recuperar password de n8n

```powershell
terraform -chdir=terraform/wazuh-deploy output -raw n8n_credentials_command
```

Copia y ejecuta el comando que imprime Terraform.

## Recuperar password de Linux UI Ubuntu

```powershell
terraform -chdir=terraform/wazuh-deploy output -raw linux_ui_rdp_credentials_command
```

## Recuperar password de RHEL UI

```powershell
gcloud compute ssh rhel-ui-workstation --project=wazuh-iac-on-gcp --zone=us-east1-b --command="sudo cat /root/rhel-ui-rdp-credentials.txt"
```

## Resetear password de Windows Server

```powershell
terraform -chdir=terraform/wazuh-deploy output -raw windows_rdp_password_command
```

## Donde si van los secretos

- n8n cloud: `/opt/wazuh-n8n/.env` dentro de la VM `n8n-automation`.
- n8n local: `integrations/n8n/.env`, ignorado por Git.
- Tokens Jira, OpenAI y Telegram: password manager o GCP Secret Manager.
- Passwords temporales de VM: archivos bajo `/root/*credentials*.txt` en la VM correspondiente.

## Donde no van

No guardar secretos en:

- `README.md`
- `docs/`
- `.env.example`
- `terraform.tfvars.example`
- screenshots
- tickets o evidencias commiteadas
