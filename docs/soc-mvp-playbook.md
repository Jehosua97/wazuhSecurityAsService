# SOC MVP Playbook

## Objetivo

Convertir este laboratorio de Wazuh en un MVP comercial y operativo que demuestre valor de un servicio tipo SOC para PYMES y medianas empresas.

El cliente no compra "reglas" ni "logs". El cliente compra:

- visibilidad de activos y riesgos
- deteccion temprana de incidentes
- evidencia de cumplimiento
- capacidad de respuesta guiada
- reportes ejecutivos que expliquen impacto y prioridad

## Lo que este repo ya resuelve

- despliegue rapido de Wazuh en GCP
- endpoint monitoreado con agente Wazuh
- laboratorio web con Juice Shop
- FIM sobre evidencia y datos simulados
- SCA y vulnerability detection
- reglas locales de demo para web, SSH, FIM y panel de ataques
- active response para escenarios de alta confianza

## Lo que falta para parecer un SOC y no solo un lab

### 1. Casos de uso orientados a negocio

Cada alerta importante debe responder tres preguntas:

- que paso
- que activo de negocio fue afectado
- que haria el SOC a continuacion

Casos de uso base para el MVP:

- ataque web contra aplicacion expuesta a internet
- abuso de autenticacion en SSH o acceso administrativo
- cambios no autorizados en evidencia, configuracion o datos sensibles
- exposicion de vulnerabilidades criticas en activos inventariados
- perdida de visibilidad de agentes o activos criticos

### 2. Clasificacion operacional

Define un modelo simple de severidad para demo y operacion:

- `P1 / Critico`: compromiso activo, datos sensibles, multiple detecciones correlacionadas
- `P2 / Alto`: intento confirmado o persistente contra activo critico
- `P3 / Medio`: hallazgo relevante con riesgo acotado
- `P4 / Bajo`: higiene, informativo, baseline

El objetivo es que el dashboard hable en lenguaje SOC:

- incidentes criticos abiertos
- activos con mayor riesgo
- vulnerabilidades pendientes
- cobertura de monitoreo

### 3. Segmentacion por cliente y activo

Un SOC vende contexto, no solo eventos. Agrupa agentes y detecciones por:

- cliente
- ambiente: produccion, qa, demo
- tipo de activo: servidor, endpoint, web, crown-jewel
- criticidad: alta, media, baja

Para este MVP, una buena base de naming es:

- `customer_pyme_demo`
- `internet_facing`
- `critical_asset`
- `compliance_scope`

### 4. Flujo de respuesta

Toda alerta visible en demo debe tener un "siguiente paso SOC".

Ejemplos:

- web attack: validar IP origen, revisar endpoints atacados, bloquear si hay alta confianza
- SSH brute force: revisar recurrencia, bloquear origen, verificar cambios posteriores
- FIM: confirmar si hubo cambio autorizado, identificar archivo y usuario
- vulnerabilidades: priorizar por CVSS, exposicion y criticidad del activo

## Como vender el valor en 5 minutos

### Paso 1. Mostrar cobertura

Entra a Wazuh y enseña:

- activos monitoreados
- sistema operativo, paquetes, puertos y procesos
- estado del agente

Mensaje comercial:

"En menos de una hora podemos darle visibilidad inicial de sus activos y riesgos tecnicos."

### Paso 2. Mostrar ataque controlado

Abre el panel:

- `http://IP_PUBLICA_TARGET/panel/`

Ejecuta:

- `SQLi login controlado`
- `Recon de API y productos`
- `Cambio FIM de evidencia`

Mensaje comercial:

"No solo detectamos que hubo actividad sospechosa. La contextualizamos sobre el activo, el tipo de ataque y el posible impacto."

### Paso 3. Mostrar correlacion tecnica y de negocio

Busca en Wazuh:

- `rule.id: 100140 or rule.id: 100141 or rule.id: 100142 or rule.id: 100143 or rule.id: 100144 or rule.id: 100145`
- `agent.name: "pyme-demo-target"`
- `rule.groups: web or rule.groups: syscheck`

Mensaje comercial:

"El cliente no tiene que interpretar logs. Recibe incidentes priorizados y explicados."

### Paso 4. Mostrar cumplimiento

Enseña:

- cambios en `/opt/pyme-compliance`
- etiquetado LFPDPPP, PCI-DSS e ISO 27001 en reglas

Mensaje comercial:

"El mismo servicio ayuda a seguridad y a cumplimiento. Eso acelera auditorias y reportes ejecutivos."

### Paso 5. Mostrar accion SOC

Explica el playbook:

- triage inicial
- confirmacion
- contencion
- recomendacion
- seguimiento

Mensaje comercial:

"No entregamos una consola. Entregamos monitoreo, criterio y respuesta guiada."

## Tuneo recomendado del MVP

### Prioridad 1. Que el dashboard se vea como SOC

- crear saved searches por severidad
- crear vistas por `critical_asset`, `internet_facing`, `compliance_scope`
- destacar top 5 riesgos, top 5 activos y top vulnerabilidades
- separar panel operativo de panel ejecutivo

### Prioridad 2. Reglas orientadas a incidentes

- correlacionar multiples probes web en una sola alerta de campana
- elevar severidad cuando FIM ocurre despues de intento de acceso
- alertar cuando un agente critico deja de reportar
- distinguir entre hallazgo tecnico y incidente de negocio

### Prioridad 3. Narrativa para cliente

- agregar descripcion "que significa" y "que haria el SOC" por caso de uso
- usar nombres de reglas entendibles por no tecnicos
- preparar un guion de demo de 3 a 5 minutos

### Prioridad 4. Operacion realista

- definir SLA de atencion
- definir formatos de reporte semanal y mensual
- documentar onboarding de cliente y alta de agentes
- documentar excepciones y whitelists

## Backlog sugerido para este repo

### Quick wins

- ampliar `local_rules.xml` con correlacion de incidentes multi-etapa
- documentar queries de dashboard por caso de uso
- crear un tablero de demo operativo y otro ejecutivo
- actualizar mensajes de `apply-wazuh-config.ps1` para incluir reglas nuevas

### Siguiente iteracion

- agrupar agentes por cliente y criticidad
- agregar decoders o reglas para aplicaciones adicionales
- crear reporte mensual base con incidentes, vulnerabilidades y cambios
- integrar webhook hacia ticketing o correo para simular escalacion SOC

### Iteracion comercial

- una landing "SOC service" en la demo
- una matriz de cobertura por sector: retail, fintech, salud, manufactura
- playbooks por caso: phishing endpoint, servidor expuesto, web app vulnerable

## Frase de valor recomendada

"Este MVP demuestra como un SOC gestionado con Wazuh puede darle a una empresa visibilidad, deteccion y respuesta inicial sin partir de cero ni depender de herramientas propietarias costosas."
