# Demo de modulos Wazuh en la VM Windows AD

## Objetivo

Esta guia deja una demo visual y controlada dentro de la VM `ad2016-dc01` para mostrar en Wazuh como monitoreamos una VM Windows de cliente.

La narrativa es honesta:

- Nativo en la VM Windows: `log collector`, `command execution`, `FIM`, `SCA`, `system inventory`, `malware detection/rootcheck` y `active response` seguro.
- Integrado pero no nativo en esa VM: `container security` y `cloud security`. Desde Windows se generan eventos de narrativa segura para que el cliente vea la cobertura en el mismo dashboard, pero la recoleccion nativa vive en `docker-host` y en integraciones cloud del laboratorio.

## Archivos

- `ansible/windows-ad-lab/files/Setup-WindowsWazuhModulesDemo.ps1`
- `ansible/windows-ad-lab/files/Generate-WindowsWazuhModulesDemo.ps1`

## Que configura

- `Application` y `Microsoft-Windows-PowerShell/Operational` como fuentes Windows visibles.
- Logs planos:
  - `C:\AD-Demo\ModuleDemo\Logs\module-demo.log`
  - `C:\AD-Demo\ModuleDemo\Logs\cloud-gcp-demo.log`
- `wodle name="command"` con comandos autorizados para disco y grupo privilegiado.
- `syscheck` sobre `C:\AD-Demo\ModuleDemo\Config` y `C:\AD-Demo\ModuleDemo\Evidence`.
- Politica SCA custom `etc/shared/wazuh_demo_windows_sca.yml`.
- `syscollector` con OS, red, paquetes, puertos y procesos.
- `rootcheck` habilitado.
- Active Response seguro en Windows con `module-demo-response.cmd` en modo evidencia solamente.

## Preparacion del manager

Para que el Active Response seguro de Windows se dispare desde el manager y no solo en fallback local, aplica la configuracion del repo al manager:

```powershell
.\scripts\apply-wazuh-config.ps1 -ProjectId "wazuh-iac-on-gcp" -Zone "us-central1-a"
```

Esto empuja:

- la regla `100316` para disparar el Active Response de Windows
- el comando `windows-module-demo-response` en el manager

## Como instalarlo en la VM

Si usas esta VM Vagrant:

```powershell
cd ansible/windows-ad-lab
vagrant upload files/Setup-WindowsWazuhModulesDemo.ps1 C:/Windows/Temp/Setup-WindowsWazuhModulesDemo.ps1
vagrant upload files/Generate-WindowsWazuhModulesDemo.ps1 C:/Windows/Temp/Generate-WindowsWazuhModulesDemo.ps1
vagrant winrm -c "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File C:/Windows/Temp/Setup-WindowsWazuhModulesDemo.ps1"
```

El setup tambien deja un launcher visual en:

```text
C:\Users\Public\Desktop\Run-Wazuh-Modules-Demo.cmd
```

## Como correr la demo frente al cliente

Dentro del Windows Server:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File C:\AD-Demo\ModuleDemo\Scripts\Generate-WindowsWazuhModulesDemo.ps1
```

Esto genera:

- eventos Windows en `Application`
- lineas controladas para `wazuh-module-demo` y `gcp-demo`
- un cambio FIM en el baseline
- un drift SCA intencional y explicable
- evidencia JSON del run
- trigger de Active Response seguro

## Queries utiles

Todo el demo de modulos:

```text
agent.name: "ad2016-dc01" and rule.groups: wazuh_module_visibility
```

Log collector y command:

```text
agent.name: "ad2016-dc01" and rule.groups: (wazuh_agent_logcollector or wazuh_agent_command)
```

FIM y SCA:

```text
agent.name: "ad2016-dc01" and rule.groups: (wazuh_agent_fim or wazuh_agent_sca or syscheck or sca)
```

Inventario, vulnerabilidades y rootcheck:

```text
agent.name: "ad2016-dc01" and rule.groups: (wazuh_agent_syscollector or wazuh_agent_vulnerability_detection or wazuh_agent_rootcheck or rootcheck or vulnerability_management)
```

Active Response:

```text
agent.name: "ad2016-dc01" and rule.groups: wazuh_agent_active_response
```

Container y cloud:

```text
agent.name: "ad2016-dc01" and rule.groups: (wazuh_agent_container_security or wazuh_agent_cloud_security or cloud_security)
```

## Nota operativa

Si no has aplicado la config del manager y aun asi necesitas cerrar la demo, el trigger script crea evidencia local de Active Response en modo fallback. Eso mantiene la narrativa visual, pero la automatizacion real manager -> agent requiere aplicar la configuracion del repo al manager.
