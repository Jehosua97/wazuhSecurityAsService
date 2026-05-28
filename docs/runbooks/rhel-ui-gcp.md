# RHEL UI en GCP

Este runbook explica como usar la VM Red Hat con interfaz grafica para demos visuales.

## Estado actual

| Campo | Valor |
|---|---|
| VM | `rhel-ui-workstation` |
| Proyecto | `wazuh-iac-on-gcp` |
| Zona | `us-east1-b` |
| IP publica | `34.75.69.7` |
| Sistema | Red Hat Enterprise Linux 9.6 |
| Escritorio | GNOME |
| Acceso remoto | XRDP, puerto `3389` |
| Usuario demo | `esquivel` |

Nota: esta VM ya existe en GCP y fue preparada con `scripts/configure-rhel-ui-workstation.sh`. Actualmente esta fuera del modulo Terraform principal; el siguiente paso ideal seria modelarla tambien en Terraform.

## Conectarse por RDP

Desde Windows:

```powershell
mstsc /v:34.75.69.7:3389
```

Usuario:

```text
esquivel
```

Para ver la password guardada en la VM:

```powershell
gcloud compute ssh rhel-ui-workstation --project=wazuh-iac-on-gcp --zone=us-east1-b --command="sudo cat /root/rhel-ui-rdp-credentials.txt"
```

## Si RDP directo no conecta

Usa tunel SSH:

```powershell
gcloud compute ssh rhel-ui-workstation --project=wazuh-iac-on-gcp --zone=us-east1-b --ssh-flag="-L13389:localhost:3389" --ssh-flag="-N"
```

Luego abre RDP a:

```text
localhost:13389
```

## Validar servicio XRDP

```powershell
gcloud compute ssh rhel-ui-workstation --project=wazuh-iac-on-gcp --zone=us-east1-b --command="systemctl is-active xrdp && sudo ss -ltnp sport = :3389"
```

## Reaplicar setup de escritorio

Si la VM pierde el escritorio o XRDP:

```powershell
gcloud compute scp scripts/configure-rhel-ui-workstation.sh rhel-ui-workstation:/tmp/configure-rhel-ui-workstation.sh --project=wazuh-iac-on-gcp --zone=us-east1-b
gcloud compute ssh rhel-ui-workstation --project=wazuh-iac-on-gcp --zone=us-east1-b --command="sudo bash /tmp/configure-rhel-ui-workstation.sh"
```

## Carpeta de demo

La carpeta preparada para mostrar archivos desde la UI es:

```text
/home/esquivel/Confidencial
```

Tambien aparece como acceso rapido en el escritorio y en Documentos.
