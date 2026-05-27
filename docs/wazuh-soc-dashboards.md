# Wazuh SOC Dashboards

## Objetivo

Este documento acompana el import de dos dashboards para tu instancia actual de Wazuh:

- `SOC Ejecutivo - PYME Mexico`
- `SOC Operativo - PYME Mexico`
- `SOC Modulos Wazuh - Demo tecnico`
- `SOC Docker y Cloud Security - Visual`
- `SOC Geo - Amenazas y respuesta` en la seccion Maps

Los dashboards se crean como saved objects de OpenSearch Dashboards y se importan sobre el data view `wazuh-alerts-*`.
El mapa SOC usa un indice dedicado `soc-lab-geo-events` con campo `location` tipo `geo_point`.

## Como importarlos

Desde PowerShell en la raiz del repo:

```powershell
.\scripts\import-wazuh-dashboards.ps1
```

Si cambiaste la contrasena del dashboard:

```powershell
.\scripts\import-wazuh-dashboards.ps1 -DashboardPassword "TU_PASSWORD"
```

## URLs

Una vez importados, toma tu base URL desde:

```powershell
cd terraform\wazuh-deploy
terraform output wazuh_dashboard_url
```

Y agrega:

- Ejecutivo: `/app/dashboards#/view/soc-ejecutivo-dashboard`
- Operativo: `/app/dashboards#/view/soc-operativo-dashboard`
- Modulos Wazuh: `/app/dashboards#/view/soc-modulos-wazuh-dashboard`
- Docker y Cloud Security: `/app/dashboards#/view/soc-docker-cloud-security-dashboard`
- Mapa SOC: `/app/maps-dashboards#/view/soc-geo-threat-map`

## Dashboard Ejecutivo

Pensado para cliente o direccion.

Paneles:

- Riesgo alto visible al cliente
- Riesgo en activos criticos
- Impacto de cumplimiento
- Superficie publica expuesta

## Dashboard Operativo

Pensado para analista o demo SOC.

Paneles:

- Incidentes correlacionados
- Incidentes de infraestructura
- Timeline de `pyme-demo-target`
- Actividad de `metasploit-node`
- Actividad de `edge-gateway`
- Actividad de `db-server`
- Actividad de `docker-host`

## Dashboard Modulos Wazuh

Pensado para explicar capacidades del agente Wazuh durante una demo tecnica.

Paneles:

- Vista general de modulos
- Log collector y Command
- FIM y SCA
- Inventario, vulnerabilidades y malware detection
- Active Response seguro
- Contenedores y Cloud

## Dashboard Docker y Cloud Security

Pensado para mostrar visualmente el modulo de Docker dentro de Cloud Security.

Paneles:

- Vista general Docker + Cloud
- Runtime Docker en `docker-host`
- Drift de configuracion de contenedores
- Eventos GCP Cloud Security simulados

## Mapa SOC

Pensado para explicar visualmente de donde vienen los eventos y que respuesta
ejecuta el SOC.

Capas:

- fuerza bruta con bloqueo global de 2 minutos
- IP maliciosa por reputacion
- escaneo y reconocimiento
- Kali controlado
- activos protegidos y automatizacion
- Docker / Container Security
- GCP / Cloud Security

Para importarlo o refrescar sus datos:

```powershell
.\scripts\import-wazuh-soc-map.ps1
```

## Queries base

Estos dashboards reutilizan las queries operativas que ya quedaron documentadas en:

- `docs/soc-dashboard-queries.md`
- `docs/endpoint-noise-playbook.md`
