# Endpoint Onboarding

## Idea base

Tu Wazuh manager puede vivir en la nube y aun asi monitorear:

- tu laptop o localhost
- VMs on-prem o en otra nube
- servidores Linux o Windows
- hosts Docker
- endpoints conectados por VPN

La clave es separar dos cosas:

- conectividad hacia el manager
- enrolamiento del agente

## Como esta hoy este proyecto

Por defecto, el firewall del manager acepta trafico de agentes desde:

- la subnet privada del laboratorio `10.0.1.0/24`

Ademas, ahora puedes agregar rangos externos confiables usando:

- `extra_agent_source_ranges`

Esto permite dar acceso a:

- tu IP publica para registrar tu laptop
- la IP publica de una VM externa
- una red de oficina o VPN

## Paso 1. Permitir el origen del endpoint

Edita `terraform/wazuh-deploy/terraform.tfvars`:

```hcl
extra_agent_source_ranges = [
  "203.0.113.10/32"
]
```

Ejemplos utiles:

- una sola laptop en casa: `["TU_IP_PUBLICA/32"]`
- una oficina pequena: `["TU_RANGO_PUBLICO/29"]`
- una VPN sitio a sitio: `["10.20.0.0/24"]`

Luego aplica:

```powershell
cd terraform\wazuh-deploy
terraform apply
```

## Paso 2. Obtener la direccion del manager

Despues del apply:

```powershell
terraform output
```

Fijate especialmente en:

- `wazuh_manager_public_ip`
- `wazuh_manager_private_ip`
- `agent_enrollment_ports`

Usa:

- IP publica para endpoints externos
- IP privada para endpoints dentro de la misma VPC, red peered o VPN privada

## Paso 3. Enrolar el endpoint

La forma mas facil es desde el dashboard:

1. Entra a Wazuh.
2. Ve a `Agents management`.
3. Entra a `Summary`.
4. Haz clic en `Deploy new agent`.
5. Elige sistema operativo, IP del manager, nombre de agente y grupo.

Referencia oficial:

- https://documentation.wazuh.com/current/cloud-service/getting-started/enroll-agents.html
- https://documentation.wazuh.com/current/installation-guide/wazuh-agent/index.html

## Linux o VM Linux externa

Patron recomendado:

- abre conectividad con `extra_agent_source_ranges`
- usa la IP publica o privada del manager
- asigna un nombre entendible por cliente y activo

Ejemplos de naming:

- `cliente-a-web-01`
- `cliente-a-db-01`
- `laptop-jhoshua`
- `docker-host-demo`

Referencia oficial Linux:

- https://documentation.wazuh.com/current/installation-guide/wazuh-agent/wazuh-agent-package-linux.html

## Windows o tu laptop personal

Tu localhost o laptop tambien puede ser un endpoint.

La ruta correcta es:

- permitir tu IP publica en `extra_agent_source_ranges`
- instalar el agente de Wazuh
- apuntarlo a la IP publica del manager
- verificar que aparezca en `Agents management`

Referencia oficial Windows:

- https://documentation.wazuh.com/current/installation-guide/wazuh-agent/wazuh-agent-package-windows.html

## Docker y contenedores

Para Docker, el patron mas sano en un MVP SOC normalmente no es meter un agente dentro de cada contenedor efimero.

Lo recomendado es:

- instalar un agente en el host Docker
- monitorear logs y cambios del host
- enviar al host los logs de las apps que quieras vigilar

Usa un agente por contenedor solo si:

- el contenedor es de larga vida
- realmente lo tratas como un servidor
- necesitas controles muy especificos dentro del contenedor

En una demo comercial, un mensaje claro seria:

"Monitoreamos el host Docker como activo principal y extendemos visibilidad a las aplicaciones mediante logs, procesos y cambios relevantes."

## VMs nuevas en GCP

Si creas otra VM dentro de la misma VPC o una red conectada privadamente:

- no necesitas abrir el manager al mundo
- usa la IP privada `wazuh_manager_private_ip`
- instala el agente normalmente

Este es el caso mas limpio para crecimiento interno del laboratorio.

## Agrupar endpoints por cliente o rol

Cuando ya tengas varios agentes, no los dejes todos en `default`.

Empieza con grupos como:

- `customer_pyme_demo`
- `internet_facing`
- `critical_asset`
- `workstations`
- `docker_hosts`
- `compliance_scope`

Referencia oficial sobre grouping:

- https://documentation.wazuh.com/current/user-manual/agent/agent-management/grouping-agents.html

## Recomendacion operativa

Si vas a vender esto como SOC:

- no abras `1514` y `1515` a `0.0.0.0/0`
- usa `extra_agent_source_ranges` solo para IPs o redes confiables
- si vas a crecer, prefiere VPN, Zero Trust o conectividad privada
- usa grupos por cliente y criticidad desde el primer dia

## Resumen rapido

### Para agregar tu localhost

- agrega tu IP publica a `extra_agent_source_ranges`
- haz `terraform apply`
- instala el agente en tu laptop
- apunta el agente al `wazuh_manager_public_ip`

### Para agregar una VM externa

- agrega la IP publica de origen o el rango de su red
- haz `terraform apply`
- instala el agente
- asigna nombre y grupo

### Para agregar Docker

- instala el agente en el host Docker
- manda los logs de las apps al host
- monitorea el host como endpoint principal
