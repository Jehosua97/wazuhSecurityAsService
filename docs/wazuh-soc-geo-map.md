# Wazuh SOC Geo Map

## Objetivo

Este mapa usa la seccion **Maps** de Wazuh/OpenSearch Dashboards para mostrar
de forma visual los escenarios del laboratorio sobre el globo:

- fuerza bruta SSH con bloqueo global de 2 minutos
- IP con reputacion maliciosa y bloqueo global
- escaneo de puertos contra Linux UI
- Kali controlado como actividad red-team autorizada
- activos protegidos: FIM sensible y n8n
- Docker / Container Security en `docker-host`
- GCP / Cloud Security para cambios IAM y compute

## Como importarlo

Desde PowerShell en la raiz del repo:

```powershell
.\scripts\import-wazuh-soc-map.ps1
```

El script crea o actualiza:

- indice: `soc-lab-geo-events`
- data view: `soc-lab-geo-events`
- mapa: `SOC Geo - Amenazas y respuesta`

URL directa:

```text
https://<WAZUH_PUBLIC_IP>/app/maps-dashboards#/view/soc-geo-threat-map
```

Si la URL directa no abre, entra a:

```text
Wazuh Dashboard -> Maps -> SOC Geo - Amenazas y respuesta
```

## Capas del mapa

| Capa | Color | Que demuestra |
|---|---|---|
| Fuerza bruta - bloqueo global 2m | Rojo | Reglas `100020`, `100120`, `5712`; bloqueo en todos los peers por 120 segundos |
| IP maliciosa - reputacion | Rojo oscuro | Regla `100100`; bloqueo global por lista AlienVault |
| Escaneo y reconocimiento | Naranja | Port scan contra `linux-ui-workstation`; bloqueo local |
| Kali controlado | Morado | Actividad red-team autorizada desde `kali-attacker` |
| Activos protegidos y automatizacion | Azul | FIM sensible, n8n y senales de activos criticos |
| Docker - Container Security | Verde | Reinicios, pulls de imagen y drift en `docker-host` |
| GCP - Cloud Security | Cian | Cambios IAM y compute representados como eventos cloud |

## Campos importantes

El mapa usa el campo:

```text
location
```

como `geo_point`. Los tooltips muestran:

- `scenario`
- `event_type`
- `srcip`
- `target_agent`
- `rule_id`
- `response`
- `business_message`

## Nota operativa

Este mapa es una capa narrativa para demo SOC. No depende de que Wazuh haga
GeoIP automaticamente sobre cada alerta en `wazuh-alerts-*`; el script crea un
indice dedicado con puntos geograficos curados a partir de los escenarios que ya
existen en el lab.
