# Changelog

## Unreleased

### Added

- Creada carpeta `demo-mode/` con scripts seguros para generar eventos controlados en Wazuh.
- Agregado `demo-mode/run_all_demo_events.sh` para ejecutar todos los escenarios.
- Agregado `demo-mode/reset_demo.sh` para revertir artefactos temporales.
- Agregada documentacion operativa en `demo-mode/README.md`.
- Creada carpeta `ansible/windows-ad-lab/` con Vagrantfile, inventario, playbooks Ansible, variables de ejemplo y generador seguro de eventos para Windows Server 2016 + Active Directory + Wazuh Agent.
- Agregada demo de modulos del agente Wazuh en contenedores Linux: log collector, command, FIM, SCA, syscollector, rootcheck, active response seguro, Docker listener, cloud demo y vulnerability detection.
- Agregado dashboard `SOC Modulos Wazuh - Demo tecnico` y documentacion `docs/wazuh-agent-modules-demo.md`.

### Fixed

- Asignada la IP estatica `wazuh-server-public-ip` directamente a `wazuh-server` para que `cost-saver` no cambie la IP publica del manager.
- Ajustados `scripts/lab-master.ps1` y `scripts/local-docker-lab.ps1` para resolver la IP real desde GCP/Terraform antes de usar `WAZUH_MANAGER_IP` del entorno.
- Corregido `scripts/lab-master.ps1 -Action status` para exportar la IP resuelta a `WAZUH_MANAGER_IP` antes de consultar Docker Compose.
- Agregado self-healing de usuario/grupo `wazuh` en `docker/linux-endpoints/entrypoint.sh` para que los agentes no queden desconectados al recrear contenedores con volumenes persistentes.
