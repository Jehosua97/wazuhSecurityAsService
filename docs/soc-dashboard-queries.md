# SOC Dashboard Queries

## Objetivo

Estas consultas estan pensadas para guardarse como saved searches o listas operativas dentro de Wazuh Dashboard, de forma que la demo se vea y se opere como un SOC.

Las consultas usan los grupos agregados en `local_rules.xml`, especialmente:

- `soc_signal`
- `soc_incident`
- `incident_priority_p1`
- `incident_priority_p2`
- `internet_facing`
- `critical_asset`
- `compliance_scope`
- `admin_plane`
- `web_attack_signal`
- `evidence_tamper_signal`
- `edge_gateway`
- `database_endpoint`
- `docker_host`
- `windows_endpoint`
- `infrastructure_incident`

## Listas operativas

### 1. Incidentes P1

```text
rule.groups: incident_priority_p1
```

Uso:

- lista principal de incidentes criticos
- demo para hablar de triage y escalacion

### 2. Incidentes P2

```text
rule.groups: incident_priority_p2 and not rule.groups: incident_priority_p1
```

Uso:

- cola de analistas
- backlog de seguimiento del turno

### 3. Incidentes correlacionados

```text
rule.groups: soc_incident
```

Uso:

- vista de incidentes ya agregados
- evita mostrar ruido de eventos unitarios

### 4. Ataques internet-facing

```text
rule.groups: internet_facing and rule.groups: (web or attack or recon)
```

Uso:

- monitoreo de aplicaciones publicas
- demo de superficie expuesta y proteccion de perimetro

### 5. Manipulacion de evidencia y cumplimiento

```text
rule.groups: compliance_scope and rule.groups: (syscheck or evidence_tamper_signal)
```

Uso:

- evidencia para PCI, ISO o LFPDPPP
- cambios no autorizados en rutas sensibles

### 6. Abuso del plano administrativo

```text
rule.groups: admin_plane and rule.groups: authentication_failed
```

Uso:

- intentos de abuso de SSH o accesos administrativos
- soporte para narrativa de hardening y control de acceso

### 7. Activos criticos con alertas de alta severidad

```text
rule.groups: critical_asset and rule.level >= 10
```

Uso:

- priorizacion basada en negocio
- cola principal para activos de alto impacto

### 8. Campana multi-etapa en el mismo activo

```text
rule.id: (100150 or 100151 or 100152 or 100153)
```

Uso:

- mostrar correlacion SOC
- demo de incidentes frente a eventos sueltos

### 9. Acciones del panel de demo

```text
rule.id: (100140 or 100141 or 100142 or 100143 or 100144 or 100145)
```

Uso:

- confirmar que el panel genero telemetria
- explicar la narrativa del ataque controlado

### 10. Timeline de un activo especifico

```text
agent.name: "pyme-demo-target" and rule.groups: (soc_signal or soc_incident)
```

Uso:

- reconstruccion de incidente
- vista por activo para clientes

### 11. Actividad del endpoint Metasploit

```text
agent.name: "metasploit-node" and rule.groups: metasploit_endpoint
```

Uso:

- confirmar que el endpoint ofensivo esta reportando a Wazuh
- mostrar trazabilidad del workstation de pentesting dentro del SOC

### 12. Actividad del edge gateway

```text
agent.name: "edge-gateway" and rule.groups: edge_gateway
```

Uso:

- mostrar telemetria de firewall y VPN
- enseñar cobertura del perimetro dentro del SOC

### 13. Actividad del database endpoint

```text
agent.name: "db-server" and rule.groups: database_endpoint
```

Uso:

- mostrar eventos de autenticacion, cambios de esquema y acceso a datos
- conectar monitoreo tecnico con narrativa de cumplimiento

### 14. Actividad del docker host

```text
agent.name: "docker-host" and rule.groups: docker_host
```

Uso:

- mostrar visibilidad sobre contenedores y drift operativo
- reforzar el alcance de Wazuh sobre workloads modernos

### 15. Incidentes de infraestructura

```text
rule.groups: infrastructure_incident
```

Uso:

- ver correlacion de eventos de gateway, base de datos y contenedores
- operar el MVP como una cola SOC de infraestructura

### 16. Actividad del Windows Server

```text
agent.name: "windows-server" and rule.groups: windows_endpoint
```

Uso:

- mostrar telemetria de Application Log en Windows Server
- validar que los endpoints Windows tambien reportan al SOC

## Listas ejecutivas

### Riesgo alto visible al cliente

```text
rule.groups: (incident_priority_p1 or incident_priority_p2)
```

### Riesgo en activos criticos

```text
rule.groups: critical_asset and rule.groups: soc_incident
```

### Señales con impacto de cumplimiento

```text
rule.groups: compliance_scope and rule.level >= 8
```

## Layout sugerido del dashboard

### Vista SOC Operativa

- lista `Incidentes P1`
- lista `Incidentes P2`
- lista `Campana multi-etapa en el mismo activo`
- grafica por `rule.groups`
- top `agent.name`
- top `data.srcip`

### Vista Ejecutiva

- lista `Riesgo alto visible al cliente`
- lista `Riesgo en activos criticos`
- lista `Señales con impacto de cumplimiento`
- top vulnerabilidades criticas
- activos sin agente o con agente desconectado

## Consulta de demo rapida

Cuando quieras mostrar el MVP en vivo:

```text
agent.name: "pyme-demo-target" and rule.id: (100141 or 100143 or 100144 or 100150 or 100152 or 100153)
```

Para mostrar la nueva infraestructura monitoreada:

```text
agent.name: ("edge-gateway" or "db-server" or "docker-host" or "windows-server") and rule.id: (100170 or 100171 or 100172 or 100173 or 100180 or 100181 or 100182 or 100183 or 100190 or 100191 or 100192 or 100193 or 100194 or 100200 or 100201 or 100202 or 100203 or 100204)
```

Para mostrar el endpoint Linux UI con carpeta sensible:

```text
rule.id: (100010 or 100015 or 100020 or 100030) or rule.groups: linux_ui_endpoint
```

Para mostrar MITRE ATT&CK:

```text
rule.mitre.id: (T1486 or T1595)
```
