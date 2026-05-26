# Linux UI sensitive-folder lab

Este flujo prepara un endpoint Linux con interfaz grafica para monitorear una carpeta sensible visible desde Documentos, detectar comportamiento tipo ransomware, intentos fallidos contra el usuario `esquivel` y escaneos de puertos.

En el despliegue GCP actual, Terraform crea esta maquina:

```text
linux-ui-workstation
```

El escritorio usa XFCE + XRDP. La carpeta sensible real y monitoreada es `/home/esquivel/Confidencial`. Tambien se mantiene `/Confidencial` como enlace de compatibilidad para comandos viejos.

```text
/home/esquivel/Confidencial
/home/esquivel/Documents/Confidencial
/home/esquivel/Documentos/Confidencial
/home/esquivel/Desktop/Confidencial
```

## Rutas configuradas

Manager:

- Reglas: `/var/ossec/etc/rules/local_rules.xml`
- Decoder firewall-drop: `/var/ossec/etc/decoders/local_decoder.xml`

Agente Linux UI:

- Configuracion del agente: `/var/ossec/etc/ossec.conf`
- Carpeta sensible real: `/home/esquivel/Confidencial`
- Acceso desde documentos: `~/Documentos/Confidencial` o `~/Documents/Confidencial`
- Logs de autenticacion: `/var/log/auth.log`
- Logs de firewall/kernel: `/var/log/kern.log`
- Simulador ransomware: `/usr/local/bin/simulate-confidential-ransomware-burst.sh`

## Reglas agregadas

- `100015`, nivel 10: DLP/FIM sobre cambios, creaciones o borrados en `/home/esquivel/Confidencial`.
- `100010`, nivel 12: heuristica ransomware, 4 eventos FIM en 10 segundos, MITRE `T1486`.
- `100020`, nivel 10: autenticacion fallida SSH/su contra el usuario `esquivel`.
- `100029`, nivel 3: evento base de firewall drop con prefijo `wazuh-fw-drop:`.
- `100030`, nivel 10: escaneo de puertos desde la misma IP origen, MITRE `T1595`.

## Preparar el Manager

Desde la raiz del repo:

```powershell
.\scripts\apply-wazuh-config.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a"
```

Esto copia `local_rules.xml`, `local_decoder.xml` y reinicia el manager.

## Preparar el Agente Linux UI

### Opcion A: VM GCP creada por Terraform

Si estas usando la infraestructura de este repo, no tienes que instalarlo manualmente. Terraform ya crea `linux-ui-workstation`, instala XRDP, crea el usuario `esquivel`, configura Wazuh Agent y prepara `/home/esquivel/Confidencial`.

Para obtener la IP y comandos:

```powershell
terraform -chdir="terraform/wazuh-deploy" output linux_ui_public_ip
terraform -chdir="terraform/wazuh-deploy" output linux_ui_private_ip
terraform -chdir="terraform/wazuh-deploy" output linux_ui_rdp_credentials_command
```

Para ver credenciales RDP:

```powershell
gcloud compute ssh linux-ui-workstation --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo cat /root/linux-ui-rdp-credentials.txt"
```

Luego abre RDP contra la IP publica y entra con el usuario `esquivel`.

Si tu red bloquea salida directa al puerto `3389`, crea un tunel local y conecta RDP a `localhost:13389`:

```powershell
gcloud compute ssh linux-ui-workstation --project=wazuh-iac-on-gcp --zone=us-central1-a --ssh-flag="-L 13389:localhost:3389" --ssh-flag="-N"
```

### Opcion B: endpoint externo/manual

Primero asegurate de que el agente Wazuh ya este instalado y enrolado al manager. Luego, en el endpoint Linux UI, desde una copia del repo:

```bash
sudo bash scripts/setup-linux-ui-sensitive-agent.sh
```

Si quieres usar otra ruta sensible:

```bash
sudo SENSITIVE_DIR="/home/esquivel/Confidencial" DESKTOP_USER="esquivel" bash scripts/setup-linux-ui-sensitive-agent.sh
```

El script hace esto:

- Crea `/home/esquivel/Confidencial`.
- Crea un acceso en `~/Documentos/Confidencial` o `~/Documents/Confidencial`.
- Agrega FIM realtime sobre `/home/esquivel/Confidencial`.
- Agrega lectura de `/var/log/auth.log` y `/var/log/kern.log`.
- Configura `nftables` para loguear y descartar SYN TCP hacia puertos `1-1024`, excepto SSH `22`, con prefijo `wazuh-fw-drop:`.
- Reinicia `wazuh-agent`.

## Simular DLP/FIM

En el agente:

```bash
sudo sh -c 'echo "cliente=demo" > /home/esquivel/Confidencial/cliente-demo.txt'
sudo sh -c 'echo "actualizado=$(date -Is)" >> /home/esquivel/Confidencial/cliente-demo.txt'
sudo rm -f /home/esquivel/Confidencial/cliente-demo.txt
```

Busqueda en Dashboard:

```text
rule.id: 100015 or rule.groups: confidential_data
```

## Simular ransomware

En el agente:

```bash
sudo /usr/local/bin/simulate-confidential-ransomware-burst.sh
```

O desde el repo:

```bash
sudo bash scripts/simulate-confidential-ransomware-burst.sh /home/esquivel/Confidencial
```

Busqueda en Dashboard:

```text
rule.id: 100010 or rule.mitre.id: T1486
```

En MITRE ATT&CK debe aparecer la tecnica:

```text
T1486 - Data Encrypted for Impact
```

## Simular autenticacion fallida contra esquivel

Prueba real por SSH desde otra terminal o maquina:

```bash
ssh esquivel@<AGENT_IP>
```

Escribe una contrasena incorrecta.

Para generar una prueba controlada local sin depender de password real:

```bash
logger -p authpriv.warning -t sshd "Failed password for esquivel from 203.0.113.50 port 53022 ssh2"
logger -p authpriv.warning -t su "FAILED su for esquivel by $(whoami)"
```

Busqueda en Dashboard:

```text
rule.id: 100020 or (rule.groups: authentication_failed and full_log: esquivel)
```

## Simular escaneo de puertos

Desde otra maquina, contra la IP del agente Linux UI:

```bash
sudo nmap -Pn -sS -T4 -p1-1024 <AGENT_IP>
```

Desde `metasploit-node` en este laboratorio:

```powershell
gcloud compute ssh metasploit-node --project=wazuh-iac-on-gcp --zone=us-central1-a --command="sudo bash -lc 'command -v nmap >/dev/null 2>&1 || (apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y nmap); nmap -Pn -sS -T4 -p1-1024 10.0.1.19'"
```

Si no tienes permisos para SYN scan:

```bash
nmap -Pn -sT -T4 -p1-1024 <AGENT_IP>
```

Busqueda en Dashboard:

```text
rule.id: 100030 or rule.mitre.id: T1595
```

En MITRE ATT&CK debe aparecer la tecnica:

```text
T1595 - Active Scanning
```

## Verificacion rapida en CLI

En el manager:

```bash
sudo docker exec single-node_wazuh.manager_1 grep -E '"id":"100010"|"id":"100015"|"id":"100020"|"id":"100030"' /var/ossec/logs/alerts/alerts.json
```

En el agente:

```bash
sudo systemctl status wazuh-agent --no-pager
sudo tail -n 30 /var/log/kern.log
sudo tail -n 30 /var/log/auth.log
```
