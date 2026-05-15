# Wazuh SOC Dashboards

## Objetivo

Este documento acompana el import de dos dashboards para tu instancia actual de Wazuh:

- `SOC Ejecutivo - PYME Mexico`
- `SOC Operativo - PYME Mexico`

Los dashboards se crean como saved objects de OpenSearch Dashboards y se importan sobre el data view `wazuh-alerts-*`.

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

## Queries base

Estos dashboards reutilizan las queries operativas que ya quedaron documentadas en:

- `docs/soc-dashboard-queries.md`
- `docs/endpoint-noise-playbook.md`
