# Windows Server 2016 Active Directory Lab for Wazuh

Este paquete deja listo un laboratorio Windows Server 2016 con Active Directory para correrlo en otra PC con VirtualBox. La VM se conecta al Wazuh Manager en GCP como endpoint Windows y genera eventos defensivos/controlados para demo.

No ejecutes esto en la laptop actual si no tienes VirtualBox instalado.

## Objetivo

- Crear una VM Windows Server 2016 local.
- Promoverla como Domain Controller de un dominio demo.
- Crear OUs, grupos y usuarios ficticios.
- Instalar y configurar Wazuh Agent para conectarse al manager GCP.
- Activar logs de Windows relevantes para SOC.
- Monitorear una carpeta sensible con FIM.
- Incluir un script seguro de eventos para demo y evidencia.

## Arquitectura

```text
Otra PC con VirtualBox/Vagrant/Ansible
|
+-- Windows Server 2016 VM
    |
    +-- Active Directory Domain Services
    +-- DNS
    +-- Usuarios y grupos demo
    +-- C:\AD-Demo\Confidential
    +-- Wazuh Agent
        |
        +-- 1514/tcp -> Wazuh Manager GCP
        +-- 1515/tcp -> Wazuh registration service

Wazuh GCP:
https://34.135.112.15
```

## Requisitos en la PC donde se va a correr

- VirtualBox.
- Vagrant.
- WSL Ubuntu, Linux o macOS con Ansible.
- Python con soporte WinRM:

```bash
python3 -m pip install --user "pywinrm>=0.4.3"
ansible-galaxy collection install -r requirements.yml
```

En Windows puro, Ansible no se ejecuta de forma nativa. Usa WSL Ubuntu o una maquina Linux como control node.

## Archivos principales

- `Vagrantfile`: crea la VM Windows Server 2016 en VirtualBox.
- `inventories/vagrant.yml`: inventario WinRM para Ansible.
- `group_vars/windows_ad_lab.example.yml`: variables de dominio, usuarios y Wazuh.
- `playbooks/01-bootstrap-windows.yml`: prepara hostname, WinRM, directorios y Administrator.
- `playbooks/02-promote-domain-controller.yml`: instala AD DS/DNS y crea el bosque.
- `playbooks/03-configure-ad-users-and-wazuh.yml`: crea usuarios/grupos, instala Wazuh Agent y configura FIM/logs.
- `playbooks/04-run-demo-events.yml`: genera eventos seguros para demo.
- `files/Generate-ADDemoEvents.ps1`: script PowerShell de eventos controlados.

## Preparacion

Desde esta carpeta:

```bash
cd ansible/windows-ad-lab
cp group_vars/windows_ad_lab.example.yml group_vars/windows_ad_lab.yml
```

Edita `group_vars/windows_ad_lab.yml`:

```yaml
wazuh_manager_ip: "34.135.112.15"
wazuh_agent_name: "ad2016-dc01"
windows_administrator_password: "CAMBIAR_EN_PASSWORD_MANAGER"
ad_safe_mode_password: "CAMBIAR_EN_PASSWORD_MANAGER"
```

No subas `group_vars/windows_ad_lab.yml` al repositorio. Esta ignorado por `.gitignore`.

## Crear la VM

```bash
vagrant up
```

Si el box por defecto no esta disponible en tu equipo, puedes usar otro box Windows Server 2016 compatible con WinRM:

```bash
WINDOWS_BOX="tu/box-windows-2016" vagrant up
```

El puerto WinRM del guest `5985` se expone localmente como `55985`.

## Ejecutar Ansible

Instala colecciones:

```bash
ansible-galaxy collection install -r requirements.yml
```

Valida conectividad inicial:

```bash
ansible-playbook -i inventories/vagrant.yml playbooks/00-validate-inputs.yml
```

Prepara Windows:

```bash
ansible-playbook -i inventories/vagrant.yml playbooks/01-bootstrap-windows.yml
```

Promueve a Domain Controller:

```bash
ansible-playbook -i inventories/vagrant.yml playbooks/02-promote-domain-controller.yml
```

Despues del reboot, configura AD, usuarios y Wazuh:

```bash
ansible-playbook -i inventories/vagrant.yml playbooks/03-configure-ad-users-and-wazuh.yml
```

Genera eventos seguros de demo:

```bash
ansible-playbook -i inventories/vagrant.yml playbooks/04-run-demo-events.yml
```

## Usuarios demo incluidos

Los usuarios se definen en `group_vars/windows_ad_lab.yml`. El ejemplo incluye:

- `ana.garcia`: Finanzas.
- `carlos.mendez`: Operaciones.
- `sofia.ramirez`: Gerencia.
- `it.soc`: TI/SOC.
- `svc.backup`: cuenta de servicio demo.

Todos son ficticios y deben usarse solo en laboratorio.

## Validacion en Wazuh

En el Wazuh Dashboard:

```text
agent.name: "ad2016-dc01"
```

Consultas utiles:

```text
agent.name: "ad2016-dc01" and data.win.system.channel: "Application"
agent.name: "ad2016-dc01" and rule.groups: "syscheck"
agent.name: "ad2016-dc01" and location: "Security"
agent.name: "ad2016-dc01" and location: "Directory Service"
```

En el manager por SSH:

```bash
sudo docker exec single-node_wazuh.manager_1 /var/ossec/bin/agent_control -l
```

Debe aparecer:

```text
Name: ad2016-dc01, Active
```

## Eventos seguros que genera

`files/Generate-ADDemoEvents.ps1` no explota nada y no intenta autenticar usuarios reales. Solo genera:

- Eventos en Application Log con fuente `WazuhADLabDemo`.
- Cambios en `C:\AD-Demo\Confidential` para FIM.
- Evidencia en `C:\AD-Demo\Evidence`.
- Evento administrativo simulado y no ofensivo.

## Riesgos y mitigaciones

- La VM Windows consume recursos locales: usar 4 GB RAM minimo.
- AD modifica la VM profundamente: usar solo laboratorio.
- WinRM basico sin cifrado se usa solo contra `127.0.0.1`/red local del lab.
- No uses passwords reales.
- No mezcles este dominio demo con redes de clientes.
- Abre en GCP los puertos 1514/1515 solo a la IP publica de la PC que ejecuta la VM o usa VPN.

## Apagar o destruir

Apagar:

```bash
vagrant halt
```

Destruir:

```bash
vagrant destroy -f
```

## Troubleshooting

Ver estado:

```bash
vagrant status
```

Probar WinRM:

```bash
ansible -i inventories/vagrant.yml win2016_bootstrap -m ansible.windows.win_ping
```

Si falla despues de promover a dominio, usa el alias `win2016_dc`:

```bash
ansible -i inventories/vagrant.yml win2016_dc -m ansible.windows.win_ping
```

Si el agente Wazuh no aparece activo:

- Revisa que `wazuh_manager_ip` sea la IP fija actual.
- Revisa firewall GCP para permitir la IP publica de la PC donde corre la VM.
- En Windows revisa el servicio `WazuhSvc`.
- Revisa `C:\Program Files (x86)\ossec-agent\ossec.log`.
