# Endpoints locales en Docker con Wazuh en GCP

Este modo deja solamente `wazuh-server` en GCP. Los endpoints del laboratorio viven en tu localhost como contenedores Docker y se enrolan al Wazuh cloud por la IP publica del manager.

## Archivos nuevos

- `docker-compose.endpoints.yml`: endpoints Linux locales.
- `docker-compose.windows.yml`: endpoint Windows Server local.
- `docker/linux-endpoints/Dockerfile`: imagen base de endpoints Linux.
- `docker/windows-endpoint/Dockerfile`: imagen base del endpoint Windows.
- `scripts/local-docker-lab.ps1`: wrapper para operar el laboratorio.
- `.env.example`: variables para Docker Compose.

## Antes de levantar Docker

En `terraform/wazuh-deploy/terraform.tfvars` deja:

```hcl
enable_gcp_endpoints = false

# Recomendado: usa tu IP publica real para dashboard, SSH y agentes.
admin_source_ranges = ["TU_IP_PUBLICA/32"]
extra_agent_source_ranges = ["TU_IP_PUBLICA/32"]
```

Luego aplica Terraform. Esto conserva el manager y remueve las VMs endpoint de GCP:

```powershell
terraform -chdir="terraform/wazuh-deploy" plan
terraform -chdir="terraform/wazuh-deploy" apply
```

Aplica reglas y dashboards del manager:

```powershell
.\scripts\apply-wazuh-config.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a"
.\scripts\import-wazuh-dashboards.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a" -DashboardUser "admin" -DashboardPassword "SecretPassword"
```

## Levantar endpoints Linux

El script obtiene la IP publica de Wazuh desde Terraform. Si prefieres fijarla manualmente, usa `-WazuhManagerIp`.

```powershell
.\scripts\local-docker-lab.ps1 -Scope Linux -Action up
```

Contenedores Linux incluidos:

- `pyme-demo-target`
- `metasploit-node`
- `edge-gateway`
- `db-server`
- `docker-host`
- `linux-ui-workstation`

Puertos locales utiles:

- Panel PyME/Juice Shop proxy: `http://localhost:8080/panel/`
- Juice Shop directo: `http://localhost:3000`
- Docker host demo: `http://localhost:8081`
- Linux UI por RDP: `localhost:13389`
- MariaDB demo: `localhost:13306`

Credenciales RDP de Linux UI:

```powershell
docker compose -f docker-compose.endpoints.yml exec linux-ui-workstation cat /root/linux-ui-rdp-credentials.txt
```

## Windows Server en contenedor

Docker Desktop no puede ejecutar Linux containers y Windows containers en el mismo engine al mismo tiempo. Para levantar Windows:

1. En Docker Desktop, cambia a **Windows containers**.
2. Ejecuta:

```powershell
.\scripts\local-docker-lab.ps1 -Scope Windows -Action up
```

Si ves un error parecido a `docker:desktop-linux` o `no match for platform in manifest`, Docker sigue en modo Linux containers. Cambialo desde Docker Desktop o intenta:

```powershell
& "$Env:ProgramFiles\Docker\Docker\DockerCli.exe" -SwitchDaemon
```

Verifica el engine activo:

```powershell
docker info --format "{{.OSType}}"
```

Debe responder `windows` antes de ejecutar el compose de Windows.

Endpoint Windows incluido:

- `windows-server`

Generar eventos Windows:

```powershell
docker compose -f docker-compose.windows.yml exec windows-server powershell.exe -ExecutionPolicy Bypass -File C:\ProgramData\WazuhDemo\Generate-WindowsDemoEvents.ps1
```

Nota honesta para demo: Windows containers sirven para mostrar enrolamiento y telemetria controlada de Windows. Para pruebas de Event Log, Security Log, RDP y comportamiento completo de Windows Server, una VM Windows sigue siendo mas fiel que un contenedor.

## Simular ataques y ruido

```powershell
docker compose -f docker-compose.endpoints.yml exec pyme-demo-target /usr/local/bin/pyme-demo-generate-events.sh
docker compose -f docker-compose.endpoints.yml exec metasploit-node /usr/local/bin/metasploit-demo-generate-events.sh
docker compose -f docker-compose.endpoints.yml exec edge-gateway /usr/local/bin/gateway-demo-generate-events.sh
docker compose -f docker-compose.endpoints.yml exec db-server /usr/local/bin/db-demo-generate-events.sh
docker compose -f docker-compose.endpoints.yml exec docker-host /usr/local/bin/docker-demo-generate-events.sh
docker compose -f docker-compose.endpoints.yml exec linux-ui-workstation /usr/local/bin/simulate-confidential-ransomware-burst.sh
docker compose -f docker-compose.endpoints.yml exec linux-ui-workstation /usr/local/bin/linux-ui-demo-auth-failure.sh
docker compose -f docker-compose.endpoints.yml exec metasploit-node nmap -Pn -sS -T4 -p1-1024 linux-ui-workstation
docker compose -f docker-compose.endpoints.yml exec linux-ui-workstation /usr/local/bin/linux-ui-demo-portscan-log.sh
```

## Operacion diaria

Apagar contenedores sin perder datos del agente:

```powershell
.\scripts\local-docker-lab.ps1 -Scope Linux -Action down
```

Destruir contenedores y volumenes locales:

```powershell
.\scripts\local-docker-lab.ps1 -Scope Linux -Action destroy
```

Ver estado:

```powershell
.\scripts\local-docker-lab.ps1 -Scope Linux -Action status
```

Ver logs:

```powershell
.\scripts\local-docker-lab.ps1 -Scope Linux -Action logs
```

## Busquedas en Wazuh Dashboard

Todos los endpoints:

```text
agent.name: ("pyme-demo-target" or "metasploit-node" or "edge-gateway" or "db-server" or "docker-host" or "linux-ui-workstation" or "windows-server")
```

Linux UI DLP/ransomware/auth/scan:

```text
agent.name: "linux-ui-workstation" and rule.id: (100010 or 100015 or 100020 or 100030)
```

Windows:

```text
agent.name: "windows-server" and rule.groups: windows_endpoint
```
